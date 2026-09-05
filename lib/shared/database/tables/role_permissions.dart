import 'package:drift/drift.dart';
import 'permissions.dart';
import 'roles.dart';

/// Membership of a permission in a role (§4.25). `granted` allows
/// clean future negation of a permission without deleting the row.
@DataClassName('RolePermissionRow')
@TableIndex(name: 'idx_role_permissions_permission', columns: {#permissionId})
class RolePermissions extends Table {
  TextColumn get id => text()();
  TextColumn get roleId => text().references(Roles, #id)();
  TextColumn get permissionId =>
      text().references(Permissions, #id)();
  BoolColumn get granted =>
      boolean().withDefault(const Constant(true))();
  IntColumn get createdAt => integer()();

  @override
  Set<Column> get primaryKey => {id};

  @override
  List<Set<Column>> get uniqueKeys => [
        {roleId, permissionId},
      ];
}