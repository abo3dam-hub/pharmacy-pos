import 'dart:io';

import 'package:drift/drift.dart' hide isNull;
import 'package:path/path.dart' as p;

import '../../core/errors/exceptions.dart';
import '../../core/util/ids.dart';
import '../../features/backup/domain/entities/backup_manifest.dart';
import '../../features/backup/domain/entities/backup_results.dart';
import '../../shared/database/app_database.dart';
import '../../shared/models/enums.dart';
import 'audit_service.dart';
import 'backup_archive_service.dart';

/// Tables that must exist and be readable after a restore activates.
const Set<String> kRequiredTablesAfterRestore = {
  'users', 'roles', 'role_permissions', 'permissions',
  'items', 'batches', 'stock_movements', 'item_units', 'units',
  'categories', 'manufacturers',
  'active_ingredients', 'item_active_ingredients',
  'indications', 'item_indications',
  'suppliers', 'purchase_invoices', 'purchase_invoice_items',
  'purchase_bonuses', 'customers', 'customer_payments',
  'prescriptions', 'prescription_items',
  'sales_invoices', 'sales_invoice_items',
  'returns', 'return_items', 'expenses', 'expense_categories',
  'cashbox_transactions', 'accounts', 'journal_entries',
  'journal_entry_lines', 'audit_logs', 'lost_sales',
  'app_settings', 'accounting_periods',
};

/// Safe, destructive restore workflow (§37, Env C).
///
/// Order of operations (any failure before activation leaves the live data
/// untouched; any failure after activation triggers an emergency rollback):
///
///  1. validate archive structure + manifest + every SHA-256;
///  2. validate format version + schema compatibility (never downgrade);
///  3. stage files + migrate staged DB forward (if supported) + integrity;
///  4. reconcile receipt references to the live receipts directory;
///  5. create a complete emergency backup of the CURRENT data;
///  6. close the live connection (caller's [onBeforeReplace]);
///  7. replace the live DB + managed files;
///  8. reopen + integrity-check + verify schema + audit the restore.
///
/// Restore is data restoration only: it never calls any financial posting
/// operation and never recalculates or reposts journal rows.
class RestoreService {
  const RestoreService({
    this.archiver = const BackupArchiveService(),
    this.audit = const AuditService(),
  });

  final BackupArchiveService archiver;
  final AuditService audit;

  /// Read-only archive inspection used by the UI before a destructive restore.
  /// Validates structure + checksums + format + schema without touching the
  /// filesystem outside a temp staging dir.
  Future<RestorePreview> preview(
    String archivePath, {
    int? currentSchemaVersion,
  }) async {
    final schemaNow = currentSchemaVersion ?? kCurrentSupportedSchemaVersion;
    if (!await File(archivePath).exists()) {
      return RestorePreview(
        archivePath: archivePath,
        valid: false,
        reason: 'ملف النسخة غير موجود',
      );
    }
    final work = await Directory.systemTemp.createTemp('pharmacy_preview_');
    try {
      final extracted = await archiver.extractAndVerify(
        archivePath: archivePath,
        destinationDir: work.path,
      );
      final manifest = extracted.manifest;
      if (manifest.formatVersion != kBackupFormatVersion) {
        return RestorePreview(
          archivePath: archivePath,
          manifest: manifest,
          valid: false,
          reason: 'صيغة النسخة الاحتياطية غير مدعومة',
        );
      }
      if (manifest.schemaVersion < 1) {
        return RestorePreview(
          archivePath: archivePath,
          manifest: manifest,
          valid: false,
          reason: 'رقم مخطط قاعدة البيانات في النسخة غير صالح',
        );
      }
      if (manifest.schemaVersion > schemaNow) {
        return RestorePreview(
          archivePath: archivePath,
          manifest: manifest,
          valid: false,
          reason:
              'النسخة من إصدار أحدث من التطبيق ولا يمكن الاستعادة إليها',
        );
      }
      return RestorePreview(
        archivePath: archivePath,
        manifest: manifest,
        valid: true,
      );
    } on InvalidOperationException catch (e) {
      return RestorePreview(
        archivePath: archivePath,
        valid: false,
        reason: e.failure.message,
      );
    } catch (_) {
      return RestorePreview(
        archivePath: archivePath,
        valid: false,
        reason: 'النسخة تالفة أو غير صالحة',
      );
    } finally {
      if (await work.exists()) {
        try {
          await work.delete(recursive: true);
        } catch (_) {
          // Best-effort cleanup: never mask the preview verdict.
        }
      }
    }
  }

