import 'package:get_it/get_it.dart';

import '../../data/daos/batch_dao.dart';
import '../../data/daos/category_dao.dart';
import '../../data/daos/item_dao.dart';
import '../../data/daos/manufacturer_dao.dart';
import '../../data/daos/stock_movement_dao.dart';
import '../../data/daos/therapeutic_group_dao.dart';
import '../../data/daos/unit_dao.dart';
import '../../domain/services/audit_service.dart';
import '../../domain/services/base_unit_converter.dart';
import '../../domain/services/bonus_calculator.dart';
import '../../domain/services/permission_service.dart';
import '../../domain/services/purchase_service.dart';
import '../../domain/services/return_service.dart';
import '../../domain/services/sale_service.dart';
import '../../domain/services/stock_service.dart';
import '../../features/auth/application/auth_controller.dart';
import '../../features/auth/application/users_controller.dart';
import '../../features/auth/data/daos/user_dao.dart';
import '../../features/auth/data/repositories/auth_repository_impl.dart';
import '../../features/auth/domain/repositories/auth_repository.dart';
import '../../features/auth/domain/services/password_service.dart';
import '../../features/auth/domain/usecases/change_password.dart';
import '../../features/auth/domain/usecases/check_permission.dart';
import '../../features/auth/domain/usecases/create_user.dart';
import '../../features/auth/domain/usecases/deactivate_user.dart';
import '../../features/auth/domain/usecases/get_current_user.dart';
import '../../features/auth/domain/usecases/list_users.dart';
import '../../features/auth/domain/usecases/login.dart';
import '../../features/auth/domain/usecases/logout.dart';
import '../../features/auth/domain/usecases/reactivate_user.dart';
import '../../features/auth/domain/usecases/update_user.dart';
import '../../shared/database/app_database.dart';
import '../../shared/models/enums.dart';

final getIt = GetIt.instance;

/// Registers the singleton dependency graph (databases, DAOs, services).
void setupDependencies() {
  if (getIt.isRegistered<AppDatabase>()) return;

  getIt.registerLazySingleton<AppDatabase>(() => AppDatabase.runtime());

  // Pure domain services.
  getIt.registerLazySingleton<BaseUnitConverter>(
      () => const BaseUnitConverter());
  getIt.registerLazySingleton<BonusCalculator>(() => const BonusCalculator());
  getIt.registerLazySingleton<StockService>(() => const StockService());
  getIt.registerLazySingleton<AuditService>(() => const AuditService());
  getIt.registerLazySingleton<PermissionService>(
      () => const PermissionService());

  // Transactional services.
  getIt.registerLazySingleton<SaleService>(() => SaleService());
  getIt.registerLazySingleton<PurchaseService>(() => PurchaseService());
  getIt.registerLazySingleton<ReturnService>(() => ReturnService());

  // DAOs.
  final db = getIt<AppDatabase>();
  getIt.registerLazySingleton<ItemDao>(() => ItemDao(db));
  getIt.registerLazySingleton<UnitDao>(() => UnitDao(db));
  getIt.registerLazySingleton<BatchDao>(() => BatchDao(db));
  getIt.registerLazySingleton<StockMovementDao>(() => StockMovementDao(db));
  getIt.registerLazySingleton<CategoryDao>(() => CategoryDao(db));
  getIt.registerLazySingleton<ManufacturerDao>(() => ManufacturerDao(db));
  getIt.registerLazySingleton<TherapeuticGroupDao>(
      () => TherapeuticGroupDao(db));

  _registerAuth(db);
}

/// Auth & user-management graph (§16). AuthController's audit callback writes
/// the immutable audit trail for login success/failure and logout.
void _registerAuth(AppDatabase db) {
  final audit = getIt<AuditService>();
  final passwords = const PasswordService();

  getIt.registerLazySingleton<UserDao>(() => UserDao(db));
  getIt.registerLazySingleton<AuthRepository>(
      () => AuthRepositoryImpl(getIt<UserDao>()));

  final authRepo = getIt<AuthRepository>();
  getIt.registerLazySingleton<LoginUseCase>(() => LoginUseCase(authRepo, passwords));
  getIt.registerLazySingleton<LogoutUseCase>(() => const LogoutUseCase());
  getIt.registerLazySingleton<GetCurrentUserUseCase>(() => GetCurrentUserUseCase(authRepo));
  getIt.registerLazySingleton<ChangePasswordUseCase>(() => ChangePasswordUseCase(authRepo, passwords));
  getIt.registerLazySingleton<ListUserPermissionsUseCase>(() => ListUserPermissionsUseCase(authRepo));
  getIt.registerLazySingleton<CheckPermissionUseCase>(() => CheckPermissionUseCase(authRepo));
  getIt.registerLazySingleton<CreateUserUseCase>(() => CreateUserUseCase(authRepo, passwords));
  getIt.registerLazySingleton<UpdateUserUseCase>(() => UpdateUserUseCase(authRepo));
  getIt.registerLazySingleton<DeactivateUserUseCase>(() => DeactivateUserUseCase(authRepo));
  getIt.registerLazySingleton<ReactivateUserUseCase>(() => ReactivateUserUseCase(authRepo));
  getIt.registerLazySingleton<ListUsersUseCase>(() => ListUsersUseCase(authRepo));
  getIt.registerLazySingleton<ListRolesUseCase>(() => ListRolesUseCase(authRepo));

  getIt.registerLazySingleton<AuthController>(() {
    final controller = AuthController(
      getIt<LoginUseCase>(),
      getIt<LogoutUseCase>(),
      getIt<GetCurrentUserUseCase>(),
      getIt<ListUserPermissionsUseCase>(),
    );
    controller.audit = ({
      required user,
      required success,
      note = '',
    }) async {
      // Unknown usernames have no row, and audit_logs.userId is NOT NULL;
      // those failures are intentionally not auditable (§4.27).
      if (user == null) return;
      final action = switch (note) {
        'logout' => AuditAction.logout,
        _ when success => AuditAction.login,
        _ => AuditAction.loginFailed,
      };
      try {
        await audit.write(
          db,
          userId: user.id,
          action: action,
          entityType: 'user',
          entityId: user.id,
          note: note,
        );
      } catch (_) {
        // Audit must never break the login flow.
      }
    };
    return controller;
  });

  getIt.registerLazySingleton<UsersViewController>(() => UsersViewController(
        getIt<ListUsersUseCase>(),
        getIt<ListRolesUseCase>(),
        getIt<CreateUserUseCase>(),
        getIt<UpdateUserUseCase>(),
        getIt<DeactivateUserUseCase>(),
        getIt<ReactivateUserUseCase>(),
        getIt<ChangePasswordUseCase>(),
        audit,
        db,
      ));
}