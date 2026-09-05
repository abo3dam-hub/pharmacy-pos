import 'package:drift/drift.dart';
import 'batches.dart';
import 'items.dart';
import 'returns.dart';

/// Lines of a return order.
///
/// quantity_base_signed > 0 means goods are restocked into the original batch.
/// `originalInvoiceItemId` references a sales line when the return is a sale
/// return; `purchaseItemId` references a purchase line for purchase returns.
@DataClassName('ReturnItemRow')
@TableIndex(name: 'idx_return_items_return', columns: {#returnId})
@TableIndex(name: 'idx_return_items_item', columns: {#itemId})
class ReturnItems extends Table {
  TextColumn get id => text()();
  TextColumn get returnId => text().references(ReturnOrders, #id)();
  TextColumn get originalInvoiceItemId => text().nullable()();
  TextColumn get purchaseItemId => text().nullable()();
  TextColumn get itemId => text().references(Items, #id)();
  TextColumn get batchId => text().nullable().references(Batches, #id)();
  IntColumn get quantityBaseSigned => integer()();
  IntColumn get unitCostMicros => integer()();
  IntColumn get amountMicros => integer()();
  TextColumn get reason => text().nullable()();
  TextColumn get notes => text().nullable()();
  IntColumn get createdAt => integer()();

  @override
  Set<Column> get primaryKey => {id};

  @override
  List<String> get customConstraints => [
        'CHECK (quantity_base_signed != 0)',
      ];
}