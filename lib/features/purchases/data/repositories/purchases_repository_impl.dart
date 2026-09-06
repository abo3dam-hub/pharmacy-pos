import 'package:drift/drift.dart';

import '../../../../core/data_grid/page_request.dart';
import '../../../../core/errors/exceptions.dart';
import '../../../../core/money/money.dart';
import '../../../../core/util/ids.dart';
import '../../../../data/daos/purchase_dao.dart';
import '../../../../data/daos/supplier_dao.dart';
import '../../../../domain/services/audit_service.dart';
import '../../../../domain/services/bonus_calculator.dart';
import '../../../../domain/services/stock_service.dart';
import '../../../../shared/database/app_database.dart';
import '../../../../shared/models/enums.dart';
import '../../domain/repositories/purchases_repository.dart';

/// Drift-backed [PurchasesRepository].
///
/// Design (documented in PHASE4-REPORT.md):
/// * creating an invoice only records a `pending` document — no batches, no
///   stock yet; lines carry `effective_* = paid` as placeholders;
/// * receiving (in one transaction) creates batches, resolves bonuses via the
///   [BonusCalculator], posts `purchase` ledger movements, optionally updates
///   master pricing (guarded by `lock_auto_price_update` + audited) and
///   re-derives the supplier balance;
/// * `purchase_bonuses` rows exist from creation with `batchId` NULL and get
///   their batch/effective cost on receive;
/// * Buy A Get B bonuses get their own batch + own `purchase` movement at
///   cost 0 inside the same transaction (§13).
class PurchasesRepositoryImpl implements PurchasesRepository {
  const PurchasesRepositoryImpl(
    this._db,
    this._dao,
    this._suppliers,
    this._bonus,
    this._stock,
    this._audit,
  );

  final AppDatabase _db;
  final PurchaseDao _dao;
  final SupplierDao _suppliers;
  final BonusCalculator _bonus;
  final StockService _stock;
  final AuditService _audit;

  @override
  AppDatabase get database => _db;

  @override
  Future<PurchaseInvoiceRow> createPending(
    PurchaseDraft draft, {
    required String actingUserId,
    required String actingRoleId,
  }) {
    _validateDraft(draft, actingUserId);
    return _db.transaction(() async =>
        _writeInvoice(newId: true, draft: draft, actingUserId: actingUserId));
  }

  @override
  Future<PurchaseInvoiceRow> updatePending(
    String invoiceId,
    PurchaseDraft draft, {
    required String actingUserId,
    required String actingRoleId,
  }) {
    _validateDraft(draft, actingUserId);
    return _db.transaction(() async {
      final existing = await _findInvoice(invoiceId);
      if (existing.purchaseStatus != PurchaseStatus.pending) {
        throw InvalidOperationException(
            'لا يمكن تعديل فاتورة شراء بعد استلامها أو إلغائها');
      }
      if (draft.lines.isEmpty) {
        throw ValidationException('فاتورة الشراء بدون أصناف');
      }
      await (_db.delete(_db.purchaseBonuses)
            ..where((b) => b.purchaseInvoiceId.equals(invoiceId)))
          .go();
      await (_db.delete(_db.purchaseInvoiceItems)
            ..where((l) => l.invoiceId.equals(invoiceId)))
          .go();
      return _writeInvoice(
          newId: false, draft: draft, actingUserId: actingUserId, id: invoiceId);
    });
  }

