/// Regression test for Ali's critical inventory-list bug (2026-09-25):
/// opening the inventory list shows a "loading" indicator that never ends
/// while RAM/CPU spike and the device heats up — the app must be force-closed.
///
/// Root cause: `_ItemsTabState._syncPageSize` runs inside a LayoutBuilder on
/// every build and schedules a post-frame `load()` whenever the computed
/// page size differs from `state.request.pageSize`. But `request.pageSize`
/// only updates when a load COMMITS, so any rebuild while a load is in flight
/// schedules ANOTHER load; each new load supersedes the previous one (load
/// generation token), so under contention no load ever commits → the spinner
/// never clears, and unbounded concurrent DB queries pile up (CPU/RAM).
///
/// The test pumps the real [ItemsTab] over a real in-memory database and
/// asserts:
///   1. the loading state resolves within a bounded number of pumps, and
///   2. the list `load()` is issued only a handful of times (no reload loop).
///
/// Second requirement (same page): the adaptive page size must be sane — a
/// normal desktop window must show a proper page (>= 25 rows, the app-wide
/// convention), not a degenerate 4-5.
library;

import 'package:drift/drift.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pharmacy_pos/core/config/app_config.dart';
import 'package:pharmacy_pos/core/data_grid/page_request.dart';
import 'package:pharmacy_pos/core/di/providers.dart';
import 'package:pharmacy_pos/core/theme/app_theme.dart';
import 'package:pharmacy_pos/core/widgets/adaptive_page_size.dart';
import 'package:pharmacy_pos/data/daos/active_ingredient_dao.dart';
import 'package:pharmacy_pos/data/daos/batch_dao.dart';
import 'package:pharmacy_pos/data/daos/category_dao.dart';
import 'package:pharmacy_pos/data/daos/indication_dao.dart';
import 'package:pharmacy_pos/data/daos/item_active_ingredient_dao.dart';
import 'package:pharmacy_pos/data/daos/item_dao.dart';
import 'package:pharmacy_pos/data/daos/item_indication_dao.dart';
import 'package:pharmacy_pos/data/daos/item_supplier_dao.dart';
import 'package:pharmacy_pos/data/daos/manufacturer_dao.dart';
import 'package:pharmacy_pos/data/daos/stock_movement_dao.dart';
import 'package:pharmacy_pos/data/daos/supplier_dao.dart';
import 'package:pharmacy_pos/data/daos/unit_dao.dart';
import 'package:pharmacy_pos/domain/services/audit_service.dart';
import 'package:pharmacy_pos/domain/services/permission_service.dart';
import 'package:pharmacy_pos/domain/services/stock_service.dart';
import 'package:pharmacy_pos/features/auth/application/auth_controller.dart';
import 'package:pharmacy_pos/features/auth/data/daos/user_dao.dart';
import 'package:pharmacy_pos/features/auth/data/repositories/auth_repository_impl.dart';
import 'package:pharmacy_pos/features/auth/domain/services/password_service.dart';
import 'package:pharmacy_pos/features/auth/domain/usecases/get_current_user.dart';
import 'package:pharmacy_pos/features/auth/domain/usecases/check_permission.dart';
import 'package:pharmacy_pos/features/auth/domain/usecases/login.dart';
import 'package:pharmacy_pos/features/auth/domain/usecases/logout.dart';
import 'package:pharmacy_pos/features/inventory/application/inventory_controller.dart';
import 'package:pharmacy_pos/features/inventory/application/master_data_controller.dart';
import 'package:pharmacy_pos/features/inventory/data/repositories/inventory_repository_impl.dart';
import 'package:pharmacy_pos/features/inventory/domain/entities/inventory_item.dart';
import 'package:pharmacy_pos/features/inventory/domain/services/inventory_excel_service.dart';
import 'package:pharmacy_pos/features/inventory/domain/services/inventory_view_builder.dart';
import 'package:pharmacy_pos/features/inventory/domain/usecases/active_ingredients_use_cases.dart';
import 'package:pharmacy_pos/features/inventory/domain/usecases/batches_use_cases.dart';
import 'package:pharmacy_pos/features/inventory/domain/usecases/bulk_use_cases.dart';
import 'package:pharmacy_pos/features/inventory/domain/usecases/categories_use_cases.dart';
import 'package:pharmacy_pos/features/inventory/domain/usecases/create_item.dart';
import 'package:pharmacy_pos/features/inventory/domain/usecases/delete_item.dart';
import 'package:pharmacy_pos/features/inventory/domain/usecases/delete_master_data.dart';
import 'package:pharmacy_pos/features/inventory/domain/usecases/excel_use_cases.dart';
import 'package:pharmacy_pos/features/inventory/domain/usecases/indications_use_cases.dart';
import 'package:pharmacy_pos/features/inventory/domain/usecases/list_items.dart';
import 'package:pharmacy_pos/features/inventory/domain/usecases/manufacturers_use_cases.dart';
import 'package:pharmacy_pos/features/inventory/domain/usecases/set_item_active.dart';
import 'package:pharmacy_pos/features/inventory/domain/usecases/stock_use_cases.dart';
import 'package:pharmacy_pos/features/inventory/domain/usecases/units_use_cases.dart';
import 'package:pharmacy_pos/features/inventory/domain/usecases/update_item.dart';
import 'package:pharmacy_pos/features/inventory/presentation/widgets/items_tab.dart';
import 'package:pharmacy_pos/features/settings/application/ui_preferences_service.dart';
import 'package:pharmacy_pos/features/suppliers/data/repositories/supplier_repository_impl.dart';
import 'package:pharmacy_pos/features/suppliers/domain/usecases/suppliers_use_cases.dart';
import 'package:pharmacy_pos/l10n/app_localizations.dart';
import 'package:pharmacy_pos/shared/database/app_database.dart';
import 'package:pharmacy_pos/shared/database/settings_dao.dart';

