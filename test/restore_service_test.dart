import 'dart:convert';
import 'dart:io';

import 'package:archive/archive.dart' show Archive, ArchiveFile;
import 'package:archive/archive_io.dart'
    show ZipDecoder, ZipEncoder, InputFileStream;
import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:pharmacy_pos/core/constants/account_codes.dart';
import 'package:pharmacy_pos/core/errors/exceptions.dart';
import 'package:pharmacy_pos/domain/services/backup_archive_service.dart';
import 'package:pharmacy_pos/domain/services/restore_service.dart';
import 'package:pharmacy_pos/domain/services/sale_service.dart';
import 'package:pharmacy_pos/features/backup/domain/entities/backup_manifest.dart';
import 'package:pharmacy_pos/shared/database/app_database.dart';
import 'package:pharmacy_pos/shared/models/enums.dart';

import 'helpers.dart';

/// Phase 13 restore safety: full validated restore replaces the live database
/// and managed files, preserves financial integrity (no reposting), keeps the
/// emergency backup, reconciles receipt references and rejects incompatible,
/// corrupt or hostile archives before anything is touched.
void main() {
  const archiver = BackupArchiveService();
  const restoreService = RestoreService();
  late AppDatabase db; // "current live" data (in-memory).
  late Directory work;
  late String liveDatabasePath;
  late String liveReceiptsDir;
  late String emergencyDir;

  setUp(() {
    db = newDatabase();
    work = Directory.systemTemp.createTempSync('restore_test_');
    liveDatabasePath = p.join(work.path, 'live', 'pharmacy_pos.sqlite');
    liveReceiptsDir = p.join(work.path, 'liveReceipts');
    emergencyDir = p.join(work.path, 'emergency');
  });

  tearDown(() async {
    await db.close();
    if (work.existsSync()) {
      work.deleteSync(recursive: true);
    }
  });

  Future<void> seedFinancialData() async {
    final itemId = await insertItem(db);
    await insertBatch(db, itemId,
        quantityBase: 10, expiryDays: 90, unitCostMicros: 10000);
    // A cash sale: revenue 20.00, cash 20.00, COGS 10.00, inventory -10.00.
    await SaleService().recordSale(
      db,
      SaleRequest(
        invoiceNumber: 'SI-R1',
        lines: [
          SaleLineRequest(
              itemId: itemId,
              quantityBase: 1,
              unitPriceMicros: 20000,
              unitTypeId: 'unit_strip'),
        ],
        paymentMethod: PaymentMethod.cash,
        userId: 'user_admin',
        paidMicros: 20000,
      ),
    );
  }

  Future<String> seedExpenseWithReceipt() async {
    final receipts = Directory(p.join(work.path, 'receipts'));
    receipts.createSync(recursive: true);
    final receiptFile = File(p.join(receipts.path, 'rec_1.png'))
      ..writeAsBytesSync(Uint8List.fromList(List.generate(64, (i) => i)));
    final now = DateTime.now().millisecondsSinceEpoch;
    const expenseId = 'exp_restore';
    await db.into(db.expenses).insert(ExpensesCompanion.insert(
          id: expenseId,
          amountMicros: 1500000,
          category: 'rent',
          description: 'إيجار',
          expenseDate: now,
          userId: 'user_admin',
          receiptPath: Value(receiptFile.path),
          createdAt: now,
          updatedAt: now,
        ));
    return expenseId;
  }

  Future<String> createArchive() async {
    return (await archiver.createBackup(
      db: db,
      databasePath: 'unused.sqlite',
      receiptsDirectory: p.join(work.path, 'receipts'),
      destinationDirectory: p.join(work.path, 'archives'),
      fileName: 'restore_me.zip',
    ))
        .archivePath;
  }

  Future<String> categoryId(AppDatabase target) async {
    final now = DateTime.now().millisecondsSinceEpoch;
    const id = 'cat_old_default';
    await target.into(target.categories).insert(
          CategoriesCompanion.insert(
            id: id,
            name: 'أدوية',
            createdAt: now,
            updatedAt: now,
          ),
          mode: InsertMode.insertOrIgnore,
        );
    return id;
  }

  Future<void> seedOldStateOnDisk() async {
    // A pre-existing live database that must be fully replaced by the restore.
    Directory(p.dirname(liveDatabasePath)).createSync(recursive: true);
    final old = AppDatabase.fromFilePath(liveDatabasePath);
    final now = DateTime.now().millisecondsSinceEpoch;
    await old.into(old.items).insert(ItemsCompanion.insert(
          id: 'item_old_only',
          primaryBarcode: Value('9999999999999'),
          tradeName: 'منتج قديم',
          categoryId: await categoryId(old),
          createdAt: now,
          updatedAt: now,
        ));
    await old.close();
    // Old managed receipts that must disappear after the restore.
    final oldReceipts = Directory(liveReceiptsDir)..createSync(recursive: true);
    File(p.join(oldReceipts.path, 'old_trace.txt'))
        .writeAsStringSync('should be replaced');
  }

  Future<void> expectFinancialInvariants(AppDatabase restored) async {
    final cash = await restored.customSelect(
        'SELECT COALESCE(SUM(amount_micros), 0) AS s '
        'FROM cashbox_transactions').getSingle();
    expect(cash.read<int>('s'), 20000);

    final journals = await restored
        .customSelect('SELECT COUNT(*) AS c FROM journal_entries').getSingle();
    expect(journals.read<int>('c'), 1);

    final sums = await restored.customSelect(
        'SELECT total_debit_micros AS d, total_credit_micros AS c '
        'FROM journal_entries').getSingle();
    expect(sums.read<int>('d'), 30000);
    expect(sums.read<int>('c'), 30000);

    Future<int> balance(String code) async {
      final row = await (restored.select(restored.accounts)
            ..where((a) => a.code.equals(code)))
          .getSingle();
      return row.balanceMicros;
    }

    expect(await balance(SystemAccountCode.salesRevenue), 20000);
    expect(await balance(SystemAccountCode.cash), 20000);
    expect(await balance(SystemAccountCode.costOfGoodsSold), 10000);
    expect(await balance(SystemAccountCode.inventory), -10000);
  }

  test('full restore replaces the live data and preserves financial integrity',
      () async {
    await seedFinancialData();
    final expenseId = await seedExpenseWithReceipt();
    final archivePath = await createArchive();
    await seedOldStateOnDisk();

    final result = await restoreService.restore(
      archivePath: archivePath,
      liveDb: db,
      liveDatabasePath: liveDatabasePath,
      receiptsDirectory: liveReceiptsDir,
      emergencyDirectory: emergencyDir,
      userId: 'user_admin',
    );

    expect(result.schemaAfterRestore, kCurrentSupportedSchemaVersion);
    expect(result.databaseIntegrityOk, isTrue);
    expect(result.restoredReceiptCount, 1);
    expect(result.emergencyBackupPath, startsWith(emergencyDir));
    expect(File(result.emergencyBackupPath).existsSync(), isTrue,
        reason: 'the emergency backup must be preserved');
    expect(File(liveDatabasePath).existsSync(), isTrue);

    // The old live DB was replaced: 'item_old_only' must be gone.
    final reopened = AppDatabase.fromFilePath(liveDatabasePath);
    try {
      final oldItem = await (reopened.select(reopened.items)
            ..where((i) => i.id.equals('item_old_only')))
          .getSingleOrNull();
      expect(oldItem, isNull);

      // The restored seeded sale is present.
      await expectFinancialInvariants(reopened);

      // Receipt reconciliation: expense points at the live receipts dir.
      final expense = await (reopened.select(reopened.expenses)
            ..where((e) => e.id.equals(expenseId)))
          .getSingle();
      expect(expense.receiptPath, p.join(liveReceiptsDir, 'rec_1.png'));

      // Managed files replaced: the receipt exists and 'old_trace.txt' is gone.
      expect(File(p.join(liveReceiptsDir, 'rec_1.png')).existsSync(), isTrue);
      expect(File(p.join(liveReceiptsDir, 'old_trace.txt')).existsSync(),
          isFalse);

      // Audit trail: restore completed recorded exactly once on the restored
      // database (the pre-restore start row lived in the replaced data).
      final restores = await (reopened.select(reopened.auditLogs)
            ..where((l) => l.action.equals('restore_backup')))
          .get();
      expect(restores, hasLength(1));
      expect(restores.single.note, 'restore_completed');
    } finally {
      await reopened.close();
    }
  });

  test('preview reports a valid archive as valid with its manifest', () async {
    await seedFinancialData();
    final archivePath = await createArchive();
    final preview = await restoreService.preview(archivePath);
    expect(preview.valid, isTrue);
    expect(preview.manifest, isNotNull);
    expect(preview.manifest!.schemaVersion, kCurrentSupportedSchemaVersion);
  });

  test('preview rejects a newer-schema archive without touching the live file',
      () async {
    await seedFinancialData();
    final archivePath = await createArchive();
    await seedOldStateOnDisk();

    // Tamper the manifest's schema version to a hypothetical future one.
    final spoiled = p.join(work.path, 'future.zip');
    _rewriteManifestJson(archivePath, spoiled,
        (json) => json['schema_version'] = 9);

    final preview = await restoreService.preview(spoiled);
    expect(preview.valid, isFalse);
    expect(preview.reason, isNotEmpty);

    await expectLater(
      restoreService.restore(
        archivePath: spoiled,
        liveDb: db,
        liveDatabasePath: liveDatabasePath,
        receiptsDirectory: liveReceiptsDir,
        emergencyDirectory: emergencyDir,
      ),
      throwsA(isA<InvalidOperationException>()),
    );
    // Nothing was replaced: the old DB file and old trace are untouched.
    expect(File(liveDatabasePath).existsSync(), isTrue);
    expect(File(p.join(liveReceiptsDir, 'old_trace.txt')).existsSync(), isTrue);
  });

  test('restore rejects a corrupt archive before any activation', () async {
    await seedFinancialData();
    final archivePath = await createArchive();
    final raw = File(archivePath).readAsBytesSync();
    final flipped = Uint8List.fromList(raw)..[64] ^= 0xFF;
    final corrupt = File(p.join(work.path, 'corrupt.zip'));
    corrupt.writeAsBytesSync(flipped);

    await expectLater(
      restoreService.restore(
        archivePath: corrupt.path,
        liveDb: db,
        liveDatabasePath: liveDatabasePath,
        receiptsDirectory: liveReceiptsDir,
        emergencyDirectory: emergencyDir,
      ),
      throwsA(isA<InvalidOperationException>()),
    );
    expect(File(liveDatabasePath).existsSync(), isFalse,
        reason: 'corrupt archives must never reach the activation step');
  });

  test('restore rejects a missing file', () async {
    await expectLater(
      restoreService.restore(
        archivePath: p.join(work.path, 'missing.zip'),
        liveDb: db,
        liveDatabasePath: liveDatabasePath,
        receiptsDirectory: liveReceiptsDir,
        emergencyDirectory: emergencyDir,
      ),
      throwsA(isA<InvalidOperationException>()),
    );
  });

  test('onBeforeReplace is invoked before the live DB is replaced', () async {
    await seedFinancialData();
    await seedExpenseWithReceipt();
    final archivePath = await createArchive();
    await seedOldStateOnDisk();

    var beforeReplaceCalls = 0;
    await restoreService.restore(
      archivePath: archivePath,
      liveDb: db,
      liveDatabasePath: liveDatabasePath,
      receiptsDirectory: liveReceiptsDir,
      emergencyDirectory: emergencyDir,
      userId: 'user_admin',
      onBeforeReplace: () async {
        beforeReplaceCalls++;
      },
    );

    // The close callback must have run exactly once, right before replacement.
    expect(beforeReplaceCalls, 1);
    // The old live data was replaced.
    final reopened = AppDatabase.fromFilePath(liveDatabasePath);
    try {
      final oldItem = await (reopened.select(reopened.items)
            ..where((i) => i.id.equals('item_old_only')))
          .getSingleOrNull();
      expect(oldItem, isNull);
    } finally {
      await reopened.close();
    }
  });

  test('an unclosable live DB aborts restore without touching live data',
      () async {
    await seedFinancialData();
    await seedExpenseWithReceipt();
    final archivePath = await createArchive();
    await seedOldStateOnDisk();

    final marker = File(p.join(work.path, 'close_failed.marker'));
    await expectLater(
      restoreService.restore(
        archivePath: archivePath,
        liveDb: db,
        liveDatabasePath: liveDatabasePath,
        receiptsDirectory: liveReceiptsDir,
        emergencyDirectory: emergencyDir,
        userId: 'user_admin',
        onBeforeReplace: () async {
          await marker.writeAsString('attempted');
          throw StateError('cannot close live database');
        },
      ),
      throwsA(isA<InvalidOperationException>()),
    );

    // The close was attempted, the restore was aborted, and the live DB and
    // receipts are untouched (no deletion, no rollback of live data).
    expect(await marker.readAsString(), 'attempted');
    expect(File(liveDatabasePath).existsSync(), isTrue,
        reason: 'live DB must not be deleted when the connection is unclosable');
    expect(File(p.join(liveReceiptsDir, 'old_trace.txt')).existsSync(), isTrue,
        reason: 'live receipts must not be deleted when close fails');

    // The still-open live in-memory DB is fully intact (nothing was destroyed).
    final row = await db.customSelect(
        'SELECT COALESCE(SUM(amount_micros),0) AS s '
        'FROM cashbox_transactions').getSingle();
    expect(row.read<int>('s'), 20000);

    // An emergency backup was still created and preserved for safety.
    final emergencyDirObj = Directory(emergencyDir);
    final emergencyFiles = emergencyDirObj.existsSync()
        ? emergencyDirObj.listSync().whereType<File>().toList()
        : <File>[];
    expect(emergencyFiles, isNotEmpty,
        reason: 'the pre-restore emergency backup must remain available');
    expect(await emergencyFiles.first.exists(), isTrue);
  });

  test('an unclosable live DB never leaves stale WAL/SHM behind trials',
      () async {
    // Guard: a live (open) in-memory DB has no on-disk sidecar; this test
    // verifies that aborting before replacement never creates WAL/SHM around
    // the live path.
    await seedFinancialData();
    final archivePath = await createArchive();
    Directory(p.dirname(liveDatabasePath)).createSync(recursive: true);
    // Simulate a pre-existing live DB file + stale sidecars.
    File(liveDatabasePath).writeAsBytesSync(const [1, 2, 3, 4]);
    File('$liveDatabasePath-wal').writeAsBytesSync(const [9]);
    File('$liveDatabasePath-shm').writeAsBytesSync(const [9]);

    await expectLater(
      restoreService.restore(
        archivePath: archivePath,
        liveDb: db,
        liveDatabasePath: liveDatabasePath,
        receiptsDirectory: liveReceiptsDir,
        emergencyDirectory: emergencyDir,
        userId: 'user_admin',
        onBeforeReplace: () async => throw StateError('close refused'),
      ),
      throwsA(isA<InvalidOperationException>()),
    );

    // The live files were not touched in any way.
    expect(File(liveDatabasePath).readAsBytesSync(), [1, 2, 3, 4]);
    expect(File('$liveDatabasePath-wal').readAsBytesSync(), [9]);
    expect(File('$liveDatabasePath-shm').readAsBytesSync(), [9]);
  });
}

/// Rewrites [source]'s `manifest.json` via [mutate] and writes a new archive
/// to [target]. This keeps the database bytes untouched so only the manifest
/// disagrees (checksum mismatch stays detectable).
void _rewriteManifestJson(
  String source,
  String target,
  void Function(Map<String, Object?> json) mutate,
) {
  final input = InputFileStream(source);
  final decoded = ZipDecoder().decodeBuffer(input);
  final archive = Archive();
  for (final entry in decoded.files) {
    if (entry.name == BackupArchiveLayout.manifestFileName) {
      final content = entry.content as List<int>;
      final json = Map<String, Object?>.from(
          jsonDecode(utf8.decode(content)) as Map<String, dynamic>);
      mutate(json);
      archive.addFile(ArchiveFile(entry.name,
          const JsonEncoder().convert(json).length,
          const JsonEncoder().convert(json).codeUnits));
    } else {
      final bytes = entry.content as List<int>;
      archive.addFile(ArchiveFile(entry.name, bytes.length, bytes));
    }
  }
  final bytes = ZipEncoder().encode(archive, level: 0)!;
  File(target).writeAsBytesSync(bytes);
  input.closeSync();
}