import '../../../../core/data_grid/page_request.dart';
import '../entities/user.dart';

/// Inputs for creating / updating a user (§4.25 + §12).
class UserCreateRequest {
  const UserCreateRequest({
    required this.username,
    required this.displayName,
    required this.roleId,
    required this.passwordHash,
    this.phone,
    this.notes,
    this.isActive = true,
  });

  final String username;
  final String displayName;
  final String roleId;

  /// Pre-hashed password (bcrypt). Plaintext never reaches the repository.
  final String passwordHash;
  final String? phone;
  final String? notes;
  final bool isActive;
}

class UserUpdateRequest {
  const UserUpdateRequest({
    required this.id,
    required this.displayName,
    required this.roleId,
    this.phone,
    this.notes,
  });

  final String id;
  final String displayName;
  final String roleId;
  final String? phone;
  final String? notes;
}

/// Data access contract for authentication & user management.
///
/// Implementation lives in the Data layer; use cases depend only on this
/// interface so domain stays free of Flutter/Drift types.
abstract class AuthRepository {
  Future<AppUser?> findByUsername(String username);

  Future<AppUser?> findById(String id);

  Future<AppUser> createUser(UserCreateRequest request);

  Future<AppUser> updateUser(UserUpdateRequest request);

  Future<void> setActive(String id, bool active);

  /// Replaces the bcrypt hash (no plaintext is ever stored).
  Future<void> changePasswordHash(String id, String newPasswordHash);

  Future<void> recordLogin(String id, {required int atMillis});

  Future<PageResult<AppUser>> listUsers(PageRequest request);

  Future<List<RoleInfo>> listRoles();

  Future<Set<String>> permissionsForRole(String? roleId);

  Future<bool> hasPermission(String? roleId, String permissionCode);
}