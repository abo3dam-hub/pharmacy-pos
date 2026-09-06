import 'package:drift/drift.dart';

import '../../core/errors/exceptions.dart';
import '../../core/constants/permission_codes.dart';
import '../../core/util/ids.dart';
import '../../shared/database/app_database.dart';
import '../../shared/models/enums.dart';
import 'audit_service.dart';
import 'financial_posting_service.dart';
import 'permission_service.dart';
import 'stock_service.dart';

class SaleReturnRequest {
  const SaleReturnRequest({
    required this.returnNumber,
    required this.originalInvoiceItemId,
    required this.quantityBase,
    required this.userId,
    this.reason,
    this.notes,
  });

  /// Sequential return document number.
  final String returnNumber;

  /// The sold line being returned/reversed.
  final String originalInvoiceItemId;

  /// Quantity (base units) to restore to the original batch — always positive.
  final int quantityBase;
  final String userId;
  final String? reason;
  final String? notes;
}

class SaleReturnOutcome {
  const SaleReturnOutcome({required this.returnOrder, required this.returnItem});

  final ReturnRow returnOrder;
  final ReturnItemRow returnItem;
}

/// Sale returns (§14). Standalone return orders restore stock to the *original*
/// batch, reverse the sale line amounts and append ledger + audit rows — all in
/// one transaction. Revenue/cost/profit totals are recorded on the return so
/// the accounting layer can post the reversal (Phase 9).
class ReturnService {
  ReturnService({
    AuditService? audit,
    PermissionService? permissions,
    FinancialPostingService? financial,
  })  : _audit = audit ?? const AuditService(),
        _permissions = permissions ?? const PermissionService(),
        _financial = financial ?? const FinancialPostingService();

  final AuditService _audit;
  final PermissionService _permissions;
  final StockService _stock = const StockService();
  final FinancialPostingService _financial;

