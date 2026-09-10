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

  /// Replaces the item's ingredient relations. [ingredientIds] is the ordered
  /// selection; [strengths] maps an ingredient id to its per-product strength
  /// (العيار), e.g. `{'ai_1': '400 mg'}` — omitted entries persist as NULL.
  Future<void> setForItem(
    String itemId,
    List<String> ingredientIds, {
    Map<String, String>? strengths,
  }) async {
    final ids = ingredientIds.toSet().toList();
    final strengthByIngredient = strengths ?? const <String, String>{};
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
                strength: Value(strengthByIngredient[ingredientId]),
              ),
              mode: InsertMode.insertOrIgnore,
            );
      }
    });
  }
}