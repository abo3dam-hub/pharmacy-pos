import 'package:drift/drift.dart';
import 'items.dart';
import 'suppliers.dart';

@DataClassName('BatchRow')
@TableIndex(name: 'idx_batches_item', columns: {#itemId, #isVoided})
@TableIndex(name: 'idx_batches_expiry', columns: {#expiryDate})
@TableIndex(name: 'idx_batches_number', columns: {#batchNumber})
class Batches extends Table {
  TextColumn get id => text()();
  TextColumn get itemId => text().references(Items, #id)();
  TextColumn get batchNumber => text()();
  IntColumn get productionDate => integer().nullable()();
  IntColumn get expiryDate => integer()();
  IntColumn get quantityBase => integer().withDefault(const Constant(0))();
  IntColumn get originalQuantityBase => integer()();
  IntColumn get unitCostMicros => integer().withDefault(const Constant(0))();
  IntColumn get sellingPriceMicros => integer().nullable()();
  TextColumn get supplierId =>
      text().nullable().references(Suppliers, #id)();
  IntColumn get receivedDate => integer().nullable()();
  TextColumn get notes => text().nullable()();
  BoolColumn get isVoided => boolean().withDefault(const Constant(false))();
  IntColumn get createdAt => integer()();
  IntColumn get updatedAt => integer()();

  @override
  Set<Column> get primaryKey => {id};

  @override
  List<Set<Column>> get uniqueKeys => [
        {itemId, batchNumber},
      ];

  @override
  List<String> get customConstraints => [
        'CHECK (quantity_base >= 0)',
        'CHECK (original_quantity_base >= 0)',
      ];
}