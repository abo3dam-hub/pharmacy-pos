import 'dart:io';
import 'dart:typed_data';

import 'package:archive/archive_io.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:pharmacy_pos/core/errors/exceptions.dart';
import 'package:pharmacy_pos/domain/services/backup_archive_service.dart';
import 'package:pharmacy_pos/domain/services/backup_service.dart';
import 'package:pharmacy_pos/features/backup/domain/entities/backup_manifest.dart';
import 'package:pharmacy_pos/shared/database/app_database.dart';
import 'package:pharmacy_pos/shared/models/enums.dart';

import 'helpers.dart';

/// Phase 13 backup archive: self-contained zip layout, manifest integrity,
/// SHA-256 verification and strict rejection of corrupt or hostile archives.
void main() {
  const service = BackupArchiveService();
  late AppDatabase db;
  late Directory work;

  setUp(() {
    db = newDatabase();
    work = Directory.systemTemp.createTempSync('backup_test_');
  });

  tearDown(() async {
    await db.close();
    if (work.existsSync()) {
      work.deleteSync(recursive: true);
    }
  });

  Future<String> seed() async {
    final itemId = await insertItem(db);
    await insertBatch(db, itemId,
        quantityBase: 12, expiryDays: 90, unitCostMicros: 5000);
    return itemId;
  }

  Future<String> createBackup({String? fileName}) async {
    return (await service.createBackup(
      db: db,
      databasePath: 'unused.sqlite',
      receiptsDirectory: p.join(work.path, 'receipts'),
      destinationDirectory: p.join(work.path, 'out'),
      fileName: fileName,
    ))
        .archivePath;
  }

  test('creates a verifiable zip with manifest + database entries', () async {
    await seed();
    final archivePath = await createBackup(fileName: 'b1.zip');
    expect(File(archivePath).existsSync(), isTrue);

    // Layout inside the zip.
    final input1 = InputFileStream(archivePath);
    final decoded1 = ZipDecoder().decodeBuffer(input1);
    expect(decoded1.files.map((f) => f.name),
        containsAll([BackupArchiveLayout.manifestFileName, BackupArchiveLayout.databaseFileName]));
    await decoded1.clear();
    input1.closeSync();

    // Extract + verify (the service's own validation) succeeds.
    final extracted = await service.extractAndVerify(
      archivePath: archivePath,
      destinationDir: p.join(work.path, 'extracted'),
    );
    expect(extracted.manifest.formatVersion, kBackupFormatVersion);
    expect(extracted.manifest.schemaVersion, kCurrentSupportedSchemaVersion);
    expect(extracted.manifest.databaseFileName,
        BackupArchiveLayout.databaseFileName);
    // The extracted database opens and is intact.
    final reopened = AppDatabase.fromFilePath(extracted.databaseStagedPath);
    final integrity = await reopened.customSelect('PRAGMA integrity_check').getSingle();
    expect(integrity.data.values.first, 'ok');
    await reopened.close();

    // Ledger: one completed backup row with a matching checksum.
    final latest = await const BackupService().latest(db);
    expect(latest, isNotNull);
    expect(latest!.status, BackupStatus.completed);
    expect(latest.checksumSha256, isNotNull);
    expect(await sha256OfFile(archivePath), latest.checksumSha256);
  });

  test('includes managed receipt files and verifies them', () async {
    await seed();
    final receipts = Directory(p.join(work.path, 'receipts'));
    receipts.createSync(recursive: true);
    final receiptFile = File(p.join(receipts.path, 'rec_1.png'))
      ..writeAsBytesSync(Uint8List.fromList(List.generate(64, (i) => i)));

    final archivePath = await createBackup();
    final extracted = await service.extractAndVerify(
      archivePath: archivePath,
      destinationDir: p.join(work.path, 'extracted2'),
    );
    expect(extracted.stagedReceipts, hasLength(1));
    // The extracted bytes equal the original receipt bytes.
    expect(
        await File(extracted.stagedReceipts.single).readAsBytes(),
        await receiptFile.readAsBytes());
    expect(extracted.manifest.files.single.relativePath,
        startsWith(BackupArchiveLayout.filesRoot));
  });

  test('fails cleanly when the archive is already missing', () async {
    await expectLater(
      service.extractAndVerify(
          archivePath: p.join(work.path, 'nope.zip'),
          destinationDir: p.join(work.path, 'x')),
      throwsA(isA<InvalidOperationException>()),
    );
  });

  test('rejects a corrupted (bit-flipped) archive', () async {
    await seed();
    final archivePath = await createBackup();
    final raw = File(archivePath).readAsBytesSync();
    final flipped = Uint8List.fromList(raw)..[128] ^= 0xFF;
    final corrupt = File(p.join(work.path, 'corrupt.zip'));
    corrupt.writeAsBytesSync(flipped);

    await expectLater(
      service.extractAndVerify(
          archivePath: corrupt.path, destinationDir: p.join(work.path, 'cx')),
      throwsA(isA<InvalidOperationException>()),
    );
  });

  test('rejects path-traversal (zip-slip) archive entries', () async {
    final archive = Archive();
    archive.addFile(ArchiveFile('../../escape.txt', 1, const [1]));
    final zipPath = p.join(work.path, 'slip.zip');
    File(zipPath).writeAsBytesSync(
        ZipEncoder().encode(archive, level: 0)!);

    await expectLater(
      service.extractAndVerify(
          archivePath: zipPath, destinationDir: p.join(work.path, 'esc')),
      throwsA(isA<InvalidOperationException>()),
    );
  });

  test('rejects an archive whose embedded manifest has a wrong db checksum',
      () async {
    // Build the valid layout manually, then disagree with the DB hash.
    final manifest = BackupManifest(
      formatVersion: kBackupFormatVersion,
      applicationVersion: 'test',
      schemaVersion: 10,
      createdAtMillis: DateTime.now().millisecondsSinceEpoch,
      databaseFileName: BackupArchiveLayout.databaseFileName,
      databaseSizeBytes: 4,
      databaseSha256: '0' * 64,
      files: const [],
    );
    final archive = Archive()
      ..addFile(ArchiveFile(
          BackupArchiveLayout.manifestFileName,
          manifest.toJsonString().length,
          manifest.toJsonString().codeUnits))
      ..addFile(ArchiveFile(BackupArchiveLayout.databaseFileName, 4, [1, 2, 3, 4]));
    final zipPath = p.join(work.path, 'badsha.zip');
    File(zipPath).writeAsBytesSync(
        ZipEncoder().encode(archive, level: 0)!);

    await expectLater(
      service.extractAndVerify(
          archivePath: zipPath, destinationDir: p.join(work.path, 'bads')),
      throwsA(isA<InvalidOperationException>()),
    );
  });

  test('rejects an archive with an unexpected extra file', () async {
    await seed();
    final archivePath = await createBackup();

    // Re-wrap the original entries plus a rogue "files/evil.txt".
    final input2 = InputFileStream(archivePath);
    final decoded2 = ZipDecoder().decodeBuffer(input2);
    final archive = Archive();
    for (final entry in decoded2.files) {
      final bytes = (entry.content as List<int>);
      archive.addFile(
          ArchiveFile(entry.name, bytes.length, bytes));
    }
    archive.addFile(ArchiveFile('files/evil.txt', 3, [1, 2, 3]));
    await decoded2.clear();
    input2.closeSync();
    final zipPath = p.join(work.path, 'extra.zip');
    File(zipPath).writeAsBytesSync(
        ZipEncoder().encode(archive, level: 0)!);

    await expectLater(
      service.extractAndVerify(
          archivePath: zipPath, destinationDir: p.join(work.path, 'xx')),
      throwsA(isA<InvalidOperationException>()),
    );
  });

  test('cleans up its staging temp directory after a successful backup',
      () async {
    final before =
        Directory.systemTemp.listSync().whereType<Directory>().toList();
    await seed();
    await createBackup(fileName: 'clean.zip');
    final after =
        Directory.systemTemp.listSync().whereType<Directory>().toList();
    // No 'pharmacy_backup_*' staging directories leak after completion.
    final leaked = after
        .where((d) =>
            p.basename(d.path).startsWith('pharmacy_backup_') &&
            !before.any((b) => b.path == d.path))
        .toList();
    expect(leaked, isEmpty);
  });
}