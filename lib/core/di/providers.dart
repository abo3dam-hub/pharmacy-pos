import 'package:flutter_riverpod/flutter_riverpod.dart';

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
import '../../features/auth/domain/repositories/auth_repository.dart';
import '../../shared/database/app_database.dart';
import 'injection.dart';

/// Riverpod-agnostic providers for [[getIt]]-owned singletons (§35).
final databaseProvider = Provider<AppDatabase>((ref) => getIt<AppDatabase>());

final authControllerProvider =
    StateNotifierProvider<AuthController, AuthState>(
        (ref) => getIt<AuthController>());
final usersViewControllerProvider =
    StateNotifierProvider<UsersViewController, UsersViewState>(
        (ref) => getIt<UsersViewController>());
final authRepositoryProvider =
    Provider<AuthRepository>((ref) => getIt<AuthRepository>());
final userDaoProvider = Provider<UserDao>((ref) => getIt<UserDao>());

final baseUnitConverterProvider = Provider<BaseUnitConverter>(
    (ref) => getIt<BaseUnitConverter>());
final bonusCalculatorProvider =
    Provider<BonusCalculator>((ref) => getIt<BonusCalculator>());
final stockServiceProvider =
    Provider<StockService>((ref) => getIt<StockService>());
final auditServiceProvider =
    Provider<AuditService>((ref) => getIt<AuditService>());
final permissionServiceProvider =
    Provider<PermissionService>((ref) => getIt<PermissionService>());
final saleServiceProvider =
    Provider<SaleService>((ref) => getIt<SaleService>());
final purchaseServiceProvider =
    Provider<PurchaseService>((ref) => getIt<PurchaseService>());
final returnServiceProvider =
    Provider<ReturnService>((ref) => getIt<ReturnService>());

final itemDaoProvider = Provider<ItemDao>((ref) => getIt<ItemDao>());
final unitDaoProvider = Provider<UnitDao>((ref) => getIt<UnitDao>());
final batchDaoProvider = Provider<BatchDao>((ref) => getIt<BatchDao>());
final stockMovementDaoProvider =
    Provider<StockMovementDao>((ref) => getIt<StockMovementDao>());
final categoryDaoProvider =
    Provider<CategoryDao>((ref) => getIt<CategoryDao>());
final manufacturerDaoProvider =
    Provider<ManufacturerDao>((ref) => getIt<ManufacturerDao>());
final therapeuticGroupDaoProvider =
    Provider<TherapeuticGroupDao>((ref) => getIt<TherapeuticGroupDao>());