import 'package:drift/drift.dart';

import '../../core/errors/exceptions.dart';
import '../../core/constants/permission_codes.dart';
import '../../core/money/money.dart';
import '../../core/util/ids.dart';
import '../../shared/database/app_database.dart';
import '../../shared/models/enums.dart';
import 'audit_service.dart';
import 'bonus_calculator.dart';
import 'permission_service.dart';
import 'stock_service.dart';

/// A bonus granted on a purchase line (free goods bonus 1/2/3, gift, ...).
class PurchaseBonusRequest {
  const PurchaseBonusRequest({
    required this.quantityBase,
    this.bonusType = PurchaseBonusType.bonus_1,
    this.note,
  });

  final int quantityBase;
  final PurchaseBonusType bonusType;
  final String? note;
}

class PurchaseLineRequest {
  const PurchaseLineRequest({
    required this.itemId,
    required this.quantityBase,
    required this.unitCostMicros,
    required this.unitTypeId,
    required this.batchNumber,
    this.expiryDate,
    this.productionDate,
    this.discountBasisPoints = 0,
    this.bonuses = const [],
  });

  final String itemId;
  final int quantityBase;
  final int unitCostMicros;

  /// Unit type at purchase time (box/strip/…) — NOT NULL per §4.17.
  final String unitTypeId;
  final String batchNumber;
  final int? expiryDate;
  final int? productionDate;
  final int discountBasisPoints;
  final List<PurchaseBonusRequest> bonuses;
}

class PurchaseRequest {
  const PurchaseRequest({
    required this.invoiceNumber,
    required this.supplierId,
    required this.invoiceDate,
    required this.lines,
    required this.userId,
    this.expectedDate,
    this.paidMicros = 0,
    this.notes,
  });

  final String invoiceNumber;
  final String supplierId;
  final int invoiceDate;
  final List<PurchaseLineRequest> lines;
  final String userId;
  final int? expectedDate;
  final int paidMicros;
  final String? notes;
}

class PurchaseOutcome {
  const PurchaseOutcome({
    required this.invoice,
    required this.lines,
    required this.batches,
  });

  final PurchaseInvoiceRow invoice;
  final List<PurchaseInvoiceItemRow> lines;
  final List<BatchRow> batches;
}

/// Records a received purchase as one atomic transaction (§12, §13, §26):
/// invoice, batch creation (bonus-adjusted effective cost), bonus rows,
/// stock ledger, caches, audit.
class PurchaseService {
  PurchaseService({AuditService? audit, PermissionService? permissions})
      : _audit = audit ?? const AuditService(),
        _permissions = permissions ?? const PermissionService();

  final AuditService _audit;
  final PermissionService _permissions;
  final StockService _stock = const StockService();
  final BonusCalculator _bonus = const BonusCalculator();

