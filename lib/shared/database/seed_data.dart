import 'package:bcrypt/bcrypt.dart';
import 'package:drift/drift.dart';

import '../../core/constants/account_codes.dart';
import '../../core/constants/permission_codes.dart';
import '../models/enums.dart';
import 'app_database.dart';

const _defaultAdminPassword = 'Admin@123';

/// Permission codes granted to the read-only `viewer` role (§16 roles). Shared
/// by the fresh-install seed and the idempotent legacy seed below so both stay
/// in lock-step.
const kViewerPermissionCodes = {
  Perm.search,
  Perm.viewInventory,
  Perm.viewAlternatives,
  Perm.inventoryView,
  Perm.stockView,
  Perm.salesView,
  Perm.purchasesView,
  Perm.suppliersView,
  Perm.customersView,
  Perm.reportsViewSales,
  Perm.reportsViewPurchases,
  Perm.reportsViewInventory,
  Perm.reportsViewProfit,
  Perm.cashboxView,
  Perm.expensesView,
  Perm.expenseCategoriesView,
};

/// Seeds the default data that must exist on first run.
///
/// This is kept in its own library (separate from `app_database.dart`) so the
/// drift annotation stays free of references to generated symbols, which are
/// only available after code generation has run.
Future<void> seedDefaults(AppDatabase db) async {
  final now = DateTime.now().millisecondsSinceEpoch;

  // Default units (name = unique Arabic name, plan `name_ar`; nameEn = English).
  await db.batch((batch) {
    batch.insertAll(db.units, [
      UnitsCompanion.insert(
        id: 'unit_strip',
        name: 'شريط',
        nameEn: const Value('Strip'),
        createdAt: now,
        updatedAt: now,
      ),
      UnitsCompanion.insert(
        id: 'unit_box',
        name: 'علبة',
        nameEn: const Value('Box'),
        createdAt: now,
        updatedAt: now,
      ),
      UnitsCompanion.insert(
        id: 'unit_tablet',
        name: 'قرص',
        nameEn: const Value('Tablet'),
        createdAt: now,
        updatedAt: now,
      ),
    ]);
  });

  // Default main category so master-data inserts always have a valid
  // `items.categoryId` (NN per §4.7).
  await db.into(db.categories).insert(
        CategoriesCompanion.insert(
          id: 'cat_default',
          name: 'أدوية',
          nameEn: const Value('Medicines'),
          createdAt: now,
          updatedAt: now,
        ),
      );

  // Default roles — `name` is the canonical stable code, `nameAr` the Arabic
  // display name (§4.26).
  await db.batch((batch) {
    batch.insertAll(db.roles, [
      RoleRow(
        id: 'role_admin',
        name: 'admin',
        nameAr: 'مدير النظام',
        isSystem: true,
        isActive: true,
        createdAt: now,
        updatedAt: now,
      ),
      RoleRow(
        id: 'role_pharmacist',
        name: 'pharmacist',
        nameAr: 'صيدلي',
        isSystem: true,
        isActive: true,
        createdAt: now,
        updatedAt: now,
      ),
      RoleRow(
        id: 'role_cashier',
        name: 'cashier',
        nameAr: 'كاشير',
        isSystem: true,
        isActive: true,
        createdAt: now,
        updatedAt: now,
      ),
      RoleRow(
        id: 'role_viewer',
        name: 'viewer',
        nameAr: 'مشاهد',
        isSystem: true,
        isActive: true,
        createdAt: now,
        updatedAt: now,
      ),
    ]);
  });

  // All permissions — `name` stores the canonical code, `nameAr` the Arabic
  // label (§4.26).
  final permRows = <PermissionsCompanion>[];
  for (final p in kSeedPermissions) {
    permRows.add(PermissionsCompanion.insert(
      id: 'perm_${p.code.replaceAll('.', '_')}',
      code: p.code,
      name: p.code,
      nameAr: p.name,
      createdAt: now,
    ));
  }
  await db.batch((batch) {
    batch.insertAll(db.permissions, permRows);
  });

  // Admin role → all permissions.
  await db.batch((batch) {
    batch.insertAll(
      db.rolePermissions,
      [
        for (var i = 0; i < permRows.length; i++)
          RolePermissionsCompanion.insert(
            id: 'rp_admin_$i',
            roleId: 'role_admin',
            permissionId: permRows[i].id.value,
            granted: const Value(true),
            createdAt: now,
          ),
      ],
    );
  });

  // Pharmacist role → inventory, stock, purchases, sales, customers,
  // prescriptions, lost sales, reports and cashbox operating permissions.
  final pharmacistCodes = {
    Perm.sell,
    Perm.returnProducts,
    Perm.search,
    Perm.viewInventory,
    Perm.viewAlternatives,
    Perm.changePrices,
    Perm.inventoryView,
    Perm.inventoryCreate,
    Perm.inventoryEdit,
    Perm.pricingEdit,
    Perm.stockView,
    Perm.stockAdjust,
    Perm.stockTransfer,
    Perm.purchasesView,
    Perm.purchasesCreate,
    Perm.purchasesEdit,
    Perm.suppliersView,
    Perm.suppliersCreate,
    Perm.suppliersEdit,
    Perm.salesView,
    Perm.salesCreate,
    Perm.salesReturnCreate,
    Perm.customersView,
    Perm.customersCreate,
    Perm.customersEdit,
    Perm.prescriptionsView,
    Perm.prescriptionsCreate,
    Perm.lostSalesView,
    Perm.lostSalesCreate,
    Perm.lostSalesClose,
    Perm.reportsViewSales,
    Perm.reportsViewPurchases,
    Perm.reportsViewInventory,
    Perm.reportsViewProfit,
    Perm.cashboxView,
    Perm.cashboxOperate,
    Perm.expensesView,
    Perm.expensesCreate,
    Perm.expensesEdit,
    Perm.expensesVoid,
    Perm.expenseCategoriesView,
    Perm.expenseCategoriesManage,
  };
  await db.batch((batch) {
    batch.insertAll(
      db.rolePermissions,
      [
        for (final p in permRows)
          if (pharmacistCodes.contains(p.code.value))
            RolePermissionsCompanion.insert(
              id: 'rp_pharmacist_${p.id.value}',
              roleId: 'role_pharmacist',
              permissionId: p.id.value,
              granted: const Value(true),
              createdAt: now,
            ),
      ],
    );
  });

  // Cashier role → sales + customers + prescriptions + lost sales + cashbox.
  final cashierCodes = {
    Perm.sell,
    Perm.returnProducts,
    Perm.search,
    Perm.salesView,
    Perm.salesCreate,
    Perm.customersView,
    Perm.customersCreate,
    Perm.prescriptionsView,
    Perm.lostSalesCreate,
    Perm.cashboxView,
  };
  await db.batch((batch) {
    batch.insertAll(
      db.rolePermissions,
      [
        for (final p in permRows)
          if (cashierCodes.contains(p.code.value))
            RolePermissionsCompanion.insert(
              id: 'rp_cashier_${p.id.value}',
              roleId: 'role_cashier',
              permissionId: p.id.value,
              granted: const Value(true),
              createdAt: now,
            ),
      ],
    );
  });

  // Viewer role → read-only: search, inventory views, stock views, sales /
  // purchases / customers reports. Never mutating rights (§16 roles).
  final viewerCodes = kViewerPermissionCodes;
  await db.batch((batch) {
    batch.insertAll(
      db.rolePermissions,
      [
        for (final p in permRows)
          if (viewerCodes.contains(p.code.value))
            RolePermissionsCompanion.insert(
              id: 'rp_viewer_${p.id.value}',
              roleId: 'role_viewer',
              permissionId: p.id.value,
              granted: const Value(true),
              createdAt: now,
            ),
      ],
    );
  });

  // Admin user (bcrypt hash generated at runtime).
  final adminHash = BCrypt.hashpw(_defaultAdminPassword, BCrypt.gensalt());
  await db.into(db.users).insert(UsersCompanion.insert(
        id: 'user_admin',
        username: 'admin',
        passwordHash: adminHash,
        fullName: 'مدير النظام',
        roleId: 'role_admin',
        createdAt: now,
        updatedAt: now,
      ));

  // Default partial-sale markup (10% = 1000 bp) — Phase 6 Design Lock §7.3.
  await db.into(db.appSettings).insert(
        AppSettingsCompanion.insert(
          key: 'partial_sale_markup_basis_points',
          value: '1000',
          updatedAt: now,
        ),
      );

  // Default chart of accounts (sample).
  final defaultAccounts = <AccountsCompanion>[
    AccountsCompanion.insert(
      id: 'acc_1000',
      code: '1000',
      name: 'الصندوق',
      accountType: AccountType.asset,
      isSystem: const Value(true),
      createdAt: now,
      updatedAt: now,
    ),
    AccountsCompanion.insert(
      id: 'acc_1001',
      code: '1001',
      name: 'البنك',
      accountType: AccountType.asset,
      isSystem: const Value(true),
      createdAt: now,
      updatedAt: now,
    ),
    AccountsCompanion.insert(
      id: 'acc_1100',
      code: '1100',
      name: 'حسابات القبض',
      accountType: AccountType.asset,
      isSystem: const Value(true),
      createdAt: now,
      updatedAt: now,
    ),
    AccountsCompanion.insert(
      id: 'acc_1200',
      code: '1200',
      name: 'مخزون البضاعة',
      accountType: AccountType.asset,
      isSystem: const Value(true),
      createdAt: now,
      updatedAt: now,
    ),
    AccountsCompanion.insert(
      id: 'acc_2000',
      code: '2000',
      name: 'حسابات الدفع',
      accountType: AccountType.liability,
      isSystem: const Value(true),
      createdAt: now,
      updatedAt: now,
    ),
    AccountsCompanion.insert(
      id: 'acc_3000',
      code: '3000',
      name: 'رأس المال',
      accountType: AccountType.equity,
      isSystem: const Value(true),
      createdAt: now,
      updatedAt: now,
    ),
    AccountsCompanion.insert(
      id: 'acc_4000',
      code: '4000',
      name: 'المبيعات',
      accountType: AccountType.revenue,
      isSystem: const Value(true),
      createdAt: now,
      updatedAt: now,
    ),
    AccountsCompanion.insert(
      id: 'acc_4001',
      code: '4001',
      name: 'مرتجعات المبيعات',
      accountType: AccountType.revenue,
      isSystem: const Value(true),
      createdAt: now,
      updatedAt: now,
    ),
    AccountsCompanion.insert(
      id: 'acc_5000',
      code: '5000',
      name: 'تكلفة المبيعات',
      accountType: AccountType.expense,
      isSystem: const Value(true),
      createdAt: now,
      updatedAt: now,
    ),
    AccountsCompanion.insert(
      id: 'acc_5100',
      code: '5100',
      name: 'مصروفات تشغيلية',
      accountType: AccountType.expense,
      isSystem: const Value(true),
      createdAt: now,
      updatedAt: now,
    ),
    AccountsCompanion.insert(
      id: 'acc_5101',
      code: '5101',
      name: 'إيجار',
      accountType: AccountType.expense,
      isSystem: const Value(true),
      createdAt: now,
      updatedAt: now,
    ),
    AccountsCompanion.insert(
      id: 'acc_5102',
      code: '5102',
      name: 'رواتب',
      accountType: AccountType.expense,
      isSystem: const Value(true),
      createdAt: now,
      updatedAt: now,
    ),
  ];
  await db.batch((batch) {
    batch.insertAll(db.accounts, defaultAccounts);
  });

  // Phase 9 expense categories master (idempotent; the engine resolves the GL
  // account for each expense against this table).
  await seedExpenseCategories(db);

  // Phase 10 chart of accounts additions: cash over/short + purchase returns.
  await db.batch((batch) {
    batch.insertAll(db.accounts, [
      AccountsCompanion.insert(
        id: 'acc_1099',
        code: '1099',
        name: 'فرق الصندوق',
        nameEn: const Value('Cash Over/Short'),
        accountType: AccountType.expense,
        isSystem: const Value(true),
        createdAt: now,
        updatedAt: now,
      ),
      AccountsCompanion.insert(
        id: 'acc_4002',
        code: '4002',
        name: 'مرتجعات المشتريات',
        nameEn: const Value('Purchase Returns'),
        accountType: AccountType.liability,
        isSystem: const Value(true),
        createdAt: now,
        updatedAt: now,
      ),
    ], mode: InsertMode.insertOrIgnore);
  });

  // Phase 10 accounting permissions are part of kSeedPermissions (loop above)
  // for fresh installs; this ensures idempotent addition for any partial state.
  await ensureAccountingPermissions(db);
}

