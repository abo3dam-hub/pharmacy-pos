import 'package:drift/drift.dart';

import '../../core/data_grid/page_request.dart';
import '../../core/util/ids.dart';
import '../../shared/database/app_database.dart';

/// Master-data DAO for items (§4.2). All queries are paginated/filtered in
/// SQL; barcode lookup is index-backed.
class ItemDao {
  const ItemDao(this._db);

  final AppDatabase _db;

  Expression<bool>? _filter(
    String search, {
    String? categoryId,
    String? manufacturerId,
    bool? onlyActive,
  }) {
    final conds = <Expression<bool>>[];
    final q = search.trim();
    if (q.isNotEmpty) {
      final like = '%${_escapeLike(q)}%';
      conds.add([
        _db.items.tradeName.like(like),
        _db.items.tradeNameEn.like(like),
        _db.items.scientificName.like(like),
        _db.items.primaryBarcode.like(like),
        _db.items.secondaryBarcode.like(like),
      ].reduce((a, b) => a | b));
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
    final filter = _filter(page.search,
        categoryId: categoryId,
        manufacturerId: manufacturerId,
        onlyActive: onlyActive);

    final totalExpr = _db.items.id.count();
    final countQuery = _db.selectOnly(_db.items)..addColumns([totalExpr]);
    if (filter != null) countQuery.where(filter);
    final countRow = await countQuery.getSingle();

    final query = _db.select(_db.items);
    if (filter != null) query.where((i) => filter);
    query
      ..orderBy([(i) => _order(page.orderBy, page.ascending)])
      ..limit(page.pageSize, offset: page.offset);
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

  static String _escapeLike(String value) =>
      value.replaceAll(r'\', r'\\').replaceAll('%', r'\%').replaceAll('_', r'\_');

  /// Convenience id generation for new items.
  static String newItemId() => newId('item');
}