  /// Full validated restore. See class docs for the safety model.
  Future<RestoreResult> restore({
    required String archivePath,
    required AppDatabase liveDb,
    required String liveDatabasePath,
    required String receiptsDirectory,
    required String emergencyDirectory,
    int? currentSchemaVersion,
    String? userId,
    Future<void> Function()? onBeforeReplace,
  }) async {
    final schemaNow = currentSchemaVersion ?? kCurrentSupportedSchemaVersion;
    final staging = await Directory.systemTemp.createTemp('pharmacy_restore_');
    try {
      // 1. Structure + manifest + checksum validation.
      final extracted = await archiver.extractAndVerify(
        archivePath: archivePath,
        destinationDir: staging.path,
      );
      final manifest = extracted.manifest;

      // 2. Format + schema compatibility.
      if (manifest.formatVersion != kBackupFormatVersion) {
        throw InvalidOperationException('صيغة النسخة الاحتياطية غير مدعومة');
      }
      if (manifest.schemaVersion > schemaNow) {
        throw InvalidOperationException(
            'النسخة من إصدار أحدث ولا يمكن استعادتها (لا يوجد تخفيض للمخطط)');
      }
      if (manifest.schemaVersion < 1) {
        throw InvalidOperationException('رقم مخطط قاعدة البيانات غير صالح');
      }

      // 3. Stage + migrate + validate the database copy.
      final stagedDbPath = extracted.databaseStagedPath;
      await _validateStagedDatabase(
        stagedDbPath,
        expectedAfterMigration: schemaNow,
        receiptsDirectory: receiptsDirectory,
        stagedReceipts: extracted.stagedReceipts,
        projectName: liveDatabasePath,
      );

      // 4. Pre-restore audit on the live DB.
      try {
        await audit.write(
          liveDb,
          userId: userId ?? 'user_admin',
          action: AuditAction.restoreBackup,
          entityType: 'backup',
          entityId: p.basename(archivePath),
          after: {
            'source': p.basename(archivePath),
            'schema': schemaNow,
            'status': 'restore_start',
          },
          note: 'restore_start',
        );
      } catch (_) {
        // Audit must never block the safety flow.
      }

      // 5. Emergency backup of the current data (before any destruction).
      final emergencyFileName = 'pre_restore_${newId('safety')}.zip';
      final emergencyDir = Directory(emergencyDirectory);
      if (!await emergencyDir.exists()) {
        await emergencyDir.create(recursive: true);
      }
      final BackupArchiveResult emergency;
      try {
        emergency = await archiver.createBackup(
          db: liveDb,
          databasePath: liveDatabasePath,
          receiptsDirectory: receiptsDirectory,
          destinationDirectory: emergencyDir.path,
          fileName: emergencyFileName,
          userId: userId,
        );
      } catch (_) {
        // If even the emergency backup fails we must never proceed.
        throw InvalidOperationException(
            'تعذّر إنشاء نسخة أمان قبل الاستعادة؛ تم إيقاف العملية');
      }
      final emergencyBackupPath = emergency.archivePath;

      // 6. Close the live connection BEFORE any filesystem replacement. On
      //    Windows an open SQLite file cannot be safely deleted/replaced, and a
      //    stale WAL/SHM could otherwise override the restored data. If the
      //    connection cannot be closed, nothing has been replaced yet — abort
      //    loudly and preserve the emergency backup (no rollback needed).
      try {
        await onBeforeReplace?.call();
      } catch (e) {
        throw InvalidOperationException(
            'تعذّر إغلاق قاعدة البيانات الحالية بأمان؛ تم إيقاف الاستعادة '
            'قبل أي تغيير. احتفظ بنسخة الأمان: $emergencyBackupPath');
      }

      // 7. Replace files; if anything here fails we roll back to [emergency].
      try {
        // Replace the live database file (drop stale WAL artefacts).
        for (final suffix in const ['-wal', '-shm']) {
          final sidecar = File('$liveDatabasePath$suffix');
          if (await sidecar.exists()) {
            await sidecar.delete();
          }
        }
        final liveFile = File(liveDatabasePath);
        if (await liveFile.exists()) {
          await liveFile.delete();
        }
        await File(stagedDbPath).copy(liveDatabasePath);

        // Replace managed receipt files.
        await _replaceReceipts(
          receiptsDirectory,
          extracted.stagedReceipts,
          manifest.files,
        );

        // 8. Reopen + validate the activated database.
        final reopened = AppDatabase.fromFilePath(liveDatabasePath);
        await _assertHealthy(reopened);
        final schemaAfter =
            await _userVersion(reopened);
        try {
          await audit.write(
            reopened,
            userId: userId ?? 'user_admin',
            action: AuditAction.restoreBackup,
            entityType: 'backup',
            entityId: p.basename(archivePath),
            before: {
              'source': p.basename(archivePath),
              'schema': schemaAfter,
            },
            after: {
              'status': 'restore_completed',
              'receipts': extracted.stagedReceipts.length,
              'emergency': p.basename(emergencyBackupPath),
            },
            note: 'restore_completed',
          );
        } catch (_) {
          // Audit failure must not flip a healthy restore into a failure.
        } finally {
          await reopened.close();
        }

        return RestoreResult(
          archivePath: archivePath,
          manifest: manifest,
          emergencyBackupPath: emergencyBackupPath,
          schemaAfterRestore: schemaAfter,
          restoredReceiptCount: extracted.stagedReceipts.length,
          databaseIntegrityOk: true,
        );
      } catch (e) {
        // 9. Replacement/activation failed → roll back to the emergency backup
        //    and report failure loudly. The emergency archive stays preserved.
        final rolledBack =
            await _tryRollback(emergencyBackupPath, liveDatabasePath,
                receiptsDirectory);
        if (!rolledBack) {
          throw InvalidOperationException(
              'فشلت الاستعادة ولم تنجح العودة للنسخة السابقة تلقائياً؛ '
              'احتفظ بنسخة الأمان: $emergencyBackupPath');
        }
        throw InvalidOperationException(
            'فشلت الاستعادة وتمت العودة للبيانات السابقة: $e');
      }
    } finally {
      if (await staging.exists()) {
        try {
          await staging.delete(recursive: true);
        } catch (_) {
          // Best-effort cleanup: an undeliverable locked handle (Windows) must
          // not replace the primary restore outcome with a delete failure.
        }
      }
    }
  }