/// Phase 10 accounting RBAC — idempotently ensures the accounting permission
/// seeds exist and grants them to admin (all), pharmacist (view) and viewer
/// (view). Fresh installs already cover these via kSeedPermissions.
Future<void> ensureAccountingPermissions(AppDatabase db) async {
  final now = DateTime.now().millisecondsSinceEpoch;
  const newCodes = <String, String>{
    Perm.accountingView: 'عرض القيود المحاسبية',
    Perm.accountingPost: 'ترحيل قيود محاسبية',
  };
  await db.batch((batch) {
    for (final e in newCodes.entries) {
      batch.insert(
        db.permissions,
        PermissionsCompanion.insert(
          id: 'perm_${e.key.replaceAll('.', '_')}',
          code: e.key,
          name: e.key,
          nameAr: e.value,
          createdAt: now,
        ),
        mode: InsertMode.insertOrIgnore,
      );
    }
    // Admin → both.
    for (final e in newCodes.entries) {
      batch.insert(
        db.rolePermissions,
        RolePermissionsCompanion.insert(
          id: 'rp_admin_${e.key.replaceAll('.', '_')}',
          roleId: 'role_admin',
          permissionId: 'perm_${e.key.replaceAll('.', '_')}',
          granted: const Value(true),
          createdAt: now,
        ),
        mode: InsertMode.insertOrIgnore,
      );
    }
    // Pharmacist → view.
    batch.insert(
      db.rolePermissions,
      RolePermissionsCompanion.insert(
        id: 'rp_pharmacist_accounting_view',
        roleId: 'role_pharmacist',
        permissionId: 'perm_accounting_view',
        granted: const Value(true),
        createdAt: now,
      ),
      mode: InsertMode.insertOrIgnore,
    );
    // Viewer → view.
    batch.insert(
      db.rolePermissions,
      RolePermissionsCompanion.insert(
        id: 'rp_viewer_accounting_view',
        roleId: 'role_viewer',
        permissionId: 'perm_accounting_view',
        granted: const Value(true),
        createdAt: now,
      ),
      mode: InsertMode.insertOrIgnore,
    );
  });
}

