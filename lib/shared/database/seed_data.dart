import 'package:bcrypt/bcrypt.dart';
import 'package:drift/drift.dart';

import '../../core/constants/permission_codes.dart';
import '../models/enums.dart';
import 'app_database.dart';

const _defaultAdminPassword = 'Admin@123';

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
  final viewerCodes = {
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
  };
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
}