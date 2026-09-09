import 'package:drift/drift.dart';

import '../../core/util/ids.dart';
import '../../shared/database/app_database.dart';

/// DAO for the `item_active_ingredients` junction — the canonical per-product
/// active-ingredient relation. Replaced wholesale on save (like suppliers);
/// the composite unique key guards against duplicates.
class ItemActiveIngredientDao {
  const ItemActiveIngredientDao(this._db);

  final AppDatabase _db;

  Future<List<ItemActiveIngredientRow>> forItem(String itemId) =>
      (_db.select(_db.itemActiveIngredients)
            ..where((r) => r.itemId.equals(itemId)))
          .get();

  Future<List<String>> activeIngredientIdsForItem(String itemId) async {
    final rows = await forItem(itemId);
    return [for (final row in rows) row.activeIngredientId];
  }

  Future<void> setForItem(String itemId, List<String> ingredientIds) async {
    final ids = ingredientIds.toSet().toList();
    await _db.transaction(() async {
      await (_db.delete(_db.itemActiveIngredients)
            ..where((r) => r.itemId.equals(itemId)))
          .go();
      for (final ingredientId in ids) {
        await _db.into(_db.itemActiveIngredients).insert(
              ItemActiveIngredientsCompanion.insert(
                id: newId('iai'),
                itemId: itemId,
                activeIngredientId: ingredientId,
              ),
              mode: InsertMode.insertOrIgnore,
            );
      }
    });
  }
}