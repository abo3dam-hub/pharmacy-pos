import 'package:drift/drift.dart';

import '../../core/util/ids.dart';
import '../../shared/database/app_database.dart';

/// DAO for indication master data (الاستطباب / دلالة الاستخدام). Per-item links
/// live in `item_indications`.
class IndicationDao {
  const IndicationDao(this._db);

  final AppDatabase _db;

  Future<List<IndicationRow>> all({bool? activeOnly}) {
    final q = _db.select(_db.indications)
      ..orderBy([(r) => OrderingTerm.asc(r.name)]);
    if (activeOnly != null) q.where((r) => r.isActive.equals(activeOnly));
    return q.get();
  }

  Future<IndicationRow?> byId(String id) =>
      (_db.select(_db.indications)..where((r) => r.id.equals(id)))
          .getSingleOrNull();

  Future<void> insert(IndicationRow row) =>
      _db.into(_db.indications).insert(row);

  Future<void> update(IndicationRow row) =>
      (_db.update(_db.indications)..where((r) => r.id.equals(row.id)))
          .write(row.toCompanion(true));

  Future<void> setActive(String id, bool active) =>
      (_db.update(_db.indications)..where((r) => r.id.equals(id))).write(
        IndicationsCompanion(
          isActive: Value(active),
          updatedAt: Value(DateTime.now().millisecondsSinceEpoch),
        ),
      );

  static String newIndicationId() => newId('ind');
}