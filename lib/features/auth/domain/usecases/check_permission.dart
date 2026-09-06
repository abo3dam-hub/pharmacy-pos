import '../repositories/auth_repository.dart';

/// RBAC check resolved through the repository (never sprinkled in widgets).
class CheckPermissionUseCase {
  const CheckPermissionUseCase(this._repository);

  final AuthRepository _repository;

  Future<bool> call(String? roleId, String permissionCode) =>
      _repository.hasPermission(roleId, permissionCode);
}

/// All permission codes currently granted to a role.
class ListUserPermissionsUseCase {
  const ListUserPermissionsUseCase(this._repository);

  final AuthRepository _repository;

  Future<Set<String>> call(String roleId) =>
      _repository.permissionsForRole(roleId);
}