import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:pharmacy_pos/core/config/app_config.dart';
import 'package:pharmacy_pos/domain/services/backup_service.dart';
import 'package:pharmacy_pos/shared/database/app_database.dart';
import 'package:pharmacy_pos/shared/models/enums.dart';

import 'helpers.dart';

/// Backup ledger + restore verification (§37, §17 audit integration).
void main() {
  const service = BackupService();

  late Directory dir;

  setUp(() {
    ensureSqlite();
    dir = Directory.systemTemp.createTempSync('pharmacy_backup_test');
  });

  tearDown(() {
    if (dir.existsSync()) dir.deleteSync(recursive: true);
  });

  test('recordCompleted writes ledger row, checksum and audit entry', () async {
    final db = newDatabase();
    try {
      // Build a real file copy to "back up".
      final source = AppDatabase.fromFilePath('${dir.path}/source.db');
      final itemId = await insertItem(source);
      await insertBatch(source, itemId,
          quantityBase: 4, expiryDays: 30, unitCostMicros: 8000);
      await source.close();

      final size = File('${dir.path}/source.db').lengthSync();
      final row = await service.recordCompleted(db,
          filePath: '${dir.path}/source.db', sizeBytes: size,
          note: 'periodic');

      expect(row.status, BackupStatus.completed);
      expect(row.fileName, startsWith(AppConfig.backupFilePrefix));
      expect(row.schemaVersion, db.schemaVersion);
      expect(row.appVersion, AppConfig.appVersion);
      expect(row.sizeBytes, size);
      expect(row.checksumSha256, hasLength(64));

      expect(await service.latest(db), isNotNull);
      final audit = await (db.select(db.auditLogs)
            ..where((a) => a.entityType.equals('backup')))
          .get();
      expect(audit, hasLength(1));
      expect(audit.single.action, 'backup');
      expect(audit.single.entityId, row.id);
    } finally {
      await db.close();
    }
  });

  test('verifyRestore reopens the backup copy with intact data + checksum',
      () async {
    ensureSqlite();
    // The live store.
    final storePath = '${dir.path}/store.db';
    final db = AppDatabase.fromFilePath(storePath);
    final itemId = await insertItem(db);
    await insertBatch(db, itemId,
        quantityBase: 6, expiryDays: 45, unitCostMicros: 9000);
    await db.close();

    // A static backup copy (as produced by VACUUM INTO / file copy §37).
    final backupPath = '${dir.path}/backup.db';
    File(storePath).copySync(backupPath);
    final size = File(backupPath).lengthSync();
    final checksum = await sha256OfFile(backupPath);

    // Record the ledger entry against the live store; the copy stays static.
    final fav = AppDatabase.fromFilePath(storePath);
    final row = await service.recordCompleted(fav,
        filePath: backupPath, sizeBytes: size, userId: 'user_admin');
    await fav.close();
    expect(row.checksumSha256, checksum,
        reason: 'recorded checksum matches the static backup copy');

    final verification = await service.verifyRestore(backupPath,
        expectedChecksum: checksum);
    expect(verification.ok, isTrue, reason: 'PRAGMA integrity_check == ok');
    expect(verification.schemaVersion, 1);
    expect(verification.latestChecksumMatches, isTrue);

    // Data survived in the restored copy.
    final reopened = AppDatabase.fromFilePath(backupPath);
    final item = await (reopened.select(reopened.items)
          ..where((i) => i.id.equals(itemId)))
        .getSingle();
    expect(item.tradeName, 'بانادول');
    expect(item.currentStockBase, 6);
    await reopened.close();
  });

  test('recordCompleted rejects a missing file', () async {
    final db = newDatabase();
    try {
      await expectLater(
        () async => service.recordCompleted(db,
            filePath: '${dir.path}/does_not_exist.db', sizeBytes: 0),
        throwsA(isA<FileSystemException>()),
      );
    } finally {
      await db.close();
    }
  });
}