/// Phase 9 expense categories master (idempotent — `insertOrIgnore`). Codes
/// match the legacy `ExpenseCategory` enum names so `expenses.category` keeps
/// its meaning after the v7 upgrade; GL mapping follows §19 (`rent`→5101,
/// `salaries`→5102, everything else→5100 operating expenses).
Future<void> seedExpenseCategories(AppDatabase db) async {
  final now = DateTime.now().millisecondsSinceEpoch;
  await db.batch((batch) {
    batch.insertAll(db.expenseCategories, [
      ExpenseCategoriesCompanion.insert(
        id: 'expcat_rent',
        code: 'rent',
        name: 'إيجار',
        nameEn: const Value('Rent'),
        accountCode: SystemAccountCode.rent,
        isActive: const Value(true),
        isSystem: const Value(true),
        createdAt: now,
        updatedAt: now,
      ),
      ExpenseCategoriesCompanion.insert(
        id: 'expcat_utilities',
        code: 'utilities',
        name: 'مرافق',
        nameEn: const Value('Utilities'),
        accountCode: SystemAccountCode.operatingExpenses,
        isActive: const Value(true),
        isSystem: const Value(true),
        createdAt: now,
        updatedAt: now,
      ),
      ExpenseCategoriesCompanion.insert(
        id: 'expcat_salaries',
        code: 'salaries',
        name: 'رواتب',
        nameEn: const Value('Salaries'),
        accountCode: SystemAccountCode.salaries,
        isActive: const Value(true),
        isSystem: const Value(true),
        createdAt: now,
        updatedAt: now,
      ),
      ExpenseCategoriesCompanion.insert(
        id: 'expcat_maintenance',
        code: 'maintenance',
        name: 'صيانة',
        nameEn: const Value('Maintenance'),
        accountCode: SystemAccountCode.operatingExpenses,
        isActive: const Value(true),
        isSystem: const Value(true),
        createdAt: now,
        updatedAt: now,
      ),
      ExpenseCategoriesCompanion.insert(
        id: 'expcat_transportation',
        code: 'transportation',
        name: 'نقل',
        nameEn: const Value('Transportation'),
        accountCode: SystemAccountCode.operatingExpenses,
        isActive: const Value(true),
        isSystem: const Value(true),
        createdAt: now,
        updatedAt: now,
      ),
      ExpenseCategoriesCompanion.insert(
        id: 'expcat_taxes',
        code: 'taxes',
        name: 'ضرائب',
        nameEn: const Value('Taxes'),
        accountCode: SystemAccountCode.operatingExpenses,
        isActive: const Value(true),
        isSystem: const Value(true),
        createdAt: now,
        updatedAt: now,
      ),
      ExpenseCategoriesCompanion.insert(
        id: 'expcat_marketing',
        code: 'marketing',
        name: 'تسويق',
        nameEn: const Value('Marketing'),
        accountCode: SystemAccountCode.operatingExpenses,
        isActive: const Value(true),
        isSystem: const Value(true),
        createdAt: now,
        updatedAt: now,
      ),
      ExpenseCategoriesCompanion.insert(
        id: 'expcat_other',
        code: 'other',
        name: 'أخرى',
        nameEn: const Value('Other'),
        accountCode: SystemAccountCode.operatingExpenses,
        isActive: const Value(true),
        isSystem: const Value(true),
        createdAt: now,
        updatedAt: now,
      ),
    ], mode: InsertMode.insertOrIgnore);
  });
}

