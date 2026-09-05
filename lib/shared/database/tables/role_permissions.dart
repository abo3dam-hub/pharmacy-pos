import 'package:drift/drift.dart';
import 'permissions.dart';
import 'roles.dart';

@DataClassName('RolePermissionRow')
class RolePermissions extends Table {
  TextColumn get roleId => text().references(Roles, #id)();
  TextColumn get permissionId =>
      text().references(Permissions, #id)();
  IntColumn get createdAt => integer()();

  @override
  Set<Column> get primaryKey => {roleId, permissionId};
}