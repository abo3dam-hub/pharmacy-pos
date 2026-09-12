import 'package:drift/drift.dart';

import '../../core/errors/exceptions.dart';
import '../../core/constants/permission_codes.dart';
import '../../core/money/money.dart';
import '../../core/util/ids.dart';
import '../../shared/database/app_database.dart';
import '../../shared/models/enums.dart';
import 'audit_service.dart';
import 'financial_posting_service.dart';
import 'permission_service.dart';
import 'stock_service.dart';

/// One product line requested for sale. Quantity is in base units (for
/// FEFO/cost allocation); money is priced per sell unit.
class SaleLineRequest {
  const SaleLineRequest({
    required this.itemId,
    required this.quantityBase,
    required this.unitPriceMicros,
    required this.unitTypeId,
    this.vatRateBasisPoints = 0,
    this.discountBasisPoints = 0,
    this.prescriptionItemId,
    this.quantity,
    this.unitBaseQuantity,
  });

  final String itemId;

  /// Base units consumed for this line (FEFO / cost / stock deduction).
  final int quantityBase;

  /// Price per single SELL unit (integer micro-units). Two-mode pricing lock:
  /// the line gross is `unitPriceMicros × quantity` — a box line carries the
  /// full package price, a part line the partial selling price; the price is
  /// never reconstructed from the base-unit conversion ratio.
  final int unitPriceMicros;

  /// Unit type at sell time (box/strip/…) — NOT NULL per §4.15.
  final String unitTypeId;
  final int vatRateBasisPoints;
  final int discountBasisPoints;

  /// When dispensing from a prescription, the linked prescription item (Phase 6).
  final String? prescriptionItemId;

  /// Number of sell units priced at [unitPriceMicros]. Defaults to
  /// [quantityBase] for legacy callers (sell unit == base unit).
  final int? quantity;

  /// Base quantity per sell unit. Defaults to 1 for legacy callers.
  final int? unitBaseQuantity;
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
    this.cashMicros,
    this.cardMicros,
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