  /// Shared header+lines writer used by create and update.
  Future<PurchaseInvoiceRow> _writeInvoice({
    required bool newId,
    required PurchaseDraft draft,
    required String actingUserId,
    String? id,
  }) async {
    final now = DateTime.now().millisecondsSinceEpoch;
    final invoiceId = id ?? PurchaseDao.newInvoiceId();

    final inUse = await (_db.select(_db.purchaseInvoices)
          ..where((i) => i.invoiceNumber.equals(draft.invoiceNumber.trim())))
        .getSingleOrNull();
    if (inUse != null && inUse.id != invoiceId) {
      throw DuplicateException('رقم فاتورة الشراء مستخدم مسبقاً');
    }

    const taxMicros = 0;
    const shippingMicros = 0;
    var subtotalMicros = 0;
    var discountTotalMicros = 0;
    for (final line in draft.lines) {
      subtotalMicros += line.unitCostMicros * line.quantityBase;
      discountTotalMicros += _lineDiscount(line);
    }
    final totalMicros = subtotalMicros - discountTotalMicros;
    if (draft.paidMicros < 0 || draft.paidMicros > totalMicros) {
      throw ValidationException('المبلغ المدفوع لا يمكن أن يتجاوز الإجمالي');
    }

    if (newId) {
      await _db.into(_db.purchaseInvoices).insert(
            PurchaseInvoicesCompanion.insert(
              id: invoiceId,
              invoiceNumber: draft.invoiceNumber.trim(),
              purchaseStatus: PurchaseStatus.pending,
              supplierId: draft.supplierId,
              userId: draft.userId,
              invoiceDate: draft.invoiceDate,
              expectedDate: draft.expectedDate != null
                  ? Value(draft.expectedDate!)
                  : const Value(null),
              receivedDate: const Value(null),
              subtotalMicros: Value(subtotalMicros),
              discountTotalMicros: Value(discountTotalMicros),
              taxTotalMicros: Value(taxMicros),
              shippingMicros: Value(shippingMicros),
              totalMicros: Value(totalMicros),
              paidMicros: Value(draft.paidMicros),
              remainingMicros: Value(totalMicros - draft.paidMicros),
              notes:
                  draft.notes != null ? Value(draft.notes!) : const Value(null),
              createdAt: now,
              updatedAt: now,
            ),
          );
    } else {
      await (_db.update(_db.purchaseInvoices)
            ..where((i) => i.id.equals(invoiceId)))
          .write(
        PurchaseInvoicesCompanion(
          invoiceNumber: Value(draft.invoiceNumber.trim()),
          purchaseStatus: Value(PurchaseStatus.pending),
          supplierId: Value(draft.supplierId),
          userId: Value(draft.userId),
          invoiceDate: Value(draft.invoiceDate),
          expectedDate: draft.expectedDate != null
              ? Value(draft.expectedDate!)
              : const Value(null),
          receivedDate: const Value(null),
          subtotalMicros: Value(subtotalMicros),
          discountTotalMicros: Value(discountTotalMicros),
          taxTotalMicros: Value(taxMicros),
          shippingMicros: Value(shippingMicros),
          totalMicros: Value(totalMicros),
          paidMicros: Value(draft.paidMicros),
          remainingMicros: Value(totalMicros - draft.paidMicros),
          notes: draft.notes != null ? Value(draft.notes!) : const Value(null),
          updatedAt: Value(now),
        ),
      );
    }

    for (final line in draft.lines) {
      final lineId = PurchaseDao.newLineId();
      final gross = line.unitCostMicros * line.quantityBase;
      final discount = _lineDiscount(line);
      await _db.into(_db.purchaseInvoiceItems).insert(
            PurchaseInvoiceItemsCompanion.insert(
              id: lineId,
              invoiceId: invoiceId,
              itemId: line.itemId,
              batchId: const Value(null),
              unitTypeId: line.unitTypeId,
              quantityBase: line.quantityBase,
              unitCostMicros: line.unitCostMicros,
              discountBasisPoints: Value(line.discountBasisPoints),
              lineDiscountMicros: Value(discount),
              lineTotalMicros: gross - discount,
              taxMicros: const Value(0),
              effectiveQuantityBase: line.quantityBase,
              effectiveUnitCostMicros: line.unitCostMicros,
              bonusQuantityBase: const Value(0),
              notes: const Value(null),
              createdAt: now,
            ),
          );

      for (final bonus in line.bonuses) {
        await _db.into(_db.purchaseBonuses).insert(
              PurchaseBonusesCompanion.insert(
                id: PurchaseDao.newBonusId(),
                purchaseInvoiceId: invoiceId,
                purchaseInvoiceItemId: lineId,
                itemId: bonus.itemId != null ? Value(bonus.itemId) : const Value(null),
                batchId: const Value(null),
                bonusQuantityBase: bonus.quantityBase,
                unitCostMicros: 0,
                bonusType: bonus.bonusType,
                note: bonus.note != null ? Value(bonus.note!) : const Value(null),
                createdAt: now,
              ),
            );
      }
    }

    await _audit.write(
      _db,
      userId: actingUserId,
      action: AuditAction.create,
      entityType: 'purchase_invoice',
      entityId: invoiceId,
      after: {
        'invoice_number': draft.invoiceNumber.trim(),
        'status': 'pending',
        'total_micros': totalMicros,
        'lines': draft.lines.length,
      },
      note: 'إنشاء فاتورة شراء معلّقة',
    );
    return _dao.invoiceById(invoiceId).then((v) => v!.invoice);
  }

