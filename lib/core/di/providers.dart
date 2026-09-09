import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/daos/batch_dao.dart';
import '../../data/daos/category_dao.dart';
import '../../data/daos/customer_dao.dart';
import '../../data/daos/item_dao.dart';
import '../../data/daos/manufacturer_dao.dart';
import '../../data/daos/prescription_dao.dart';
import '../../data/daos/purchase_dao.dart';
import '../../data/daos/supplier_dao.dart';
import '../../data/daos/stock_movement_dao.dart';
import '../../data/daos/therapeutic_group_dao.dart';
import '../../data/daos/unit_dao.dart';
import '../../domain/services/audit_service.dart';
import '../../domain/services/base_unit_converter.dart';
import '../../domain/services/bonus_calculator.dart';
import '../../domain/services/cashbox_service.dart';
import '../../domain/services/customer_payment_service.dart';
import '../../domain/services/permission_service.dart';
import '../../domain/services/purchase_service.dart';
import '../../domain/services/return_service.dart';
import '../../domain/services/sale_service.dart';
import '../../domain/services/stock_service.dart';
import '../../features/accounts/application/accounting_controller.dart';
import '../../features/accounts/application/cashbox_controller.dart';
import '../../features/accounts/data/accounting_dao.dart';
import '../../features/auth/application/auth_controller.dart';
import '../../features/auth/application/users_controller.dart';
import '../../features/auth/data/daos/user_dao.dart';
import '../../features/auth/domain/repositories/auth_repository.dart';
import '../../features/backup/application/data_management_controller.dart';
import '../../features/customers/application/customers_controller.dart';
import '../../features/customers/domain/usecases/customers_use_cases.dart';
import '../../features/expenses/application/expense_controller.dart';
import '../../features/expenses/domain/repositories/expense_repository.dart';
import '../../features/inventory/application/inventory_controller.dart';
import '../../features/inventory/application/master_data_controller.dart';
import '../../features/inventory/domain/repositories/inventory_repository.dart';
import '../../features/inventory/domain/services/inventory_excel_service.dart';
import '../../features/inventory/domain/services/inventory_view_builder.dart';
import '../../features/purchases/application/purchases_controller.dart';
import '../../features/purchases/domain/usecases/purchases_use_cases.dart';
import '../../features/dashboard/application/dashboard_controller.dart';
import '../../features/prescriptions/application/prescriptions_controller.dart';
import '../../features/sales/data/pos_catalog_dao.dart';
import '../../features/sales/data/z_report_dao.dart';
import '../../features/sales/domain/repositories/sales_repository.dart';
import '../../features/sales/presentation/controllers/pos_workspace_controller.dart';
import '../../features/sales/presentation/controllers/pos_workspace_state.dart';
import '../../features/suppliers/application/suppliers_controller.dart';
import '../../features/suppliers/domain/usecases/suppliers_use_cases.dart';
import '../../features/settings/application/settings_controller.dart';
import '../../features/audit/application/audit_controller.dart';
import '../../features/auth/application/rbac_controller.dart';
import '../../features/accounts/domain/repositories/cashbox_repository.dart';
import '../../features/reports/application/reports_controller.dart';
import '../../features/reports/data/reports_dao.dart';
import '../../features/reports/domain/entities/report_models.dart';
import '../../shared/database/app_database.dart';
import '../../shared/database/settings_dao.dart';
import '../../core/shortcuts/shortcut_bindings_controller.dart';
import '../../core/shortcuts/shortcut_manager.dart';
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
final cashboxServiceProvider =
    Provider<CashboxService>((ref) => getIt<CashboxService>());
final cashboxRepositoryProvider =
    Provider<CashboxRepository>((ref) => getIt<CashboxRepository>());
final cashboxControllerProvider =
    StateNotifierProvider<CashboxController, CashboxViewState>(
        (ref) => getIt<CashboxController>());