  /// Optional payment split (cash/card components of [paidMicros]). When both
  /// are absent the split is derived from [paymentMethod]; when provided they
  /// must sum to [paidMicros].
  final int? cashMicros;
  final int? cardMicros;
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
/// Two-mode pricing lock (§5): a sale line's money is priced per sell unit —
/// the box at the full package price or the sellable part at the partial
/// selling price (`gross = unitPriceMicros × quantity`) — never reconstructed
/// from the base-unit conversion ratio. The line's exact gross/discount/VAT
/// are partitioned across its FEFO slots (integer, last slot takes the
/// remainder) so the persisted rows always sum to the line totals.
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
    FinancialPostingService? financial,
  })  : _audit = audit ?? const AuditService(),
        _permissions = permissions ?? const PermissionService(),
        _financial = financial ?? const FinancialPostingService();

  final AuditService _audit;
  final PermissionService _permissions;
  final StockService _stock = const StockService();
  final FinancialPostingService _financial;

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
            db, line.itemId, line.quantityBase, atMillis: now);

        // Two-mode pricing lock: money is computed per sell unit — exactly.
        // lineGross = unitPrice × sell units (never reconstructed from the
        // base-unit conversion ratio); discount and VAT are the same
        // half-up line-level rates used by the POS preview.
        final sellUnits = line.quantity ?? line.quantityBase;
        final sellUnitBase = line.unitBaseQuantity ?? 1;
        final lineGross = line.unitPriceMicros * sellUnits;
        final lineDiscount = Money.fromUnits(lineGross)
            .timesRatio(line.discountBasisPoints, 10000)
            .units;
        final lineNet = lineGross - lineDiscount;
        final lineVat = Money.fromUnits(lineNet)
            .timesRatio(line.vatRateBasisPoints, 10000)
            .units;

        // Distribute the line's exact money across its FEFO slots so the rows
        // always sum to the line totals (integer partition, last slot takes the
        // remainder) — no drift through rounding.
        final slotQtys = [for (final s in allocations) s.quantityBase];
        final grossShares = _allocateExact(lineGross, slotQtys);
        final netShares = _allocateExact(lineNet, slotQtys);
        final vatShares = _allocateExact(lineVat, slotQtys);

        for (var i = 0; i < allocations.length; i++) {
          final slot = allocations[i];
          final slotGross = grossShares[i];
          final slotNet = netShares[i];
          final slotDiscount = slotGross - slotNet;
          final slotVat = vatShares[i];
          final slotCost = slot.batch.unitCostMicros * slot.quantityBase;

          subtotalMicros += slotGross;
          discountTotalMicros += slotDiscount;
          vatTotalMicros += slotVat;
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
                  unitBaseQuantity: Value(sellUnitBase),
                  unitPriceMicros: line.unitPriceMicros,
                  vatRateBasisPoints: Value(line.vatRateBasisPoints),
                  lineDiscountBasisPoints: Value(line.discountBasisPoints),
                  lineSubtotalMicros: Value(slotGross),
                  lineDiscountMicros: Value(slotDiscount),
                  taxMicros: Value(slotVat),
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

      final totalMicros = subtotalMicros - discountTotalMicros + vatTotalMicros;

      // Resolve the payment split (cash/card components of paidMicros) and
      // validate settlement rules (Phase 7.5 §11/§12).
      var cashMicros = request.cashMicros;
      var cardMicros = request.cardMicros;
      if (cashMicros == null && cardMicros == null) {
        final paidByCard = request.paymentMethod == PaymentMethod.card;
        cashMicros = paidByCard ? 0 : request.paidMicros;
        cardMicros = paidByCard ? request.paidMicros : 0;
      } else {
        cashMicros ??= 0;
        cardMicros ??= 0;
      }
      if (cashMicros < 0 || cardMicros < 0) {
        throw ValidationException('مبالغ الدفع لا يمكن أن تكون سالبة');
      }
      if (cashMicros + cardMicros != request.paidMicros) {
        throw ValidationException(
            'تقسيم الدفع (نقدي + بطاقة) لا يطابق المبلغ المدفوع '
            '(${request.paidMicros})');
      }

      var creditMicros = 0;
      if (request.saleStatus == SaleStatus.completed) {
        if (request.paymentMethod == PaymentMethod.credit) {
          final customer = request.customerId == null
              ? null
              : await (db.select(db.customers)
                    ..where((c) => c.id.equals(request.customerId!)))
                  .getSingleOrNull();
          if (customer == null) {
            throw InvalidOperationException('البيع الآجل يتطلب عميلاً');
          }
          if (!customer.hasAccount) {
            throw ValidationException(
                'العميل ${customer.name} لا يملك حساباً آجلاً (has_account)');
          }
          creditMicros = totalMicros - request.paidMicros;
          if (creditMicros <= 0) {
            throw InvalidOperationException(
                'البيع الآجل يجب أن يترك رصيداً متبقياً ($creditMicros)');
          }
          if (customer.creditLimitMicros > 0 &&
              customer.balanceMicros + creditMicros > customer.creditLimitMicros) {
            throw ValidationException(
                'تجاوز سقف الائتمان: الرصيد الحالي '
                '${customer.balanceMicros} + الآجل $creditMicros > السقف '
                '${customer.creditLimitMicros}');
          }
        } else if (request.paidMicros < totalMicros) {
          throw InvalidOperationException(
              'المبلغ المدفوع (${request.paidMicros}) أقل من الإجمالي ($totalMicros)');
        }
      }

      final changeMicros =
          request.paidMicros > totalMicros ? request.paidMicros - totalMicros : 0;
      final remainingMicros =
          request.paymentMethod == PaymentMethod.credit ? creditMicros : 0;

      await (db.update(db.salesInvoices)..where((i) => i.id.equals(invoiceId)))
          .write(
        SalesInvoicesCompanion(
          subtotalMicros: Value(subtotalMicros),
          discountTotalMicros: Value(discountTotalMicros),
          vatTotalMicros: Value(vatTotalMicros),
          totalMicros: Value(totalMicros),
          totalCostMicros: Value(totalCostMicros),
          profitMicros: Value(profitMicros),
          paidMicros: Value(request.paidMicros),
          changeMicros: Value(changeMicros),
          remainingMicros: Value(remainingMicros),
          cashMicros: Value(cashMicros),
          cardMicros: Value(cardMicros),
          creditMicros: Value(creditMicros),
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
        // Financial posting: drawer + double-entry journal (atomic).
        await _financial.postSale(
          db,
          invoiceId: invoiceId,
          invoiceNumber: request.invoiceNumber,
          totalMicros: totalMicros,
          costMicros: totalCostMicros,
          cashMicros: cashMicros,
          cardMicros: cardMicros,
          creditMicros: creditMicros,
          changeMicros: changeMicros,
          userId: request.userId,
          atMillis: now,
        );
        if (request.customerId != null) {
          await _financial.syncCustomerBalance(db, request.customerId!, at: now);
        }
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

  /// Partitions [total] across positive [weights] so the shares always sum to
  /// exactly [total]: each share gets `total ~/ weightSum` × its weight plus a
  /// half-up proportional slice of the integer remainder (the last share takes
  /// any leftover). Keeps per-row money in exact agreement with the line totals
  /// across FEFO slots without floating point.
  static List<int> _allocateExact(int total, List<int> weights) {
    final weightSum = weights.fold<int>(0, (a, b) => a + b);
    if (weightSum <= 0) return List.filled(weights.length, 0);
    final whole = total ~/ weightSum;
    var remainder = total - whole * weightSum;
    final shares = [for (final w in weights) whole * w];
    for (var i = 0; i < weights.length && remainder > 0; i++) {
      final carry = (remainder * weights[i] + weightSum ~/ 2) ~/ weightSum;
      final amount = carry.clamp(0, remainder);
      shares[i] += amount;
      remainder -= amount;
    }
    if (remainder != 0) {
      shares[weights.length - 1] += remainder;
    }
    return shares;
  }

  /// Voids a completed, never-returned invoice (§19): the invoice row is kept
  /// and flagged `voided` (never physically deleted) while stock, drawer,
  /// journal entries, prescription quantities and the customer balance are
  /// reversed in one atomic transaction. Requires `sales.void` permission and
  /// a mandatory reason.
  Future<SalesInvoiceRow> voidInvoice(
    AppDatabase db, {
    required String invoiceId,
    required String userId,
    required String reason,
  }) async {
    await _permissions.requireUserPermission(db, userId, Perm.salesVoid);
    if (reason.trim().isEmpty) {
      throw ValidationException('سبب إلغاء الفاتورة مطلوب');
    }

    return db.transaction(() async {
      final now = DateTime.now().millisecondsSinceEpoch;

      final invoice = await (db.select(db.salesInvoices)
            ..where((i) => i.id.equals(invoiceId)))
          .getSingleOrNull();
      if (invoice == null) {
        throw NotFoundException('الفاتورة غير موجودة: $invoiceId');
      }
      if (invoice.saleStatus != SaleStatus.completed) {
        throw InvalidOperationException(
            'لا يمكن إلغاء فاتورة بحالة ${invoice.saleStatus.name}');
      }

      final lines = await (db.select(db.salesInvoiceItems)
            ..where((i) => i.invoiceId.equals(invoiceId)))
          .get();
      if (lines.isEmpty) {
        throw InvalidOperationException('لا يمكن إلغاء فاتورة بدون بنود');
      }
      if (lines.any((l) => l.returnQuantityBase > 0)) {
        throw InvalidOperationException(
            'لا يمكن إلغاء فاتورة عليها مرتجع (عائدات جزئية/كلية)');
      }

      // 1. Restore stock to the same batches the sale consumed.
      for (final line in lines) {
        await _stock.applyMovement(
          db,
          itemId: line.itemId,
          batchId: line.batchId,
          movementType: MovementType.sale_return,
          quantityBaseSigned: line.quantityBaseSigned,
          unitCostMicros: line.unitCostMicros,
          refType: 'sale_void',
          refId: invoiceId,
          userId: userId,
          note: 'إلغاء فاتورة ${invoice.invoiceNumber}',
          atMillis: now,
        );
      }

      // 2. Reverse prescription dispensing (Phase 6).
      if (invoice.prescriptionId != null) {
        for (final line in lines.where((l) => l.prescriptionItemId != null)) {
          await _reversePrescriptionDispensing(db, line);
        }
        await _updatePrescriptionStatus(db, invoice.prescriptionId!);
      }

      // 3. Reversal of drawer + journal and the outstanding AR.
      final drawerNet = invoice.cashMicros - invoice.changeMicros;
      await _financial.postVoidReversal(
        db,
        invoiceId: invoiceId,
        invoiceNumber: invoice.invoiceNumber,
        totalMicros: invoice.totalMicros,
        costMicros: invoice.totalCostMicros,
        drawerNetMicros: drawerNet < 0 ? 0 : drawerNet,
        cardMicros: invoice.cardMicros,
        creditMicros: invoice.creditMicros,
        userId: userId,
        atMillis: now,
      );

      // 4. Flag the invoice as voided — never delete.
      await (db.update(db.salesInvoices)..where((i) => i.id.equals(invoiceId)))
          .write(
        SalesInvoicesCompanion(
          saleStatus: Value(SaleStatus.voided),
          voidReason: Value(reason.trim()),
          voidedBy: Value(userId),
          voidedAt: Value(now),
          updatedAt: Value(now),
        ),
      );

      // 5. Re-derive the customer balance (voided invoices drop out of the
      //    ledger feed).
      if (invoice.customerId != null) {
        await _financial.syncCustomerBalance(db, invoice.customerId!, at: now);
      }

      // 6. Audit the void.
      await _audit.write(
        db,
        userId: userId,
        action: AuditAction.voidOrder,
        entityType: 'sales_invoice',
        entityId: invoiceId,
        before: {
          'sale_status': invoice.saleStatus.name,
          'total_micros': invoice.totalMicros,
          'paid_micros': invoice.paidMicros,
        },
        after: {
          'sale_status': 'voided',
          'reason': reason.trim(),
          'voided_by': userId,
        },
      );

      return (await (db.select(db.salesInvoices)
            ..where((i) => i.id.equals(invoiceId)))
          .getSingle());
    });
  }

  /// Reverses the dispensed quantity of one returned/voided sale line.
  Future<void> _reversePrescriptionDispensing(
      AppDatabase db, SalesInvoiceItemRow line) async {
    if (line.prescriptionItemId == null) return;
    final pi = await (db.select(db.prescriptionItems)
          ..where((p) => p.id.equals(line.prescriptionItemId!)))
        .getSingleOrNull();
    if (pi == null) return;
    final newDispensed =
        (pi.dispensedQuantityBase - line.quantityBaseSigned).clamp(0, pi.quantityBase);
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
