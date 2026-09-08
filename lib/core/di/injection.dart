import 'package:get_it/get_it.dart';

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
import '../../domain/services/financial_posting_service.dart';
import '../../domain/services/permission_service.dart';
import '../../domain/services/purchase_service.dart';
import '../../domain/services/return_service.dart';
import '../../domain/services/sale_service.dart';
import '../../domain/services/stock_service.dart';
import '../../features/accounts/application/accounting_controller.dart';
import '../../features/accounts/application/cashbox_controller.dart';
import '../../features/accounts/data/accounting_dao.dart';
import '../../features/accounts/data/cashbox_repository_impl.dart';
import '../../features/accounts/domain/repositories/cashbox_repository.dart';
import '../../domain/services/accounting_period_service.dart';
import '../../domain/services/customer_payment_service.dart';
import '../../features/auth/application/auth_controller.dart';
import '../../features/sales/data/z_report_dao.dart';
import '../../shared/database/settings_dao.dart';
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
import '../../features/customers/application/customers_controller.dart';
import '../../features/customers/data/repositories/customer_repository_impl.dart';
import '../../features/customers/domain/repositories/customer_repository.dart';
import '../../features/customers/domain/usecases/customers_use_cases.dart';
import '../../features/expenses/application/expense_controller.dart';
import '../../features/expenses/data/expense_repository_impl.dart';
import '../../features/expenses/domain/repositories/expense_repository.dart';
import '../../features/expenses/domain/services/receipt_storage.dart';
import '../../features/expenses/domain/usecases/expenses_use_cases.dart';
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
import '../../features/purchases/application/purchases_controller.dart';
import '../../features/purchases/data/repositories/purchases_repository_impl.dart';
import '../../features/purchases/domain/repositories/purchases_repository.dart';
import '../../features/purchases/domain/usecases/purchases_use_cases.dart';
import '../../features/prescriptions/application/prescriptions_controller.dart';
import '../../features/prescriptions/data/repositories/prescription_repository_impl.dart';
import '../../features/prescriptions/domain/repositories/prescription_repository.dart';
import '../../features/prescriptions/domain/usecases/prescriptions_use_cases.dart';
import '../../features/sales/data/pos_catalog_dao.dart';
import '../../features/sales/data/sales_repository_impl.dart';
import '../../features/sales/domain/repositories/sales_repository.dart';
import '../../features/suppliers/application/suppliers_controller.dart';
import '../../features/suppliers/data/repositories/supplier_repository_impl.dart';
import '../../features/suppliers/domain/repositories/supplier_repository.dart';
import '../../features/suppliers/domain/usecases/suppliers_use_cases.dart';
import '../../features/reports/application/reports_controller.dart';
import '../../features/reports/data/reports_dao.dart';
import '../../features/reports/domain/services/report_export_service.dart';
import '../../features/settings/application/settings_controller.dart';
import '../../features/settings/data/settings_repository_impl.dart';
import '../../features/settings/domain/repositories/settings_repository.dart';
import '../../features/settings/domain/usecases/settings_use_cases.dart';
import '../../features/audit/application/audit_controller.dart';
import '../../features/audit/data/audit_dao.dart';
import '../../features/audit/domain/usecases/audit_use_cases.dart';
import '../../features/auth/application/rbac_controller.dart';
import '../../features/auth/data/daos/rbac_dao.dart';
import '../../features/auth/domain/usecases/rbac_use_cases.dart';
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
  getIt.registerLazySingleton<SupplierDao>(() => SupplierDao(db));
  getIt.registerLazySingleton<PurchaseDao>(() => PurchaseDao(db));
  getIt.registerLazySingleton<CustomerDao>(() => CustomerDao(db));
  getIt.registerLazySingleton<PrescriptionDao>(() => PrescriptionDao(db));

  _registerAuth(db);
  _registerInventory(db);
  _registerPhase4(db);
  _registerPhase5(db);
  _registerPhase7(db);
  _registerPhase8(db);
  _registerPhase9(db);
  _registerPhase10(db);
  _registerPhase11(db);
  _registerPhase12(db);
}

