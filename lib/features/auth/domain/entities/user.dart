/// Canonical system roles. The DB is the source of truth for role rows
/// (`roles.name` = 'admin' | 'pharmacist' | 'cashier' | 'viewer'); this enum
/// is the domain-level convenience used by the UI and default assignment.
enum UserRole {
  admin,
  pharmacist,
  cashier,
  viewer;

  /// Canonical `roles.name` persistence-literal for this role (§4.26).
  String get code => switch (this) {
        UserRole.admin => 'admin',
        UserRole.pharmacist => 'pharmacist',
        UserRole.cashier => 'cashier',
        UserRole.viewer => 'viewer',
      };

  /// The seeded stable `roles.id` that holds this role (§16 seeds).
  String get roleId => switch (this) {
        UserRole.admin => 'role_admin',
        UserRole.pharmacist => 'role_pharmacist',
        UserRole.cashier => 'role_cashier',
        UserRole.viewer => 'role_viewer',
      };

  static UserRole? fromCode(String? code) => switch (code) {
        'admin' => UserRole.admin,
        'pharmacist' => UserRole.pharmacist,
        'cashier' => UserRole.cashier,
        'viewer' => UserRole.viewer,
        _ => null,
      };
}

/// A role row as exposed to domain/UI (name + Arabic label).
class RoleInfo {
  const RoleInfo({
    required this.id,
    required this.name,
    required this.nameAr,
    this.isSystem = false,
  });

  final String id;
  final String name;
  final String nameAr;
  final bool isSystem;

  UserRole? get userRole => UserRole.fromCode(name);
}

/// Authenticated user — maps the `users` row (§4.25) into a pure domain entity.
///
/// [passwordHash] is the **bcrypt hash only**; plaintext never lives on the
/// entity, the session, or in memory beyond the login form field.
class AppUser {
  const AppUser({
    required this.id,
    required this.username,
    required this.displayName,
    required this.roleId,
    required this.isActive,
    required this.passwordHash,
    required this.createdAt,
    required this.updatedAt,
    this.roleName,
    this.roleNameAr,
    this.phone,
    this.notes,
    this.lastLoginAt,
  });

  final String id;
  final String username;
  final String displayName;
  final String roleId;
  final String? roleName;
  final String? roleNameAr;
  final bool isActive;
  final String passwordHash;
  final int createdAt;
  final int updatedAt;
  final int? lastLoginAt;
  final String? phone;
  final String? notes;

  String get roleLabel => roleNameAr ?? roleName ?? roleId;

  bool get isAdmin => roleId == UserRole.admin.roleId;

  AppUser copyWith({
    String? id,
    String? username,
    String? displayName,
    String? roleId,
    String? roleName,
    String? roleNameAr,
    bool? isActive,
    String? passwordHash,
    int? createdAt,
    int? updatedAt,
    int? Function()? lastLoginAt,
    String? Function()? phone,
    String? Function()? notes,
  }) {
    return AppUser(
      id: id ?? this.id,
      username: username ?? this.username,
      displayName: displayName ?? this.displayName,
      roleId: roleId ?? this.roleId,
      roleName: roleName ?? this.roleName,
      roleNameAr: roleNameAr ?? this.roleNameAr,
      isActive: isActive ?? this.isActive,
      passwordHash: passwordHash ?? this.passwordHash,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      lastLoginAt: lastLoginAt != null ? lastLoginAt() : this.lastLoginAt,
      phone: phone != null ? phone() : this.phone,
      notes: notes != null ? notes() : this.notes,
    );
  }

  /// Non-sensitive snapshot used in audit rows (never the password hash).
  Map<String, Object?> toAuditJson() => {
        'id': id,
        'username': username,
        'fullName': displayName,
        'roleId': roleId,
        'isActive': isActive,
        'lastLoginAt': lastLoginAt,
      };
}

/// Login outcome codes — kept separate from the string catalog so domain stays
/// pure; the UI maps each code to a localized message.
enum LoginFailure { invalidCredentials, inactive }