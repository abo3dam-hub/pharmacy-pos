import 'package:drift/drift.dart';
import '../../models/enums.dart';

/// Chart of accounts (دليل الحسابات).
@DataClassName('AccountRow')
@TableIndex(name: 'idx_accounts_type', columns: {#accountType})
class Accounts extends Table {
  TextColumn get id => text()();
  TextColumn get code => text().unique()();
  TextColumn get name => text()();
  TextColumn get accountType => textEnum<AccountType>()();
  TextColumn get parentId => text().nullable().references(Accounts, #id)();
  BoolColumn get isSystem => boolean().withDefault(const Constant(false))();
  IntColumn get openingBalanceMicros => integer().withDefault(const Constant(0))();
  IntColumn get balanceMicros => integer().withDefault(const Constant(0))();
  BoolColumn get isActive => boolean().withDefault(const Constant(true))();
  TextColumn get notes => text().nullable()();
  IntColumn get createdAt => integer()();
  IntColumn get updatedAt => integer()();

  @override
  Set<Column> get primaryKey => {id};
}