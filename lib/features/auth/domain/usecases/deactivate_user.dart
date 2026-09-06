import 'package:pharmacy_pos/core/constants/permission_codes.dart';
import 'package:pharmacy_pos/core/errors/exceptions.dart';

import '../repositories/auth_repository.dart';
import '../services/permission_guard.dart';

/// Deactivates a user (soft disable, §28 — `is_active = 0`).
/// Requires `users.edit`; prevents deactivating the acting admin.
class DeactivateUserUseCase {
  const DeactivateUserUseCase(this._repository);

  final AuthRepository _repository;

  Future<void> call(String id, {String? actingUserId, String? actingRoleId}) async {
    await ensurePermission(_repository, actingRoleId, Perm.usersEdit);
    if (id == actingUserId) {
      throw InvalidOperationException('لا يمكنك تعطيل حسابك الخاص');
    }
    final user = await _repository.findById(id);
    if (user == null) {
      throw NotFoundException('المستخدم غير موجود');
    }
    if (!user.isActive) return;
    await _repository.setActive(id, false);
  }
}