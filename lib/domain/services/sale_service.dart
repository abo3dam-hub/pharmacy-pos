import 'package:drift/drift.dart';

import '../../core/errors/exceptions.dart';
import '../../core/constants/permission_codes.dart';
import '../../core/money/money.dart';
import '../../core/util/ids.dart';
import '../../shared/database/app_database.dart';
import '../../shared/models/enums.dart';
import 'audit_service.dart';
import 'permission_service.dart';
import 'stock_service.dart';

/// One product line requested for sale. Quantity is in base units.
class SaleLineRequest {
  const SaleLineRequest({
    required this.itemId,
    required this.quantityBase,
    required this.unitPriceMicros,
    required this.unitTypeId,
    this.vatRateBasisPoints = 0,
    this.discountBasisPoints = 0,
    this.prescriptionItemId,
    this.partialSaleUnitPriceMicros,
  });

  final String itemId;
  final int quantityBase;
  final int unitPriceMicros;

  /// Unit type at sell time (box/strip/…) — NOT NULL per §4.15.
  final String unitTypeId;
  final int vatRateBasisPoints;
  final int discountBasisPoints;

  /// When dispensing from a prescription, the linked prescription item (Phase 6).
  final String? prescriptionItemId;

  /// When selling a partial-sale item, the pre-calculated unit price per
  /// base-unit from [PartialPriceCalculator]. When null, [unitPriceMicros]
  /// is used as-is (normal full-product sale).
  final int? partialSaleUnitPriceMicros;
}

class SaleRequest {
  const SaleRequest({
    required this.invoiceNumber,
    required this.lines,
    required this.paymentMethod,
    required this.userId,
    this.customerId,
    this.paidMicros = 0,
    this.notes,
    this.saleStatus = SaleStatus.completed,
    this.prescriptionId,
  });

  final String invoiceNumber;
  final List<SaleLineRequest> lines;
  final PaymentMethod paymentMethod;
  final String? customerId;
  final String userId;
  final int paidMicros;
  final String? notes;
  final SaleStatus saleStatus;

  /// When dispensing from a prescription, the linked prescription (Phase 6).
  final String? prescriptionId;
}

class SaleOutcome {
  const SaleOutcome({
    required this.invoice,
    required this.lines,
    required this.movements,
  });

  final SalesInvoiceRow invoice;
  final List<SalesInvoiceItemRow> lines;
  final int movements;
}

/// Records a completed sale as one atomic transaction (§11, §26): FEFO batch
/// deduction, stock ledger, invoice header + batch-linked lines, caches, audit.
///
/// Each sold line is linked to the exact batch it was consumed from (FEFO).
///
/// Partial-sale support (Phase 6): when a line provides
/// [SaleLineRequest.partialSaleUnitPriceMicros], the caller has pre-computed
/// the unit price via [PartialPriceCalculator]. The sale service passes it
/// through to the line item and inventory at the pre-computed rate.
///
/// Prescription dispensing (Phase 6): when `prescriptionId` is provided on the
/// request and/or `prescriptionItemId` on a line, the sale links back to the
/// prescription and updates `dispensedQuantityBase` on the prescription item.
/// The prescription status is automatically updated to `partially_dispensed`
/// or `dispensed` as appropriate.
class SaleService {
  SaleService({
    AuditService? audit,
    PermissionService? permissions,
  })  : _audit = audit ?? const AuditService(),
        _permissions = permissions ?? const PermissionService();

  final AuditService _audit;
  final PermissionService _permissions;
  final StockService _stock = const StockService();

