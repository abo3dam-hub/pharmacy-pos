import 'package:drift/drift.dart';

import '../../core/util/ids.dart';
import '../../shared/database/app_database.dart';

/// DAO for product categories (§4.3).
class CategoryDao {
  const CategoryDao(this._db);

  final AppDatabase _db;

  Future<List<CategoryRow>> all() {
    final q = _db.select(_db.categories)
      ..orderBy([(c) => OrderingTerm.asc(c.name)]);
    return q.get();
  }

  Future<CategoryRow?> byId(String id) => (_db.select(_db.categories)
        ..where((c) => c.id.equals(id)))
      .getSingleOrNull();

  Future<void> insertCategory(CategoryRow row) =>
      _db.into(_db.categories).insert(row);

  Future<void> updateCategory(CategoryRow row) =>
      (_db.update(_db.categories)..where((c) => c.id.equals(row.id)))
          .write(row.toCompanion(true));

  Future<void> setCategoryActive(String id, bool active) =>
      (_db.update(_db.categories)..where((c) => c.id.equals(id))).write(
        CategoriesCompanion(
          isActive: Value(active),
          updatedAt: Value(DateTime.now().millisecondsSinceEpoch),
        ),
      );

  static String newCategoryId() => newId('cat');
}