/// Phase 7 — POS workspace data layer over the existing transactional engine.
void _registerPhase7(AppDatabase db) {
  getIt.registerLazySingleton<PosCatalogDao>(() => PosCatalogDao(db));
  getIt.registerLazySingleton<SettingsDao>(() => SettingsDao(db));
  getIt.registerLazySingleton<ZReportDao>(() => ZReportDao(db));
  getIt.registerLazySingleton<SalesRepository>(() => SalesRepositoryImpl(
        db,
        getIt<PosCatalogDao>(),
        getIt<StockService>(),
        getIt<SaleService>(),
        getIt<ReturnService>(),
      ));
}

/// Phase 8 — Cash Box (الصندوق) workflow over the existing financial engine.
void _registerPhase8(AppDatabase db) {
  getIt.registerLazySingleton<CashboxService>(() => const CashboxService());
  getIt.registerLazySingleton<CashboxRepository>(
      () => CashboxRepositoryImpl(db, getIt<CashboxService>()));
  getIt.registerLazySingleton<CashboxController>(
      () => CashboxController(getIt<CashboxRepository>()));
}

/// Phase 9 — Expenses (المصروفات): categorized, receipt-scanned, paginated
/// expense journal with a reverse (cancel) workflow over the financial engine.
void _registerPhase9(AppDatabase db) {
  getIt.registerLazySingleton<FinancialPostingService>(
      () => const FinancialPostingService());
  getIt.registerLazySingleton<ReceiptStorage>(() => LocalReceiptStorage());
  getIt.registerLazySingleton<ExpenseRepository>(
      () => ExpenseRepositoryImpl(
        db,
        getIt<ReceiptStorage>(),
        getIt<FinancialPostingService>(),
      ));
  getIt.registerLazySingleton<ListExpensesUseCase>(
      () => ListExpensesUseCase(getIt<ExpenseRepository>(), getIt<PermissionService>()));
  getIt.registerLazySingleton<ListExpenseCategoriesUseCase>(
      () => ListExpenseCategoriesUseCase(
          getIt<ExpenseRepository>(), getIt<PermissionService>()));
  getIt.registerLazySingleton<CreateExpenseUseCase>(
      () => CreateExpenseUseCase(getIt<ExpenseRepository>(), getIt<PermissionService>()));
  getIt.registerLazySingleton<UpdateExpenseUseCase>(
      () => UpdateExpenseUseCase(getIt<ExpenseRepository>(), getIt<PermissionService>(),
          getIt<AuditService>()));
  getIt.registerLazySingleton<CancelExpenseUseCase>(
      () => CancelExpenseUseCase(getIt<ExpenseRepository>(), getIt<PermissionService>()));
  getIt.registerLazySingleton<AttachReceiptUseCase>(
      () => AttachReceiptUseCase(getIt<ExpenseRepository>(), getIt<PermissionService>(),
          getIt<AuditService>()));
  getIt.registerLazySingleton<RemoveReceiptUseCase>(
      () => RemoveReceiptUseCase(getIt<ExpenseRepository>(), getIt<PermissionService>(),
          getIt<AuditService>()));
  getIt.registerLazySingleton<CreateExpenseCategoryUseCase>(
      () => CreateExpenseCategoryUseCase(getIt<ExpenseRepository>(),
          getIt<PermissionService>(), getIt<AuditService>()));
  getIt.registerLazySingleton<UpdateExpenseCategoryUseCase>(
      () => UpdateExpenseCategoryUseCase(getIt<ExpenseRepository>(),
          getIt<PermissionService>(), getIt<AuditService>()));
  getIt.registerLazySingleton<SetExpenseCategoryActiveUseCase>(
      () => SetExpenseCategoryActiveUseCase(getIt<ExpenseRepository>(),
          getIt<PermissionService>(), getIt<AuditService>()));
  getIt.registerLazySingleton<ExpenseController>(
      () => ExpenseController(
        getIt<ListExpensesUseCase>(),
        getIt<ListExpenseCategoriesUseCase>(),
        getIt<CreateExpenseUseCase>(),
        getIt<UpdateExpenseUseCase>(),
        getIt<CancelExpenseUseCase>(),
        getIt<AttachReceiptUseCase>(),
        getIt<RemoveReceiptUseCase>(),
        getIt<CreateExpenseCategoryUseCase>(),
        getIt<UpdateExpenseCategoryUseCase>(),
        getIt<SetExpenseCategoryActiveUseCase>(),
      ));
}