import 'helpers.dart';

const _perms = PermissionService();
const _audit = AuditService();

InventoryRepositoryImpl _repo(AppDatabase db) => InventoryRepositoryImpl(
      db,
      ItemDao(db),
      CategoryDao(db),
      ManufacturerDao(db),
      UnitDao(db),
      BatchDao(db),
      StockMovementDao(db),
      ItemSupplierDao(db),
      StockService(),
      ActiveIngredientDao(db),
      IndicationDao(db),
      ItemActiveIngredientDao(db),
      ItemIndicationDao(db),
    );

InventoryController _inventoryController(AppDatabase db,
    {ListItemsUseCase Function(InventoryRepositoryImpl, InventoryViewBuilder)?
        listItemsFactory}) {
  final repo = _repo(db);
  final viewBuilder = InventoryViewBuilder(repo);
  return InventoryController(
    listItemsFactory?.call(repo, viewBuilder) ??
        ListItemsUseCase(repo, _perms, viewBuilder: viewBuilder),
    CreateItemUseCase(repo, _perms, _audit),
    UpdateItemUseCase(repo, _perms, _audit),
    SetItemActiveUseCase(repo, _perms, _audit),
    DeleteItemUseCase(repo, _perms, _audit),
    AddBatchUseCase(repo, _perms, _audit),
    VoidBatchUseCase(repo, _perms, _audit),
    ListBatchesUseCase(repo, _perms),
    AdjustStockUseCase(repo, _perms, _audit),
    BulkUpdateItemsUseCase(repo, _perms, _audit),
    ExportItemsUseCase(repo, _perms, InventoryExcelService(repo),
        viewBuilder: viewBuilder),
    ImportItemsUseCase(repo, _perms, _audit),
  );
}

MasterDataController _masterDataController(AppDatabase db) {
  final repo = _repo(db);
  return MasterDataController(
    ListCategoriesUseCase(repo, _perms),
    SaveCategoryUseCase(repo, _perms, _audit),
    SetCategoryActiveUseCase(repo, _perms, _audit),
    DeleteCategoryUseCase(repo, _perms, _audit),
    SaveManufacturerUseCase(repo, _perms, _audit),
    SetManufacturerActiveUseCase(repo, _perms, _audit),
    DeleteManufacturerUseCase(repo, _perms, _audit),
    AllManufacturersUseCase(repo, _perms),
    ListUnitsUseCase(repo, _perms),
    SaveUnitUseCase(repo, _perms, _audit),
    DeleteUnitUseCase(repo, _perms, _audit),
    ListActiveIngredientsUseCase(repo, _perms),
    SaveActiveIngredientUseCase(repo, _perms, _audit),
    SetActiveIngredientActiveUseCase(repo, _perms, _audit),
    DeleteActiveIngredientUseCase(repo, _perms, _audit),
    ListIndicationsUseCase(repo, _perms),
    SaveIndicationUseCase(repo, _perms, _audit),
    SetIndicationActiveUseCase(repo, _perms, _audit),
    DeleteIndicationUseCase(repo, _perms, _audit),
  );
}