/// Phase 9 expense RBAC — idempotently creates the `expenses.edit`,
/// `expenses.void`, `expenses.categories.view` and
/// `expenses.categories.manage` permissions and grants them to admin
/// (all), pharmacist (edit/void/categories) and viewer (categories view).
/// Used by the v6→v7 upgrade so already-installed stores get the new rights;
/// fresh databases cover these through the kSeedPermissions loop above.
Future<void> ensureExpensePermissions(AppDatabase db) async {
  final now = DateTime.now().millisecondsSinceEpoch;
  final newCodes = <String, String>{
    Perm.expensesEdit: 'تعديل مصروف',
    Perm.expensesVoid: 'إلغاء مصروف',
    Perm.expenseCategoriesView: 'عرض فئات المصروفات',
    Perm.expenseCategoriesManage: 'إدارة فئات المصروفات',
  };
  await db.batch((batch) {
    for (final e in newCodes.entries) {
      batch.insert(db.permissions, PermissionsCompanion.insert(
            id: 'perm_${e.key.replaceAll('.', '_')}',
            code: e.key,
            name: e.key,
            nameAr: e.value,
            createdAt: now,
          ),
          mode: InsertMode.insertOrIgnore);
    }
    // Admin → all four.
    for (final e in newCodes.entries) {
      batch.insert(
        db.rolePermissions,
        RolePermissionsCompanion.insert(
          id: 'rp_admin_${e.key.replaceAll('.', '_')}',
          roleId: 'role_admin',
          permissionId: 'perm_${e.key.replaceAll('.', '_')}',
          granted: const Value(true),
          createdAt: now,
        ),
        mode: InsertMode.insertOrIgnore,
      );
    }
    // Pharmacist → edit/void + category view/manage.
    for (final e in {
      Perm.expensesEdit,
      Perm.expensesVoid,
      Perm.expenseCategoriesView,
      Perm.expenseCategoriesManage,
    }) {
      batch.insert(
        db.rolePermissions,
        RolePermissionsCompanion.insert(
          id: 'rp_pharmacist_${e.replaceAll('.', '_')}',
          roleId: 'role_pharmacist',
          permissionId: 'perm_${e.replaceAll('.', '_')}',
          granted: const Value(true),
          createdAt: now,
        ),
        mode: InsertMode.insertOrIgnore,
      );
    }
    // Viewer → category view only.
    batch.insert(
      db.rolePermissions,
      RolePermissionsCompanion.insert(
        id: 'rp_viewer_expenses_categories_view',
        roleId: 'role_viewer',
        permissionId: 'perm_expenses_categories_view',
        granted: const Value(true),
        createdAt: now,
      ),
      mode: InsertMode.insertOrIgnore,
    );
  });
}

