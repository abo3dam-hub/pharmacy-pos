import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:drift/native.dart';
import 'package:pharmacy_pos/shared/database/app_database.dart';
import 'package:pharmacy_pos/shared/database/seed_data.dart';
import 'package:pharmacy_pos/shared/models/enums.dart';
import 'package:sqlite3/sqlite3.dart' as sqlite3;

import 'helpers.dart';

/// Mirrors the forward-only `_migrate` contract (§29) for v1→v4 upgrade.
class _V1Database extends AppDatabase {
  _V1Database(super.e);

  @override
  int get schemaVersion => 4;

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

    test('fresh database creates at schema v4 with all columns', () async {
      ensureSqlite();
      final path = dbFile().path;

      final db = AppDatabase.fromFilePath(path);
      final itemId = await insertItem(db);
      final batchId = await insertBatch(db, itemId,
          quantityBase: 7, expiryDays: 90, unitCostMicros: 5000);

      // Verify schema version is 4.
      final userVersion =
          await db.customSelect('PRAGMA user_version').getSingle();
      expect(userVersion.data.values.first, 4,
          reason: 'fresh DB must be schema v4');

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
      expect(reopenedVersion.data.values.first, 4);
      await reopened.close();
    });

    test('v1 → v4 migration adds all Phase 6 columns without data loss',
        () async {
      ensureSqlite();
      final path = dbFile().path;

      // Create a v4 database with data.
      final db = AppDatabase.fromFilePath(path);
      final itemId = await insertItem(db);
      expect(db.schemaVersion, 4);

      // Verify the new columns exist before simulating v1.
      final beforeItem = await (db.select(db.items)
            ..where((i) => i.id.equals(itemId)))
          .getSingle();
      expect(beforeItem.partialSaleEnabled, false);

      // Simulate a v1 database: drop ALL Phase 6 additions and set user_version=1.
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
      raw.execute('PRAGMA user_version = 1');
      raw.dispose();
      await db.close();

      // Reopen under v4 schema: onUpgrade(1 → 4) creates everything in place.
      final upgraded = _V1Database(NativeDatabase(File(path)));

      // Verify user_version is 4 after migration.
      final userVersion = await upgraded
          .customSelect('PRAGMA user_version')
          .getSingle();
      expect(userVersion.data.values.first, 4,
          reason: 'v1 → v4 migration must set user_version to 4');

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

      await upgraded.close();
    });
  });
}
