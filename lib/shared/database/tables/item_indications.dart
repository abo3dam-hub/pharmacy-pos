import 'package:drift/drift.dart';
import 'indications.dart';
import 'items.dart';

/// Many-to-many link between an item and its therapeutic indications
/// (الاستطبابات). Composite `(itemId, indicationId)` unique key prevents
/// duplicates; indexed both ways for the product form and Smart search.
@DataClassName('ItemIndicationRow')
@TableIndex(name: 'idx_item_ind_item', columns: {#itemId})
@TableIndex(name: 'idx_item_ind_indication', columns: {#indicationId})
class ItemIndications extends Table {
  TextColumn get id => text()();
  TextColumn get itemId => text().references(Items, #id)();
  TextColumn get indicationId => text().references(Indications, #id)();

  @override
  Set<Column> get primaryKey => {id};

  @override
  List<Set<Column>> get uniqueKeys => [
        {itemId, indicationId},
      ];
}