import 'package:pharmacy_pos/core/data_grid/page_request.dart';

import '../entities/user.dart';
import '../repositories/auth_repository.dart';

/// Paged user search (DB-side pagination per §30).
class ListUsersUseCase {
  const ListUsersUseCase(this._repository);

  final AuthRepository _repository;

  Future<PageResult<AppUser>> call(PageRequest request) =>
      _repository.listUsers(request);
}

/// Available roles for assignment dropdowns.
class ListRolesUseCase {
  const ListRolesUseCase(this._repository);

  final AuthRepository _repository;

  Future<List<RoleInfo>> call() => _repository.listRoles();
}