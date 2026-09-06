import 'package:pharmacy_pos/core/errors/exceptions.dart';

import '../entities/user.dart';
import '../repositories/auth_repository.dart';

/// Reads the current user row (fresh from the store) by id.
class GetCurrentUserUseCase {
  const GetCurrentUserUseCase(this._repository);

  final AuthRepository _repository;

  Future<AppUser> call(String userId) async {
    final user = await _repository.findById(userId);
    if (user == null) {
      throw NotFoundException('المستخدم غير موجود');
    }
    return user;
  }
}