  @override
  Future<PurchaseInvoiceRow> receive(
    String invoiceId, {
    required List<ReceiveLineInput> inputs,
    required String actingUserId,
    required String actingRoleId,
  }) {
    return _db.transaction(() async {
      final invoice = await _findInvoice(invoiceId);
      if (invoice.purchaseStatus != PurchaseStatus.pending) {
        throw InvalidOperationException('الفواتير المستلمة أو الملغاة لا تُستلم');
      }
      final lines = await _dao.linesForInvoice(invoiceId);
      if (lines.isEmpty) {
        throw ValidationException('فاتورة الشراء بدون أصناف');
      }
      if (inputs.length != lines.length) {
        throw ValidationException('أدخل رقم التشغيلة لكل سطر في الفاتورة');
      }
      final byLine = {for (final i in inputs) i.lineId: i};
      for (final l in lines) {
        if (!byLine.containsKey(l.line.id)) {
          throw ValidationException('تفاصيل الاستلام ناقصة');
        }
        final input = byLine[l.line.id]!;
        if (input.batchNumber.trim().isEmpty) {
          throw ValidationException('رقم التشغيلة مطلوب');
        }
      }
      final bonusViews = await _dao.bonusesForInvoice(invoiceId);
      final bonusesByLine = <String, List<PurchaseBonusRow>>{};
      for (final bv in bonusViews) {
        bonusesByLine
            .putIfAbsent(bv.bonus.purchaseInvoiceItemId, () => [])
            .add(bv.bonus);
      }

      final now = DateTime.now().millisecondsSinceEpoch;
      final changedItems = <String>[];

      for (final l in lines) {
        final input = byLine[l.line.id]!;
        final line = l.line;
        final item = await (_db.select(_db.items)
              ..where((x) => x.id.equals(line.itemId)))
            .getSingleOrNull();
        if (item == null) {
          throw NotFoundException('المنتج رقم ${line.itemId} غير موجود');
        }
        final lineBonuses = bonusesByLine[line.id] ?? const <PurchaseBonusRow>[];
        final sameItem = [
          for (final b in lineBonuses)
            if (b.itemId == null || b.itemId == line.itemId) b
        ];
        final diffItem = [
          for (final b in lineBonuses)
            if (b.itemId != null && b.itemId != line.itemId) b
        ];
        final gross = line.unitCostMicros * line.quantityBase;
        final paid = gross - _lineDiscountFor(line);
        final calc = _bonus.calculate(
          purchasedQuantityBase: line.quantityBase,
          bonusesBase: [for (final b in sameItem) b.bonusQuantityBase],
          totalCostMicros: paid,
        );

        final batchId = await _createBatch(
          itemId: line.itemId,
          batchNumber: input.batchNumber,
          originalQuantityBase: calc.effectiveQuantityBase,
          unitCostMicros: calc.effectiveUnitCostMicros,
          bonusQtyBase: calc.bonusQuantityBase,
          expiry: input.expiryDate,
          itemHasExpiry: item.hasExpiry,
          supplierId: invoice.supplierId,
          receivedAt: now,
          note: 'شراء ${invoice.invoiceNumber}',
        );

        await (_db.update(_db.purchaseInvoiceItems)
              ..where((x) => x.id.equals(line.id)))
            .write(
          PurchaseInvoiceItemsCompanion(
            batchId: Value(batchId),
            effectiveQuantityBase: Value(calc.effectiveQuantityBase),
            effectiveUnitCostMicros: Value(calc.effectiveUnitCostMicros),
            bonusQuantityBase: Value(calc.bonusQuantityBase),
          ),
        );

        for (final b in sameItem) {
          await (_db.update(_db.purchaseBonuses)
                ..where((x) => x.id.equals(b.id)))
              .write(
            PurchaseBonusesCompanion(
              batchId: Value(batchId),
              unitCostMicros: Value(calc.effectiveUnitCostMicros),
            ),
          );
        }

        for (final b in diffItem) {
          final bonusItem = await (_db.select(_db.items)
                ..where((x) => x.id.equals(b.itemId!)))
              .getSingleOrNull();
          final bonusBatchId = await _createBatch(
            itemId: b.itemId!,
            batchNumber: input.batchNumber,
            originalQuantityBase: b.bonusQuantityBase,
            unitCostMicros: 0,
            bonusQtyBase: 0,
            expiry: input.expiryDate,
            itemHasExpiry: bonusItem?.hasExpiry ?? false,
            supplierId: invoice.supplierId,
            receivedAt: now,
            note: 'هدية Buy A Get B — ${invoice.invoiceNumber}',
          );
          await (_db.update(_db.purchaseBonuses)
                ..where((x) => x.id.equals(b.id)))
              .write(
            PurchaseBonusesCompanion(
              batchId: Value(bonusBatchId),
              unitCostMicros: Value(0),
            ),
          );
          await _stock.applyMovement(
            _db,
            itemId: b.itemId!,
            batchId: bonusBatchId,
            movementType: MovementType.purchase,
            quantityBaseSigned: b.bonusQuantityBase,
            unitCostMicros: 0,
            refType: 'purchase_bonus',
            refId: b.id,
            userId: actingUserId,
            note: 'هدية على ${invoice.invoiceNumber}',
            atMillis: now,
          );
          await _audit.write(
            _db,
            userId: actingUserId,
            action: AuditAction.create,
            entityType: 'batch',
            entityId: bonusBatchId,
            after: {
              'item_id': b.itemId,
              'batch_number': input.batchNumber,
              'quantity_base': b.bonusQuantityBase,
              'unit_cost_micros': 0,
            },
            note: 'تشغيلة هدية (Buy A Get B) — ${invoice.invoiceNumber}',
          );
        }

        await _stock.applyMovement(
          _db,
          itemId: line.itemId,
          batchId: batchId,
          movementType: MovementType.purchase,
          quantityBaseSigned: calc.effectiveQuantityBase,
          unitCostMicros: calc.effectiveUnitCostMicros,
          refType: 'purchase_line',
          refId: line.id,
          userId: actingUserId,
          note: 'شراء ${invoice.invoiceNumber}',
          atMillis: now,
        );

        await _audit.write(
          _db,
          userId: actingUserId,
          action: AuditAction.create,
          entityType: 'batch',
          entityId: batchId,
          after: {
            'item_id': line.itemId,
            'batch_number': input.batchNumber,
            'quantity_base': calc.effectiveQuantityBase,
            'unit_cost_micros': calc.effectiveUnitCostMicros,
            'bonus_quantity_base': calc.bonusQuantityBase,
          },
          note: 'تشغيلة عند استلام ${invoice.invoiceNumber}',
        );

        if (!item.lockAutoPriceUpdate &&
            item.costMicros != calc.effectiveUnitCostMicros) {
          final before = {
            'cost_micros': item.costMicros,
            'profit_margin_basis_points': item.profitMarginBasisPoints,
          };
          await (_db.update(_db.items)..where((x) => x.id.equals(item.id))).write(
            ItemsCompanion(
              costMicros: Value(calc.effectiveUnitCostMicros),
              profitMarginBasisPoints:
                  Value(_marginFor(calc.effectiveUnitCostMicros, item.sellingPriceMicros)),
              updatedAt: Value(now),
            ),
          );
          await _audit.write(
            _db,
            userId: actingUserId,
            action: AuditAction.priceChange,
            entityType: 'item',
            entityId: item.id,
            before: before,
            after: {
              'cost_micros': calc.effectiveUnitCostMicros,
              'profit_margin_basis_points':
                  _marginFor(calc.effectiveUnitCostMicros, item.sellingPriceMicros),
            },
            note: 'تحديث تلقائي من فاتورة شراء ${invoice.invoiceNumber}',
          );
          changedItems.add(item.id);
        }
      }

      await (_db.update(_db.purchaseInvoices)
            ..where((i) => i.id.equals(invoiceId)))
          .write(
        PurchaseInvoicesCompanion(
          purchaseStatus: Value(PurchaseStatus.received),
          receivedDate: Value(now),
          isVoided: const Value(false),
          updatedAt: Value(now),
        ),
      );
      await _suppliers.syncBalance(invoice.supplierId, at: now);

      await _audit.write(
        _db,
        userId: actingUserId,
        action: AuditAction.update,
        entityType: 'purchase_invoice',
        entityId: invoiceId,
        before: {'status': 'pending'},
        after: {
          'status': 'received',
          'received_date': now,
          'batches_created': lines.length,
          'prices_updated': changedItems.length,
        },
        note: 'استلام فاتورة شراء ${invoice.invoiceNumber}',
      );

      return _dao.invoiceById(invoiceId).then((v) => v!.invoice);
    });
  }