  Future<PurchaseOutcome> recordPurchase(
      AppDatabase db, PurchaseRequest request) async {
    if (request.lines.isEmpty) {
      throw ValidationException('فاتورة الشراء بدون أصناف');
    }
    if (request.userId.isEmpty) {
      throw ValidationException('معرف المستخدم مطلوب لفاتورة الشراء');
    }
    await _permissions.requireUserPermission(
        db, request.userId, Perm.purchasesCreate);

    return db.transaction(() async {
      final now = DateTime.now().millisecondsSinceEpoch;
      final invoiceId = newId('piv');

      var subtotalMicros = 0;
      var discountTotalMicros = 0;

      await db.into(db.purchaseInvoices).insert(
            PurchaseInvoicesCompanion.insert(
              id: invoiceId,
              invoiceNumber: request.invoiceNumber,
              purchaseStatus: PurchaseStatus.received,
              supplierId: request.supplierId,
              invoiceDate: request.invoiceDate,
              userId: request.userId,
              expectedDate:
                  request.expectedDate != null ? Value(request.expectedDate!) : const Value(null),
              receivedDate: Value(now),
              paidMicros: Value(request.paidMicros),
              notes: request.notes != null ? Value(request.notes!) : const Value(null),
              createdAt: now,
              updatedAt: now,
            ),
          );

      final lines = <PurchaseInvoiceItemRow>[];
      final batches = <BatchRow>[];

      for (final line in request.lines) {
        final gross = line.unitCostMicros * line.quantityBase;
        final discount = Money.fromUnits(gross)
            .timesRatio(line.discountBasisPoints, 10000)
            .units;
        final paid = gross - discount;
        subtotalMicros += gross;
        discountTotalMicros += discount;

        final calc = _bonus.calculate(
          purchasedQuantityBase: line.quantityBase,
          bonusesBase: [for (final b in line.bonuses) b.quantityBase],
          totalCostMicros: paid,
        );

        final batchId = newId('bat');
        final item = await (db.select(db.items)
              ..where((i) => i.id.equals(line.itemId)))
            .getSingleOrNull();
        final hasExpiry = item?.hasExpiry ?? false;
        final int? expiry;
        if (hasExpiry) {
          expiry = line.expiryDate ?? now + (365 * 24 * 60 * 60 * 1000);
        } else {
          expiry = null;
        }
        await db.into(db.batches).insert(
              BatchesCompanion.insert(
                id: batchId,
                itemId: line.itemId,
                batchNumber: line.batchNumber,
                productionDate: line.productionDate != null
                    ? Value(line.productionDate!)
                    : const Value(null),
                expiryDate: expiry != null ? Value(expiry) : const Value(null),
                originalQuantityBase: calc.effectiveQuantityBase,
                unitCostMicros: Value(calc.effectiveUnitCostMicros),
                supplierId:
                    Value(request.supplierId),
                receivedDate: Value(now),
                notes: line.bonuses.isNotEmpty
                    ? Value('Includes ${calc.bonusQuantityBase} bonus units')
                    : const Value(null),
                createdAt: now,
                updatedAt: now,
              ),
            );

        final lineId = newId('pli');
        await db.into(db.purchaseInvoiceItems).insert(
              PurchaseInvoiceItemsCompanion.insert(
                id: lineId,
                invoiceId: invoiceId,
                itemId: line.itemId,
                batchId: Value(batchId),
                unitTypeId: line.unitTypeId,
                quantityBase: line.quantityBase,
                unitCostMicros: line.unitCostMicros,
                discountBasisPoints: Value(line.discountBasisPoints),
                lineDiscountMicros: Value(discount),
                lineTotalMicros: paid,
                effectiveQuantityBase: calc.effectiveQuantityBase,
                effectiveUnitCostMicros: calc.effectiveUnitCostMicros,
                bonusQuantityBase: Value(calc.bonusQuantityBase),
                createdAt: now,
              ),
            );

        for (final bonus in line.bonuses) {
          await db.into(db.purchaseBonuses).insert(
                PurchaseBonusesCompanion.insert(
                  id: newId('bon'),
                  purchaseInvoiceId: invoiceId,
                  purchaseInvoiceItemId: lineId,
                  itemId: Value(line.itemId),
                  batchId: Value(batchId),
                  bonusQuantityBase: bonus.quantityBase,
                  unitCostMicros: calc.effectiveUnitCostMicros,
                  bonusType: bonus.bonusType,
                  note: bonus.note != null ? Value(bonus.note!) : const Value(null),
                  createdAt: now,
                ),
              );
        }

        await _stock.applyMovement(
          db,
          itemId: line.itemId,
          batchId: batchId,
          movementType: MovementType.purchase,
          quantityBaseSigned: calc.effectiveQuantityBase,
          unitCostMicros: calc.effectiveUnitCostMicros,
          refType: 'purchase_line',
          refId: lineId,
          userId: request.userId,
          note: 'شراء ${request.invoiceNumber}',
          atMillis: now,
        );

        lines.add(await (db.select(db.purchaseInvoiceItems)
                  ..where((i) => i.id.equals(lineId)))
              .getSingle());
        batches.add(await (db.select(db.batches)
                  ..where((b) => b.id.equals(batchId)))
              .getSingle());
      }

      final totalMicros = subtotalMicros - discountTotalMicros;
      await (db.update(db.purchaseInvoices)
            ..where((i) => i.id.equals(invoiceId)))
          .write(
        PurchaseInvoicesCompanion(
          subtotalMicros: Value(subtotalMicros),
          discountTotalMicros: Value(discountTotalMicros),
          totalMicros: Value(totalMicros),
          paidMicros: Value(request.paidMicros),
          remainingMicros: Value(totalMicros - request.paidMicros),
        ),
      );

      await _audit.write(
        db,
        userId: request.userId,
        action: AuditAction.create,
        entityType: 'purchase_invoice',
        entityId: invoiceId,
        after: {'invoice_number': request.invoiceNumber, 'total_micros': totalMicros},
      );

      final savedInvoice = await (db.select(db.purchaseInvoices)
            ..where((i) => i.id.equals(invoiceId)))
          .getSingle();
      return PurchaseOutcome(
        invoice: savedInvoice,
        lines: lines,
        batches: batches,
      );
    });
  }
}