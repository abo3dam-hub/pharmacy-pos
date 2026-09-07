import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:drift/native.dart';
import 'package:pharmacy_pos/shared/database/app_database.dart';
import 'package:pharmacy_pos/shared/database/seed_data.dart';
import 'package:pharmacy_pos/shared/models/enums.dart';
import 'package:sqlite3/sqlite3.dart' as sqlite3;

import 'helpers.dart';

/// Mirrors the forward-only `_migrate` contract (§29, Phase 7.5/9/10) for
/// v1→v8 upgrade — implementers must keep this mirror in lockstep with
/// `AppDatabase._migrate` in `app_database.dart`.
class _V1Database extends AppDatabase {
  _V1Database(super.e);

  @override
  int get schemaVersion => 8;

  @override
  MigrationStrategy get migration => MigrationStrategy(
        onCreate: (m) async {
          await m.createAll();
          await seedDefaults(this);
        },
        onUpgrade: (m, from, to) async {
          if (from < 2) {
            await m.addColumn(items, items.partialSaleEnabled);
            await m.addColumn(items, items.sellablePartUnitId);
            await m.addColumn(items, items.partsPerFullProduct);
            await m.addColumn(items, items.sellablePartBaseQuantity);
            await m.addColumn(items, items.partialSaleMarkupBasisPoints);
            await m.createTable(appSettings);
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
            await m.addColumn(salesInvoices, salesInvoices.prescriptionId);
            await m.addColumn(
                salesInvoiceItems, salesInvoiceItems.prescriptionItemId);
            await m.addColumn(
                prescriptionItems, prescriptionItems.dispensedQuantityBase);
          }
          if (from < 5) {
            await m.addColumn(salesInvoices, salesInvoices.cashMicros);
            await m.addColumn(salesInvoices, salesInvoices.cardMicros);
            await m.addColumn(salesInvoices, salesInvoices.creditMicros);
            await m.addColumn(salesInvoices, salesInvoices.voidedBy);
            await m.addColumn(salesInvoices, salesInvoices.voidedAt);
            await m.createTable(customerPayments);
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
            final absent = await customSelect(
              "SELECT COUNT(*) AS c FROM sqlite_master "
              "WHERE type = 'table' AND name = 'lost_sales'",
            ).getSingle();
            if (absent.read<int>('c') == 0) {
              await m.createTable(lostSales);
            }
          }
          if (from < 7) {
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
            final pCount = await customSelect(
              "SELECT COUNT(*) AS c FROM permissions WHERE code = 'accounting.view'",
            ).getSingle();
            if (pCount.read<int>('c') < 1) {
              await ensureAccountingPermissions(this);
            }
          }
        },
        beforeOpen: (details) async {
          await customStatement('PRAGMA foreign_keys = ON');
          await customStatement('PRAGMA journal_mode=WAL');
        },
      );
}

