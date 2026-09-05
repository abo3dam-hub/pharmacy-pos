import 'package:drift/drift.dart';
import '../../models/enums.dart';
import 'users.dart';

/// Lost sales / النواقص (§4.28, §15) — captured from the POS in one tap when
/// an item is not found. Reports aggregate by product/barcode/scientific name
/// to drive purchasing decisions.
@DataClassName('LostSaleRow')
@TableIndex(name: 'idx_lost_sales_requested', columns: {#requestedItemName})
@TableIndex(name: 'idx_lost_sales_scientific', columns: {#scientificName})
@TableIndex(name: 'idx_lost_sales_status', columns: {#status})
@TableIndex(name: 'idx_lost_sales_created', columns: {#createdAt})
class LostSales extends Table {
  TextColumn get id => text()();
  TextColumn get requestedItemName => text()();
  TextColumn get barcode => text().nullable()();
  TextColumn get scientificName => text().nullable()();
  IntColumn get quantityRequested => integer()();
  TextColumn get customerName => text().nullable()();
  TextColumn get customerPhone => text().nullable()();
  TextColumn get userId => text().references(Users, #id)();
  TextColumn get status => textEnum<LostSaleStatus>()();
  TextColumn get note => text().nullable()();
  IntColumn get createdAt => integer()();
  IntColumn get updatedAt => integer()();

  @override
  Set<Column> get primaryKey => {id};

  @override
  List<String> get customConstraints => [
        'CHECK (quantity_requested > 0)',
      ];
}