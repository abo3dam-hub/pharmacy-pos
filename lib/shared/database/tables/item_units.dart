import 'package:drift/drift.dart';
import 'items.dart';
import 'units.dart';

@DataClassName('ItemUnitRow')
@TableIndex(name: 'idx_item_units_unit', columns: {#unitId})
class ItemUnits extends Table {
  TextColumn get id => text()();
  TextColumn get itemId => text().references(Items, #id)();
  TextColumn get unitId => text().references(Units, #id)();

  /// How many base units make up one of this unit
  /// (e.g. 1 box = 25 strips → conversion_to_base = 25).
  IntColumn get conversionToBase => integer().withDefault(const Constant(1))();
  BoolColumn get isDefault => boolean().withDefault(const Constant(false))();
  BoolColumn get isSaleUsage => boolean().withDefault(const Constant(false))();
  BoolColumn get isPurchaseUsage =>
      boolean().withDefault(const Constant(false))();
  BoolColumn get printBarcodeLabel =>
      boolean().withDefault(const Constant(false))();
  TextColumn get barcode => text().nullable().unique()();
  TextColumn get notes => text().nullable()();
  IntColumn get createdAt => integer()();

  @override
  Set<Column> get primaryKey => {id};

  @override
  List<Set<Column>> get uniqueKeys => [
        {itemId, unitId},
      ];
}