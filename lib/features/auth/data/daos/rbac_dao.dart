import 'package:drift/drift.dart';

import '../../../../../core/errors/exceptions.dart';
import '../../../../../core/util/ids.dart';
import '../../../../../shared/database/app_database.dart';
import '../../domain/entities/rbac.dart';

/// Poor-man's module grouping for the permission-assignment dialog (Phase 12).
/// Group label is derived from the `code` prefix; see [PermissionGroups] for
/// the localized display names.
String permissionModule(String code) {
  final dot = code.indexOf('.');
  return dot == -1 ? 'general' : code.substring(0, dot);
}

/// Role/permission data access over the pre-existing §4.25 tables. All
/// mutations happen in transactions; role rows are never deleted out from
/// under their users (guard in the use-case layer).
class RbacDao {
  const RbacDao(this._db);

  final AppDatabase _db;

  /// All roles ordered by creation (system first), with permission+user counts.
  Future<List<RoleRecord>> listRoles() async {
    final roles = await _db.select(_db.roles).get();
    final perms = await _permissionCountsByRole();
    final users = await _userCountsByRole();
    return [
      for (final role in roles)
        RoleRecord(
          id: role.id,
          name: role.name,
          nameAr: role.nameAr,
          isSystem: role.isSystem,
          isActive: role.isActive,
          createdAt: role.createdAt,
          updatedAt: role.updatedAt,
          permissionCount: perms[role.id] ?? 0,
          userCount: users[role.id] ?? 0,
        ),
    ];
  }

  /// All canonical permissions ordered by code.
  Future<List<PermissionInfo>> listPermissions() async {
    final rows = await _db.select(_db.permissions).get()
      ..sort((a, b) => a.code.compareTo(b.code));
    return [
      for (final row in rows)
        PermissionInfo(id: row.id, code: row.code, nameAr: row.nameAr),
    ];
  }

  Future<Set<String>> getRolePermissionCodes(String roleId) async {
    final rows = await (_db.select(_db.rolePermissions)
          ..where((rp) => rp.roleId.equals(roleId) & rp.granted.equals(true)))
        .get();
    final perms = await _db.select(_db.permissions).get();
    final byId = {for (final p in perms) p.id: p.code};
    return {
      for (final rp in rows)
        if (byId[rp.permissionId] != null) byId[rp.permissionId]!,
    };
  }

  /// Creates a custom role. [name] must be unique (also used as display).
  Future<RoleRow> createRole({required String name, required String nameAr}) async {
    final now = DateTime.now().millisecondsSinceEpoch;
    final existing = await (_db.select(_db.roles)
          ..where((r) => r.name.equals(name)))
        .getSingleOrNull();
    if (existing != null) {
      throw DuplicateException('اسم الدور موجود مسبقاً');
    }
    final row = RoleRow(
      id: newId('role'),
      name: name,
      nameAr: nameAr,
      isSystem: false,
      isActive: true,
      createdAt: now,
      updatedAt: now,
    );
    await _db.into(_db.roles).insert(row);
    return row;
  }

  /// Renames a role's Arabic display label (canonical `name` stays stable).
  Future<void> updateRole({
    required String id,
    required String nameAr,
  }) async {
    final now = DateTime.now().millisecondsSinceEpoch;
    await (_db.update(_db.roles)..where((r) => r.id.equals(id))).write(
      RolesCompanion(nameAr: Value(nameAr), updatedAt: Value(now)),
    );
  }

  /// Replaces the role's permission set (delete-then-insert grant rows).
  Future<void> setRolePermissions({
    required String roleId,
    required Set<String> codes,
  }) async {
    final perms = await _db.select(_db.permissions).get();
    final idByCode = {for (final p in perms) p.code: p.id};
    final now = DateTime.now().millisecondsSinceEpoch;
    await _db.transaction(() async {
      await (_db.delete(_db.rolePermissions)
            ..where((rp) => rp.roleId.equals(roleId)))
          .go();
      var i = 0;
      for (final code in codes.toList()..sort()) {
        final pid = idByCode[code];
        if (pid == null) continue;
        await _db.into(_db.rolePermissions).insert(
              RolePermissionsCompanion.insert(
                id: '$roleId.$pid.$i',
                roleId: roleId,
                permissionId: pid,
                granted: const Value(true),
                createdAt: now,
              ),
            );
        i++;
      }
    });
  }

