import '../../../../core/data_grid/page_request.dart';
import '../../domain/entities/user.dart';
import '../../domain/repositories/auth_repository.dart';
import '../daos/user_dao.dart';

/// Data-layer implementation of [AuthRepository] backed by [UserDao] (Drift).
class AuthRepositoryImpl implements AuthRepository {
  const AuthRepositoryImpl(this._dao);

  final UserDao _dao;

  @override
  Future<AppUser?> findByUsername(String username) =>
      _dao.findByUsername(username);

  @override
  Future<AppUser?> findById(String id) => _dao.findById(id);

  @override
  Future<AppUser> createUser(UserCreateRequest request) =>
      _dao.createUser(request);

  @override
  Future<AppUser> updateUser(UserUpdateRequest request) =>
      _dao.updateUser(request);

  @override
  Future<void> setActive(String id, bool active) => _dao.setActive(id, active);

  @override
  Future<void> changePasswordHash(String id, String newPasswordHash) =>
      _dao.changePasswordHash(id, newPasswordHash);

  @override
  Future<void> recordLogin(String id, {required int atMillis}) =>
      _dao.recordLogin(id, atMillis: atMillis);

  @override
  Future<PageResult<AppUser>> listUsers(PageRequest request) =>
      _dao.listUsers(request);

  @override
  Future<List<RoleInfo>> listRoles() => _dao.listRoles();

  @override
  Future<Set<String>> permissionsForRole(String? roleId) =>
      _dao.permissionsForRole(roleId);

  @override
  Future<bool> hasPermission(String? roleId, String permissionCode) =>
      _dao.hasPermission(roleId, permissionCode);
}