/// Phase 13 backup/restore/export RBAC — idempotently ensures the
/// `backup`, `backup.restore` and `export.data` permission seeds exist and are
/// granted to admin. Fresh installs already cover these via kSeedPermissions;
/// this guarantees the rights exist for any partial state (upgraded databases
/// and restored archives that predate Phase 13).
Future<void> ensureBackupPermissions(AppDatabase db) async {
  final now = DateTime.now().millisecondsSinceEpoch;
  const newCodes = <String, String>{
    Perm.backup: 'النسخ الاحتياطي',
    Perm.backupRestore: 'الاستعادة من نسخة',
    Perm.exportData: 'تصدير البيانات',
  };
  await db.batch((batch) {
    for (final e in newCodes.entries) {
      batch.insert(
        db.permissions,
        PermissionsCompanion.insert(
          id: 'perm_${e.key.replaceAll('.', '_')}',
          code: e.key,
          name: e.key,
          nameAr: e.value,
          createdAt: now,
        ),
        mode: InsertMode.insertOrIgnore,
      );
    }
    for (final e in newCodes.entries) {
      batch.insert(
        db.rolePermissions,
        RolePermissionsCompanion.insert(
          id: 'rp_admin_${e.key.replaceAll('.', '_')}',
          roleId: 'role_admin',
          permissionId: 'perm_${e.key.replaceAll('.', '_')}',
          granted: const Value(true),
          createdAt: now,
        ),
        mode: InsertMode.insertOrIgnore,
      );
    }
  });
}

