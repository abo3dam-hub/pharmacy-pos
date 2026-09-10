import 'dart:io';

import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:drift_flutter/drift_flutter.dart';
import 'package:path/path.dart' as p;

import '../models/enums.dart';
import '../models/enum_value_converter.dart';

import 'seed_data.dart';
import 'tables/accounting_periods.dart';
import 'tables/accounts.dart';
import 'tables/active_ingredients.dart';
import 'tables/app_settings.dart';
import 'tables/audit_logs.dart';
import 'tables/backups.dart';
import 'tables/batches.dart';
import 'tables/cashbox_transactions.dart';
import 'tables/categories.dart';
import 'tables/customer_payments.dart';
import 'tables/customers.dart';
import 'tables/expense_categories.dart';
import 'tables/expenses.dart';
import 'tables/indications.dart';
import 'tables/item_active_ingredients.dart';
import 'tables/item_indications.dart';
import 'tables/item_suppliers.dart';
import 'tables/item_units.dart';
import 'tables/items.dart';
import 'tables/journal_entries.dart';
import 'tables/journal_entry_lines.dart';
import 'tables/lost_sales.dart';
import 'tables/manufacturers.dart';
import 'tables/permissions.dart';
import 'tables/prescription_items.dart';
import 'tables/prescriptions.dart';
import 'tables/purchase_bonuses.dart';
import 'tables/purchase_invoice_items.dart';
import 'tables/purchase_invoices.dart';
import 'tables/return_items.dart';
import 'tables/returns.dart';
import 'tables/role_permissions.dart';
import 'tables/roles.dart';
import 'tables/sales_invoice_items.dart';
import 'tables/sales_invoices.dart';
import 'tables/stock_movements.dart';
import 'tables/sub_categories.dart';
import 'tables/suppliers.dart';
import 'tables/therapeutic_groups.dart';
import 'tables/units.dart';
import 'tables/users.dart';
part 'app_database.g.dart';

@DriftDatabase(tables: [
  Manufacturers,
  TherapeuticGroups,
  Categories,
  SubCategories,
  Units,
  ItemUnits,
  Items,
  ItemSuppliers,
  ActiveIngredients,
  ItemActiveIngredients,
  Indications,
  ItemIndications,
  Batches,
  StockMovements,
  Suppliers,
  Customers,
  CustomerPayments,
  Prescriptions,
  PrescriptionItems,
  SalesInvoices,
  SalesInvoiceItems,
  PurchaseInvoices,
  PurchaseInvoiceItems,
  PurchaseBonuses,
  Returns,
  ReturnItems,
  Expenses,
  ExpenseCategories,
  CashboxTransactions,
  Accounts,
  JournalEntries,
  JournalEntryLines,
  Users,
  Roles,
  Permissions,
  RolePermissions,
  AuditLogs,
  LostSales,
  Backups,
  AppSettings,
  AccountingPeriods,
])
class AppDatabase extends _$AppDatabase {
  AppDatabase(super.e);

  AppDatabase.runtime() : super(driftDatabase(name: 'pharmacy_pos'));

  factory AppDatabase.forTesting() => AppDatabase(NativeDatabase.memory());

  /// Opens a database backed by an explicit [File] at [path] — used by the
  /// backup/restore round-trip (§37) and by migration upgrade tests.
  factory AppDatabase.fromFilePath(String path) =>
      AppDatabase(NativeDatabase(File(p.absolute(path))));

  @override
  int get schemaVersion => 11;

  @override
  MigrationStrategy get migration => MigrationStrategy(
        onCreate: (m) async {
          await m.createAll();
          await seedDefaults(this);
        },
        onUpgrade: _migrate,
        beforeOpen: (details) async {
          await customStatement('PRAGMA foreign_keys = ON');
          await customStatement('PRAGMA journal_mode=WAL');
          // Phase 13 rights must exist on every database the app opens —
          // fresh installs, upgraded stores and restored archives.
          await ensureBackupPermissions(this);
          // Phase 15: the read-only viewer role was historically only seeded on
          // fresh installs; heal upgraded/restored stores idempotently.
          await ensureViewerSeeded(this);
        },
      );