  @override
  Future<PurchaseInvoiceRow> cancel(
    String invoiceId, {
    required String actingUserId,
    required String actingRoleId,
    String? reason,
  }) {
    return _db.transaction(() async {
      final invoice = await _findInvoice(invoiceId);
      if (invoice.purchaseStatus != PurchaseStatus.pending) {
        throw InvalidOperationException('يمكن إلغاء الفاتورة المعلّقة فقط');
      }
      final now = DateTime.now().millisecondsSinceEpoch;
      await (_db.update(_db.purchaseInvoices)
            ..where((i) => i.id.equals(invoiceId)))
          .write(
        PurchaseInvoicesCompanion(
          purchaseStatus: Value(PurchaseStatus.cancelled),
          isVoided: Value(true),
          updatedAt: Value(now),
          notes: reason != null ? Value(reason) : const Value.absent(),
        ),
      );
      await _audit.write(
        _db,
        userId: actingUserId,
        action: AuditAction.voidOrder,
        entityType: 'purchase_invoice',
        entityId: invoiceId,
        before: {'status': 'pending'},
        after: {'status': 'cancelled', 'reason': reason},
        note: 'إلغاء فاتورة شراء ${invoice.invoiceNumber}: $reason',
      );
      return _dao.invoiceById(invoiceId).then((v) => v!.invoice);
    });
  }