ProviderContainer _container(AppDatabase db,
    {ListItemsUseCase Function(InventoryRepositoryImpl, InventoryViewBuilder)?
        listItemsFactory}) {
  final passwords = const PasswordService();
  final authRepo = AuthRepositoryImpl(UserDao(db));
  final authController = AuthController(
    LoginUseCase(authRepo, passwords),
    const LogoutUseCase(),
    GetCurrentUserUseCase(authRepo),
    ListUserPermissionsUseCase(authRepo),
  );
  authController.audit =
      ({required user, required success, note = ''}) async {};

  return ProviderContainer(
    overrides: [
      databaseProvider.overrideWithValue(db),
      authRepositoryProvider.overrideWithValue(authRepo),
      authControllerProvider.overrideWith((ref) => authController),
      inventoryControllerProvider.overrideWith(
          (ref) => _inventoryController(db, listItemsFactory: listItemsFactory)),
      masterDataControllerProvider
          .overrideWith((ref) => _masterDataController(db)),
      allSuppliersUseCaseProvider.overrideWithValue(
        AllSuppliersUseCase(
            SupplierRepositoryImpl(db, SupplierDao(db)), _perms),
      ),
      uiPreferencesServiceProvider.overrideWithValue(
        UiPreferencesService(SettingsDao(db)),
      ),
    ],
  );
}

Future<void> _seedStockedItems(AppDatabase db, int count) async {
  for (var i = 0; i < count; i++) {
    final id = await insertItem(
      db,
      barcode: '6291041500${100 + i}',
      id: 'item_loop_$i',
    );
    // Give every item real stock so the default in-stock-only tab lists them.
    await insertBatch(db, id, quantityBase: 10 + i);
  }
  // Distinct names so rows are individually findable.
  for (var i = 0; i < count; i++) {
    await (db.update(db.items)..where((t) => t.id.equals('item_loop_$i')))
        .write(ItemsCompanion(tradeName: Value('دواء الاختبار $i')));
  }
}

Future<ProviderContainer> _pumpInventoryTab(
  WidgetTester tester,
  AppDatabase db, {
  Size viewport = const Size(1280, 900),
  ListItemsUseCase Function(InventoryRepositoryImpl, InventoryViewBuilder)?
      listItemsFactory,
}) async {
  final container = _container(db, listItemsFactory: listItemsFactory);
  addTearDown(container.dispose);
  await container.read(authControllerProvider.notifier).login('admin', 'Admin@123');

  tester.view.physicalSize = viewport;
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);

  await tester.pumpWidget(
    UncontrolledProviderScope(
      container: container,
      child: MaterialApp(
        theme: AppTheme.light(),
        locale: const Locale(AppConfig.defaultLocale),
        supportedLocales: AppLocalizations.supportedLocales,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        home: const Scaffold(body: ItemsTab()),
      ),
    ),
  );
  return container;
}

/// Simulates Ali's slow device: every list query takes 300ms — longer than
/// a frame — the way a 22k-item database behaves on his hardware.
class _SlowListItems extends ListItemsUseCase {
  _SlowListItems(
    super.repo,
    super.permissions, {
    required super.viewBuilder,
    required this.onQuery,
  });

  final void Function() onQuery;

  @override
  Future<({List<InventoryItemView> items, int total, PageRequest request})>
      call(
    PageRequest page, {
    String? categoryId,
    String? manufacturerId,
    bool? onlyActive,
    bool? inStockOnly,
    String? actingRoleId,
  }) async {
    onQuery();
    await Future.delayed(const Duration(milliseconds: 300));
    return super.call(
      page,
      categoryId: categoryId,
      manufacturerId: manufacturerId,
      onlyActive: onlyActive,
      inStockOnly: inStockOnly,
      actingRoleId: actingRoleId,
    );
  }
}

