import 'package:drift/drift.dart';

@DataClassName('CustomerRow')
@TableIndex(name: 'idx_customers_name', columns: {#name})
class Customers extends Table {
  TextColumn get id => text()();
  TextColumn get name => text()();
  TextColumn get phone => text().nullable()();
  TextColumn get secondaryPhone => text().nullable()();
  TextColumn get email => text().nullable()();
  TextColumn get address => text().nullable()();
  TextColumn get taxVatNumber => text().nullable()();
  IntColumn get openingBalanceMicros => integer().withDefault(const Constant(0))();
  IntColumn get balanceMicros => integer().withDefault(const Constant(0))();
  IntColumn get creditLimitMicros => integer().withDefault(const Constant(0))();
  TextColumn get notes => text().nullable()();
  BoolColumn get isActive => boolean().withDefault(const Constant(true))();
  IntColumn get createdAt => integer()();
  IntColumn get updatedAt => integer()();

  @override
  Set<Column> get primaryKey => {id};
}