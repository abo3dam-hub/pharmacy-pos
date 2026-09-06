import 'package:drift/drift.dart';

import '../../core/data_grid/page_request.dart';
import '../../core/util/ids.dart';
import '../../shared/database/app_database.dart';

/// DAO for manufacturers (§4.1).
class ManufacturerDao {
  const ManufacturerDao(this._db);

  final AppDatabase _db;

  Future<List<ManufacturerRow>> all() {
    final q = _db.select(_db.manufacturers)
      ..orderBy([(m) => OrderingTerm.asc(m.name)]);
    return q.get();
  }

  Future<PageResult<ManufacturerRow>> search(PageRequest page) async {
    final filter = page.search.trim().isEmpty
        ? null
        : _db.manufacturers.name.like('%${_escapeLike(page.search)}%');
    final totalExpr = _db.manufacturers.id.count();
    final count = _db.selectOnly(_db.manufacturers)..addColumns([totalExpr]);
    if (filter != null) count.where(filter);
    final countRow = await count.getSingle();
    final q = _db.select(_db.manufacturers)
      ..orderBy([(m) => OrderingTerm.asc(m.name)])
      ..limit(page.pageSize, offset: page.offset);
    if (filter != null) q.where((m) => filter);
    return PageResult(
      items: await q.get(),
      total: countRow.read(totalExpr) ?? 0,
      request: page,
    );
  }

  Future<void> insert(ManufacturerRow row) =>
      _db.into(_db.manufacturers).insert(row);

  Future<void> update(ManufacturerRow row) =>
      (_db.update(_db.manufacturers)..where((m) => m.id.equals(row.id)))
          .write(row.toCompanion(true));

  Future<void> setActive(String id, bool active) =>
      (_db.update(_db.manufacturers)..where((m) => m.id.equals(id))).write(
        ManufacturersCompanion(
          isActive: Value(active),
          updatedAt: Value(DateTime.now().millisecondsSinceEpoch),
        ),
      );

  static String _escapeLike(String value) =>
      value.replaceAll(r'\', r'\\').replaceAll('%', r'\%').replaceAll('_', r'\_');

  static String newManufacturerId() => newId('mfr');
}