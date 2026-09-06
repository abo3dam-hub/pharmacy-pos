import 'package:pharmacy_pos/core/constants/permission_codes.dart';
import 'package:pharmacy_pos/core/errors/exceptions.dart';

import '../entities/user.dart';
import '../repositories/auth_repository.dart';
import '../services/password_service.dart';
import '../services/permission_guard.dart';

/// Creates a user: validates input, hashes the password (bcrypt), and persists
/// the account with the given role (§16). Requires `users.create`.
class CreateUserUseCase {
  const CreateUserUseCase(this._repository, this._passwords);

  final AuthRepository _repository;
  final PasswordService _passwords;

  Future<AppUser> call({
    required String username,
    required String displayName,
    required String roleId,
    required String password,
    String? phone,
    String? notes,
    String? actingRoleId,
  }) async {
    await ensurePermission(_repository, actingRoleId, Perm.usersCreate);
    final normalized = username.trim();
    if (normalized.isEmpty) {
      throw ValidationException('اسم المستخدم مطلوب');
    }
    if (displayName.trim().isEmpty) {
      throw ValidationException('الاسم مطلوب');
    }
    if (!_passwords.isValidLength(password)) {
      throw ValidationException('كلمة المرور قصيرة جدًا');
    }
    if (await _repository.findByUsername(normalized) != null) {
      throw DuplicateException('اسم المستخدم مستخدم مسبقًا');
    }
    final hash = _passwords.hash(password);
    return _repository.createUser(UserCreateRequest(
      username: normalized,
      displayName: displayName.trim(),
      roleId: roleId,
      passwordHash: hash,
      phone: phone,
      notes: notes,
    ));
  }
}