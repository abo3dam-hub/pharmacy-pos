import 'dart:io';

import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:drift_flutter/drift_flutter.dart';
import 'package:path/path.dart' as p;

import '../models/enums.dart';
import '../models/enum_value_converter.dart';

import 'seed_data.dart';
import 'tables/accounts.dart';
import 'tables/app_settings.dart';
import 'tables/audit_logs.dart';
import 'tables/backups.dart';
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
  Returns,
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
  Backups,
  AppSettings,
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
  int get schemaVersion => 3;

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
  }
}
