import 'package:drift/drift.dart';

import '../../../core/data_grid/page_request.dart';
import '../../../core/errors/exceptions.dart';
import '../../../core/util/ids.dart';
import '../../../domain/services/return_service.dart';
import '../../../domain/services/sale_service.dart';
import '../../../domain/services/stock_service.dart';
import '../../../shared/database/app_database.dart';
import '../../../shared/models/enum_value_converter.dart';
import '../../../shared/models/enums.dart';
import '../../sales/domain/entities/pos_catalog_item.dart';
import '../../sales/domain/entities/pos_customer.dart';
import '../../sales/domain/entities/pos_invoice.dart';
import '../../sales/domain/entities/smart_alternative.dart';
import '../../sales/domain/repositories/sales_repository.dart';
import '../../sales/domain/services/smart_alternatives_service.dart';
import '../../sales/domain/usecases/payment_calculator.dart';
import 'pos_catalog_dao.dart';

/// The POS data layer (§5): implements the domain repository contract over the
/// existing transactional engine — every stock/financial change runs through
/// SaleService / ReturnService / StockService inside one transaction.
class SalesRepositoryImpl implements SalesRepository {
  SalesRepositoryImpl(
    this._db,
    this._catalogDao,
    this._stock,
    this._saleService,
    this._returnService,
  );

  final AppDatabase _db;
  final PosCatalogDao _catalogDao;
  final StockService _stock;
  final SaleService _saleService;
  final ReturnService _returnService;

  @override
  Future<PageResult<PosCatalogItem>> searchCatalog(
    PageRequest request, {
    bool? inStockOnly,
  }) =>
      _catalogDao.search(request, inStockOnly: inStockOnly);

  @override
  Future<PosCatalogItem?> itemByBarcode(String barcode) =>
      _catalogDao.byBarcode(barcode);

  @override
  Future<PosCatalogItem?> itemById(String id) => _catalogDao.byId(id);

  // ── Customers & prescriptions ────────────────────────────────────────

  @override
  Future<List<PosCustomer>> findCustomers(String query, {int limit = 20}) async {
    final q = query.trim();
    final rows = await (_db.select(_db.customers)
          ..where((c) {
            final base = c.isActive.equals(true);
            if (q.isEmpty) return base;
            final like = '%${_escapeLike(q)}%';
            return base &
                (c.name.like(like) |
                    (c.phone.isNotNull() & c.phone.like(like)));
          })
          ..orderBy([(c) => OrderingTerm.asc(c.name)])
          ..limit(limit))
        .get();
    return [
      for (final c in rows)
        PosCustomer(
          id: c.id,
          name: c.name,
          phone: c.phone,
          hasAccount: c.hasAccount,
          isActive: c.isActive,
          balanceMicros: c.balanceMicros,
          creditLimitMicros: c.creditLimitMicros,
        ),
    ];
  }

  @override
  Future<List<PosRxSummary>> activePrescriptionsForCustomer(
      String customerId) async {
    final headers = await (_db.select(_db.prescriptions)
          ..where((p) =>
              p.customerId.equals(customerId) &
              (p.status.equalsValue(PrescriptionStatus.active) |
                  p.status
                      .equalsValue(PrescriptionStatus.partially_dispensed)))
          ..orderBy([
            (p) => OrderingTerm.desc(p.createdAt),
            (p) => OrderingTerm.desc(p.prescriptionNumber),
          ]))
        .get();
    if (headers.isEmpty) return const [];

    final rxIds = {for (final h in headers) h.id};
    final items = await (_db.select(_db.prescriptionItems)
          ..where((pi) => pi.prescriptionId.isIn(rxIds))
          ..orderBy([(pi) => OrderingTerm.asc(pi.createdAt)]))
        .get();
    final itemIds = {for (final it in items) it.itemId};
    final names = <String, String>{};
    if (itemIds.isNotEmpty) {
      final itemRows =
          await (_db.select(_db.items)..where((i) => i.id.isIn(itemIds))).get();
      for (final r in itemRows) {
        names[r.id] = r.tradeName;
      }
    }

    return [
      for (final h in headers)
        PosRxSummary(
          id: h.id,
          prescriptionNumber: h.prescriptionNumber,
          patientName: h.patientName,
          doctorName: h.doctorName,
          statusName: h.status.name,
          createdAt: h.createdAt,
          items: [
            for (final it in items.where((i) => i.prescriptionId == h.id))
              PosRxItemSummary(
                id: it.id,
                prescriptionId: it.prescriptionId,
                itemId: it.itemId,
                itemName: names[it.itemId] ?? '',
                quantityBase: it.quantityBase,
                dispensedQuantityBase: it.dispensedQuantityBase,
              ),
          ],
        ),
    ];
  }