  Future<SaleReturnOutcome> recordSaleReturn(
      AppDatabase db, SaleReturnRequest request) async {
    await _permissions.requireUserPermission(
        db, request.userId, Perm.salesReturnCreate);

    if (request.quantityBase <= 0) {
      throw ValidationException(
          'كمية المرتجع يجب أن تكون موجبة (تُعاد للدفعة الأصلية)');
    }

    return db.transaction(() async {
      final now = DateTime.now().millisecondsSinceEpoch;

      final originalLine = await (db.select(db.salesInvoiceItems)
            ..where((i) => i.id.equals(request.originalInvoiceItemId)))
          .getSingleOrNull();
      if (originalLine == null) {
        throw NotFoundException(
            'سطر الفاتورة الأصلي غير موجود: ${request.originalInvoiceItemId}');
      }
      if (originalLine.quantityBaseSigned <= 0) {
        throw InvalidOperationException(
            'لا يمكن إرجاع سطر بيع ليس له كمية موجبة');
      }
      final alreadyReturned = originalLine.returnQuantityBase;
      final available = originalLine.quantityBaseSigned - alreadyReturned;
      if (request.quantityBase > available) {
        throw NotEnoughStockException(
            'كمية المرتجع (${request.quantityBase}) أكبر من المتاح '
            '($available) على السطر الأصلي');
      }

      // The original batch the goods came from.
      final movement = await (db.select(db.stockMovements)
            ..where((m) =>
                m.refType.equals('sale_line') &
                m.refId.equals(request.originalInvoiceItemId)))
          .getSingleOrNull();
      final batchId = movement?.batchId;
      if (batchId == null) {
        throw InvalidOperationException(
            'تعذر تحديد الدفعة الأصلية للسطر المرتجع');
      }
      final batch = await (db.select(db.batches)
            ..where((b) => b.id.equals(batchId)))
          .getSingle();
      final batchNumber = batch.batchNumber;

      // Revenue/cost reversal figures from the original sale line.
      final unitPrice =
          originalLine.unitPriceMicros;
      final unitCost = originalLine.unitCostMicros;
      final reversalMicros = -(request.quantityBase * unitPrice);

      await (db.update(db.salesInvoiceItems)
            ..where((i) => i.id.equals(request.originalInvoiceItemId)))
          .write(
        SalesInvoiceItemsCompanion(
          returnQuantityBase: Value(alreadyReturned + request.quantityBase),
        ),
      );

      final originalInvoice = await (db.select(db.salesInvoices)
            ..where((i) => i.id.equals(originalLine.invoiceId)))
          .getSingleOrNull();
      if (originalInvoice == null) {
        throw NotFoundException(
            'فاتورة البيع الأصلية غير موجودة: ${originalLine.invoiceId}');
      }
      if (originalInvoice.saleStatus == SaleStatus.voided) {
        throw InvalidOperationException(
            'لا يمكن إرجاع أصناف من فاتورة ملغاة (${originalInvoice.invoiceNumber})');
      }

      final returnId = newId('ret');
      await db.into(db.returns).insert(
            ReturnsCompanion.insert(
              id: returnId,
              returnNumber: request.returnNumber,
              type: ReturnType.sale_return,
              originalInvoiceId: originalLine.invoiceId,
              originalInvoiceType: 'sale',
              customerId: originalInvoice.customerId != null
                  ? Value(originalInvoice.customerId!)
                  : const Value(null),
              userId: request.userId,
              totalMicros: Value(reversalMicros),
              reason: request.reason != null ? Value(request.reason!) : const Value(null),
              notes: request.notes != null ? Value(request.notes!) : const Value(null),
              createdAt: now,
              updatedAt: now,
            ),
          );

      final itemId = originalLine.itemId;
      await db.into(db.returnItems).insert(
            ReturnItemsCompanion.insert(
              id: newId('rit'),
              returnId: returnId,
              originalInvoiceItemId: request.originalInvoiceItemId,
              itemId: itemId,
              batchId: batchId,
              quantityBaseSigned: request.quantityBase,
              unitCostMicros: unitCost,
              amountMicros: reversalMicros,
              reason: request.reason != null ? Value(request.reason!) : const Value(null),
              notes: Value(
                  'استرجاع للدفعة الأصلية $batchNumber على فاتورة '
                  '${originalLine.invoiceId}'),
              createdAt: now,
            ),
          );

      await _stock.applyMovement(
        db,
        itemId: itemId,
        batchId: batchId,
        movementType: MovementType.sale_return,
        quantityBaseSigned: request.quantityBase,
        unitCostMicros: unitCost,
        refType: 'return',
        refId: returnId,
        userId: request.userId,
        note: 'مرتجع ${request.returnNumber} إلى الدفعة $batchNumber',
        atMillis: now,
      );

      // Financial reversal (§14): the reversed revenue first offsets any
      // outstanding accounts-receivable on the invoice, the rest is refunded
      // as cash; inventory/cost is restored via the GL.
      final reversalAmount = -reversalMicros;
      final outstanding = (originalInvoice.remainingMicros).clamp(0, reversalAmount);
      final cashRefundMicros = reversalAmount - outstanding;
      await _financial.postReturn(
        db,
        returnId: returnId,
        returnNumber: request.returnNumber,
        invoiceNumber: originalInvoice.invoiceNumber,
        reversalRevenueMicros: reversalAmount,
        costMicros: request.quantityBase * unitCost,
        accountsReceivableOffsetMicros: outstanding,
        refundCashMicros: cashRefundMicros,
        userId: request.userId,
        atMillis: now,
      );

      // Advance the invoice lifecycle: completed → partially/fully returned.
      await _advanceInvoiceStatus(db, originalInvoice.id);

      // Re-derive the customer balance (sale invoice remaining + returns net).
      if (originalInvoice.customerId != null) {
        await _financial.syncCustomerBalance(
            db, originalInvoice.customerId!, at: now);
      }

      await _audit.write(
        db,
        userId: request.userId,
        action: AuditAction.create,
        entityType: 'sale_return',
        entityId: returnId,
        after: {
          'original_line': request.originalInvoiceItemId,
          'quantity_base': request.quantityBase,
          'reversal_micros': reversalMicros,
          'invoice_status': originalInvoice.saleStatus.name,
        },
      );

      // Reverse prescription dispensing if the returned line was from a
      // prescription (Phase 6).
      if (originalLine.prescriptionItemId != null) {
        final pi = await (db.select(db.prescriptionItems)
              ..where((p) =>
                  p.id.equals(originalLine.prescriptionItemId!)))
            .getSingleOrNull();
        if (pi != null) {
          final newDispensed =
              (pi.dispensedQuantityBase - request.quantityBase)
                  .clamp(0, pi.quantityBase);
          final fullyDispensed = newDispensed >= pi.quantityBase;
          await (db.update(db.prescriptionItems)
                ..where((p) =>
                    p.id.equals(originalLine.prescriptionItemId!)))
              .write(
            PrescriptionItemsCompanion(
              dispensedQuantityBase: Value(newDispensed),
              isDispensed: Value(fullyDispensed),
            ),
          );
          // Recheck prescription status.
          await _recheckPrescriptionStatus(
              db, pi.prescriptionId);
        }
      }

      final saved = await (db.select(db.returns)
            ..where((r) => r.id.equals(returnId)))
          .getSingle();
      final line = await (db.select(db.returnItems)
            ..where((r) => r.returnId.equals(returnId)))
          .getSingle();
      return SaleReturnOutcome(returnOrder: saved, returnItem: line);
    });
  }

  /// Recheck and update prescription status after a return.
  Future<void> _recheckPrescriptionStatus(
      AppDatabase db, String prescriptionId) async {
    final items = await (db.select(db.prescriptionItems)
          ..where((p) => p.prescriptionId.equals(prescriptionId)))
        .get();
    if (items.isEmpty) return;

    final allDispensed =
        items.every((i) => i.dispensedQuantityBase >= i.quantityBase);
    final anyDispensed = items.any((i) => i.dispensedQuantityBase > 0);

    PrescriptionStatus newStatus;
    if (allDispensed) {
      newStatus = PrescriptionStatus.dispensed;
    } else if (anyDispensed) {
      newStatus = PrescriptionStatus.partially_dispensed;
    } else {
      newStatus = PrescriptionStatus.active;
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

  /// Advances the invoice sale-status after a partial/full return:
  /// `completed → partially_returned → fully_returned`.
  Future<void> _advanceInvoiceStatus(AppDatabase db, String invoiceId) async {
    final lines = await (db.select(db.salesInvoiceItems)
          ..where((i) => i.invoiceId.equals(invoiceId)))
        .get();
    if (lines.isEmpty) return;

    final allReturned =
        lines.every((l) => l.returnQuantityBase >= l.quantityBaseSigned);
    final anyReturned = lines.any((l) => l.returnQuantityBase > 0);
    if (!anyReturned) return;

    final newStatus =
        allReturned ? SaleStatus.fully_returned : SaleStatus.partially_returned;
    final now = DateTime.now().millisecondsSinceEpoch;
    await (db.update(db.salesInvoices)..where((i) => i.id.equals(invoiceId)))
        .write(
      SalesInvoicesCompanion(
        saleStatus: Value(newStatus),
        updatedAt: Value(now),
      ),
    );
  }
}