import 'package:drift/drift.dart';

import '../../core/util/ids.dart';
import '../../shared/database/app_database.dart';

/// DAO for active-ingredient master data (المادة الفعالة). Replaces the legacy
/// free-text `items.active_ingredient` typing with a reusable, spell-checked
/// list; per-item links live in `item_active_ingredients`.
class ActiveIngredientDao {
  const ActiveIngredientDao(this._db);

  final AppDatabase _db;

  Future<List<ActiveIngredientRow>> all({bool? activeOnly}) {
    final q = _db.select(_db.activeIngredients)
      ..orderBy([(r) => OrderingTerm.asc(r.name)]);
    if (activeOnly != null) q.where((r) => r.isActive.equals(activeOnly));
    return q.get();
  }

  Future<ActiveIngredientRow?> byId(String id) =>
      (_db.select(_db.activeIngredients)..where((r) => r.id.equals(id)))
          .getSingleOrNull();

  Future<void> insert(ActiveIngredientRow row) =>
      _db.into(_db.activeIngredients).insert(row);

  Future<void> update(ActiveIngredientRow row) =>
      (_db.update(_db.activeIngredients)..where((r) => r.id.equals(row.id)))
          .write(row.toCompanion(true));

  Future<void> setActive(String id, bool active) =>
      (_db.update(_db.activeIngredients)..where((r) => r.id.equals(id))).write(
        ActiveIngredientsCompanion(
          isActive: Value(active),
          updatedAt: Value(DateTime.now().millisecondsSinceEpoch),
        ),
      );

  static String newActiveIngredientId() => newId('aig');
}