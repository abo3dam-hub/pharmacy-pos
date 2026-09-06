import 'package:drift/drift.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pharmacy_pos/core/di/providers.dart';
import 'package:pharmacy_pos/domain/services/audit_service.dart';
import 'package:pharmacy_pos/features/auth/application/auth_controller.dart';
import 'package:pharmacy_pos/features/auth/application/users_controller.dart';
import 'package:pharmacy_pos/features/auth/data/daos/user_dao.dart';
import 'package:pharmacy_pos/features/auth/data/repositories/auth_repository_impl.dart';
import 'package:pharmacy_pos/features/auth/domain/repositories/auth_repository.dart';
import 'package:pharmacy_pos/features/auth/domain/services/password_service.dart';
import 'package:pharmacy_pos/features/auth/domain/usecases/change_password.dart';
import 'package:pharmacy_pos/features/auth/domain/usecases/check_permission.dart';
import 'package:pharmacy_pos/features/auth/domain/usecases/create_user.dart';
import 'package:pharmacy_pos/features/auth/domain/usecases/deactivate_user.dart';
import 'package:pharmacy_pos/features/auth/domain/usecases/get_current_user.dart';
import 'package:pharmacy_pos/features/auth/domain/usecases/list_users.dart';
import 'package:pharmacy_pos/features/auth/domain/usecases/login.dart';
import 'package:pharmacy_pos/features/auth/domain/usecases/logout.dart';
import 'package:pharmacy_pos/features/auth/domain/usecases/reactivate_user.dart';
import 'package:pharmacy_pos/features/auth/domain/usecases/update_user.dart';
import 'package:pharmacy_pos/shared/database/app_database.dart';

import 'helpers.dart';

/// Builds the auth dependency graph over an in-memory testing DB and returns
/// the wired [ProviderContainer] plus the DB for direct assertions.
///
/// The DB seeds its defaults on create (§4.25), so no extra seeding is needed.
/// Overrides the real getIt-backed singletons so widget tests stay hermetic.
Future<({ProviderContainer container, AppDatabase db, AuthRepository repository})>
    buildAuthHarness() async {
  final db = newDatabase();
  return attachAuthTo(db);
}

/// Wires auth providers to an existing testing DB (used after seeding).
({ProviderContainer container, AppDatabase db, AuthRepository repository})
    attachAuthTo(AppDatabase db) {
  final passwords = const PasswordService();
  final repository = AuthRepositoryImpl(UserDao(db));

  final authController = AuthController(
    LoginUseCase(repository, passwords),
    const LogoutUseCase(),
    GetCurrentUserUseCase(repository),
    ListUserPermissionsUseCase(repository),
  );
  // No-op audit for hermetic widget tests (audit rows are covered by the
  // controller's own tests against a real DB).
  authController.audit = ({required user, required success, note = ''}) async {};

  final usersController = UsersViewController(
    ListUsersUseCase(repository),
    ListRolesUseCase(repository),
    CreateUserUseCase(repository, passwords),
    UpdateUserUseCase(repository),
    DeactivateUserUseCase(repository),
    ReactivateUserUseCase(repository),
    ChangePasswordUseCase(repository, passwords),
    const AuditService(),
    db,
  );

  final container = ProviderContainer(overrides: [
    databaseProvider.overrideWithValue(db),
    authRepositoryProvider.overrideWithValue(repository),
    authControllerProvider.overrideWith((ref) => authController),
    usersViewControllerProvider.overrideWith((ref) => usersController),
  ]);
  return (container: container, db: db, repository: repository);
}

/// Seeds an additional user directly (bypassing the permission-gated use case)
/// for setups that need a second account before/without login.
Future<void> seedExtraUser(
  AppDatabase db, {
  String username = 'cashier',
  String password = 'Cashier@123',
  String roleId = 'role_cashier',
  String fullName = 'كاشير',
}) async {
  final passwords = const PasswordService();
  await db.into(db.users).insert(
        UsersCompanion.insert(
          id: 'user_$username',
          username: username,
          passwordHash: passwords.hash(password),
          fullName: fullName,
          roleId: roleId,
          isActive: const Value(true),
          createdAt: DateTime.now().millisecondsSinceEpoch,
          updatedAt: DateTime.now().millisecondsSinceEpoch,
        ),
      );
}