void main() {
  setUpAll(ensureSqlite);

  testWidgets(
    'inventory list resolves loading with a bounded number of list loads '
    '(no reload loop)',
    (tester) async {
      final db = newDatabase();
      addTearDown(db.close);
      await _seedStockedItems(db, 30);

      final container = await _pumpInventoryTab(tester, db);

      var loadingEntries = 0;
      container.listen<InventoryViewState>(
        inventoryControllerProvider,
        (prev, next) {
          if (next.status == InventoryStatus.loading &&
              prev?.status != InventoryStatus.loading) {
            loadingEntries++;
          }
        },
      );

      // Bounded pumps: a reload loop would keep entering `loading` forever.
      for (var i = 0; i < 80; i++) {
        await tester.pump(const Duration(milliseconds: 100));
      }

      final state = container.read(inventoryControllerProvider);
      expect(
        state.status,
        InventoryStatus.ready,
        reason: 'loading must resolve; got $state.status '
            'after 80 pumps ($loadingEntries loading entries)',
      );
      expect(
        loadingEntries,
        lessThanOrEqualTo(3),
        reason: 'expected at most initial + one page-size sync load, '
            'got $loadingEntries list loads (reload loop)',
      );
      expect(state.items, isNotEmpty);
      expect(find.textContaining('دواء الاختبار 0'), findsWidgets);
    },
    timeout: const Timeout(Duration(seconds: 120)),
  );

  testWidgets(
    'slow device: page-size sync issues exactly one corrective load '
    '(no reload loop)',
    (tester) async {
      // Deterministic reproduction of Ali's wedged inventory list: with a
      // 300ms query (his 22k-item database) the old code scheduled a new
      // load on every frame — each superseding the last — so no load ever
      // committed, the spinner never cleared, and abandoned queries piled
      // up (CPU/RAM). The fix publishes the in-flight page size
      // synchronously, so the sync sees it and stops after one correction.
      final db = newDatabase();
      addTearDown(db.close);
      await _seedStockedItems(db, 30);

      var queries = 0;
      final container = await _pumpInventoryTab(
        tester,
        db,
        listItemsFactory: (repo, viewBuilder) => _SlowListItems(
          repo,
          _perms,
          viewBuilder: viewBuilder,
          onQuery: () => queries++,
        ),
      );

      // 40 pumps x 100ms = 4s of virtual time; each query takes 300ms.
      for (var i = 0; i < 40; i++) {
        await tester.pump(const Duration(milliseconds: 100));
      }

      final state = container.read(inventoryControllerProvider);
      expect(
        state.status,
        InventoryStatus.ready,
        reason: 'loading must resolve on a slow device; still '
            '${state.status} after $queries queries',
      );
      expect(
        queries,
        lessThanOrEqualTo(3),
        reason: 'expected initial + one page-size correction load, '
            'got $queries queries (reload loop)',
      );
      expect(state.request.pageSize, 25);
      expect(find.textContaining('دواء الاختبار 0'), findsWidgets);
    },
    timeout: const Timeout(Duration(seconds: 120)),
  );

  testWidgets(
    'adaptive page size is sane on a desktop viewport (>= 25 rows)',
    (tester) async {
      final db = newDatabase();
      addTearDown(db.close);
      await _seedStockedItems(db, 40);

      final container = await _pumpInventoryTab(tester, db);
      for (var i = 0; i < 80; i++) {
        await tester.pump(const Duration(milliseconds: 100));
      }

      final state = container.read(inventoryControllerProvider);
      expect(state.status, InventoryStatus.ready);
      expect(
        state.request.pageSize,
        greaterThanOrEqualTo(25),
        reason: 'desktop page must hold >= 25 rows (app convention), '
            'got ${state.request.pageSize}',
      );
      // And the rows actually render.
      expect(find.textContaining('دواء الاختبار 0'), findsWidgets);
    },
    timeout: const Timeout(Duration(seconds: 120)),
  );

  test(
    'rowsThatFit floors at the conventional page size (25), never 4-5',
    () {
      // Even when the viewport fits fewer rows, the page size must not
      // collapse to a degenerate handful: (900 - 40) / 44 = 19.5 -> 19
      // rows fit, but the policy floor is the conventional 25.
      final n = rowsThatFit(
        availableHeight: 900,
        rowHeight: 44,
        headerHeight: 40,
      );
      expect(n, 25, reason: 'got $n');
    },
  );
}
