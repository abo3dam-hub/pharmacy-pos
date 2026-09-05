import 'package:drift/drift.dart';
import 'batches.dart';
import 'items.dart';
import 'returns.dart';

/// Lines of a return order (§4.19).
///
/// `quantityBaseSigned` > 0 means goods are restocked into the original batch.
/// `originalInvoiceItemId` references the original line being reversed, and
/// `batchId` the original batch (restoration target) — one return line per
/// original line.
@DataClassName('ReturnItemRow')
@TableIndex(name: 'idx_return_items_return', columns: {#returnId})
@TableIndex(name: 'idx_return_items_item', columns: {#itemId})
class ReturnItems extends Table {
  TextColumn get id => text()();
  TextColumn get returnId => text().references(Returns, #id)();
  TextColumn get originalInvoiceItemId => text()();
  TextColumn get purchaseItemId => text().nullable()();
  TextColumn get itemId => text().references(Items, #id)();
  TextColumn get batchId => text().references(Batches, #id)();
  IntColumn get quantityBaseSigned => integer()();
  IntColumn get unitCostMicros => integer()();
  IntColumn get amountMicros => integer()();
  TextColumn get reason => text().nullable()();
  TextColumn get notes => text().nullable()();
  IntColumn get createdAt => integer()();

  @override
  Set<Column> get primaryKey => {id};

  @override
  List<Set<Column>> get uniqueKeys => [
        {returnId, originalInvoiceItemId},
      ];

  @override
  List<String> get customConstraints => [
        'CHECK (quantity_base_signed != 0)',
      ];
}