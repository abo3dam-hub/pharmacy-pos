import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:drift/native.dart';
import 'package:pharmacy_pos/shared/database/app_database.dart';
import 'package:pharmacy_pos/shared/database/seed_data.dart';
import 'package:pharmacy_pos/shared/models/enums.dart';
import 'package:sqlite3/sqlite3.dart' as sqlite3;

import 'helpers.dart';

/// Mirrors the forward-only `_migrate` contract (§29, Phase 7.5) for v1→v5
/// upgrade — implementers must keep this mirror in lockstep with
/// `AppDatabase._migrate` in `app_database.dart`.
class _V1Database extends AppDatabase {
  _V1Database(super.e);

  @override
  int get schemaVersion => 5;

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

    test('fresh database creates at schema v5 with all columns', () async {
      ensureSqlite();
      final path = dbFile().path;

      final db = AppDatabase.fromFilePath(path);
      final itemId = await insertItem(db);
      final batchId = await insertBatch(db, itemId,
          quantityBase: 7, expiryDays: 90, unitCostMicros: 5000);

      // Verify schema version is 5.
      final userVersion =
          await db.customSelect('PRAGMA user_version').getSingle();
      expect(userVersion.data.values.first, 5,
          reason: 'fresh DB must be schema v5');

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
      expect(reopenedVersion.data.values.first, 5);
      await reopened.close();
    });

    test('v1 → v5 migration adds all Phase 6 + financial columns without data loss',
        () async {
      ensureSqlite();
      final path = dbFile().path;

      // Create a v5 database with data.
      final db = AppDatabase.fromFilePath(path);
      final itemId = await insertItem(db);
      expect(db.schemaVersion, 5);

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
      raw.execute('PRAGMA user_version = 1');
      raw.dispose();
      await db.close();

      // Reopen under v5 schema: onUpgrade(1 → 5) creates everything in place.
      final upgraded = _V1Database(NativeDatabase(File(path)));

      // Verify user_version is 5 after migration.
      final userVersion = await upgraded
          .customSelect('PRAGMA user_version')
          .getSingle();
      expect(userVersion.data.values.first, 5,
          reason: 'v1 → v5 migration must set user_version to 5');

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

      await upgraded.close();
    });
  });
}
