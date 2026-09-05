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
import '../../shared/database/app_database.dart';

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
}