  @override
  Future<PurchaseReturnOutcome> recordReturn(PurchaseReturnRequest request) {
    return _db.transaction(() async {
      final invoice = await _findInvoice(request.invoiceId);
      if (invoice.purchaseStatus != PurchaseStatus.received || invoice.isVoided) {
        throw InvalidOperationException(
            'لا يمكن إرجاع إلا فاتورة شراء مستلمة وغير ملغاة');
      }
      if (request.lines.isEmpty) {
        throw ValidationException('المرتجع بدون أصناف');
      }
      if (request.userId.isEmpty) {
        throw ValidationException('معرف المستخدم مطلوب للمرتجع');
      }
      final now = DateTime.now().millisecondsSinceEpoch;
      var totalMicros = 0;
      final lines = <ReturnItemRow>[];
      final returnId = PurchaseDao.newReturnId();

      for (final rl in request.lines) {
        if (rl.quantityBase <= 0) {
          throw ValidationException('كمية المرتجع يجب أن تكون موجبة');
        }
        final line = await _dao.lineById(rl.lineId);
        if (line == null || line.invoiceId != request.invoiceId) {
          throw NotFoundException('سطر الفاتورة غير موجود في الفاتورة المحددة');
        }
        final available = await _dao.availableToReturn(rl.lineId);
        if (rl.quantityBase > available) {
          throw NotEnoughStockException(
              'كمية المرتجع (${rl.quantityBase}) أكبر من المتاح ($available) '
              'على السطر ${rl.lineId}');
        }
        final batch = await (_db.select(_db.batches)
              ..where((b) => b.id.equals(line.batchId!)))
            .getSingle();
        final amountMicros = -(rl.quantityBase * batch.unitCostMicros);
        totalMicros += amountMicros;
        final returnItemId = newId('rit');
        await _db.into(_db.returnItems).insert(
              ReturnItemsCompanion.insert(
                id: returnItemId,
                returnId: returnId,
                originalInvoiceItemId: rl.lineId,
                itemId: line.itemId,
                batchId: line.batchId!,
                quantityBaseSigned: -rl.quantityBase,
                unitCostMicros: batch.unitCostMicros,
                amountMicros: amountMicros,
                reason:
                    request.reason != null ? Value(request.reason!) : const Value(null),
                notes: Value('مرتجع إلى المورد على دفعة ${batch.batchNumber}'),
                createdAt: now,
              ),
            );
        await _stock.applyMovement(
          _db,
          itemId: line.itemId,
          batchId: line.batchId!,
          movementType: MovementType.purchase_return,
          quantityBaseSigned: -rl.quantityBase,
          unitCostMicros: batch.unitCostMicros,
          refType: 'return',
          refId: returnId,
          userId: request.userId,
          note: 'مرتجع ${request.returnNumber} من دفعة ${batch.batchNumber}',
          atMillis: now,
        );
        lines.add(await (_db.select(_db.returnItems)
              ..where((r) => r.id.equals(returnItemId)))
            .getSingle());
      }

      await _db.into(_db.returns).insert(
            ReturnsCompanion.insert(
              id: returnId,
              returnNumber: request.returnNumber.trim(),
              type: ReturnType.purchase_return,
              originalInvoiceId: request.invoiceId,
              originalInvoiceType: 'purchase',
              supplierId: Value(invoice.supplierId),
              userId: request.userId,
              totalMicros: Value(totalMicros),
              status: Value('completed'),
              reason: request.reason != null ? Value(request.reason!) : const Value(null),
              notes: request.notes != null ? Value(request.notes!) : const Value(null),
              createdAt: now,
              updatedAt: now,
            ),
          );
      await _suppliers.syncBalance(invoice.supplierId, at: now);

      await _audit.write(
        _db,
        userId: request.userId,
        action: AuditAction.create,
        entityType: 'purchase_return',
        entityId: returnId,
        after: {
          'return_number': request.returnNumber,
          'invoice_id': request.invoiceId,
          'total_micros': totalMicros,
          'lines': lines.length,
        },
        note: 'مرتجع مشتريات ${request.returnNumber}',
      );

      final saved = await (_db.select(_db.returns)..where((r) => r.id.equals(returnId)))
          .getSingle();
      return PurchaseReturnOutcome(returnOrder: saved, returnLines: lines);
    });
  }

