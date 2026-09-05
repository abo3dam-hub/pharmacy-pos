import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:drift/drift.dart' hide isNotNull;
import 'package:drift/native.dart';
import 'package:pharmacy_pos/shared/database/app_database.dart';
import 'package:pharmacy_pos/shared/database/seed_data.dart';
import 'package:sqlite3/sqlite3.dart' as sqlite3;

import 'helpers.dart';

/// A future schema copy that only declares the `backups` table as a v2
/// addition — mirrors the forward-only `_migrate` contract (§29).
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
            await m.createTable(backups);
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
/// and that the forward-only upgrade path can add a missing table in place.
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
      expect(userVersion.data.values.first, 1, reason: 'schemaVersion stays 1');
      final tables = await reopened
          .customSelect(
              "SELECT name FROM sqlite_master WHERE type='table'")
          .get();
      final names = tables.map((r) => r.data.values.first as String).toSet();
      expect(names, contains('backups'));
      await reopened.close();
    });

    test('forward-only upgrade adds the backups table without data loss',
        () async {
      ensureSqlite();
      final path = dbFile().path;

      // A real v1 database with data but no backups table — as if it was
      // created before the backups ledger existed (§37).
      final db = AppDatabase.fromFilePath(path);
      final itemId = await insertItem(db);
      expect(db.schemaVersion, 1);
      final raw = sqlite3.sqlite3.open(path);
      raw.execute('DROP TABLE IF EXISTS backups');
      raw.dispose();
      await db.close();

      // Reopen under the upgraded (v2) schema: onUpgrade(1 → 2) creates
      // `backups` in place and keeps the existing rows.
      final upgraded = _V2Database(NativeDatabase(File(path)));
      final userVersion = await upgraded
          .customSelect('PRAGMA user_version')
          .getSingle();
      expect(userVersion.data.values.first, 2);
      final backups = await upgraded.select(upgraded.backups).get();
      expect(backups, isEmpty);
      final item = await (upgraded.select(upgraded.items)
            ..where((i) => i.id.equals(itemId)))
          .getSingle();
      expect(item.id, itemId, reason: 'existing data preserved through upgrade');
      await upgraded.close();
    });
  });
}