  /// Deletes a custom role and its permission memberships.
  Future<void> deleteRole(String roleId) async {
    await _db.transaction(() async {
      await (_db.delete(_db.rolePermissions)
            ..where((rp) => rp.roleId.equals(roleId)))
          .go();
      await (_db.delete(_db.roles)..where((r) => r.id.equals(roleId))).go();
    });
  }

  /// Stable module ordering for display (matches §16 canonical grouping order).
  static const List<String> moduleOrder = [
    'general',
    'inventory',
    'purchases',
    'sales',
    'customers',
    'prescriptions',
    'cashbox',
    'expenses',
    'accounting',
    'lost_sales',
    'reports',
    'users',
    'roles',
    'audit',
    'settings',
    'backup',
  ];

  Future<Map<String, int>> _permissionCountsByRole() async {
    final rows = await _db.customSelect(
      'SELECT role_id AS roleId, COUNT(*) AS n FROM role_permissions'
      ' WHERE granted = 1 GROUP BY role_id',
    ).get();
    return {for (final r in rows) r.read<String>('roleId'): r.read<int>('n')};
  }

  Future<Map<String, int>> _userCountsByRole() async {
    final rows = await _db.customSelect(
      'SELECT role_id AS roleId, COUNT(*) AS n FROM users'
      ' WHERE is_active = 1 GROUP BY role_id',
    ).get();
    return {for (final r in rows) r.read<String>('roleId'): r.read<int>('n')};
  }
}

/// Localized module display labels for the permission dialog.
class PermissionGroups {
  PermissionGroups._();

  static const Map<String, ({String ar, String en})> _labels = {
    'general': (ar: 'عام (الأساسيات)', en: 'General (core)'),
    'inventory': (ar: 'المخزون', en: 'Inventory'),
    'purchases': (ar: 'المشتريات', en: 'Purchases'),
    'sales': (ar: 'المبيعات', en: 'Sales'),
    'customers': (ar: 'العملاء', en: 'Customers'),
    'prescriptions': (ar: 'الوصفات الطبية', en: 'Prescriptions'),
    'cashbox': (ar: 'الصندوق', en: 'Cashbox'),
    'expenses': (ar: 'المصروفات', en: 'Expenses'),
    'accounting': (ar: 'المحاسبة', en: 'Accounting'),
    'lost_sales': (ar: 'النواقص', en: 'Lost sales'),
    'reports': (ar: 'التقارير', en: 'Reports'),
    'users': (ar: 'المستخدمون', en: 'Users'),
    'roles': (ar: 'الأدوار والصلاحيات', en: 'Roles & permissions'),
    'audit': (ar: 'سجل التدقيق', en: 'Audit log'),
    'settings': (ar: 'الإعدادات', en: 'Settings'),
    'backup': (ar: 'النسخ الاحتياطي', en: 'Backup'),
  };

  static String label(String module, String languageCode) {
    final entry = _labels[module];
    if (entry == null) return module;
    return languageCode == 'en' ? entry.en : entry.ar;
  }

  /// Groups permissions by module, ordered per [RbacDao.moduleOrder].
  static List<({String module, List<PermissionInfo> permissions})> group(
    List<PermissionInfo> permissions,
  ) {
    final buckets = <String, List<PermissionInfo>>{};
    for (final p in permissions) {
      buckets.putIfAbsent(permissionModule(p.code), () => []).add(p);
    }
    final ordered = <String>[
      for (final m in RbacDao.moduleOrder)
        if (buckets.containsKey(m)) m,
      for (final m in buckets.keys)
        if (!RbacDao.moduleOrder.contains(m)) m,
    ];
    return [
      for (final m in ordered)
        (module: m, permissions: buckets[m]!),
    ];
  }
}