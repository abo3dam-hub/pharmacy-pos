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
import '../../features/inventory/application/inventory_controller.dart';
import '../../features/inventory/application/master_data_controller.dart';
import '../../features/inventory/data/repositories/inventory_repository_impl.dart';
import '../../features/inventory/domain/repositories/inventory_repository.dart';
import '../../features/inventory/domain/services/inventory_excel_service.dart';
import '../../features/inventory/domain/services/inventory_view_builder.dart';
import '../../features/inventory/domain/usecases/batches_use_cases.dart';
import '../../features/inventory/domain/usecases/bulk_use_cases.dart';
import '../../features/inventory/domain/usecases/categories_use_cases.dart';
import '../../features/inventory/domain/usecases/create_item.dart';
import '../../features/inventory/domain/usecases/excel_use_cases.dart';
import '../../features/inventory/domain/usecases/groups_use_cases.dart';
import '../../features/inventory/domain/usecases/list_items.dart';
import '../../features/inventory/domain/usecases/manufacturers_use_cases.dart';
import '../../features/inventory/domain/usecases/set_item_active.dart';
import '../../features/inventory/domain/usecases/stock_use_cases.dart';
import '../../features/inventory/domain/usecases/units_use_cases.dart';
import '../../features/inventory/domain/usecases/update_item.dart';
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
  _registerInventory(db);
}

/// Inventory & categories module (§3, §4). The feature is wired over the
/// shared DAO graph; stock mutations always go through the ledger.
void _registerInventory(AppDatabase db) {
  final audit = getIt<AuditService>();
  final perms = getIt<PermissionService>();

  getIt.registerLazySingleton<InventoryRepository>(
    () => InventoryRepositoryImpl(
      db,
      getIt<ItemDao>(),
      getIt<CategoryDao>(),
      getIt<ManufacturerDao>(),
      getIt<TherapeuticGroupDao>(),
      getIt<UnitDao>(),
      getIt<BatchDao>(),
      getIt<StockMovementDao>(),
      getIt<StockService>(),
    ),
  );

  final repo = getIt<InventoryRepository>();
  getIt.registerLazySingleton<InventoryViewBuilder>(
      () => InventoryViewBuilder(repo));
  getIt.registerLazySingleton<InventoryExcelService>(
      () => InventoryExcelService(repo));
  final builder = getIt<InventoryViewBuilder>();
  final excel = getIt<InventoryExcelService>();

  // Items
  getIt.registerLazySingleton<ListItemsUseCase>(() => ListItemsUseCase(
        repo,
        perms,
        viewBuilder: builder,
      ));
  getIt.registerLazySingleton<CreateItemUseCase>(
      () => CreateItemUseCase(repo, perms, audit));
  getIt.registerLazySingleton<UpdateItemUseCase>(
      () => UpdateItemUseCase(repo, perms, audit));
  getIt.registerLazySingleton<SetItemActiveUseCase>(
      () => SetItemActiveUseCase(repo, perms, audit));
  getIt.registerLazySingleton<BulkUpdateItemsUseCase>(
      () => BulkUpdateItemsUseCase(repo, perms, audit));

  // Batches & stock
  getIt.registerLazySingleton<ListBatchesUseCase>(
      () => ListBatchesUseCase(repo, perms));
  getIt.registerLazySingleton<AddBatchUseCase>(
      () => AddBatchUseCase(repo, perms, audit));
  getIt.registerLazySingleton<VoidBatchUseCase>(
      () => VoidBatchUseCase(repo, perms, audit));
  getIt.registerLazySingleton<AdjustStockUseCase>(
      () => AdjustStockUseCase(repo, perms, audit));

  // Master data
  getIt.registerLazySingleton<ListCategoriesUseCase>(
      () => ListCategoriesUseCase(repo, perms));
  getIt.registerLazySingleton<SaveCategoryUseCase>(
      () => SaveCategoryUseCase(repo, perms, audit));
  getIt.registerLazySingleton<SaveSubCategoryUseCase>(
      () => SaveSubCategoryUseCase(repo, perms, audit));
  getIt.registerLazySingleton<SetCategoryActiveUseCase>(
      () => SetCategoryActiveUseCase(repo, perms, audit));
  getIt.registerLazySingleton<ListManufacturersUseCase>(
      () => ListManufacturersUseCase(repo, perms));
  getIt.registerLazySingleton<SaveManufacturerUseCase>(
      () => SaveManufacturerUseCase(repo, perms, audit));
  getIt.registerLazySingleton<SetManufacturerActiveUseCase>(
      () => SetManufacturerActiveUseCase(repo, perms, audit));
  getIt.registerLazySingleton<AllManufacturersUseCase>(
      () => AllManufacturersUseCase(repo, perms));
  getIt.registerLazySingleton<ListTherapeuticGroupsUseCase>(
      () => ListTherapeuticGroupsUseCase(repo, perms));
  getIt.registerLazySingleton<SaveTherapeuticGroupUseCase>(
      () => SaveTherapeuticGroupUseCase(repo, perms, audit));
  getIt.registerLazySingleton<SetTherapeuticGroupActiveUseCase>(
      () => SetTherapeuticGroupActiveUseCase(repo, perms, audit));
  getIt.registerLazySingleton<ListUnitsUseCase>(
      () => ListUnitsUseCase(repo, perms));
  getIt.registerLazySingleton<SaveUnitUseCase>(
      () => SaveUnitUseCase(repo, perms, audit));

  // Excel
  getIt.registerLazySingleton<ExportItemsUseCase>(
      () => ExportItemsUseCase(repo, perms, excel, viewBuilder: builder));
  getIt.registerLazySingleton<ImportItemsUseCase>(
      () => ImportItemsUseCase(repo, perms, audit));

  // Controllers
  getIt.registerLazySingleton<InventoryController>(() => InventoryController(
        getIt<ListItemsUseCase>(),
        getIt<CreateItemUseCase>(),
        getIt<UpdateItemUseCase>(),
        getIt<SetItemActiveUseCase>(),
        getIt<AddBatchUseCase>(),
        getIt<VoidBatchUseCase>(),
        getIt<ListBatchesUseCase>(),
        getIt<AdjustStockUseCase>(),
        getIt<BulkUpdateItemsUseCase>(),
        getIt<ExportItemsUseCase>(),
        getIt<ImportItemsUseCase>(),
      ));

  getIt.registerLazySingleton<MasterDataController>(
      () => MasterDataController(
            getIt<ListCategoriesUseCase>(),
            getIt<SaveCategoryUseCase>(),
            getIt<SaveSubCategoryUseCase>(),
            getIt<SetCategoryActiveUseCase>(),
            getIt<SaveManufacturerUseCase>(),
            getIt<SetManufacturerActiveUseCase>(),
            getIt<AllManufacturersUseCase>(),
            getIt<ListTherapeuticGroupsUseCase>(),
            getIt<SaveTherapeuticGroupUseCase>(),
            getIt<SetTherapeuticGroupActiveUseCase>(),
            getIt<ListUnitsUseCase>(),
            getIt<SaveUnitUseCase>(),
          ));
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