  // ── Checkout ─────────────────────────────────────────────────────────

  @override
  Future<String> nextInvoiceNumber() async =>
      PosCatalogDao.nextInvoiceNumber();

  @override
  Future<String> nextReturnNumber() async =>
      PosCatalogDao.nextReturnNumber();

  PaymentMethod _engineMethod(PosPaymentMethod method) => switch (method) {
        PosPaymentMethod.cash => PaymentMethod.cash,
        PosPaymentMethod.card => PaymentMethod.card,
        PosPaymentMethod.mixed => PaymentMethod.mixed,
        PosPaymentMethod.credit => PaymentMethod.credit,
      };

  @override
  Future<PosSaleOutcome> checkout(PosCheckoutCommand command) async {
    if (command.lines.isEmpty) {
      throw ValidationException('سلة البيع فارغة');
    }
    final outcome = await _saleService.recordSale(
      _db,
      SaleRequest(
        invoiceNumber: command.invoiceNumber,
        lines: [
          for (final l in command.lines)
            SaleLineRequest(
              itemId: l.itemId,
              quantityBase: l.quantityBase,
              unitPriceMicros: l.unitPriceMicros,
              unitTypeId: l.unitTypeId,
              vatRateBasisPoints: l.vatRateBasisPoints,
              discountBasisPoints: l.discountBasisPoints,
              prescriptionItemId: l.prescriptionItemId,
              partialSaleUnitPriceMicros: l.partialSaleUnitPriceMicros,
            ),
        ],
        paymentMethod: _engineMethod(command.paymentMethod),
        customerId: command.customerId,
        userId: command.userId,
        paidMicros: command.paidMicros,
        cashMicros: command.cashMicros,
        cardMicros: command.cardMicros,
        notes: command.notes,
        prescriptionId: command.prescriptionId,
      ),
    );
    final view = await invoiceViewById(outcome.invoice.id);
    if (view == null) {
      throw NotFoundException(
          'تعذر بناء عرض الفاتورة ${outcome.invoice.invoiceNumber}');
    }
    return PosSaleOutcome(
      invoice: view,
      lines: view.lines,
      movements: outcome.movements,
    );
  }

  @override
  Future<PosReturnOutcome> returnSaleLine(PosReturnCommand command) async {
    final outcome = await _returnService.recordSaleReturn(
      _db,
      SaleReturnRequest(
        returnNumber: command.returnNumber,
        originalInvoiceItemId: command.originalInvoiceItemId,
        quantityBase: command.quantityBase,
        userId: command.userId,
        reason: command.reason,
        notes: command.notes,
      ),
    );
    return PosReturnOutcome(
      returnId: outcome.returnOrder.id,
      returnNumber: outcome.returnOrder.returnNumber,
      reversalMicros: outcome.returnOrder.totalMicros,
      restoredQuantityBase: outcome.returnItem.quantityBaseSigned,
    );
  }

  @override
  Future<void> voidInvoice(
    String invoiceId, {
    required String userId,
    required String reason,
  }) =>
      _saleService.voidInvoice(
        _db,
        invoiceId: invoiceId,
        userId: userId,
        reason: reason,
      );

  // ── Invoice queries ──────────────────────────────────────────────────

  @override
  Future<PosInvoiceView?> invoiceViewById(String invoiceId) async {
    final header = await (_db.select(_db.salesInvoices)
          ..where((i) => i.id.equals(invoiceId)))
        .getSingleOrNull();
    if (header == null) return null;
    return _buildInvoiceView(header);
  }

