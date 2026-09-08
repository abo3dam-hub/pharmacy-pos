import 'user.dart';

/// A role row with aggregate counts for the Phase 12 roles page.
class RoleRecord {
  const RoleRecord({
    required this.id,
    required this.name,
    required this.nameAr,
    required this.isSystem,
    required this.isActive,
    required this.createdAt,
    required this.updatedAt,
    this.permissionCount = 0,
    this.userCount = 0,
  });

  final String id;
  final String name;
  final String nameAr;
  final bool isSystem;
  final bool isActive;
  final int createdAt;
  final int updatedAt;

  /// Number of granted permissions on this role.
  final int permissionCount;

  /// Number of users holding this role.
  final int userCount;

  /// Whether this is one of the four canonical system roles.
  bool get isAdmin => id == UserRole.admin.roleId;

  RoleRecord copyWith({
    String? nameAr,
    bool? isActive,
    int? permissionCount,
    int? userCount,
  }) {
    return RoleRecord(
      id: id,
      name: name,
      nameAr: nameAr ?? this.nameAr,
      isSystem: isSystem,
      isActive: isActive ?? this.isActive,
      createdAt: createdAt,
      updatedAt: updatedAt,
      permissionCount: permissionCount ?? this.permissionCount,
      userCount: userCount ?? this.userCount,
    );
  }

  UserRole? get userRole => UserRole.fromCode(name);
}

/// A permission row (canonical `code` + Arabic label).
class PermissionInfo {
  const PermissionInfo({
    required this.id,
    required this.code,
    required this.nameAr,
  });

  final String id;
  final String code;
  final String nameAr;
}

/// Role + its currently assigned permission codes.
class RoleDetail {
  const RoleDetail({required this.role, required this.permissionCodes});

  final RoleRecord role;
  final Set<String> permissionCodes;
}

/// Roles list snapshot for the page.
class RolesSnapshot {
  const RolesSnapshot({required this.roles, required this.permissions});

  final List<RoleRecord> roles;
  final List<PermissionInfo> permissions;
}

/// Result of a role-save operation (returned to the controller for refresh).
class RoleSaveResult {
  const RoleSaveResult({
    required this.role,
    required this.permissionCodes,
  });

  final RoleRecord role;
  final Set<String> permissionCodes;
}