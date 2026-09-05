import '../../core/errors/exceptions.dart';
import '../../shared/database/app_database.dart';

/// RBAC enforcement (§16). Permissions are checked in the domain/use-case layer
/// and reflected in the UI (hide/disable). Permission mutations are audited.
class PermissionService {
  const PermissionService();

  /// Resolves the role id of a user id, or null when absent.
  Future<String?> roleIdForUser(AppDatabase db, String userId) async {
    final user = await (db.select(db.users)
          ..where((u) => u.id.equals(userId)))
        .getSingleOrNull();
    return user?.roleId;
  }

  /// Set of permission codes currently granted to [roleId].
  Future<Set<String>> codesForRole(AppDatabase db, String? roleId) async {
    if (roleId == null) return const {};
    final rows = await (db.select(db.rolePermissions)
          ..where((rp) => rp.roleId.equals(roleId)))
        .get();
    final ids = rows.map((rp) => rp.permissionId).toSet();
    if (ids.isEmpty) return const {};
    final perms = await (db.select(db.permissions)
          ..where((p) => p.id.isIn(ids)))
        .get();
    return perms.map((p) => p.code).toSet();
  }

  Future<bool> hasRolePermission(
    AppDatabase db,
    String? roleId,
    String permissionCode,
  ) async {
    if (roleId == null) return false;
    final codes = await codesForRole(db, roleId);
    return codes.contains(permissionCode);
  }

  /// Convenience: checks by user id, looking up the user's role.
  Future<bool> hasUserPermission(
    AppDatabase db,
    String? userId,
    String permissionCode,
  ) async {
    if (userId == null) return false;
    final roleId = await roleIdForUser(db, userId);
    return hasRolePermission(db, roleId, permissionCode);
  }

  /// Throws [UnauthorizedException] unless the role holds the permission.
  Future<void> requireRolePermission(
    AppDatabase db,
    String? roleId,
    String permissionCode,
  ) async {
    if (!await hasRolePermission(db, roleId, permissionCode)) {
      throw UnauthorizedException('ليست لديك صلاحية: $permissionCode');
    }
  }

  /// Throws [UnauthorizedException] unless the user holds the permission.
  Future<void> requireUserPermission(
    AppDatabase db,
    String? userId,
    String permissionCode,
  ) async {
    if (!await hasUserPermission(db, userId, permissionCode)) {
      throw UnauthorizedException('ليست لديك صلاحية: $permissionCode');
    }
  }
}