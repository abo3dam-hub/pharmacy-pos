import 'package:drift/drift.dart';

import '../../core/data_grid/page_request.dart';
import '../../core/util/bilingual_name.dart';
import '../../core/util/ids.dart';
import '../../shared/database/app_database.dart';
import '../../shared/models/enums.dart';

/// Joined view: a purchase invoice header + its supplier name (for grids).
class PurchaseInvoiceView {
  const PurchaseInvoiceView({required this.invoice, required this.supplierName});

  final PurchaseInvoiceRow invoice;
  final String supplierName;
}

/// One purchase line + the item's trade name (for forms and detail views).
class PurchaseLineView {
  const PurchaseLineView({required this.line, required this.itemName});

  final PurchaseInvoiceItemRow line;
  final String itemName;
}

/// One bonus row + bonus item name (NULL item = bonus on the purchased item).
class PurchaseBonusView {
  const PurchaseBonusView({required this.bonus, required this.itemName});

  final PurchaseBonusRow bonus;

  /// Trade name of the bonus item, or null when the bonus applies to the line's
  /// own purchased item.
  final String? itemName;
}

/// Full purchase detail: header, supplier, lines and bonus rows.
class PurchaseDetailView {
  const PurchaseDetailView({
    required this.invoice,
    required this.supplierName,
    required this.lines,
    required this.bonuses,
  });

  final PurchaseInvoiceRow invoice;
  final String supplierName;
  final List<PurchaseLineView> lines;
  final List<PurchaseBonusView> bonuses;
}

/// DAO for purchase invoices (§4.16–4.18, §12). Mutations live in use cases /
/// repositories; this DAO covers the read side with DB-side filtering and
/// pagination (§30) plus the return-availability calculation.
class PurchaseDao {
  const PurchaseDao(this._db);

  final AppDatabase _db;

  /// Paginated invoice list with supplier names. Filters (number/supplier/
  /// status/date) are applied in SQL; names are joined in a bounded second
  /// lookup (one `IN` query, never N+1).
  Future<PageResult<PurchaseInvoiceView>> search(
    PageRequest page, {
    String? supplierId,
    PurchaseStatus? status,
    DateTime? fromDate,
    DateTime? toDate,
  }) async {
    final query = _db.select(_db.purchaseInvoices);
    final countExpr = _db.purchaseInvoices.id.count();
    final count = _db.selectOnly(_db.purchaseInvoices)..addColumns([countExpr]);

    final q = page.search.trim();
    if (q.isNotEmpty) {
      final like = '%${_escapeLike(q)}%';
      query.where((i) => i.invoiceNumber.like(like));
      count.where(_db.purchaseInvoices.invoiceNumber.like(like));
    }
    if (supplierId != null) {
      query.where((i) => i.supplierId.equals(supplierId));
      count.where(_db.purchaseInvoices.supplierId.equals(supplierId));
    }
    if (status != null) {
      query.where((i) => i.purchaseStatus.equalsValue(status));
      count.where(_db.purchaseInvoices.purchaseStatus.equalsValue(status));
    }
    if (fromDate != null) {
      final start = _startOfDay(fromDate);
      query.where((i) => i.invoiceDate.isBiggerOrEqualValue(start));
      count.where(_db.purchaseInvoices.invoiceDate.isBiggerOrEqualValue(start));
    }
    if (toDate != null) {
      final end = _endOfDay(toDate);
      query.where((i) => i.invoiceDate.isSmallerOrEqualValue(end));
      count.where(_db.purchaseInvoices.invoiceDate.isSmallerOrEqualValue(end));
    }

    final total = (await count.getSingle()).read(countExpr) ?? 0;
    query
      ..orderBy([
        (i) => OrderingTerm.desc(i.invoiceDate),
        (i) => OrderingTerm.desc(i.createdAt),
      ])
      ..limit(page.pageSize, offset: page.offset);
    final rows = await query.get();

    final supplierNames = await _supplierNames(rows.map((r) => r.supplierId).toSet());
    return PageResult(
      items: [
        for (final r in rows)
          PurchaseInvoiceView(
            invoice: r,
            supplierName: supplierNames[r.supplierId] ?? '',
          ),
      ],
      total: total,
      request: page,
    );
  }