  /// Opens [dbPath] with the current schema, running the supported forward
  /// migration when the backup is older, then validates health and core
  /// tables, and reconciles `expenses.receipt_path` to [receiptsDirectory].
  Future<void> _validateStagedDatabase(
    String dbPath, {
    required int expectedAfterMigration,
    required String receiptsDirectory,
    required List<String> stagedReceipts,
    required String projectName,
  }) async {
    final db = AppDatabase.fromFilePath(dbPath);
    try {
      final integrity =
          await db.customSelect('PRAGMA integrity_check').getSingle();
      if (integrity.data.values.first != 'ok') {
        throw InvalidOperationException('قاعدة البيانات في النسخة تالفة');
      }
      final version = await _userVersion(db);
      if (version != expectedAfterMigration) {
        throw InvalidOperationException(
            'مخطط قاعدة البيانات بعد الترحيل غير متوقع '
            '($version بدلاً من $expectedAfterMigration)');
      }
      await _assertRequiredTables(db);
      await _reconcileReceiptPaths(
          db, receiptsDirectory, stagedReceipts, projectName);
    } finally {
      await db.close();
    }
  }

  Future<void> _assertRequiredTables(AppDatabase db) async {
    final rows = await db.customSelect(
      "SELECT name FROM sqlite_master WHERE type = 'table'",
    ).get();
    final present = rows.map((r) => r.data.values.first as String).toSet();
    final missing =
        kRequiredTablesAfterRestore.where((t) => !present.contains(t));
    if (missing.isNotEmpty) {
      throw InvalidOperationException(
          'قاعدة البيانات في النسخة ناقصة جداول أساسية: ${missing.join('، ')}');
    }
    // Spot-check that core tables are actually readable.
    await db.select(db.users).get();
    await db.select(db.items).get();
    await db.select(db.journalEntries).get();
  }