  /// Forward-only schema upgrades. New tables/columns are appended without
  /// destructive rebuilds so existing customer databases migrate in place.
  /// `schemaVersion` stays `1` today; when the schema evolves, this helper
  /// receives the concrete old→new steps.
  Future<void> _migrate(Migrator m, int from, int to) async {
    if (from < 2) {
      // Phase 6: add partial-sale columns to items + create app_settings table.
      await m.addColumn(items, items.partialSaleEnabled);
      await m.addColumn(items, items.sellablePartUnitId);
      await m.addColumn(items, items.partsPerFullProduct);
      await m.addColumn(items, items.sellablePartBaseQuantity);
      await m.addColumn(items, items.partialSaleMarkupBasisPoints);
      await m.createTable(appSettings);
      // Seed default partial-sale markup (10% = 1000 bp).
      final now = DateTime.now().millisecondsSinceEpoch;
      await into(appSettings).insert(
        AppSettingsCompanion.insert(
          key: 'partial_sale_markup_basis_points',
          value: '1000',
          updatedAt: now,
        ),
      );
    }
    if (from < 3) {
      await m.createTable(backups);
    }
    if (from < 4) {
      // Phase 6 cross-phase integration: prescription→invoice linkage.
      await m.addColumn(salesInvoices, salesInvoices.prescriptionId);
      await m.addColumn(salesInvoiceItems, salesInvoiceItems.prescriptionItemId);
      await m.addColumn(
          prescriptionItems, prescriptionItems.dispensedQuantityBase);
    }
    if (from < 5) {
      // Phase 7.5 financial lifecycle foundation: payment split + void
      // columns on invoices, and the customer payments ledger table.
      await m.addColumn(salesInvoices, salesInvoices.cashMicros);
      await m.addColumn(salesInvoices, salesInvoices.cardMicros);
      await m.addColumn(salesInvoices, salesInvoices.creditMicros);
      await m.addColumn(salesInvoices, salesInvoices.voidedBy);
      await m.addColumn(salesInvoices, salesInvoices.voidedAt);
      await m.createTable(customerPayments);
      // Chart of accounts evolves with the financial layer: make sure the
      // inventory account exists for upgraded databases.
      final now = DateTime.now().millisecondsSinceEpoch;
      await into(accounts).insert(
        AccountsCompanion.insert(
          id: 'acc_1200',
          code: '1200',
          name: 'مخزون البضاعة',
          accountType: AccountType.asset,
          isSystem: const Value(true),
          createdAt: now,
          updatedAt: now,
        ),
        mode: InsertMode.insertOrIgnore,
      );
    }
    if (from < 6) {
      // Phase 6 gap closure: `lost_sales` was never created by the upgrade
      // path (only fresh installs). Forward-only healing for databases that
      // predate v6 — create it when absent, ignore when already present.
      final absent = await customSelect(
        "SELECT COUNT(*) AS c FROM sqlite_master "
        "WHERE type = 'table' AND name = 'lost_sales'",
      ).getSingle();
      if (absent.read<int>('c') == 0) {
        await m.createTable(lostSales);
      }
    }
    if (from < 7) {
      // Phase 9 expenses: category master + financial columns. `expenses`
      // already stores `category` as TEXT (enum name), so switching the column
      // to a plain code keeps every historical row intact; the code is the
      // seeded `expense_categories.code`. New columns carry defaults so
      // existing rows upgrade in place, then printable numbers are back-filled
      // and the expense RBAC permissions + role grants are ensured idempotently.
      await m.createTable(expenseCategories);
      await m.addColumn(expenses, expenses.paymentMethod);
      await m.addColumn(expenses, expenses.expenseNumber);
      await customStatement(
          'UPDATE expenses SET expense_number = '
          "'EXP-' || printf('%05d', rowid) "
          "WHERE expense_number IS NULL OR expense_number = ''");
      await seedExpenseCategories(this);
      await ensureExpensePermissions(this);
    }
    if (from < 8) {
      // Phase 10 accounting management: journal reversal columns, accounting
      // periods table (period close protection), and new system accounts
      // (cash over/short + purchase returns). Reversal columns are additive;
      // periods table is new; new accounts are seeded idempotently for both
      // fresh installs and upgraded databases.
      await m.addColumn(journalEntries, journalEntries.isReversal);
      await m.addColumn(
          journalEntries, journalEntries.reversalOfEntryId);
      await m.createTable(accountingPeriods);
      final now = DateTime.now().millisecondsSinceEpoch;
      await into(accounts).insert(
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
        mode: InsertMode.insertOrIgnore,
      );
      await into(accounts).insert(
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
        mode: InsertMode.insertOrIgnore,
      );
      // Ensure accountant-friendly permissions for role_admin are already
      // present (accounting.view/post are in kSeedPermissions; admin gets all).
      final pCount = await customSelect(
        "SELECT COUNT(*) AS c FROM permissions WHERE code = 'accounting.view'",
      ).getSingle();
      if (pCount.read<int>('c') < 1) {
        await ensureAccountingPermissions(this);
      }
    }
    if (from < 9) {
      // Product management UX: many-to-many preferred suppliers per item.
      // `item_suppliers` carries its own composite unique key + FK indexes so
      // existing databases migrate in place without touching purchase history.
      await m.createTable(itemSuppliers);
    }
    if (from < 10) {
      // Phase 16 product master data: reusable active-ingredient + indication
      // lists and their per-item junctions. All four tables are brand new —
      // forward-only, nothing else is rewritten.
      await m.createTable(activeIngredients);
      await m.createTable(itemActiveIngredients);
      await m.createTable(indications);
      await m.createTable(itemIndications);
    }
    if (from < 11) {
      // Phase 17 product-master redesign:
      //  * per-ingredient strength (العيار) on the item↔ingredient junction,
      //  * an explicit persisted manual part price (سعر بيع الجزء) that
      //    survives save/reload/restart; NULL = automatic (derived).
      // The partial-sale default markup moves 10% → 20% (1000 → 2000 bp) for
      // stores that never changed it (value still '1000'); deliberately-set
      // values are preserved.
      // Stores migrating from <10 create the junction tables from the *current*
      // schema (strength already present), so guard the column adds.
      final strengthPresent = await customSelect(
        "SELECT COUNT(*) AS c FROM pragma_table_info('item_active_ingredients') "
        "WHERE name = 'strength'",
      ).getSingle();
      if (strengthPresent.read<int>('c') == 0) {
        await m.addColumn(
            itemActiveIngredients, itemActiveIngredients.strength);
      }
      final manualPartPricePresent = await customSelect(
        "SELECT COUNT(*) AS c FROM pragma_table_info('items') "
        "WHERE name = 'partial_sale_price_micros'",
      ).getSingle();
      if (manualPartPricePresent.read<int>('c') == 0) {
        await m.addColumn(items, items.partialSalePriceMicros);
      }
      final now = DateTime.now().millisecondsSinceEpoch;
      await customStatement(
          "UPDATE app_settings SET value = '2000', updated_at = $now "
          "WHERE key = 'partial_sale_markup_basis_points' "
          "AND value = '1000'");
    }
  }
}