  Future<PurchaseInvoiceView?> invoiceById(String invoiceId) async {
    final row = await (_db.select(_db.purchaseInvoices)
          ..where((i) => i.id.equals(invoiceId)))
        .getSingleOrNull();
    if (row == null) return null;
    final names = await _supplierNames({row.supplierId});
    return PurchaseInvoiceView(invoice: row, supplierName: names[row.supplierId] ?? '');
  }

  /// Lines of an invoice ordered by creation (stable form/detail order).
  Future<List<PurchaseLineView>> linesForInvoice(String invoiceId) async {
    final rows = await (_db.select(_db.purchaseInvoiceItems)
          ..where((l) => l.invoiceId.equals(invoiceId))
          ..orderBy([(l) => OrderingTerm.asc(l.createdAt)]))
        .get();
    final itemNames = await _itemNames({for (final r in rows) r.itemId});
    return [
      for (final r in rows)
        PurchaseLineView(line: r, itemName: itemNames[r.itemId] ?? ''),
    ];
  }

  /// Bonus rows of an invoice with the bonus item's name (nullable).
  Future<List<PurchaseBonusView>> bonusesForInvoice(String invoiceId) async {
    final rows = await (_db.select(_db.purchaseBonuses)
          ..where((b) => b.purchaseInvoiceId.equals(invoiceId))
          ..orderBy([
            (b) => OrderingTerm.asc(b.createdAt),
            (b) => OrderingTerm.asc(b.id),
          ]))
        .get();
    final itemIds = {for (final r in rows) if (r.itemId != null) r.itemId!};
    final itemNames = await _itemNames(itemIds);
    return [
      for (final r in rows)
        PurchaseBonusView(
          bonus: r,
          itemName: r.itemId != null ? itemNames[r.itemId] : null,
        ),
    ];
  }

  Future<PurchaseInvoiceItemRow?> lineById(String lineId) =>
      (_db.select(_db.purchaseInvoiceItems)..where((l) => l.id.equals(lineId)))
          .getSingleOrNull();

  /// Quantity (base units) still returnable on a received purchase line —
  /// bounded by the effective quantity and by what the original batch holds.
  Future<int> availableToReturn(String lineId) async {
    final line = await lineById(lineId);
    if (line == null) return 0;
    if (line.batchId == null) return 0;
    final batch = await (_db.select(_db.batches)
          ..where((b) => b.id.equals(line.batchId!)))
        .getSingleOrNull();
    if (batch == null) return 0;
    final returned = await (_db.selectOnly(_db.returnItems)
          ..addColumns([_db.returnItems.quantityBaseSigned.sum()])
          ..where(_db.returnItems.originalInvoiceItemId.equals(lineId)))
        .getSingle();
    final alreadyReturned =
        returned.read(_db.returnItems.quantityBaseSigned.sum()) ?? 0;
    final cap = batch.quantityBase < line.effectiveQuantityBase
        ? batch.quantityBase
        : line.effectiveQuantityBase;
    final available = cap - alreadyReturned;
    return available < 0 ? 0 : available;
  }

  Future<Map<String, String>> _supplierNames(Set<String> ids) async {
    if (ids.isEmpty) return const {};
    final rows = await (_db.select(_db.suppliers)
          ..where((s) => s.id.isIn(ids)))
        .get();
    return {for (final r in rows) r.id: r.name};
  }

  Future<Map<String, String>> _itemNames(Set<String> ids) async {
    if (ids.isEmpty) return const {};
    final rows = await (_db.select(_db.items)..where((i) => i.id.isIn(ids))).get();
    return {for (final r in rows) r.id: bilingualName(r.tradeName, r.tradeNameEn ?? '')};
  }

  static String newInvoiceId() => newId('piv');
  static String newLineId() => newId('pli');
  static String newBonusId() => newId('bon');
  static String newBatchId() => newId('bat');
  static String newReturnId() => newId('ret');

  static String _escapeLike(String value) =>
      value.replaceAll(r'\', r'\\').replaceAll('%', r'\%').replaceAll('_', r'\_');

  static int _startOfDay(DateTime d) =>
      DateTime(d.year, d.month, d.day).millisecondsSinceEpoch;

  static int _endOfDay(DateTime d) =>
      DateTime(d.year, d.month, d.day, 23, 59, 59, 999).millisecondsSinceEpoch;
}