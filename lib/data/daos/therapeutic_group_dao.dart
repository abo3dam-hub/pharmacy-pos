import 'package:drift/drift.dart';

import '../../core/util/ids.dart';
import '../../shared/database/app_database.dart';

/// DAO for therapeutic groups (§4.1).
class TherapeuticGroupDao {
  const TherapeuticGroupDao(this._db);

  final AppDatabase _db;

  Future<List<TherapeuticGroupRow>> all() {
    final q = _db.select(_db.therapeuticGroups)
      ..orderBy([(g) => OrderingTerm.asc(g.name)]);
    return q.get();
  }

  Future<TherapeuticGroupRow?> byId(String id) =>
      (_db.select(_db.therapeuticGroups)..where((g) => g.id.equals(id)))
          .getSingleOrNull();

  Future<void> insert(TherapeuticGroupRow row) =>
      _db.into(_db.therapeuticGroups).insert(row);

  static String newGroupId() => newId('grp');
}