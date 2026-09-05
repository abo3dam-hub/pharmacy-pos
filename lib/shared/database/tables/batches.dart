import 'package:drift/drift.dart';
import 'items.dart';
import 'suppliers.dart';

/// Batches / التشغيلة (§4.8, §6). Expiry, operational quantity and (effective)
/// purchase cost are attached to the batch — never to the item alone.
///
/// `quantityBase` maps to the plan's `remaining_qty_base`; `unitCostMicros`
/// maps to the plan's `purchase_cost` (effective unit cost after bonuses, §13);
/// `receivedDate` maps to the plan's `purchase_date`. `expiryDate` is NULL for
/// non-expiring products (FEFO degrades to FIFO by purchase date).
@DataClassName('BatchRow')
@TableIndex(name: 'idx_batches_item_expiry', columns: {#itemId, #expiryDate})
@TableIndex(name: 'idx_batches_expiry', columns: {#expiryDate})
@TableIndex(name: 'idx_batches_number', columns: {#batchNumber})
@TableIndex(name: 'idx_batches_supplier', columns: {#supplierId})
class Batches extends Table {
  TextColumn get id => text()();
  TextColumn get itemId => text().references(Items, #id)();
  TextColumn get batchNumber => text()();
  IntColumn get productionDate => integer().nullable()();
  IntColumn get expiryDate => integer().nullable()();
  IntColumn get quantityBase => integer().withDefault(const Constant(0))();
  IntColumn get originalQuantityBase => integer()();
  IntColumn get unitCostMicros => integer().withDefault(const Constant(0))();

  /// Bonus quantity granted on the purchase lot (base units) where applicable.
  IntColumn get bonusQtyBase => integer().withDefault(const Constant(0))();

  TextColumn get supplierId =>
      text().nullable().references(Suppliers, #id)();

  /// Maps to the plan's `purchase_date` (§4.8, NN).
  IntColumn get receivedDate =>
      integer().clientDefault(() => DateTime.now().millisecondsSinceEpoch)();
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