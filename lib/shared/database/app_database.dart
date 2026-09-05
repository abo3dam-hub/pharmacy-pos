import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:drift_flutter/drift_flutter.dart';

import '../models/enums.dart';

import 'seed_data.dart';
import 'tables/accounts.dart';
import 'tables/audit_logs.dart';
import 'tables/batches.dart';
import 'tables/cashbox_transactions.dart';
import 'tables/categories.dart';
import 'tables/customers.dart';
import 'tables/expenses.dart';
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
  Batches,
  StockMovements,
  Suppliers,
  Customers,
  Prescriptions,
  PrescriptionItems,
  SalesInvoices,
  SalesInvoiceItems,
  PurchaseInvoices,
  PurchaseInvoiceItems,
  PurchaseBonuses,
  ReturnOrders,
  ReturnItems,
  Expenses,
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
])
class AppDatabase extends _$AppDatabase {
  AppDatabase(super.e);

  AppDatabase.runtime() : super(driftDatabase(name: 'pharmacy_pos'));

  factory AppDatabase.forTesting() => AppDatabase(NativeDatabase.memory());

  @override
  int get schemaVersion => 1;

  @override
  MigrationStrategy get migration => MigrationStrategy(
        onCreate: (m) async {
          await m.createAll();
          await seedDefaults(this);
        },
        beforeOpen: (details) async {
          await customStatement('PRAGMA foreign_keys = ON');
          await customStatement('PRAGMA journal_mode=WAL');
        },
      );
}
