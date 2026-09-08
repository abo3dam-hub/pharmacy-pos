import 'dart:io';

import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:pharmacy_pos/core/di/app_database_lifecycle.dart';
import 'package:pharmacy_pos/domain/services/backup_archive_service.dart';
import 'package:pharmacy_pos/domain/services/app_paths.dart';
import 'package:pharmacy_pos/domain/services/database_lifecycle.dart';
import 'package:pharmacy_pos/domain/services/data_export_service.dart';
import 'package:pharmacy_pos/domain/services/permission_service.dart';
import 'package:pharmacy_pos/domain/services/restore_service.dart';
import 'package:pharmacy_pos/features/backup/application/data_management_controller.dart';
import 'package:pharmacy_pos/features/backup/domain/usecases/backup_use_cases.dart';
import 'package:pharmacy_pos/shared/database/app_database.dart';

import 'helpers.dart';

/// Phase 13 hardening: the restore workflow MUST own the database lifecycle —
/// the live connection is closed by [DatabaseLifecycle] before any file is
/// replaced, and an unclosable connection aborts the restore (blocker A2).
void main() {
  late AppDatabase db;
  late Directory work;

  setUp(() {
    db = newDatabase();
    work = Directory.systemTemp.createTempSync('lifecycle_test_');
  });

  tearDown(() async {
    if (await _isOpen(db)) {
      await db.close();
    }
    if (work.existsSync()) {
      work.deleteSync(recursive: true);
    }
  });

  // A controller whose paths resolve to temp dirs (backup/restore/export run
  // against the in-memory live DB, but restore targets on-disk files).
  DataManagementController buildController(AppDatabase liveDb) {
    const archiver = BackupArchiveService();
    const restore = RestoreService();
    const exporter = DataExportService();
    final permissions = const PermissionService();
    final temp = p.join(work.path, 'ctrl');
    return DataManagementController(
      CreateBackupUseCase(archiver, permissions),
      PreviewRestoreUseCase(restore, permissions),
      RestoreBackupUseCase(restore, permissions),
      ExportDataUseCase(exporter, permissions),
      AppPaths(documentsDir: () async => temp),
      liveDb,
      AppDatabaseLifecycle(liveDb),
    );
  }

  Future<void> seedLiveData() async {
    final itemId = await insertItem(db);
    await insertBatch(db, itemId,
        quantityBase: 5, expiryDays: 60, unitCostMicros: 1000);
  }

  test('AppDatabaseLifecycle closes the live connection and reports state',
      () async {
    final lc = AppDatabaseLifecycle(db);
    expect(lc.isClosed, isFalse);
    await lc.close();
    expect(lc.isClosed, isTrue);
    // Closing twice is idempotent.
    await lc.close();
    expect(lc.isClosed, isTrue);
  });

  test('restore success closes the live DB through the controller', () async {
    await seedLiveData();

    // A valid archive created from the live DB.
    final archive = (await BackupArchiveService().createBackup(
      db: db,
      databasePath: 'unused.sqlite',
      receiptsDirectory: p.join(work.path, 'empty_receipts'),
      destinationDirectory: p.join(work.path, 'archives'),
      fileName: 'life.zip',
    ))
        .archivePath;

    final livePath = p.join(work.path, 'ctrl', 'pharmacy_pos.sqlite');
    Directory(p.dirname(livePath)).createSync(recursive: true);
    // Pre-existing live data file on disk to be replaced.
    final oldDb = AppDatabase.fromFilePath(livePath);
    await awaitCategory(oldDb);
    final now = DateTime.now().millisecondsSinceEpoch;
    await oldDb.into(oldDb.items).insert(ItemsCompanion.insert(
          id: 'old_item',
          primaryBarcode: const Value('999'),
          tradeName: 'قديم',
          categoryId: 'cat_test_default',
          createdAt: now,
          updatedAt: now,
        ));
    await oldDb.close();

    final controller = buildController(db);
    final failure = await controller.restore(
      actingRoleId: 'role_admin',
      actingUserId: 'user_admin',
      archivePath: archive,
    );

    expect(failure, isNull);
    // The live connection was closed as part of activation.
    expect(controller.state.dbClosed, isTrue);
    expect(await _isOpen(db), isFalse,
        reason: 'the live singleton connection must be closed before replace');

    // The restored archive replaced the file on disk.
    final reopened = AppDatabase.fromFilePath(livePath);
    try {
      final oldItem = await (reopened.select(reopened.items)
            ..where((i) => i.id.equals('old_item')))
          .getSingleOrNull();
      expect(oldItem, isNull);
    } finally {
      await reopened.close();
    }
  });

  test('an unclosable live DB surfaces a failure and does not replace data',
      () async {
    await seedLiveData();
    final archive = (await BackupArchiveService().createBackup(
      db: db,
      databasePath: 'unused.sqlite',
      receiptsDirectory: p.join(work.path, 'empty_receipts'),
      destinationDirectory: p.join(work.path, 'archives'),
      fileName: 'life2.zip',
    ))
        .archivePath;

    final livePath = p.join(work.path, 'ctrl2', 'pharmacy_pos.sqlite');
    Directory(p.dirname(livePath)).createSync(recursive: true);
    File(livePath).writeAsBytesSync(const [1, 2, 3]);

    // A lifecycle whose close always fails must abort the restore.
    final failingLifecycle = _FailingLifecycle();
    final controller = DataManagementController(
      CreateBackupUseCase(
          const BackupArchiveService(), const PermissionService()),
      PreviewRestoreUseCase(const RestoreService(), const PermissionService()),
      RestoreBackupUseCase(const RestoreService(), const PermissionService()),
      ExportDataUseCase(const DataExportService(), const PermissionService()),
      AppPaths(documentsDir: () async => p.join(work.path, 'ctrl2')),
      db,
      failingLifecycle,
    );

    final failure = await controller.restore(
      actingRoleId: 'role_admin',
      actingUserId: 'user_admin',
      archivePath: archive,
    );

    expect(failure, isNotNull);
    // The live DB file was never replaced.
    expect(File(livePath).readAsBytesSync(), [1, 2, 3]);
    // The live in-memory DB is still open and usable.
    expect(await _isOpen(db), isTrue);
  });
}

/// True when a trivial statement still executes on [db] (i.e. it is open).
Future<bool> _isOpen(AppDatabase db) async {
  try {
    await db.customSelect('SELECT 1').get();
    return true;
  } catch (_) {
    return false;
  }
}

/// A [DatabaseLifecycle] that refuses to close (simulating an OS-level file
/// lock or an in-flight query that cannot settle).
class _FailingLifecycle implements DatabaseLifecycle {
  @override
  bool get isClosed => false;

  @override
  Future<void> close() {
    throw StateError('cannot close live database (simulated lock)');
  }
}
