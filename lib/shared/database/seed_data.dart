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

  // Default units.
  await db.batch((batch) {
    batch.insertAll(db.units, [
      UnitsCompanion.insert(
        id: 'unit_strip',
        name: 'شريط',
        createdAt: now,
        updatedAt: now,
      ),
      UnitsCompanion.insert(
        id: 'unit_box',
        name: 'علبة',
        createdAt: now,
        updatedAt: now,
      ),
      UnitsCompanion.insert(
        id: 'unit_tablet',
        name: 'قرص',
        createdAt: now,
        updatedAt: now,
      ),
    ]);
  });

  // Default roles.
  await db.batch((batch) {
    batch.insertAll(db.roles, [
      RoleRow(
        id: 'role_admin',
        name: 'مدير النظام',
        isSystem: true,
        createdAt: now,
        updatedAt: now,
      ),
      RoleRow(
        id: 'role_pharmacist',
        name: 'صيدلي',
        isSystem: true,
        createdAt: now,
        updatedAt: now,
      ),
      RoleRow(
        id: 'role_cashier',
        name: 'كاشير',
        isSystem: true,
        createdAt: now,
        updatedAt: now,
      ),
    ]);
  });

  // All permissions.
  final permRows = <PermissionsCompanion>[];
  for (final p in kSeedPermissions) {
    permRows.add(PermissionsCompanion.insert(
      id: 'perm_${p.code.replaceAll('.', '_')}',
      code: p.code,
      name: p.name,
      createdAt: now,
    ));
  }
  await db.batch((batch) {
    batch.insertAll(db.permissions, permRows);
  });

  // Admin role → all permissions.
  await db.batch((batch) {
    batch.insertAll(db.rolePermissions, [
      for (final p in permRows)
        RolePermissionsCompanion.insert(
          roleId: 'role_admin',
          permissionId: p.id.value,
          createdAt: now,
        ),
    ]);
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
    batch.insertAll(db.rolePermissions, [
      for (final p in permRows)
        if (pharmacistCodes.contains(p.code.value))
          RolePermissionsCompanion.insert(
            roleId: 'role_pharmacist',
            permissionId: p.id.value,
            createdAt: now,
          ),
    ]);
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
    batch.insertAll(db.rolePermissions, [
      for (final p in permRows)
        if (cashierCodes.contains(p.code.value))
          RolePermissionsCompanion.insert(
            roleId: 'role_cashier',
            permissionId: p.id.value,
            createdAt: now,
          ),
    ]);
  });

  // Admin user (bcrypt hash generated at runtime).
  final adminHash = BCrypt.hashpw(_defaultAdminPassword, BCrypt.gensalt());
  await db.into(db.users).insert(UsersCompanion.insert(
        id: 'user_admin',
        username: 'admin',
        passwordHash: adminHash,
        fullName: 'مدير النظام',
        roleId: const Value('role_admin'),
        createdAt: now,
        updatedAt: now,
      ));

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