/// Phase 12 — Audit log & Settings / administration: the read-only audit
/// viewer, Application Settings (Business Name / Tax / Currency) and Role &
/// Permission management. Everything wires over existing §4.25–§4.27 tables.
void _registerPhase12(AppDatabase db) {
  final audit = getIt<AuditService>();
  final perms = getIt<PermissionService>();

  // Application settings (business name / tax / currency) over `app_settings`.
  getIt.registerLazySingleton<SettingsRepository>(
      () => SettingsRepositoryImpl(getIt<SettingsDao>(), db));
  getIt.registerLazySingleton<GetAppSettingsUseCase>(
      () => GetAppSettingsUseCase(getIt<SettingsRepository>(), perms));
  getIt.registerLazySingleton<SaveAppSettingsUseCase>(
      () => SaveAppSettingsUseCase(
        getIt<SettingsRepository>(),
        perms,
        audit,
      ));
  getIt.registerLazySingleton<SettingsController>(
      () => SettingsController(
        getIt<GetAppSettingsUseCase>(),
        getIt<SaveAppSettingsUseCase>(),
        db,
      ));

  // Audit viewer (read-only, paginated, filtered).
  getIt.registerLazySingleton<AuditDao>(() => AuditDao(db));
  getIt.registerLazySingleton<ListAuditLogsUseCase>(
      () => ListAuditLogsUseCase(getIt<AuditDao>(), perms));
  getIt.registerLazySingleton<ListAuditActionsUseCase>(
      () => ListAuditActionsUseCase(getIt<AuditDao>(), perms));
  getIt.registerLazySingleton<ListAuditActorsUseCase>(
      () => ListAuditActorsUseCase(getIt<AuditDao>(), perms));
  getIt.registerLazySingleton<AuditController>(
      () => AuditController(
        getIt<ListAuditLogsUseCase>(),
        getIt<ListAuditActionsUseCase>(),
        getIt<ListAuditActorsUseCase>(),
        db,
      ));

  // Role & permission management over `roles` / `role_permissions` /
  // `permissions`.
  getIt.registerLazySingleton<RbacDao>(() => RbacDao(db));
  getIt.registerLazySingleton<LoadRolesSnapshotUseCase>(
      () => LoadRolesSnapshotUseCase(getIt<RbacDao>(), perms));
  getIt.registerLazySingleton<GetRoleDetailUseCase>(
      () => GetRoleDetailUseCase(getIt<RbacDao>(), perms));
  getIt.registerLazySingleton<CreateRoleUseCase>(
      () => CreateRoleUseCase(getIt<RbacDao>(), perms, audit));
  getIt.registerLazySingleton<UpdateRoleUseCase>(
      () => UpdateRoleUseCase(getIt<RbacDao>(), perms, audit));
  getIt.registerLazySingleton<SetRolePermissionsUseCase>(
      () => SetRolePermissionsUseCase(getIt<RbacDao>(), perms, audit));
  getIt.registerLazySingleton<DeleteRoleUseCase>(
      () => DeleteRoleUseCase(getIt<RbacDao>(), perms, audit));
  getIt.registerLazySingleton<RbacController>(
      () => RbacController(
        getIt<LoadRolesSnapshotUseCase>(),
        getIt<GetRoleDetailUseCase>(),
        getIt<CreateRoleUseCase>(),
        getIt<UpdateRoleUseCase>(),
        getIt<SetRolePermissionsUseCase>(),
        getIt<DeleteRoleUseCase>(),
        db,
      ));
}

/// Phase 11 — Reports hub: read-only reports (trial balance, income
/// statement, balance sheet, sales/purchase/inventory/lost-sales) over the
/// journal and stock ledgers. Nothing here mutates domain data.
void _registerPhase11(AppDatabase db) {
  getIt.registerLazySingleton<ReportsDao>(() => ReportsDao(db));
  getIt.registerLazySingleton<ReportExportService>(
      () => const ReportExportService());
  getIt.registerLazySingleton<TrialBalanceController>(
      () => TrialBalanceController(getIt<ReportsDao>()));
  getIt.registerLazySingleton<IncomeStatementController>(
      () => IncomeStatementController(getIt<ReportsDao>()));
  getIt.registerLazySingleton<BalanceSheetController>(
      () => BalanceSheetController(getIt<ReportsDao>()));
  getIt.registerLazySingleton<SalesReportController>(
      () => SalesReportController(getIt<ReportsDao>()));
  getIt.registerLazySingleton<PurchaseReportController>(
      () => PurchaseReportController(getIt<ReportsDao>()));
  getIt.registerLazySingleton<InventoryReportController>(
      () => InventoryReportController(getIt<ReportsDao>()));
  getIt.registerLazySingleton<LostSalesReportController>(
      () => LostSalesReportController(getIt<ReportsDao>()));
}