  @override
  Future<PageResult<PosInvoiceView>> searchSaleInvoices(
      PageRequest request) async {
    final q = request.search.trim();
    final hasQ = q.isNotEmpty;
    final pattern = '%${_escapeLike(q)}%';

    final whereSql = hasQ
        ? '(si.invoice_number LIKE ?1 OR cus.name LIKE ?1)'
        : '1=1';
    final countRows = await _db.customSelect(
      'SELECT COUNT(*) AS c FROM sales_invoices si '
      'LEFT JOIN customers cus ON si.customer_id = cus.id '
      'WHERE $whereSql',
      variables: hasQ ? [Variable.withString(pattern)] : const [],
    ).get();
    final total = countRows.single.read<int>('c');

    final rows = await _db.customSelect(
      'SELECT si.* FROM sales_invoices si '
      'LEFT JOIN customers cus ON si.customer_id = cus.id '
      'WHERE $whereSql '
      'ORDER BY si.created_at DESC, si.invoice_number DESC '
      '${hasQ ? 'LIMIT ?2 OFFSET ?3' : 'LIMIT ?1 OFFSET ?2'}',
      variables: hasQ
          ? [
              Variable.withString(pattern),
              Variable.withInt(request.pageSize),
              Variable.withInt(request.offset),
            ]
          : [
              Variable.withInt(request.pageSize),
              Variable.withInt(request.offset),
            ],
    ).get();

    final headers = <SalesInvoiceRow>[
      for (final r in rows)
        SalesInvoiceRow(
          id: r.read<String>('id'),
          invoiceNumber: r.read<String>('invoice_number'),
          invoiceType: invoiceTypeValues.fromSql(r.read<String>('invoice_type')),
          saleStatus: SaleStatus.values.byName(r.read<String>('sale_status')),
          originalInvoiceId: r.read<String?>('original_invoice_id'),
          customerId: r.read<String?>('customer_id'),
          userId: r.read<String>('user_id'),
          subtotalMicros: r.read<int>('subtotal_micros'),
          discountTotalMicros: r.read<int>('discount_total_micros'),
          vatTotalMicros: r.read<int>('vat_total_micros'),
          totalMicros: r.read<int>('total_micros'),
          totalCostMicros: r.read<int>('total_cost_micros'),
          profitMicros: r.read<int>('profit_micros'),
          paymentMethod:
              PaymentMethod.values.byName(r.read<String>('payment_method')),
          paidMicros: r.read<int>('paid_micros'),
          changeMicros: r.read<int>('change_micros'),
          cashMicros: r.read<int>('cash_micros'),
          cardMicros: r.read<int>('card_micros'),
          creditMicros: r.read<int>('credit_micros'),
          remainingMicros: r.read<int>('remaining_micros'),
          prescriptionId: r.read<String?>('prescription_id'),
          notes: r.read<String?>('notes'),
          voidReason: r.read<String?>('void_reason'),
          voidedBy: r.read<String?>('voided_by'),
          voidedAt: r.read<int?>('voided_at'),
          createdAt: r.read<int>('created_at'),
          updatedAt: r.read<int>('updated_at'),
        ),
    ];
    // One batched load for the whole page (customers + lines + names) instead
    // of 5 queries per invoice (§30 — no N+1 on the POS invoice search).
    return PageResult(
      items: await _buildInvoiceViews(headers),
      total: total,
      request: request,
    );
  }

  Future<PosInvoiceView> _buildInvoiceView(SalesInvoiceRow header) async {
    final views = await _buildInvoiceViews([header]);
    return views.single;
  }

  /// Builds views for many headers with a fixed set of batched queries:
  /// customers, lines, item names, batch numbers and unit names loaded once
  /// for the whole set ([IN] clauses), then grouped per invoice.
  Future<List<PosInvoiceView>> _buildInvoiceViews(
      List<SalesInvoiceRow> headers) async {
    if (headers.isEmpty) return const [];

    final headerIds = {for (final h in headers) h.id};
    final customerIds = {
      for (final h in headers)
        if (h.customerId != null) h.customerId!,
    };

    final customers = <String, CustomerRow>{};
    if (customerIds.isNotEmpty) {
      final rows = await (_db.select(_db.customers)
            ..where((c) => c.id.isIn(customerIds)))
          .get();
      for (final r in rows) {
        customers[r.id] = r;
      }
    }

    final linesByInvoice = <String, List<SalesInvoiceItemRow>>{};
    final itemIds = <String>{};
    final batchIds = <String>{};
    final unitIds = <String>{};
    if (headerIds.isNotEmpty) {
      final rows = await (_db.select(_db.salesInvoiceItems)
            ..where((i) => i.invoiceId.isIn(headerIds))
            ..orderBy([(i) => OrderingTerm.asc(i.createdAt)]))
          .get();
      for (final l in rows) {
        linesByInvoice.putIfAbsent(l.invoiceId, () => []).add(l);
        itemIds.add(l.itemId);
        batchIds.add(l.batchId);
        unitIds.add(l.unitTypeId);
      }
    }

    final names = <String, String>{};
    if (itemIds.isNotEmpty) {
      final items =
          await (_db.select(_db.items)..where((i) => i.id.isIn(itemIds))).get();
      for (final r in items) {
        names[r.id] = r.tradeName;
      }
    }
    final batchNumbers = <String, String>{};
    if (batchIds.isNotEmpty) {
      final batches = await (_db.select(_db.batches)
            ..where((b) => b.id.isIn(batchIds)))
          .get();
      for (final b in batches) {
        batchNumbers[b.id] = b.batchNumber;
      }
    }
    final unitNames = <String, String>{};
    if (unitIds.isNotEmpty) {
      final units =
          await (_db.select(_db.units)..where((u) => u.id.isIn(unitIds))).get();
      for (final u in units) {
        unitNames[u.id] = u.name;
      }
    }

    return [
      for (final header in headers)
        _toInvoiceView(
          header,
          customer: customers[header.customerId],
          lines: linesByInvoice[header.id] ?? const [],
          names: names,
          batchNumbers: batchNumbers,
          unitNames: unitNames,
        ),
    ];
  }