  /// Resolves expense receipt references to the restored managed files so the
  /// relationship survives application-data relocation (§4.20, Env A).
  Future<void> _reconcileReceiptPaths(
    AppDatabase db,
    String receiptsDirectory,
    List<String> stagedReceipts,
    String projectName,
  ) async {
    final bases = stagedReceipts.map((f) => p.basename(f)).toSet();
    final toUpdate = <String, String>{};
    final rows = await (db.select(db.expenses)).get();
    for (final expense in rows) {
      final ref = expense.receiptPath;
      if (ref == null || ref.isEmpty) continue;
      final base = p.basename(ref);
      if (bases.contains(base)) {
        toUpdate[expense.id] = p.join(receiptsDirectory, base);
      }
    }
    if (toUpdate.isEmpty) return;
    for (final entry in toUpdate.entries) {
      await (db.update(db.expenses)
            ..where((e) => e.id.equals(entry.key)))
          .write(ExpensesCompanion(receiptPath: Value(entry.value)));
    }
  }

  Future<void> _replaceReceipts(
    String receiptsDirectory,
    List<String> stagedReceipts,
    List<ManagedFileEntry> files,
  ) async {
    final target = Directory(receiptsDirectory);
    if (await target.exists()) {
      await target.delete(recursive: true);
    }
    await target.create(recursive: true);
    for (final stage in stagedReceipts) {
      final base = p.basename(stage);
      await File(stage).copy(p.join(target.path, base));
    }
  }

  /// Rolls the live data back from the emergency archive after a failed
  /// activation. Returns false when even the rollback did not succeed.
  Future<bool> _tryRollback(
    String emergencyBackupPath,
    String liveDatabasePath,
    String receiptsDirectory,
  ) async {
    try {
      final work = await Directory.systemTemp.createTemp('pharmacy_rollback_');
      try {
        final extracted = await archiver.extractAndVerify(
          archivePath: emergencyBackupPath,
          destinationDir: work.path,
        );
        for (final suffix in const ['-wal', '-shm']) {
          final sidecar = File('$liveDatabasePath$suffix');
          if (await sidecar.exists()) {
            await sidecar.delete();
          }
        }
        final liveFile = File(liveDatabasePath);
        if (await liveFile.exists()) {
          await liveFile.delete();
        }
        await File(extracted.databaseStagedPath).copy(liveDatabasePath);
        final target = Directory(receiptsDirectory);
        if (await target.exists()) {
          await target.delete(recursive: true);
        }
        await target.create(recursive: true);
        for (final stage in extracted.stagedReceipts) {
          await File(stage).copy(p.join(target.path, p.basename(stage)));
        }
        final reopened = AppDatabase.fromFilePath(liveDatabasePath);
        await _assertHealthy(reopened);
        await reopened.close();
        return true;
      } finally {
        if (await work.exists()) {
          try {
            await work.delete(recursive: true);
          } catch (_) {
            // Best-effort cleanup inside rollback; the boolean result stands.
          }
        }
      }
    } catch (_) {
      return false;
    }
  }

  Future<void> _assertHealthy(AppDatabase db) async {
    final integrity =
        await db.customSelect('PRAGMA integrity_check').getSingle();
    if (integrity.data.values.first != 'ok') {
      throw InvalidOperationException('قاعدة البيانات المستعادة فشلت فحص السلامة');
    }
    await _assertRequiredTables(db);
  }

  Future<int> _userVersion(AppDatabase db) async {
    final row =
        await db.customSelect('PRAGMA user_version').getSingle();
    return row.data.values.first as int;
  }
}