  @override
  Future<PageResult<PurchaseInvoiceView>> search(
    PageRequest page, {
    String? supplierId,
    PurchaseStatus? status,
    DateTime? fromDate,
    DateTime? toDate,
  }) =>
      _dao.search(page,
          supplierId: supplierId, status: status, fromDate: fromDate, toDate: toDate);

  @override
  Future<PurchaseDetailView> detail(String invoiceId) async {
    final header = await _dao.invoiceById(invoiceId);
    if (header == null) {
      throw NotFoundException('فاتورة الشراء غير موجودة: $invoiceId');
    }
    return PurchaseDetailView(
      invoice: header.invoice,
      supplierName: header.supplierName,
      lines: await _dao.linesForInvoice(invoiceId),
      bonuses: await _dao.bonusesForInvoice(invoiceId),
    );
  }

  @override
  Future<int> availableToReturn(String lineId) => _dao.availableToReturn(lineId);

  // ---- helpers ----

  Future<PurchaseInvoiceRow> _findInvoice(String invoiceId) async {
    final view = await _dao.invoiceById(invoiceId);
    if (view == null) {
      throw NotFoundException('فاتورة الشراء غير موجودة: $invoiceId');
    }
    return view.invoice;
  }

  /// Creates a batch for receive (§4.8): (item_id, batch_number) is unique, so
  /// duplicates are rejected explicitly before the constraint is hit.
  Future<String> _createBatch({
    required String itemId,
    required String batchNumber,
    required int originalQuantityBase,
    required int unitCostMicros,
    required int bonusQtyBase,
    required int? expiry,
    required bool itemHasExpiry,
    required String supplierId,
    required int receivedAt,
    required String note,
  }) async {
    final dup = await (_db.select(_db.batches)
          ..where((b) =>
              b.itemId.equals(itemId) & b.batchNumber.equals(batchNumber.trim())))
        .getSingleOrNull();
    if (dup != null) {
      throw InvalidOperationException(
          'رقم التشغيلة "$batchNumber" موجود مسبقاً لهذا المنتج على دفعة ${dup.id}');
    }
    final effectiveExpiry = itemHasExpiry
        ? (expiry ?? receivedAt + 365 * 24 * 60 * 60 * 1000)
        : null;
    final id = PurchaseDao.newBatchId();
    await _db.into(_db.batches).insert(
          BatchesCompanion.insert(
            id: id,
            itemId: itemId,
            batchNumber: batchNumber.trim(),
            productionDate: const Value(null),
            expiryDate: effectiveExpiry != null ? Value(effectiveExpiry) : const Value(null),
            quantityBase: const Value(0),
            originalQuantityBase: originalQuantityBase,
            unitCostMicros: Value(unitCostMicros),
            bonusQtyBase: Value(bonusQtyBase),
            supplierId: Value(supplierId),
            receivedDate: Value(receivedAt),
            notes: note.isNotEmpty ? Value(note) : const Value(null),
            createdAt: receivedAt,
            updatedAt: receivedAt,
          ),
        );
    return id;
  }