  PosInvoiceView _toInvoiceView(
    SalesInvoiceRow header, {
    required CustomerRow? customer,
    required List<SalesInvoiceItemRow> lines,
    required Map<String, String> names,
    required Map<String, String> batchNumbers,
    required Map<String, String> unitNames,
  }) {
    return PosInvoiceView(
      id: header.id,
      invoiceNumber: header.invoiceNumber,
      invoiceType: header.invoiceType,
      saleStatus: header.saleStatus,
      paymentMethod: header.paymentMethod,
      customerId: header.customerId,
      customerName: customer?.name ?? '',
      userId: header.userId,
      subtotalMicros: header.subtotalMicros,
      discountTotalMicros: header.discountTotalMicros,
      vatTotalMicros: header.vatTotalMicros,
      totalMicros: header.totalMicros,
      totalCostMicros: header.totalCostMicros,
      profitMicros: header.profitMicros,
      paidMicros: header.paidMicros,
      changeMicros: header.changeMicros,
      cashMicros: header.cashMicros,
      cardMicros: header.cardMicros,
      creditMicros: header.creditMicros,
      createdAt: header.createdAt,
      notes: header.notes,
      prescriptionId: header.prescriptionId,
      voidedBy: header.voidedBy,
      voidedAt: header.voidedAt,
      lines: [
        for (final l in lines)
          PosInvoiceLineView(
            id: l.id,
            invoiceId: l.invoiceId,
            itemId: l.itemId,
            itemName: names[l.itemId] ?? '',
            batchId: l.batchId,
            batchNumber: batchNumbers[l.batchId] ?? '',
            unitTypeId: l.unitTypeId,
            unitTypeName: unitNames[l.unitTypeId] ?? l.unitTypeId,
            quantityBaseSigned: l.quantityBaseSigned,
            unitPriceMicros: l.unitPriceMicros,
            vatRateBasisPoints: l.vatRateBasisPoints,
            lineDiscountBasisPoints: l.lineDiscountBasisPoints,
            lineSubtotalMicros: l.lineSubtotalMicros,
            lineDiscountMicros: l.lineDiscountMicros,
            lineTotalMicros: l.lineTotalMicros,
            unitCostMicros: l.unitCostMicros,
            costTotalMicros: l.costTotalMicros,
            profitMicros: l.profitMicros,
            prescriptionItemId: l.prescriptionItemId,
            returnQuantityBase: l.returnQuantityBase,
          ),
      ],
    );
  }

  // ── Alternatives & lost sales ────────────────────────────────────────

  @override
  Future<List<SmartAlternative>> smartAlternatives(
    PosCatalogItem item, {
    int limit = 12,
  }) async {
    final candidates = await _catalogDao.alternativeCandidates(itemId: item.id);
    return const SmartAlternativesService().rank(item, candidates, limit: limit);
  }

  @override
  Future<void> recordLostSale(PosLostSaleDraft draft) async {
    if (draft.quantityRequested <= 0) {
      throw ValidationException('الكمية المطلوبة يجب أن تكون موجبة');
    }
    if (draft.requestedItemName.trim().isEmpty) {
      throw ValidationException('اسم المنتج مطلوب لتسجيل ناقص');
    }
    final now = DateTime.now().millisecondsSinceEpoch;
    await _db.into(_db.lostSales).insert(
          LostSalesCompanion.insert(
            id: newId('ls'),
            requestedItemName: draft.requestedItemName,
            barcode: draft.barcode != null
                ? Value(draft.barcode)
                : const Value(null),
            scientificName: draft.scientificName != null
                ? Value(draft.scientificName)
                : const Value(null),
            quantityRequested: draft.quantityRequested,
            customerName: draft.customerName != null
                ? Value(draft.customerName)
                : const Value(null),
            customerPhone: draft.customerPhone != null
                ? Value(draft.customerPhone)
                : const Value(null),
            userId: draft.userId,
            status: LostSaleStatus.open,
            note: draft.note != null ? Value(draft.note) : const Value(null),
            createdAt: now,
            updatedAt: now,
          ),
        );
  }

  @override
  Future<int> availableStock(String itemId) =>
      _stock.availableQuantity(_db, itemId);

  static String _escapeLike(String value) =>
      value.replaceAll(r'\', r'\\').replaceAll('%', r'\%').replaceAll('_', r'\_');
}