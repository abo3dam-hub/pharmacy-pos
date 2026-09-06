import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:drift/native.dart';
import 'package:pharmacy_pos/shared/database/app_database.dart';
import 'package:pharmacy_pos/shared/database/seed_data.dart';
import 'package:sqlite3/sqlite3.dart' as sqlite3;

import 'helpers.dart';

/// A future schema copy that declares both the partial-sale columns and the
/// `backups` table as v2 additions — mirrors the forward-only `_migrate`
/// contract (§29).
class _V2Database extends AppDatabase {
  _V2Database(super.e);

  @override
  int get schemaVersion => 2;

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
        },
        beforeOpen: (details) async {
          await customStatement('PRAGMA foreign_keys = ON');
          await customStatement('PRAGMA journal_mode=WAL');
        },
      );
}

/// Migration / restore round-trip harness (§29, §37).
///
/// Opens a real on-disk database through [AppDatabase.fromFilePath], mutates
/// it, closes, then re-opens the file to prove that the schema + data survive
/// and that the forward-only upgrade path can add missing tables/columns in
/// place.
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

    test('data written on a file DB survives a close/reopen cycle', () async {
      ensureSqlite();
      final path = dbFile().path;

      final db = AppDatabase.fromFilePath(path);
      final itemId = await insertItem(db);
      final batchId = await insertBatch(db, itemId,
          quantityBase: 7, expiryDays: 90, unitCostMicros: 5000);
      final before = await (db.select(db.items)..where((i) => i.id.equals(itemId)))
          .getSingle();
      expect(before.currentStockBase, 7);
      await db.close();

      // Re-open the same file.
      final reopened = AppDatabase.fromFilePath(path);
      final item = await (reopened.select(reopened.items)
            ..where((i) => i.id.equals(itemId)))
          .getSingle();
      expect(item.tradeName, 'بانادول');
      expect(item.currentStockBase, 7);
      final batch = await (reopened.select(reopened.batches)
            ..where((b) => b.id.equals(batchId)))
          .getSingle();
      expect(batch.quantityBase, 7);
      expect(batch.expiryDate, isNotNull);
      final userVersion = await reopened
          .customSelect('PRAGMA user_version')
          .getSingle();
      expect(userVersion.data.values.first, 2, reason: 'schemaVersion is 2');
      // Verify partial-sale columns exist on items.
      expect(item.partialSaleEnabled, false);
      expect(item.sellablePartUnitId, isNull);
      expect(item.partsPerFullProduct, isNull);
      expect(item.sellablePartBaseQuantity, isNull);
      expect(item.partialSaleMarkupBasisPoints, isNull);
      // Verify app_settings table exists.
      final settings = await reopened.select(reopened.appSettings).get();
      expect(settings, isNotEmpty);
      await reopened.close();
    });

    test('forward-only upgrade adds partial-sale columns + app_settings without data loss',
        () async {
      ensureSqlite();
      final path = dbFile().path;

      // A real v1 database with data — as if it was created before Phase 6.
      final db = AppDatabase.fromFilePath(path);
      final itemId = await insertItem(db);
      expect(db.schemaVersion, 2);

      // Simulate a v1 database: drop Phase 6 additions and set user_version=1.
      final raw = sqlite3.sqlite3.open(path);
      raw.execute('DROP TABLE IF EXISTS app_settings');
      raw.execute('ALTER TABLE items DROP COLUMN partial_sale_enabled');
      raw.execute('ALTER TABLE items DROP COLUMN sellable_part_unit_id');
      raw.execute('ALTER TABLE items DROP COLUMN parts_per_full_product');
      raw.execute('ALTER TABLE items DROP COLUMN sellable_part_base_quantity');
      raw.execute('ALTER TABLE items DROP COLUMN partial_sale_markup_basis_points');
      raw.execute('PRAGMA user_version = 1');
      raw.dispose();
      await db.close();

      // Reopen under the upgraded (v2) schema: onUpgrade(1 → 2) creates
      // partial-sale columns + app_settings in place and keeps existing rows.
      final upgraded = _V2Database(NativeDatabase(File(path)));
      final userVersion = await upgraded
          .customSelect('PRAGMA user_version')
          .getSingle();
      expect(userVersion.data.values.first, 2);
      final settings = await upgraded.select(upgraded.appSettings).get();
      expect(settings, isNotEmpty);
      final item = await (upgraded.select(upgraded.items)
            ..where((i) => i.id.equals(itemId)))
          .getSingle();
      expect(item.id, itemId, reason: 'existing data preserved through upgrade');
      expect(item.partialSaleEnabled, false);
      await upgraded.close();
    });
  });
}