  static int _lineDiscount(PurchaseLineDraft line) {
    final gross = line.unitCostMicros * line.quantityBase;
    return Money.fromUnits(gross)
        .timesRatio(line.discountBasisPoints, 10000)
        .units;
  }

  static int _lineDiscountFor(PurchaseInvoiceItemRow line) => line.lineDiscountMicros;

  static int _marginFor(int costMicros, int sellingMicros) {
    if (costMicros <= 0) return 0;
    final diff = Money.fromUnits(sellingMicros) - Money.fromUnits(costMicros);
    return diff.timesRatio(10000, costMicros).units;
  }

  void _validateDraft(PurchaseDraft draft, String actingUserId) {
    if (actingUserId.isEmpty) {
      throw UnauthorizedException('بيانات المستخدم ناقصة للتسجيل');
    }
    if (draft.lines.isEmpty) {
      throw ValidationException('فاتورة الشراء بدون أصناف');
    }
    if (draft.supplierId.isEmpty) {
      throw ValidationException('المورد مطلوب');
    }
    if (draft.invoiceNumber.trim().isEmpty) {
      throw ValidationException('رقم فاتورة الشراء مطلوب');
    }
    for (final line in draft.lines) {
      if (line.itemId.isEmpty) throw ValidationException('المنتج مطلوب في سطر الفاتورة');
      if (line.quantityBase <= 0) {
        throw ValidationException('الكمية يجب أن تكون موجبة');
      }
      if (line.unitCostMicros < 0) {
        throw ValidationException('تكلفة الوحدة لا يمكن أن تكون سالبة');
      }
      if (line.discountBasisPoints < 0 || line.discountBasisPoints > 10000) {
        throw ValidationException('نسبة الخصم غير صحيحة');
      }
      for (final b in line.bonuses) {
        if (b.quantityBase <= 0) {
          throw ValidationException('كمية الهبة يجب أن تكون موجبة');
        }
      }
    }
  }
}