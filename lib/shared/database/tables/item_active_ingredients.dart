import 'package:drift/drift.dart';
import 'active_ingredients.dart';
import 'items.dart';

/// Many-to-many link between an item and its active ingredients (§Phase 16).
///
/// Follows the `item_suppliers` junction pattern: keeps `items.active_ingredient`
/// reader-compatible (the legacy free-text column stays populated as a
/// denormalized summary) while the canonical relation lives here. The composite
/// `(itemId, activeIngredientId)` unique key prevents duplicates at the schema
/// level.
@DataClassName('ItemActiveIngredientRow')
@TableIndex(name: 'idx_item_ai_item', columns: {#itemId})
@TableIndex(name: 'idx_item_ai_ingredient', columns: {#activeIngredientId})
class ItemActiveIngredients extends Table {
  TextColumn get id => text()();
  TextColumn get itemId => text().references(Items, #id)();
  TextColumn get activeIngredientId =>
      text().references(ActiveIngredients, #id)();

  @override
  Set<Column> get primaryKey => {id};

  @override
  List<Set<Column>> get uniqueKeys => [
        {itemId, activeIngredientId},
      ];
}