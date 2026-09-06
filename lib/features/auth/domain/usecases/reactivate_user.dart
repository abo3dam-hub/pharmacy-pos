import 'package:pharmacy_pos/core/constants/permission_codes.dart';
import 'package:pharmacy_pos/core/errors/exceptions.dart';

import '../repositories/auth_repository.dart';
import '../services/permission_guard.dart';

/// Reactivates a user (`is_active = 1`). Requires `users.edit`.
class ReactivateUserUseCase {
  const ReactivateUserUseCase(this._repository);

  final AuthRepository _repository;

  Future<void> call(String id, {String? actingRoleId}) async {
    await ensurePermission(_repository, actingRoleId, Perm.usersEdit);
    final user = await _repository.findById(id);
    if (user == null) {
      throw NotFoundException('المستخدم غير موجود');
    }
    if (user.isActive) return;
    await _repository.setActive(id, true);
  }
}