import 'package:drift/drift.dart';

import '../../core/data_grid/page_request.dart';
import '../../core/util/ids.dart';
import '../../core/util/smart_search.dart';
import '../../shared/database/app_database.dart';
import 'smart_search_dao.dart';

/// Master-data DAO for items (§4.2). All queries are paginated/filtered in
/// SQL; barcode lookup is index-backed. Text search is Arabic-normalized and
/// spans product fields plus supplier/ingredient/indication names (§P16).
class ItemDao {
  const ItemDao(this._db);

  final AppDatabase _db;

  Expression<bool>? _filter(
    String search, {
    String? categoryId,
    String? manufacturerId,
    bool? onlyActive,
    Set<String> relatedItemIds = const {},
  }) {
    final conds = <Expression<bool>>[];
    final q = search.trim();
    if (q.isNotEmpty) {
      final like = SmartSearch.likePattern(q);
      final textMatches = <Expression<bool>>[
        SmartSearch.normalizeExpr(_db.items.tradeName).like(like),
        SmartSearch.normalizeExpr(_db.items.tradeNameEn).like(like),
        SmartSearch.normalizeExpr(_db.items.scientificName).like(like),
        SmartSearch.normalizeExpr(_db.items.activeIngredient).like(like),
        SmartSearch.normalizeExpr(_db.items.equivalentDrug).like(like),
        SmartSearch.normalizeExpr(_db.items.primaryBarcode).like(like),
        SmartSearch.normalizeExpr(_db.items.secondaryBarcode).like(like),
      ];
      if (relatedItemIds.isNotEmpty) {
        textMatches.add(_db.items.id.isIn(relatedItemIds));
      }
      conds.add(textMatches.reduce((a, b) => a | b));
    }
    if (categoryId != null) conds.add(_db.items.categoryId.equals(categoryId));
    if (manufacturerId != null) {
      conds.add(_db.items.manufacturerId.equals(manufacturerId));
    }
    if (onlyActive != null) conds.add(_db.items.isActive.equals(onlyActive));
    return conds.isEmpty ? null : conds.reduce((a, b) => a & b);
  }

  /// Paginated, filterable item search (§22). Count and rows are computed in
  /// the database layer, never in Dart.
  Future<PageResult<ItemRow>> search(
    PageRequest page, {
    String? categoryId,
    String? manufacturerId,
    bool? onlyActive,
  }) async {
    final related = await SmartSearchDao(_db).matchingItemIds(page.search);
    final filter = _filter(page.search,
        categoryId: categoryId,
        manufacturerId: manufacturerId,
        onlyActive: onlyActive,
        relatedItemIds: related);

    final totalExpr = _db.items.id.count();
    final countQuery = _db.selectOnly(_db.items)..addColumns([totalExpr]);
    if (filter != null) countQuery.where(filter);
    final countRow = await countQuery.getSingle();

    final query = _db.select(_db.items);
    if (filter != null) query.where((i) => filter);
    final q = page.search.trim();
    if (q.isNotEmpty && page.orderBy == null) {
      // Relevance-first ordering: exact name → prefix → contains → everything
      // else, so the best matches lead the first page.
      query.orderBy([
        (i) => OrderingTerm.asc(_relevance(q)),
        (i) => OrderingTerm.asc(_db.items.tradeName),
      ]);
    } else {
      query.orderBy([(i) => _order(page.orderBy, page.ascending)]);
    }
    query.limit(page.pageSize, offset: page.offset);
    final items = await query.get();

    return PageResult(
      items: items,
      total: countRow.read(totalExpr) ?? 0,
      request: page,
    );
  }

  /// Reactive variant for grid widgets; re-runs the same DB-side query on
  /// every table change.
  Stream<PageResult<ItemRow>> watchSearch(
    PageRequest page, {
    String? categoryId,
    String? manufacturerId,
    bool? onlyActive,
  }) {
    return _db.select(_db.items).watch().asyncMap((_) => search(page,
        categoryId: categoryId,
        manufacturerId: manufacturerId,
        onlyActive: onlyActive));
  }

  Future<ItemRow?> byId(String id) => (_db.select(_db.items)
        ..where((i) => i.id.equals(id)))
      .getSingleOrNull();

  /// Indexed barcode lookup: primary then secondary.
  Future<ItemRow?> byBarcode(String barcode) async {
    final primary = await (_db.select(_db.items)
          ..where((i) => i.primaryBarcode.equals(barcode)))
        .getSingleOrNull();
    if (primary != null) return primary;
    return (_db.select(_db.items)..where((i) => i.secondaryBarcode.equals(barcode)))
        .getSingleOrNull();
  }

  Future<void> insert(ItemRow item) => _db.into(_db.items).insert(item);

  Future<void> update(ItemRow item) =>
      (_db.update(_db.items)..where((i) => i.id.equals(item.id)))
          .write(item.toCompanion(true));

  /// Soft-delete toggle (§28) — items are never physically deleted.
  Future<void> setActive(String id, bool active) =>
      (_db.update(_db.items)..where((i) => i.id.equals(id))).write(
        ItemsCompanion(
          isActive: Value(active),
          updatedAt: Value(DateTime.now().millisecondsSinceEpoch),
        ),
      );

  /// Relevance tier for a query, evaluated in SQL: 0 = exact normalized
  /// trade-name match, 1 = prefix, 2 = contains, 3 = any other field.
  Expression<int> _relevance(String query) {
    final normalized = SmartSearch.normalize(query);
    final name = SmartSearch.normalizeExpr(_db.items.tradeName);
    return CaseWhenExpression<int>(
      cases: [
        CaseWhen(name.equals(normalized), then: const Constant(0)),
        CaseWhen(name.like('$normalized%'), then: const Constant(1)),
        CaseWhen(name.like('%$normalized%'), then: const Constant(2)),
      ],
      orElse: const Constant(3),
    );
  }

  OrderingTerm _order(String? column, bool ascending) {
    final expr = switch (column) {
      'tradeNameEn' => _db.items.tradeNameEn,
      'scientificName' => _db.items.scientificName,
      'primaryBarcode' => _db.items.primaryBarcode,
      'currentStockBase' => _db.items.currentStockBase,
      _ => _db.items.tradeName,
    };
    return ascending ? OrderingTerm.asc(expr) : OrderingTerm.desc(expr);
  }

  /// Convenience id generation for new items.
  static String newItemId() => newId('item');
}