  Future<SaleOutcome> recordSale(AppDatabase db, SaleRequest request) async {
    if (request.lines.isEmpty) {
      throw ValidationException('فاتورة البيع بدون أصناف');
    }
    if (request.userId.isEmpty) {
      throw ValidationException('معرف المستخدم مطلوب لفاتورة البيع');
    }
    if (request.saleStatus == SaleStatus.completed) {
      await _permissions.requireUserPermission(
          db, request.userId, Perm.salesCreate);
    }

    // Validate prescription linkage (Phase 6).
    if (request.prescriptionId != null) {
      final rx = await (db.select(db.prescriptions)
            ..where((p) => p.id.equals(request.prescriptionId!)))
          .getSingleOrNull();
      if (rx == null) {
        throw NotFoundException('الوصفة الطبية غير موجودة: ${request.prescriptionId}');
      }
      if (rx.status != PrescriptionStatus.active &&
          rx.status != PrescriptionStatus.partially_dispensed) {
        throw ValidationException(
            'الوصفة الطبية ليست نشطة (${rx.status.name})');
      }
      // Lines with prescriptionItemId must belong to this prescription.
      for (final line in request.lines) {
        if (line.prescriptionItemId != null) {
          final pi = await (db.select(db.prescriptionItems)
                ..where((p) => p.id.equals(line.prescriptionItemId!)))
              .getSingleOrNull();
          if (pi == null || pi.prescriptionId != request.prescriptionId) {
            throw ValidationException(
                'عنصر الوصفة ${line.prescriptionItemId} لا ينتمي للوصفة ${request.prescriptionId}');
          }
          // Check dispensing capacity.
          final remaining = pi.quantityBase - pi.dispensedQuantityBase;
          if (line.quantityBase > remaining) {
            throw ValidationException(
                'الكمية المطلوبة (${line.quantityBase}) أكبر من المتبقي '
                '($remaining) على عنصر الوصفة');
          }
        }
      }
    }

    return db.transaction(() async {
      final now = DateTime.now().millisecondsSinceEpoch;
      final invoiceId = newId('inv');

      var subtotalMicros = 0;
      var discountTotalMicros = 0;
      var vatTotalMicros = 0;
      var totalCostMicros = 0;
      var profitMicros = 0;
      var movements = 0;
      final lineRows = <SalesInvoiceItemRow>[];

      await db.into(db.salesInvoices).insert(
            SalesInvoicesCompanion.insert(
              id: invoiceId,
              invoiceNumber: request.invoiceNumber,
              invoiceType: InvoiceType.sale,
              saleStatus: request.saleStatus,
              paymentMethod: request.paymentMethod,
              customerId: request.customerId != null
                  ? Value(request.customerId!)
                  : const Value(null),
              userId: request.userId,
              paidMicros: Value(request.paidMicros),
              notes:
                  request.notes != null ? Value(request.notes!) : const Value(null),
              prescriptionId: request.prescriptionId != null
                  ? Value(request.prescriptionId!)
                  : const Value(null),
              createdAt: now,
              updatedAt: now,
            ),
          );

      for (final line in request.lines) {
        final allocations = await _stock.allocateFefo(
            db, line.itemId, line.quantityBase,
            atMillis: now);

        for (final slot in allocations) {
          // Use pre-computed partial-sale price when available, otherwise
          // the standard unit price from the request.
          final effectiveUnitPrice =
              line.partialSaleUnitPriceMicros ?? line.unitPriceMicros;

          final slotGross = effectiveUnitPrice * slot.quantityBase;
          final slotDiscount = Money.fromUnits(slotGross)
              .timesRatio(line.discountBasisPoints, 10000)
              .units;
          final slotNet = slotGross - slotDiscount;
          final slotCost = slot.batch.unitCostMicros * slot.quantityBase;

          subtotalMicros += slotGross;
          discountTotalMicros += slotDiscount;
          totalCostMicros += slotCost;
          profitMicros += slotNet - slotCost;

          final lineId = newId('sli');
          await db.into(db.salesInvoiceItems).insert(
                SalesInvoiceItemsCompanion.insert(
                  id: lineId,
                  invoiceId: invoiceId,
                  itemId: line.itemId,
                  batchId: slot.batch.id,
                  unitTypeId: line.unitTypeId,
                  quantityBaseSigned: slot.quantityBase,
                  unitPriceMicros: effectiveUnitPrice,
                  vatRateBasisPoints: Value(line.vatRateBasisPoints),
                  lineDiscountBasisPoints: Value(line.discountBasisPoints),
                  lineSubtotalMicros: Value(slotGross),
                  lineDiscountMicros: Value(slotDiscount),
                  lineTotalMicros: Value(slotNet),
                  unitCostMicros: Value(slot.batch.unitCostMicros),
                  costTotalMicros: Value(slotCost),
                  profitMicros: Value(slotNet - slotCost),
                  prescriptionItemId: line.prescriptionItemId != null
                      ? Value(line.prescriptionItemId!)
                      : const Value(null),
                  createdAt: now,
                ),
              );
          await _stock.applyMovement(
            db,
            itemId: line.itemId,
            batchId: slot.batch.id,
            movementType: MovementType.sale,
            quantityBaseSigned: -slot.quantityBase,
            unitCostMicros: slot.batch.unitCostMicros,
            refType: 'sale_line',
            refId: lineId,
            userId: request.userId,
            note: 'فاتورة ${request.invoiceNumber}',
            atMillis: now,
          );
          movements += 1;
          lineRows.add(await (db.select(db.salesInvoiceItems)
                    ..where((i) => i.id.equals(lineId)))
                .getSingle());
        }
      }

      vatTotalMicros = _sumVat(request.lines);
      final totalMicros = subtotalMicros - discountTotalMicros + vatTotalMicros;
      if (request.saleStatus == SaleStatus.completed &&
          request.paidMicros < totalMicros) {
        throw InvalidOperationException(
            'المبلغ المدفوع (${request.paidMicros}) أقل من الإجمالي ($totalMicros)');
      }

      await (db.update(db.salesInvoices)..where((i) => i.id.equals(invoiceId)))
          .write(
        SalesInvoicesCompanion(
          subtotalMicros: Value(subtotalMicros),
          discountTotalMicros: Value(discountTotalMicros),
          vatTotalMicros: Value(vatTotalMicros),
          totalMicros: Value(totalMicros),
          totalCostMicros: Value(totalCostMicros),
          profitMicros: Value(profitMicros),
          changeMicros: Value(request.paidMicros - totalMicros),
        ),
      );

      // Update prescription item dispensed quantities (Phase 6).
      if (request.prescriptionId != null) {
        for (final line in request.lines) {
          if (line.prescriptionItemId != null) {
            final pi = await (db.select(db.prescriptionItems)
                  ..where((p) => p.id.equals(line.prescriptionItemId!)))
                .getSingle();
            final newDispensed = pi.dispensedQuantityBase + line.quantityBase;
            final fullyDispensed = newDispensed >= pi.quantityBase;
            await (db.update(db.prescriptionItems)
                  ..where((p) => p.id.equals(line.prescriptionItemId!)))
                .write(
              PrescriptionItemsCompanion(
                dispensedQuantityBase: Value(newDispensed),
                isDispensed: Value(fullyDispensed),
              ),
            );
          }
        }
        // Update prescription header status.
        await _updatePrescriptionStatus(db, request.prescriptionId!);
      }

      if (request.saleStatus == SaleStatus.completed) {
        await _audit.write(
          db,
          userId: request.userId,
          action: AuditAction.create,
          entityType: 'sales_invoice',
          entityId: invoiceId,
          after: {
            'invoice_number': request.invoiceNumber,
            'total_micros': totalMicros,
          },
        );
      }

      final savedInvoice = await (db.select(db.salesInvoices)
            ..where((i) => i.id.equals(invoiceId)))
          .getSingle();
      return SaleOutcome(
        invoice: savedInvoice,
        lines: lineRows,
        movements: movements,
      );
    });
  }

