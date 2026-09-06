import 'package:pharmacy_pos/core/constants/permission_codes.dart';
import 'package:pharmacy_pos/core/errors/exceptions.dart';

import '../repositories/auth_repository.dart';
import '../services/password_service.dart';
import '../services/permission_guard.dart';

/// Replaces a user's password hash (admin reset / self change).
///
/// Enforces the minimum length; the plaintext password is hashed here and only
/// the hash is handed to the repository. Old password is NOT required (admin
/// reset); self-service flows verify the old password before calling this.
/// Requires `users.edit` when acting on behalf of another user.
class ChangePasswordUseCase {
  const ChangePasswordUseCase(this._repository, this._passwords);

  final AuthRepository _repository;
  final PasswordService _passwords;

  Future<void> call(
    String userId,
    String newPassword, {
    String? actingRoleId,
  }) async {
    await ensurePermission(_repository, actingRoleId, Perm.usersEdit);
    if (!_passwords.isValidLength(newPassword)) {
      throw ValidationException('كلمة المرور قصيرة جدًا');
    }
    final hash = _passwords.hash(newPassword);
    await _repository.changePasswordHash(userId, hash);
  }
}