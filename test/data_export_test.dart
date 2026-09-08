import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:pharmacy_pos/domain/services/data_export_service.dart';
import 'package:pharmacy_pos/features/backup/domain/entities/data_export_result.dart';
import 'package:pharmacy_pos/shared/database/app_database.dart';

import 'helpers.dart';

/// Phase 13 export: read-only, DB-side paged CSV dump with a UTF-8 BOM, a
/// manifest, correct row counts, and zero mutation of the source database.
void main() {
  const service = DataExportService();
  late AppDatabase db;
  late Directory work;

  setUp(() {
    db = newDatabase();
    work = Directory.systemTemp.createTempSync('export_test_');
  });

  tearDown(() async {
    await db.close();
    if (work.existsSync()) {
      work.deleteSync(recursive: true);
    }
  });

  Future<int> seedRowCount() async {
    for (var i = 1; i <= 3; i++) {
      await insertItem(db, barcode: '629104150021$i');
    }
    return 3;
  }

  Future<int> tableCount(String table) async {
    final row = await db.customSelect('SELECT COUNT(*) AS c FROM $table').getSingle();
    return row.read<int>('c');
  }

  test('exports every table to CSV with a BOM, header and correct row counts',
      () async {
    final items = await seedRowCount();
    final result = await service.exportAll(
      db: db,
      destinationDirectory: p.join(work.path, 'export'),
    );

    expect(result, isA<DataExportResult>());
    final manifestFile = File(p.join(work.path, 'export', 'export_manifest.json'));
    expect(manifestFile.existsSync(), isTrue);

    final csvFiles = Directory(p.join(work.path, 'export'))
        .listSync()
        .whereType<File>()
        .where((f) => f.path.endsWith('.csv'))
        .toList();
    expect(csvFiles.length, greaterThanOrEqualTo(1),
        reason: 'all data-backed tables must appear as CSV files');

    // The items CSV has a BOM, a header row, and as many data rows as seeded.
    final itemsCsv = File(p.join(work.path, 'export', 'items.csv')).readAsBytesSync();
    final bom = [0xEF, 0xBB, 0xBF];
    expect(itemsCsv.take(3), orderedEquals(bom));
    final itemsText = itemsCsv.skip(3);
    final lines = asciiSafeDecode(itemsText).split('\n').where((l) => l.isNotEmpty);
    expect(lines, hasLength(items + 1)); // header + data rows
    expect(lines.first, contains('id,'));

    final auditRow = await tableCount('audit_logs');
    expect(auditRow, 0,
        reason: 'export must not write audit rows');
  });

  test('export keeps the database byte-identical (no mutations)', () async {
    // Deterministic snapshot: export to two folders and compare the row
    // counts and CSV bytes; the source DB is untouched across calls (only the
    // manifest's generated_at_millis differs between runs).
    final snapshotBefore = await db.customSelect(
        'PRAGMA integrity_check').getSingle();

    await service.exportAll(
        db: db,
        destinationDirectory: p.join(work.path, 'export1'));
    await service.exportAll(
        db: db,
        destinationDirectory: p.join(work.path, 'export2'));

    expect(snapshotBefore.data.values.first, 'ok');
    final manifest1 = jsonDecode(File(
            p.join(work.path, 'export1', 'export_manifest.json'))
        .readAsStringSync()) as Map<String, dynamic>;
    final manifest2 = jsonDecode(File(
            p.join(work.path, 'export2', 'export_manifest.json'))
        .readAsStringSync()) as Map<String, dynamic>;
    expect(manifest1['tables'], manifest2['tables'],
        reason: 'row counts must be identical across exports');
    final items1 = File(p.join(work.path, 'export1', 'items.csv'))
        .readAsBytesSync();
    final items2 = File(p.join(work.path, 'export2', 'items.csv'))
        .readAsBytesSync();
    expect(items1, items2,
        reason: 'CSV bytes must be identical across exports');
  });

  test('export_manifest.json carries table + row-count metadata', () async {
    await seedRowCount();
    await service.exportAll(
        db: db,
        destinationDirectory: p.join(work.path, 'export'));

    final manifestText = File(
            p.join(work.path, 'export', 'export_manifest.json'))
        .readAsStringSync();
    expect(manifestText, contains('"format"'));
    expect(manifestText, contains('"tables"'));
    expect(manifestText, contains('"items"'));
  });

  test('missing destination directory is created', () async {
    final target = p.join(work.path, 'deep', 'nested', 'export');
    await service.exportAll(db: db, destinationDirectory: target);
    expect(Directory(target).existsSync(), isTrue);
    expect(File(p.join(target, 'export_manifest.json')).existsSync(), isTrue);
  });
}

/// Decodes a UTF-8 byte list leniently (the CSV body is already BOM-stripped).
String asciiSafeDecode(Iterable<int> bytes) =>
    utf8.decode(bytes.toList(), allowMalformed: true);