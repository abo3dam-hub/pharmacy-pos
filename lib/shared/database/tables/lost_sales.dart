import 'package:drift/drift.dart';
import '../../models/enums.dart';
import 'items.dart';
import 'users.dart';

@DataClassName('LostSaleRow')
@TableIndex(name: 'idx_lost_sales_item', columns: {#itemId})
@TableIndex(name: 'idx_lost_sales_status', columns: {#status})
class LostSales extends Table {
  TextColumn get id => text()();
  TextColumn get itemId => text().references(Items, #id)();
  IntColumn get quantityBase => integer()();
  TextColumn get reason => text().nullable()();
  TextColumn get status => textEnum<LostSaleStatus>()();
  TextColumn get customerInfo => text().nullable()();
  TextColumn get userId => text().nullable().references(Users, #id)();
  IntColumn get createdAt => integer()();
  IntColumn get resolvedAt => integer().nullable()();
  IntColumn get updatedAt => integer()();

  @override
  Set<Column> get primaryKey => {id};

  @override
  List<String> get customConstraints => [
        'CHECK (quantity_base > 0)',
      ];
}