  /// Recalculates and writes the prescription header status based on its
  /// items' dispensed quantities.
  Future<void> _updatePrescriptionStatus(
      AppDatabase db, String prescriptionId) async {
    final items = await (db.select(db.prescriptionItems)
          ..where((p) => p.prescriptionId.equals(prescriptionId)))
        .get();
    if (items.isEmpty) return;

    final allDispensed = items.every((i) => i.dispensedQuantityBase >= i.quantityBase);
    final anyDispensed =
        items.any((i) => i.dispensedQuantityBase > 0);

    PrescriptionStatus newStatus;
    if (allDispensed) {
      newStatus = PrescriptionStatus.dispensed;
    } else if (anyDispensed) {
      newStatus = PrescriptionStatus.partially_dispensed;
    } else {
      return; // No change — still active.
    }

    final now = DateTime.now().millisecondsSinceEpoch;
    await (db.update(db.prescriptions)
          ..where((p) => p.id.equals(prescriptionId)))
        .write(
      PrescriptionsCompanion(
        status: Value(newStatus),
        updatedAt: Value(now),
      ),
    );
  }

  static int _sumVat(List<SaleLineRequest> lines) {
    var vat = 0;
    for (final line in lines) {
      final effectivePrice = line.partialSaleUnitPriceMicros ?? line.unitPriceMicros;
      final gross = effectivePrice * line.quantityBase;
      final discount = Money.fromUnits(gross)
          .timesRatio(line.discountBasisPoints, 10000)
          .units;
      vat += Money.fromUnits(gross - discount)
          .timesRatio(line.vatRateBasisPoints, 10000)
          .units;
    }
    return vat;
  }
}
