import '../../../../core/errors/exceptions.dart';
import '../../../../domain/services/audit_service.dart';
import '../../../../domain/services/permission_service.dart';
import '../../../../shared/database/app_database.dart';
import '../../../../shared/models/enums.dart';
import '../entities/rbac.dart';
import '../../data/daos/rbac_dao.dart';

/// Logical minimum permission set the admin role must always keep so role
/// management, user management, settings and the audit viewer never get
/// locked out (bootstrap safety, §16).
const Set<String> kAdminRoleMinimumPermissions = {
  'roles.view',
  'roles.edit',
  'users.view',
  'users.edit',
  'audit.view',
  'settings.view',
  'settings.edit',
  'backup',
  'backup.restore',
  'export.data',
};

/// Loads roles + permissions for the roles page. Requires `roles.view`.
class LoadRolesSnapshotUseCase {
  const LoadRolesSnapshotUseCase(this._dao, this._permissions);

  final RbacDao _dao;
  final PermissionService _permissions;

  Future<RolesSnapshot> call(AppDatabase db, String? actingRoleId) async {
    await _permissions.requireRolePermission(db, actingRoleId, 'roles.view');
    return RolesSnapshot(
      roles: await _dao.listRoles(),
      permissions: await _dao.listPermissions(),
    );
  }
}

/// Loads a single role's permission set. Requires `roles.view`.
class GetRoleDetailUseCase {
  const GetRoleDetailUseCase(this._dao, this._permissions);

  final RbacDao _dao;
  final PermissionService _permissions;

  Future<RoleDetail> call(
    AppDatabase db,
    String? actingRoleId,
    String roleId,
  ) async {
    await _permissions.requireRolePermission(db, actingRoleId, 'roles.view');
    return RoleDetail(
      role: (await _dao.listRoles()).firstWhere((r) => r.id == roleId),
      permissionCodes: await _dao.getRolePermissionCodes(roleId),
    );
  }
}

/// Creates a custom role. Requires `roles.edit`; audited via `role` create.
class CreateRoleUseCase {
  const CreateRoleUseCase(this._dao, this._permissions, this._audit);

  final RbacDao _dao;
  final PermissionService _permissions;
  final AuditService _audit;

  Future<RoleSaveResult> call(
    AppDatabase db, {
    required String name,
    required String nameAr,
    required String? actingUserId,
    required String? actingRoleId,
  }) async {
    await _permissions.requireRolePermission(db, actingRoleId, 'roles.edit');
    if (name.trim().isEmpty) throw ValidationException('اسم الدور مطلوب');

    final role = await _dao.createRole(name: name.trim(), nameAr: nameAr.trim());
    if (actingUserId != null) {
      await _audit.write(
        db,
        userId: actingUserId,
        action: AuditAction.create,
        entityType: 'role',
        entityId: role.id,
        after: {'name': role.name, 'nameAr': role.nameAr},
        note: 'role_created',
      );
    }
    return RoleSaveResult(role: _toRecord(role), permissionCodes: const {});
  }

  RoleRecord _toRecord(RoleRow role) => RoleRecord(
        id: role.id,
        name: role.name,
        nameAr: role.nameAr,
        isSystem: role.isSystem,
        isActive: role.isActive,
        createdAt: role.createdAt,
        updatedAt: role.updatedAt,
      );
}

/// Renames a role's Arabic label. Requires `roles.edit`; audited.
class UpdateRoleUseCase {
  const UpdateRoleUseCase(this._dao, this._permissions, this._audit);

  final RbacDao _dao;
  final PermissionService _permissions;
  final AuditService _audit;

  Future<void> call(
    AppDatabase db, {
    required String id,
    required String nameAr,
    required String? actingUserId,
    required String? actingRoleId,
  }) async {
    await _permissions.requireRolePermission(db, actingRoleId, 'roles.edit');
    if (nameAr.trim().isEmpty) throw ValidationException('الاسم العربي مطلوب');

    final roles = await _dao.listRoles();
    final before = roles.firstWhere((r) => r.id == id);
    await _dao.updateRole(id: id, nameAr: nameAr.trim());
    if (actingUserId != null) {
      await _audit.write(
        db,
        userId: actingUserId,
        action: AuditAction.update,
        entityType: 'role',
        entityId: id,
        before: {'nameAr': before.nameAr},
        after: {'nameAr': nameAr.trim()},
        note: 'role_updated',
      );
    }
  }
}

/// Replaces a role's permission set. Requires `roles.edit`; audited.
///
/// The admin role can never lose [kAdminRoleMinimumPermissions], keeping the
/// bootstrap user able to administer the system.
class SetRolePermissionsUseCase {
  const SetRolePermissionsUseCase(this._dao, this._permissions, this._audit);

  final RbacDao _dao;
  final PermissionService _permissions;
  final AuditService _audit;

  Future<Set<String>> call(
    AppDatabase db, {
    required String roleId,
    required Set<String> codes,
    required bool isSystemRole,
    required String? actingUserId,
    required String? actingRoleId,
  }) async {
    await _permissions.requireRolePermission(db, actingRoleId, 'roles.edit');

    final before = await _dao.getRolePermissionCodes(roleId);
    final normalized = Set<String>.of(codes);
    if (roleId == 'role_admin') {
      normalized.addAll(kAdminRoleMinimumPermissions);
    }
    if (!normalized.contains('roles.view') && isSystemRole) {
      // System roles stay readable — never strip their own view access.
      normalized.add('roles.view');
    }

    await _dao.setRolePermissions(roleId: roleId, codes: normalized);
    if (actingUserId != null) {
      await _audit.write(
        db,
        userId: actingUserId,
        action: AuditAction.bulkOp,
        entityType: 'permission',
        entityId: roleId,
        before: {'codes': [...before]..sort()},
        after: {'codes': [...normalized]..sort()},
        note: 'role_permissions_replaced',
      );
    }
    return normalized;
  }
}

/// Deletes a custom role. Requires `roles.edit`; audited.
///
/// Guards: the admin and seeded system roles are never deletable; a role
/// currently assigned to any user cannot be deleted (reassign first).
class DeleteRoleUseCase {
  const DeleteRoleUseCase(this._dao, this._permissions, this._audit);

  final RbacDao _dao;
  final PermissionService _permissions;
  final AuditService _audit;

  Future<void> call(
    AppDatabase db, {
    required String id,
    required String? actingUserId,
    required String? actingRoleId,
  }) async {
    await _permissions.requireRolePermission(db, actingRoleId, 'roles.edit');

    final roles = await _dao.listRoles();
    final role = roles.firstWhere((r) => r.id == id);
    if (role.isSystem) {
      throw InvalidOperationException('لا يمكن حذف الأدوار الأساسية للنظام');
    }
    if (role.userCount > 0) {
      throw InvalidOperationException(
        'لا يمكن حذف دور معيّن لمستخدمين — أعد تعيين المستخدمين أولاً',
      );
    }
    await _dao.deleteRole(id);
    if (actingUserId != null) {
      await _audit.write(
        db,
        userId: actingUserId,
        action: AuditAction.delete,
        entityType: 'role',
        entityId: id,
        before: {'name': role.name, 'nameAr': role.nameAr},
        note: 'role_deleted',
      );
    }
  }
}