import 'package:drift/drift.dart';
import '../../models/enums.dart';
import 'batches.dart';
import 'items.dart';
import 'users.dart';

/// Append-only stock movement ledger (سجل حركة المخزون) (§4.9, §10).
/// Every stock mutation of an item/batch must be written here first. Rows are
/// never updated or deleted; `quantity_base_signed` is the authoritative delta.
@DataClassName('StockMovementRow')
@TableIndex(name: 'idx_stock_movements_item_created', columns: {#itemId, #createdAt})
@TableIndex(name: 'idx_stock_movements_batch_created', columns: {#batchId, #createdAt})
@TableIndex(name: 'idx_stock_movements_ref', columns: {#refType, #refId})
@TableIndex(name: 'idx_stock_movements_type', columns: {#movementType})
class StockMovements extends Table {
  TextColumn get id => text()();
  TextColumn get itemId => text().references(Items, #id)();
  TextColumn get batchId => text().nullable().references(Batches, #id)();

  TextColumn get movementType => textEnum<MovementType>()();

  /// Signed delta applied to the batch; the running sum matches current stock.
  IntColumn get quantityBaseSigned => integer()();

  /// Running batch balance immediately after this movement.
  IntColumn get quantityBaseAfter => integer()();

  IntColumn get unitCostMicros => integer()();
  IntColumn get totalMicros => integer().withDefault(const Constant(0))();

  /// Polymorphic reference, e.g. refType `sale`, refId = sales line id.
  TextColumn get refType => text().nullable()();
  TextColumn get refId => text().nullable()();

  TextColumn get userId => text().references(Users, #id)();
  TextColumn get note => text().nullable()();
  IntColumn get createdAt => integer()();

  @override
  Set<Column> get primaryKey => {id};

  @override
  List<String> get customConstraints => [
        'CHECK (quantity_base_signed != 0)',
      ];
}