/// Phase 10 — Accounting management: chart of accounts, journal viewer,
/// account statement, and period close.
void _registerPhase10(AppDatabase db) {
  getIt.registerLazySingleton<AccountingDao>(() => AccountingDao(db));
  getIt.registerLazySingleton<AccountingPeriodService>(
      () => AccountingPeriodService());
  getIt.registerLazySingleton<CustomerPaymentService>(
      () => CustomerPaymentService());
  getIt.registerLazySingleton<AccountsController>(
      () => AccountsController(getIt<AccountingDao>()));
  getIt.registerLazySingleton<JournalController>(
      () => JournalController(getIt<AccountingDao>()));
  getIt.registerLazySingleton<JournalDetailController>(
      () => JournalDetailController(getIt<AccountingDao>()));
  getIt.registerLazySingleton<AccountStatementController>(
      () => AccountStatementController(getIt<AccountingDao>()));
  getIt.registerLazySingleton<PeriodsController>(
      () => PeriodsController(db, getIt<AccountingPeriodService>()));
}

/// Phase 5 — Customers & Prescriptions graph (customer master, derived
/// customer statements, prescriptions with items and the sale-preparation
/// lookup that Phase 6 POS consumes).
void _registerPhase5(AppDatabase db) {
  final audit = getIt<AuditService>();
  final perms = getIt<PermissionService>();

  getIt.registerLazySingleton<CustomerRepository>(
    () => CustomerRepositoryImpl(db, getIt<CustomerDao>()),
  );
  getIt.registerLazySingleton<PrescriptionRepository>(
    () => PrescriptionRepositoryImpl(db, getIt<PrescriptionDao>()),
  );

  final cusRepo = getIt<CustomerRepository>();
  final rxRepo = getIt<PrescriptionRepository>();

  getIt.registerLazySingleton<ListCustomersUseCase>(
      () => ListCustomersUseCase(cusRepo, perms));
  getIt.registerLazySingleton<AllCustomersUseCase>(
      () => AllCustomersUseCase(cusRepo, perms));
  getIt.registerLazySingleton<CreateCustomerUseCase>(
      () => CreateCustomerUseCase(cusRepo, perms, audit));
  getIt.registerLazySingleton<UpdateCustomerUseCase>(
      () => UpdateCustomerUseCase(cusRepo, perms, audit));
  getIt.registerLazySingleton<SetCustomerActiveUseCase>(
      () => SetCustomerActiveUseCase(cusRepo, perms, audit));
  getIt.registerLazySingleton<SetCustomerAccountUseCase>(
      () => SetCustomerAccountUseCase(cusRepo, perms, audit));
  getIt.registerLazySingleton<CustomerStatementUseCase>(
      () => CustomerStatementUseCase(cusRepo, perms));

  getIt.registerLazySingleton<ListPrescriptionsUseCase>(
      () => ListPrescriptionsUseCase(rxRepo, perms));
  getIt.registerLazySingleton<CreatePrescriptionUseCase>(
      () => CreatePrescriptionUseCase(rxRepo, perms, audit));
  getIt.registerLazySingleton<GetPrescriptionDetailUseCase>(
      () => GetPrescriptionDetailUseCase(rxRepo, perms));
  getIt.registerLazySingleton<CustomerActivePrescriptionsUseCase>(
      () => CustomerActivePrescriptionsUseCase(rxRepo, perms));
  getIt.registerLazySingleton<PreparePrescriptionForSaleUseCase>(
      () => PreparePrescriptionForSaleUseCase(rxRepo, perms));

  getIt.registerLazySingleton<CustomersController>(() => CustomersController(
        getIt<ListCustomersUseCase>(),
        getIt<CreateCustomerUseCase>(),
        getIt<UpdateCustomerUseCase>(),
        getIt<SetCustomerActiveUseCase>(),
        getIt<SetCustomerAccountUseCase>(),
        getIt<CustomerStatementUseCase>(),
      ));

  getIt.registerLazySingleton<PrescriptionsController>(
      () => PrescriptionsController(
            getIt<ListPrescriptionsUseCase>(),
            getIt<CreatePrescriptionUseCase>(),
            getIt<GetPrescriptionDetailUseCase>(),
            getIt<PreparePrescriptionForSaleUseCase>(),
          ));
}