/// Phase 15 legacy healing (§13): the read-only `viewer` role was historically
/// seeded only on fresh installs. Databases created during the early phases and
/// upgraded in place — plus restored archives — can therefore lack the role or
/// some of its grant rows (e.g. the Phase 9 expense-category grant). This
/// idempotently re-creates the role and every viewer grant using `INSERT OR
/// IGNORE` (safe under the `UNIQUE(roleId, permissionId)` key), so existing
/// grants and any manual permission denials are never overwritten.
Future<void> ensureViewerSeeded(AppDatabase db) async {
  final now = DateTime.now().millisecondsSinceEpoch;
  await db.batch((batch) {
    batch.insert(
      db.roles,
      RoleRow(
        id: 'role_viewer',
        name: 'viewer',
        nameAr: 'مشاهد',
        isSystem: true,
        isActive: true,
        createdAt: now,
        updatedAt: now,
      ),
      mode: InsertMode.insertOrIgnore,
    );
    for (final p in kSeedPermissions) {
      if (!kViewerPermissionCodes.contains(p.code)) continue;
      batch.insert(
        db.permissions,
        PermissionsCompanion.insert(
          id: 'perm_${p.code.replaceAll('.', '_')}',
          code: p.code,
          name: p.code,
          nameAr: p.name,
          createdAt: now,
        ),
        mode: InsertMode.insertOrIgnore,
      );
      batch.insert(
        db.rolePermissions,
        RolePermissionsCompanion.insert(
          id: 'rp_viewer_perm_${p.code.replaceAll('.', '_')}',
          roleId: 'role_viewer',
          permissionId: 'perm_${p.code.replaceAll('.', '_')}',
          granted: const Value(true),
          createdAt: now,
        ),
        mode: InsertMode.insertOrIgnore,
      );
    }
  });
}