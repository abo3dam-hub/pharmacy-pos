import 'package:drift/drift.dart';
import 'roles.dart';

@DataClassName('UserRow')
@TableIndex(name: 'idx_users_role', columns: {#roleId})
class Users extends Table {
  TextColumn get id => text()();
  TextColumn get username => text().unique()();
  TextColumn get passwordHash => text()();
  TextColumn get fullName => text()();
  TextColumn get roleId => text().nullable().references(Roles, #id)();
  TextColumn get phone => text().nullable()();
  BoolColumn get isActive => boolean().withDefault(const Constant(true))();
  IntColumn get lastLoginAt => integer().nullable()();
  TextColumn get notes => text().nullable()();
  IntColumn get createdAt => integer()();
  IntColumn get updatedAt => integer()();

  @override
  Set<Column> get primaryKey => {id};
}