/// Phase 4 — Suppliers & Purchases graph (suppliers master, statements,
/// balances, purchase invoices with bonuses/returns).
void _registerPhase4(AppDatabase db) {
  final audit = getIt<AuditService>();
  final perms = getIt<PermissionService>();

  getIt.registerLazySingleton<SupplierRepository>(
    () => SupplierRepositoryImpl(db, getIt<SupplierDao>()),
  );
  getIt.registerLazySingleton<PurchasesRepository>(
    () => PurchasesRepositoryImpl(
      db,
      getIt<PurchaseDao>(),
      getIt<SupplierDao>(),
      getIt<BonusCalculator>(),
      getIt<StockService>(),
      audit,
    ),
  );

  final supRepo = getIt<SupplierRepository>();
  final purRepo = getIt<PurchasesRepository>();

  getIt.registerLazySingleton<ListSuppliersUseCase>(
      () => ListSuppliersUseCase(supRepo, perms));
  getIt.registerLazySingleton<AllSuppliersUseCase>(
      () => AllSuppliersUseCase(supRepo, perms));
  getIt.registerLazySingleton<CreateSupplierUseCase>(
      () => CreateSupplierUseCase(supRepo, perms, audit));
  getIt.registerLazySingleton<UpdateSupplierUseCase>(
      () => UpdateSupplierUseCase(supRepo, perms, audit));
  getIt.registerLazySingleton<SetSupplierActiveUseCase>(
      () => SetSupplierActiveUseCase(supRepo, perms, audit));
  getIt.registerLazySingleton<SupplierBalancesUseCase>(
      () => SupplierBalancesUseCase(supRepo, perms));
  getIt.registerLazySingleton<SupplierStatementUseCase>(
      () => SupplierStatementUseCase(supRepo, perms));

  getIt.registerLazySingleton<ListPurchasesUseCase>(
      () => ListPurchasesUseCase(purRepo, perms));
  getIt.registerLazySingleton<GetPurchaseDetailUseCase>(
      () => GetPurchaseDetailUseCase(purRepo, perms));
  getIt.registerLazySingleton<CreatePurchaseUseCase>(
      () => CreatePurchaseUseCase(purRepo, perms));
  getIt.registerLazySingleton<UpdatePendingPurchaseUseCase>(
      () => UpdatePendingPurchaseUseCase(purRepo, perms));
  getIt.registerLazySingleton<ReceivePurchaseUseCase>(
      () => ReceivePurchaseUseCase(purRepo, perms));
  getIt.registerLazySingleton<CancelPurchaseUseCase>(
      () => CancelPurchaseUseCase(purRepo, perms));
  getIt.registerLazySingleton<PurchaseReturnUseCase>(
      () => PurchaseReturnUseCase(purRepo, perms));
  getIt.registerLazySingleton<GetAvailableReturnQtyUseCase>(
      () => GetAvailableReturnQtyUseCase(purRepo, perms));

  getIt.registerLazySingleton<SuppliersController>(() => SuppliersController(
        getIt<ListSuppliersUseCase>(),
        getIt<CreateSupplierUseCase>(),
        getIt<UpdateSupplierUseCase>(),
        getIt<SetSupplierActiveUseCase>(),
        getIt<SupplierBalancesUseCase>(),
        getIt<SupplierStatementUseCase>(),
      ));

  getIt.registerLazySingleton<PurchasesController>(() => PurchasesController(
        getIt<ListPurchasesUseCase>(),
        getIt<ReceivePurchaseUseCase>(),
        getIt<CancelPurchaseUseCase>(),
        getIt<CreatePurchaseUseCase>(),
        getIt<UpdatePendingPurchaseUseCase>(),
        getIt<PurchaseReturnUseCase>(),
      ));
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