/// Migration / restore round-trip harness (§29, §37).
void main() {
  group('file-backed database (restore round-trip)', () {
    late Directory dir;

    setUp(() {
      ensureSqlite();
      dir = Directory.systemTemp.createTempSync('pharmacy_migration_test');
    });

    tearDown(() {
      if (dir.existsSync()) dir.deleteSync(recursive: true);
    });

    File dbFile() => File('${dir.path}/store.db');

    test('fresh database creates at schema v8 with all columns', () async {
      ensureSqlite();
      final path = dbFile().path;

      final db = AppDatabase.fromFilePath(path);
      final itemId = await insertItem(db);
      final batchId = await insertBatch(db, itemId,
          quantityBase: 7, expiryDays: 90, unitCostMicros: 5000);

      // Verify schema version is 8.
      final userVersion =
          await db.customSelect('PRAGMA user_version').getSingle();
      expect(userVersion.data.values.first, 8,
          reason: 'fresh DB must be schema v8');

      // Verify v7 Phase 9 additions: category master seeded + expenses columns.
      final categories = await db.select(db.expenseCategories).get();
      expect(categories, hasLength(8),
          reason: 'seedExpenseCategories runs on fresh create');
      expect(categories.map((c) => c.code), contains('rent'));
      expect(categories.map((c) => c.code), contains('salaries'));
      final rent =
          categories.firstWhere((c) => c.code == 'rent');
      expect(rent.accountCode, '5101');
      final now9 = DateTime.now().millisecondsSinceEpoch;
      final exp = await db.into(db.expenses).insertReturning(
            ExpensesCompanion.insert(
              id: 'exp_v7_fresh',
              amountMicros: 10000,
              category: 'rent',
              description: 'إيجار يوليو',
              expenseDate: now9,
              userId: 'user_admin',
              createdAt: now9,
              updatedAt: now9,
            ),
          );
      expect(exp.paymentMethod, 'cash',
          reason: 'expenses.payment_method defaults to cash');
      expect(exp.expenseNumber, '',
          reason: 'new rows get their printable number from the engine; the '
              'v7 migration only back-fills pre-existing rows');

      // Verify partial-sale columns exist on items.
      final item = await (db.select(db.items)
            ..where((i) => i.id.equals(itemId)))
          .getSingle();
      expect(item.partialSaleEnabled, false);
      expect(item.sellablePartUnitId, isNull);
      expect(item.partsPerFullProduct, isNull);
      expect(item.sellablePartBaseQuantity, isNull);
      expect(item.partialSaleMarkupBasisPoints, isNull);

      // Verify app_settings table exists.
      final settings = await db.select(db.appSettings).get();
      expect(settings, isNotEmpty);

      // Verify prescription linkage columns exist.
      // Write a sales invoice with prescription_id.
      final now = DateTime.now().millisecondsSinceEpoch;
      await db.into(db.salesInvoices).insert(
            SalesInvoicesCompanion.insert(
              id: 'inv_v4_test',
              invoiceNumber: 'SI-V4-TEST',
              invoiceType: InvoiceType.sale,
              saleStatus: SaleStatus.completed,
              paymentMethod: PaymentMethod.cash,
              userId: 'user_admin',
              prescriptionId: const Value('rx_test'),
              createdAt: now,
              updatedAt: now,
            ),
          );
      final inv = await (db.select(db.salesInvoices)
            ..where((i) => i.id.equals('inv_v4_test')))
          .getSingle();
      expect(inv.prescriptionId, 'rx_test');

      // Verify Phase 7.5 payment-split columns exist and default to 0, and
      // the customer payments ledger table was created with its index.
      final invSplit = await db.customSelect(
          'SELECT cash_micros, card_micros, credit_micros, '
          'voided_by, voided_at FROM sales_invoices WHERE id = ?1',
          variables: [Variable.withString('inv_v4_test')]).getSingle();
      expect(invSplit.data.values, [0, 0, 0, null, null]);
      await db.customSelect(
          "SELECT COUNT(*) AS c FROM customer_payments WHERE 1 = 0").getSingle();

      // Lost sales table is part of the schema (gap closure §4.28/§15).
      final lsNow = DateTime.now().millisecondsSinceEpoch;
      await db.into(db.lostSales).insert(
            LostSalesCompanion.insert(
              id: 'ls_fresh',
              requestedItemName: 'ناقص اختباري',
              quantityRequested: 1,
              userId: 'user_admin',
              status: LostSaleStatus.open,
              createdAt: lsNow,
              updatedAt: lsNow,
            ),
          );

      // Inventory system account seeded by the v5 migration.
      final acc1200 = await (db.select(db.accounts)
            ..where((a) => a.code.equals('1200')))
          .getSingle();
      expect(acc1200.isSystem, true);
      expect(acc1200.accountType, AccountType.asset);

      // Verify prescription_items.dispensed_quantity_base.
      final batch = await (db.select(db.batches)
            ..where((b) => b.id.equals(batchId)))
          .getSingle();
      expect(batch.quantityBase, 7);

      // Verify close/reopen preserves data.
      await db.close();
      final reopened = AppDatabase.fromFilePath(path);
      final reopenedItem = await (reopened.select(reopened.items)
            ..where((i) => i.id.equals(itemId)))
          .getSingle();
      expect(reopenedItem.currentStockBase, 7);
      final reopenedVersion =
          await reopened.customSelect('PRAGMA user_version').getSingle();
      expect(reopenedVersion.data.values.first, 8);

      // Verify v8 Phase 10 additions: reversing columns on journal_entries,
      // accounting_periods table, and new system accounts.
      final acc1099 = await (reopened.select(reopened.accounts)
            ..where((a) => a.code.equals('1099')))
          .getSingleOrNull();
      expect(acc1099, isNotNull,
          reason: 'cash over/short account seeded on fresh install');
      final acc4002 = await (reopened.select(reopened.accounts)
            ..where((a) => a.code.equals('4002')))
          .getSingleOrNull();
      expect(acc4002, isNotNull,
          reason: 'purchase returns account seeded on fresh install');
      await reopened
          .select(reopened.accountingPeriods)
          .get(); // table exists without error
      await reopened.close();
    });

    test('v1 → v8 migration adds all Phase 6/7.5/9/10 columns without data loss',
        () async {
      ensureSqlite();
      final path = dbFile().path;

      // Create a v8 database with data (fresh createAll seeds v8 + an expense
      // row that must survive the simulated downgrade).
      final db = AppDatabase.fromFilePath(path);
      final itemId = await insertItem(db);
      expect(db.schemaVersion, 8);
      final preNow = DateTime.now().millisecondsSinceEpoch;
      await db.into(db.expenses).insert(
            ExpensesCompanion.insert(
              id: 'exp_mig_legacy',
              amountMicros: 25000,
              category: 'rent',
              description: 'إيجار قديم',
              expenseDate: preNow,
              userId: 'user_admin',
              createdAt: preNow,
              updatedAt: preNow,
            ),
          );

      // Verify the new columns exist before simulating v1.
      final beforeItem = await (db.select(db.items)
            ..where((i) => i.id.equals(itemId)))
          .getSingle();
      expect(beforeItem.partialSaleEnabled, false);

      // Simulate a v1 database: drop ALL Phase 6/7.5 additions and set
      // user_version=1.
      final raw = sqlite3.sqlite3.open(path);
      // Drop v2 additions (partial-sale columns + app_settings).
      raw.execute('DROP TABLE IF EXISTS app_settings');
      raw.execute('ALTER TABLE items DROP COLUMN partial_sale_enabled');
      raw.execute('ALTER TABLE items DROP COLUMN sellable_part_unit_id');
      raw.execute('ALTER TABLE items DROP COLUMN parts_per_full_product');
      raw.execute('ALTER TABLE items DROP COLUMN sellable_part_base_quantity');
      raw.execute('ALTER TABLE items DROP COLUMN partial_sale_markup_basis_points');
      // Drop v4 additions (prescription linkage columns).
      raw.execute('ALTER TABLE sales_invoices DROP COLUMN prescription_id');
      raw
          .execute('ALTER TABLE sales_invoice_items DROP COLUMN prescription_item_id');
      raw.execute(
          'ALTER TABLE prescription_items DROP COLUMN dispensed_quantity_base');
      // Drop v5 additions (payment split + void columns, customer_payments).
      raw.execute('ALTER TABLE sales_invoices DROP COLUMN cash_micros');
      raw.execute('ALTER TABLE sales_invoices DROP COLUMN card_micros');
      raw.execute('ALTER TABLE sales_invoices DROP COLUMN credit_micros');
      raw.execute('ALTER TABLE sales_invoices DROP COLUMN voided_by');
      raw.execute('ALTER TABLE sales_invoices DROP COLUMN voided_at');
      raw.execute('DROP TABLE IF EXISTS customer_payments');
      raw.execute('DELETE FROM accounts WHERE code = \'1200\'');
      // Drop v6 gap-closure table.
      raw.execute('DROP TABLE IF EXISTS lost_sales');
      // Drop v7 Phase 9 additions (category master + expenses columns), while
      // keeping the pre-existing expense row in place.
      raw.execute('DROP TABLE IF EXISTS expense_categories');
      raw.execute('ALTER TABLE expenses DROP COLUMN payment_method');
      raw.execute('ALTER TABLE expenses DROP COLUMN expense_number');
      // Drop v8 Phase 10 additions.
      raw.execute('ALTER TABLE journal_entries DROP COLUMN is_reversal');
      raw.execute('ALTER TABLE journal_entries DROP COLUMN reversal_of_entry_id');
      raw.execute('DROP TABLE IF EXISTS accounting_periods');
      raw.execute('DELETE FROM accounts WHERE code = \'1099\'');
      raw.execute('DELETE FROM accounts WHERE code = \'4002\'');
      raw.execute('PRAGMA user_version = 1');
      raw.dispose();
      await db.close();

      // Reopen under the working schema: onUpgrade(1 → 8) recreates everything.
      final upgraded = _V1Database(NativeDatabase(File(path)));

      // Verify user_version is 8 after migration.
      final userVersion = await upgraded
          .customSelect('PRAGMA user_version')
          .getSingle();
      expect(userVersion.data.values.first, 8,
          reason: 'v1 → v8 migration must set user_version to 8');

      // Verify app_settings created.
      final settings = await upgraded.select(upgraded.appSettings).get();
      expect(settings, isNotEmpty);

      // Verify partial-sale columns exist.
      final item = await (upgraded.select(upgraded.items)
            ..where((i) => i.id.equals(itemId)))
          .getSingle();
      expect(item.id, itemId, reason: 'existing data preserved through upgrade');
      expect(item.partialSaleEnabled, false);

      // Verify prescription linkage columns exist.
      final now = DateTime.now().millisecondsSinceEpoch;
      await upgraded.into(upgraded.salesInvoices).insert(
            SalesInvoicesCompanion.insert(
              id: 'inv_mig_test',
              invoiceNumber: 'SI-MIG-TEST',
              invoiceType: InvoiceType.sale,
              saleStatus: SaleStatus.completed,
              paymentMethod: PaymentMethod.cash,
              userId: 'user_admin',
              prescriptionId: const Value('rx_mig'),
              createdAt: now,
              updatedAt: now,
            ),
          );
      final inv = await (upgraded.select(upgraded.salesInvoices)
            ..where((i) => i.id.equals('inv_mig_test')))
          .getSingle();
      expect(inv.prescriptionId, 'rx_mig');
      expect(inv.cashMicros, 0, reason: 'v5 payment-split column defaults to 0');

      // Verify customer_payments table + inventory account back after v5.
      final pay = await upgraded.into(upgraded.customerPayments).insertReturning(
            CustomerPaymentsCompanion.insert(
              id: 'cpay_mig',
              paymentNumber: 'CP-MIG-1',
              customerId: 'customer_default',
              amountMicros: 100,
              paymentMethod: PaymentMethod.cash,
              userId: 'user_admin',
              createdAt: now,
              updatedAt: now,
            ),
          );
      expect(pay.id, 'cpay_mig');
      final acc1200 = await (upgraded.select(upgraded.accounts)
            ..where((a) => a.code.equals('1200')))
          .getSingle();
      expect(acc1200.isSystem, true, reason: 'v5 seeds the inventory account');

      // v6 heals the missing `lost_sales` table for upgraded databases.
      final lsNow = DateTime.now().millisecondsSinceEpoch;
      final ls = await upgraded.into(upgraded.lostSales).insertReturning(
            LostSalesCompanion.insert(
              id: 'ls_mig',
              requestedItemName: 'ناقص بعد الترقية',
              scientificName: const Value('Substance X'),
              quantityRequested: 3,
              userId: 'user_admin',
              status: LostSaleStatus.open,
              createdAt: lsNow,
              updatedAt: lsNow,
            ),
          );
      expect(ls.id, 'ls_mig', reason: 'lost_sales table created on upgrade');

      // v7 Phase 9: category master re-seeded + expense columns re-added with
      // the legacy row preserved and its printable number back-filled.
      final cats = await upgraded.select(upgraded.expenseCategories).get();
      expect(cats, hasLength(8), reason: 'v7 seeds the category master');
      final legacyExp = await (upgraded.select(upgraded.expenses)
            ..where((e) => e.id.equals('exp_mig_legacy')))
          .getSingle();
      expect(legacyExp.category, 'rent',
          reason: 'legacy expense row survives the upgrade');
      expect(legacyExp.amountMicros, 25000);
      expect(legacyExp.paymentMethod, 'cash',
          reason: 're-added default on the upgraded column');
      expect(legacyExp.expenseNumber, 'EXP-00001',
          reason: 'existing rows are back-filled with printable numbers');

      // v8 Phase 10: journal reversal columns, accounting periods table, and
      // new system accounts after upgrade.
      final upgradedAcc1099 = await (upgraded.select(upgraded.accounts)
            ..where((a) => a.code.equals('1099')))
          .getSingleOrNull();
      expect(upgradedAcc1099, isNotNull,
          reason: 'cash over/short account added on v8 upgrade');
      final upgradedAcc4002 = await (upgraded.select(upgraded.accounts)
            ..where((a) => a.code.equals('4002')))
          .getSingleOrNull();
      expect(upgradedAcc4002, isNotNull,
          reason: 'purchase returns account added on v8 upgrade');
      final periodsRows = await upgraded
          .select(upgraded.accountingPeriods)
          .get();
      expect(periodsRows, isEmpty,
          reason: 'accounting periods table exists after upgrade');
      // Reversal column persists correctly.
      await upgraded.into(upgraded.journalEntries).insert(
            JournalEntriesCompanion.insert(
              id: 'je_v8_mig',
              entryNumber: 'JE-V8-MIG',
              refType: JournalReferenceType.manual,
              entryDate: now,
              description: 'قيد اختبار v8',
              isPosted: const Value(true),
              isReversal: const Value(false),
              createdAt: now,
              updatedAt: now,
              createdBy: 'user_admin',
            ),
          );
      final je = await (upgraded.select(upgraded.journalEntries)
            ..where((e) => e.id.equals('je_v8_mig')))
          .getSingle();
      expect(je.isReversal, false,
          reason: 'journal reversal column added on v8 upgrade');

      await upgraded.close();
    });
  });
}