final customerPaymentServiceProvider =
    Provider<CustomerPaymentService>((ref) => getIt<CustomerPaymentService>());
// ── Phase 10: Accounting ────────────────────────────────────────────────────
final accountingDaoProvider =
    Provider<AccountingDao>((ref) => getIt<AccountingDao>());
final accountsControllerProvider =
    StateNotifierProvider<AccountsController, AccountsViewState>(
        (ref) => getIt<AccountsController>());
final journalControllerProvider =
    StateNotifierProvider<JournalController, JournalViewState>(
        (ref) => getIt<JournalController>());
final journalDetailControllerProvider =
    StateNotifierProvider<JournalDetailController, JournalDetailViewState>(
        (ref) => getIt<JournalDetailController>());
final accountStatementControllerProvider =
    StateNotifierProvider<AccountStatementController,
            AccountStatementViewState>(
        (ref) => getIt<AccountStatementController>());
final periodsControllerProvider =
    StateNotifierProvider<PeriodsController, PeriodsViewState>(
        (ref) => getIt<PeriodsController>());
final expenseRepositoryProvider =
    Provider<ExpenseRepository>((ref) => getIt<ExpenseRepository>());
final expenseControllerProvider =
    StateNotifierProvider<ExpenseController, ExpenseViewState>(
        (ref) => getIt<ExpenseController>());

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

final inventoryRepositoryProvider =
    Provider<InventoryRepository>((ref) => getIt<InventoryRepository>());
final inventoryViewBuilderProvider =
    Provider<InventoryViewBuilder>((ref) => getIt<InventoryViewBuilder>());
final inventoryExcelServiceProvider =
    Provider<InventoryExcelService>((ref) => getIt<InventoryExcelService>());
final inventoryControllerProvider =
    StateNotifierProvider<InventoryController, InventoryViewState>(
        (ref) => getIt<InventoryController>());
final masterDataControllerProvider =
    StateNotifierProvider<MasterDataController, MasterDataViewState>(
        (ref) => getIt<MasterDataController>());

final supplierDaoProvider = Provider<SupplierDao>((ref) => getIt<SupplierDao>());
final purchaseDaoProvider = Provider<PurchaseDao>((ref) => getIt<PurchaseDao>());
final customerDaoProvider = Provider<CustomerDao>((ref) => getIt<CustomerDao>());
final prescriptionDaoProvider =
    Provider<PrescriptionDao>((ref) => getIt<PrescriptionDao>());
final suppliersControllerProvider =
    StateNotifierProvider<SuppliersController, SuppliersViewState>(
        (ref) => getIt<SuppliersController>());
final purchasesControllerProvider =
    StateNotifierProvider<PurchasesController, PurchasesViewState>(
        (ref) => getIt<PurchasesController>());
final customersControllerProvider =
    StateNotifierProvider<CustomersController, CustomersViewState>(
        (ref) => getIt<CustomersController>());
final prescriptionsControllerProvider =
    StateNotifierProvider<PrescriptionsController, PrescriptionsViewState>(
        (ref) => getIt<PrescriptionsController>());

/// POS (Phase 7) — the data layer plus one independent workspace controller
/// per customer tab (§5 tabs).
final posCatalogDaoProvider = Provider<PosCatalogDao>((ref) => getIt<PosCatalogDao>());
final salesRepositoryProvider =
    Provider<SalesRepository>((ref) => getIt<SalesRepository>());
final settingsDaoProvider = Provider<SettingsDao>((ref) => getIt<SettingsDao>());
final shortcutBindingsProvider = StateNotifierProvider<
    ShortcutBindingsController, Map<PosShortcutKind, String>>(
    (ref) => ShortcutBindingsController(ref.watch(settingsDaoProvider)));
