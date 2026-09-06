import 'package:drift/drift.dart';

import '../../../../core/data_grid/page_request.dart';
import '../../../../core/errors/exceptions.dart';
import '../../../../core/util/ids.dart';
import '../../../../shared/database/app_database.dart';
import '../../domain/entities/user.dart';
import '../../domain/repositories/auth_repository.dart';

/// Drift data source for authentication & user management (§4.25–§4.26).
///
/// Maps `users` rows (with their role labels) to pure domain [AppUser] values.
/// Username lookups are exact and case-insensitive; search is resolved in SQL
/// (LIKE on username/fullName), never in Dart (§30).
class UserDao {
  const UserDao(this._db);

  final AppDatabase _db;

  AppUser _map(UserRow u, RoleRow? role) => AppUser(
        id: u.id,
        username: u.username,
        displayName: u.fullName,
        roleId: u.roleId,
        roleName: role?.name,
        roleNameAr: role?.nameAr,
        isActive: u.isActive,
        passwordHash: u.passwordHash,
        createdAt: u.createdAt,
        updatedAt: u.updatedAt,
        lastLoginAt: u.lastLoginAt,
        phone: u.phone,
        notes: u.notes,
      );

  Future<RoleRow?> _roleFor(String roleId) =>
      (_db.select(_db.roles)..where((r) => r.id.equals(roleId))).getSingleOrNull();

  Future<AppUser?> findByUsername(String username) async {
    final row = await (_db.select(_db.users)
          ..where((u) => u.username.lower().equals(username.toLowerCase())))
        .getSingleOrNull();
    if (row == null) return null;
    return _map(row, await _roleFor(row.roleId));
  }

  Future<AppUser?> findById(String id) async {
    final row = await (_db.select(_db.users)..where((u) => u.id.equals(id)))
        .getSingleOrNull();
    if (row == null) return null;
    return _map(row, await _roleFor(row.roleId));
  }

  Future<AppUser> createUser(UserCreateRequest request) async {
    final now = DateTime.now().millisecondsSinceEpoch;
    final id = newId('user');
    await _db.into(_db.users).insert(UsersCompanion.insert(
          id: id,
          username: request.username,
          passwordHash: request.passwordHash,
          fullName: request.displayName,
          roleId: request.roleId,
          isActive: Value(request.isActive),
          phone: Value(request.phone),
          notes: Value(request.notes),
          createdAt: now,
          updatedAt: now,
        ));
    final created = await findById(id);
    if (created == null) {
      throw InvalidOperationException('فشل حفظ المستخدم');
    }
    return created;
  }

  Future<AppUser> updateUser(UserUpdateRequest request) async {
    final now = DateTime.now().millisecondsSinceEpoch;
    await (_db.update(_db.users)..where((u) => u.id.equals(request.id))).write(
          UsersCompanion(
            fullName: Value(request.displayName),
            roleId: Value(request.roleId),
            phone: Value(request.phone),
            notes: Value(request.notes),
            updatedAt: Value(now),
          ),
        );
    final updated = await findById(request.id);
    if (updated == null) {
      throw NotFoundException('المستخدم غير موجود');
    }
    return updated;
  }

  Future<void> setActive(String id, bool active) async {
    await (_db.update(_db.users)..where((u) => u.id.equals(id))).write(
          UsersCompanion(
            isActive: Value(active),
            updatedAt: Value(DateTime.now().millisecondsSinceEpoch),
          ),
        );
  }

  Future<void> changePasswordHash(String id, String newPasswordHash) async {
    await (_db.update(_db.users)..where((u) => u.id.equals(id))).write(
          UsersCompanion(
            passwordHash: Value(newPasswordHash),
            updatedAt: Value(DateTime.now().millisecondsSinceEpoch),
          ),
        );
  }

  Future<void> recordLogin(String id, {required int atMillis}) async {
    await (_db.update(_db.users)..where((u) => u.id.equals(id))).write(
          UsersCompanion(
            lastLoginAt: Value(atMillis),
            updatedAt: Value(atMillis),
          ),
        );
  }

  Future<PageResult<AppUser>> listUsers(PageRequest request) async {
    final q = request.search.trim();
    final filter = q.isNotEmpty
        ? _db.users.username.lower().like('%$q%') |
            _db.users.fullName.lower().like('%$q%')
        : null;

    final totalExpr = _db.users.id.count();
    final countQuery = _db.selectOnly(_db.users)..addColumns([totalExpr]);
    if (filter != null) countQuery.where(filter);
    final countRow = await countQuery.getSingle();

    final query = _db.select(_db.users);
    if (filter != null) query.where((u) => filter);
    query
      ..orderBy([(u) => OrderingTerm.asc(u.fullName)])
      ..limit(request.pageSize, offset: request.offset);
    final rows = await query.get();

    final users = <AppUser>[];
    for (final row in rows) {
      users.add(_map(row, await _roleFor(row.roleId)));
    }
    return PageResult(
      items: users,
      total: countRow.read(totalExpr) ?? 0,
      request: request,
    );
  }

  Future<List<RoleInfo>> listRoles() async {
    final rows = await (_db.select(_db.roles)
          ..where((r) => r.isActive.equals(true))
          ..orderBy([(r) => OrderingTerm.asc(r.name)]))
        .get();
    return rows
        .map((r) => RoleInfo(
              id: r.id,
              name: r.name,
              nameAr: r.nameAr,
              isSystem: r.isSystem,
            ))
        .toList();
  }

  Future<Set<String>> permissionsForRole(String? roleId) async {
    if (roleId == null) return const {};
    final rows = await (_db.select(_db.rolePermissions)
          ..where((rp) => rp.roleId.equals(roleId) & rp.granted.equals(true)))
        .get();
    final ids = rows.map((rp) => rp.permissionId).toSet();
    if (ids.isEmpty) return const {};
    final perms = await (_db.select(_db.permissions)
          ..where((p) => p.id.isIn(ids)))
        .get();
    return perms.map((p) => p.code).toSet();
  }

  Future<bool> hasPermission(String? roleId, String permissionCode) async {
    final codes = await permissionsForRole(roleId);
    return codes.contains(permissionCode);
  }
}