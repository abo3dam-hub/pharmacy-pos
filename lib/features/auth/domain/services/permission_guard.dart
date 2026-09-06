import 'package:pharmacy_pos/core/errors/exceptions.dart';

import '../repositories/auth_repository.dart';

/// Centralized domain-level RBAC guard. Use cases call this with the acting
/// role; it throws [UnauthorizedException] when the permission is missing, so
/// permission logic stays out of widgets and out of the repository.
///
/// A `null` [roleId] means "no role context" and is always denied.
Future<void> ensurePermission(
  AuthRepository repository,
  String? roleId,
  String permissionCode,
) async {
  if (roleId == null || !await repository.hasPermission(roleId, permissionCode)) {
    throw UnauthorizedException('ليست لديك صلاحية لتنفيذ هذا الإجراء');
  }
}