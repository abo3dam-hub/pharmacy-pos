import 'package:drift/drift.dart';
import 'items.dart';
import 'units.dart';

/// Declares each item's canonical Base Unit + Large Unit relationship (§4.6,
/// §7). `1` base unit is one strip/tablet/fraction; `unitsPerLarge` is the
/// number of base units in one large (box) unit.
@DataClassName('ItemUnitRow')
@TableIndex(name: 'idx_item_units_item', columns: {#itemId})
@TableIndex(name: 'idx_item_units_per_large', columns: {#unitsPerLarge})
class ItemUnits extends Table {
  TextColumn get id => text()();
  TextColumn get itemId => text().references(Items, #id)();
  TextColumn get baseUnitId => text().references(Units, #id)();
  TextColumn get largeUnitId => text().references(Units, #id)();
  IntColumn get unitsPerLarge => integer().withDefault(const Constant(1))();

  @override
  Set<Column> get primaryKey => {id};

  @override
  List<Set<Column>> get uniqueKeys => [
        {itemId, baseUnitId, largeUnitId},
      ];

  @override
  List<String> get customConstraints => [
        'CHECK (units_per_large >= 1)',
      ];
}