final zReportDaoProvider = Provider<ZReportDao>((ref) => getIt<ZReportDao>());
final posWorkspaceControllerProvider = StateNotifierProvider
    .family<PosWorkspaceController, PosWorkspaceState, int>((
      ref,
      tabIndex,
    ) =>
        PosWorkspaceController(
          tabIndex: tabIndex,
          repository: getIt<SalesRepository>(),
        ));
final allCustomersUseCaseProvider =
    Provider<AllCustomersUseCase>((ref) => getIt<AllCustomersUseCase>());
final allSuppliersUseCaseProvider =
    Provider<AllSuppliersUseCase>((ref) => getIt<AllSuppliersUseCase>());
final createSupplierUseCaseProvider =
    Provider<CreateSupplierUseCase>((ref) => getIt<CreateSupplierUseCase>());
final getPurchaseDetailUseCaseProvider =
    Provider<GetPurchaseDetailUseCase>((ref) => getIt<GetPurchaseDetailUseCase>());
final createPurchaseUseCaseProvider =
    Provider<CreatePurchaseUseCase>((ref) => getIt<CreatePurchaseUseCase>());
final updatePendingPurchaseUseCaseProvider =
    Provider<UpdatePendingPurchaseUseCase>(
        (ref) => getIt<UpdatePendingPurchaseUseCase>());
final getAvailableReturnQtyUseCaseProvider =
    Provider<GetAvailableReturnQtyUseCase>(
        (ref) => getIt<GetAvailableReturnQtyUseCase>());
final purchaseReturnUseCaseProvider =
    Provider<PurchaseReturnUseCase>((ref) => getIt<PurchaseReturnUseCase>());

// Phase 11 — Reports hub controllers (all read-only).
final reportsDaoProvider = Provider<ReportsDao>((ref) => getIt<ReportsDao>());
final trialBalanceControllerProvider =
    StateNotifierProvider<TrialBalanceController,
        ReportViewState<TrialBalanceReport>>((ref) => getIt<TrialBalanceController>());
final incomeStatementControllerProvider =
    StateNotifierProvider<IncomeStatementController,
        ReportViewState<IncomeStatementReport>>((ref) => getIt<IncomeStatementController>());
final balanceSheetControllerProvider =
    StateNotifierProvider<BalanceSheetController,
        ReportViewState<BalanceSheetReport>>((ref) => getIt<BalanceSheetController>());
final salesReportControllerProvider =
    StateNotifierProvider<SalesReportController, ReportViewState<SalesReport>>(
        (ref) => getIt<SalesReportController>());
final purchaseReportControllerProvider =
    StateNotifierProvider<PurchaseReportController, ReportViewState<PurchaseReport>>(
        (ref) => getIt<PurchaseReportController>());
final inventoryReportControllerProvider =
    StateNotifierProvider<InventoryReportController,
        ReportViewState<InventoryReport>>((ref) => getIt<InventoryReportController>());
final lostSalesReportControllerProvider =
    StateNotifierProvider<LostSalesReportController,
        ReportViewState<LostSalesReport>>((ref) => getIt<LostSalesReportController>());

// ── Dashboard (P16) ────────────────────────────────────────────────────────
final dashboardControllerProvider =
    StateNotifierProvider<DashboardController, DashboardViewState>(
        (ref) => getIt<DashboardController>());

// ── Phase 12: Audit log, Settings & RBAC ────────────────────────────────────
final auditControllerProvider =
    StateNotifierProvider<AuditController, AuditViewState>(
        (ref) => getIt<AuditController>());
final settingsControllerProvider =
    StateNotifierProvider<SettingsController, SettingsViewState>(
        (ref) => getIt<SettingsController>());
final rbacControllerProvider =
    StateNotifierProvider<RbacController, RbacViewState>(
        (ref) => getIt<RbacController>());

// ── Phase 13: Backup / Restore / Export ────────────────────────────────────
final dataManagementControllerProvider = StateNotifierProvider
        <DataManagementController, DataManagementState>(
    (ref) => getIt<DataManagementController>());