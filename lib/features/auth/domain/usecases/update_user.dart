import 'package:pharmacy_pos/core/constants/permission_codes.dart';
import 'package:pharmacy_pos/core/errors/exceptions.dart';

import '../entities/user.dart';
import '../repositories/auth_repository.dart';
import '../services/permission_guard.dart';

/// Updates a user's profile (display name, role, phone, notes).
/// Requires `users.edit`.
class UpdateUserUseCase {
  const UpdateUserUseCase(this._repository);

  final AuthRepository _repository;

  Future<AppUser> call({
    required String id,
    required String displayName,
    required String roleId,
    String? phone,
    String? notes,
    String? actingRoleId,
  }) async {
    await ensurePermission(_repository, actingRoleId, Perm.usersEdit);
    if (displayName.trim().isEmpty) {
      throw ValidationException('الاسم مطلوب');
    }
    if (await _repository.findById(id) == null) {
      throw NotFoundException('المستخدم غير موجود');
    }
    return _repository.updateUser(UserUpdateRequest(
      id: id,
      displayName: displayName.trim(),
      roleId: roleId,
      phone: phone,
      notes: notes,
    ));
  }
}