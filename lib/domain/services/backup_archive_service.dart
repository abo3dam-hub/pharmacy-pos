import 'dart:io';

import 'package:archive/archive_io.dart';
import 'package:path/path.dart' as p;

import '../../core/config/app_config.dart';
import '../../core/errors/exceptions.dart';
import '../../shared/database/app_database.dart';
import '../../features/backup/domain/entities/backup_manifest.dart';
import '../../features/backup/domain/entities/backup_results.dart';
import 'backup_service.dart';

/// A successfully extracted + checksum-verified backup archive.
class ExtractedBackup {
  const ExtractedBackup({
    required this.manifest,
    required this.databaseStagedPath,
    required this.stagedReceipts,
  });

  final BackupManifest manifest;

  /// Absolute path to the extracted `database.sqlite` inside the staging dir.
  final String databaseStagedPath;

  /// Absolute paths of every extracted `files/expense_receipts/*`.
  final List<String> stagedReceipts;
}

/// Builds the self-contained, manifest-carrying backup archive (§37, Env A/B).
///
/// The archive layout is:
/// ```
/// manifest.json
/// database.sqlite          <- consistent snapshot (VACUUM INTO)
/// files/expense_receipts/  <- every app-managed receipt file
/// ```
/// SQLite is snapshotted with `VACUUM INTO` (SQLite ≥ 3.27) so a consistent
/// copy is made even while the live connection is open and in WAL mode. The
/// DB entry is stored uncompressed (STORE) to avoid pointless CPU; receipt
/// files are deflated. The finished archive is read back and every checksum is
/// verified against the manifest before the backup is declared successful.
class BackupArchiveService {
  const BackupArchiveService({this.ledger = const BackupService()});

  final BackupService ledger;

  /// Creates a self-contained backup archive and returns its metadata. The
  /// archive is validated before success: recoverable errors never leave a
  /// half-written file behind (the failed archive is deleted).
  Future<BackupArchiveResult> createBackup({
    required AppDatabase db,
    required String databasePath,
    required String receiptsDirectory,
    required String destinationDirectory,
    String? userId,
    String? fileName,
  }) async {
    final destination = Directory(destinationDirectory);
    if (!await destination.exists()) {
      await destination.create(recursive: true);
    }

    final workDir = await Directory.systemTemp.createTemp('pharmacy_backup_');
    final archivePath =
        p.join(destination.path, fileName ?? _defaultArchiveName());
    try {
      // 1. Consistent SQLite snapshot.
      final snapshotPath = p.join(workDir.path, 'database.sqlite');
      await _snapshotViaVacuumInto(db, snapshotPath);

      // 2. Discover app-managed receipt files.
      final receiptFiles = await _listReceiptFiles(receiptsDirectory);

      // 3. Manifest (db + managed files with sizes + SHA-256).
      final dbChecksum = await sha256OfFile(snapshotPath);
      final dbSize = File(snapshotPath).lengthSync();
      final managedEntries = <ManagedFileEntry>[];
      for (final receipt in receiptFiles) {
        managedEntries.add(ManagedFileEntry(
          relativePath:
              BackupArchiveLayout.receiptEntryPath(receipt.relativePath),
          sizeBytes: receipt.fileSize,
          sha256: await sha256OfFile(receipt.filePath),
        ));
      }
      final manifest = BackupManifest(
        formatVersion: kBackupFormatVersion,
        applicationVersion: AppConfig.appVersion,
        schemaVersion: db.schemaVersion,
        createdAtMillis: DateTime.now().millisecondsSinceEpoch,
        databaseFileName: BackupArchiveLayout.databaseFileName,
        databaseSizeBytes: dbSize,
        databaseSha256: dbChecksum,
        files: managedEntries,
      );
      await File(p.join(workDir.path, BackupArchiveLayout.manifestFileName))
          .writeAsString(manifest.toJsonString(), flush: true);

      // 4. Create the archive (streaming — no full in-memory copy of the DB).
      final encoder = ZipFileEncoder()..create(archivePath);
      await encoder.addFile(
        File(p.join(workDir.path, BackupArchiveLayout.manifestFileName)),
        BackupArchiveLayout.manifestFileName,
        ZipFileEncoder.GZIP,
      );
      await encoder.addFile(
        File(snapshotPath),
        manifest.databaseFileName,
        ZipFileEncoder.STORE,
      );
      for (final receipt in receiptFiles) {
        await encoder.addFile(
          File(receipt.filePath),
          BackupArchiveLayout.receiptEntryPath(receipt.relativePath),
          ZipFileEncoder.GZIP,
        );
      }
      await encoder.close();

      // 5. Validate the generated archive (read back + checksums + integrity).
      final verification =
          await extractAndVerify(archivePath: archivePath, destinationDir: workDir.path);
      final reopened = AppDatabase.fromFilePath(verification.databaseStagedPath);
      try {
        final integrity =
            await reopened.customSelect('PRAGMA integrity_check').getSingle();
        if (integrity.data.values.first != 'ok') {
          throw InvalidOperationException(
              'النسخة الاحتياطية فشلت اختبار السلامة بعد الإنشاء');
        }
      } finally {
        await reopened.close();
      }

      // 6. Record the ledger + audit entry (existing BackupService semantics).
      final archiveSize = File(archivePath).lengthSync();
      final archiveChecksum = await sha256OfFile(archivePath);
      final name = fileName ?? p.basename(archivePath);
      final row = await ledger.recordCompleted(db,
          filePath: archivePath,
          sizeBytes: archiveSize,
          fileName: name,
          note: 'self-contained backup',
          userId: userId);

      return BackupArchiveResult(
        archivePath: archivePath,
        fileName: name,
        archiveSizeBytes: archiveSize,
        archiveSha256: archiveChecksum,
        manifest: manifest,
        ledger: row,
      );
    } catch (_) {
      // Never leave a partially-written backup behind as a "success".
      if (await File(archivePath).exists()) {
        await File(archivePath).delete();
      }
      rethrow;
    } finally {
      if (await workDir.exists()) {
        try {
          await workDir.delete(recursive: true);
        } catch (_) {
          // Best-effort cleanup: a locked handle (Windows) must never mask the
          // backup result or the already-reported success.
        }
      }
    }
  }

  /// Extracts [archivePath] into [destinationDir] with path-traversal
  /// protection and verifies every embedded file's SHA-256 against its
  /// manifest entry. Throws [InvalidOperationException] with a precise reason
  /// for every recoverable corruption.
  Future<ExtractedBackup> extractAndVerify({
    required String archivePath,
    required String destinationDir,
  }) async {
    if (!await File(archivePath).exists()) {
      throw InvalidOperationException('ملف النسخة غير موجود');
    }
    final outDir = Directory(destinationDir);
    if (!await outDir.exists()) {
      await outDir.create(recursive: true);
    }

    final input = InputFileStream(archivePath);
    Archive? decoded;
    try {
      decoded = ZipDecoder().decodeBuffer(input);
      // Map archive-internal name -> staged absolute path. Archive entries and
      // manifest `relativePath` values are always forward-slash separated; the
      // on-disk (platform-separator) path is computed separately so lookups do
      // not depend on the host operating system.
      final staged = <String, String>{};

      for (final entry in decoded.files) {
        if (!entry.isFile) continue;
        final safeName = _sanitizeEntryPath(entry.name);
        final target = _safeJoin(outDir.path, safeName);
        await _extractEntry(entry, target);
        staged[entry.name] = target;
      }

      // manifest.json must exist and parse.
      final manifestFile =
          staged[BackupArchiveLayout.manifestFileName];
      if (manifestFile == null) {
        throw InvalidOperationException('النسخة لا تحتوي على manifest.json');
      }
      final manifest =
          BackupManifest.tryParse(await File(manifestFile).readAsString());
      if (manifest == null) {
        throw InvalidOperationException('manifest.json غير صالح أو تالف');
      }

      final dbExpected =
          staged[BackupArchiveLayout.databaseFileName];
      if (dbExpected == null) {
        throw InvalidOperationException('النسخة لا تحتوي على قاعدة البيانات');
      }

      // Verify database checksum + size.
      final dbStaged = File(dbExpected);
      if (dbStaged.lengthSync() != manifest.databaseSizeBytes) {
        throw InvalidOperationException('حجم قاعدة البيانات لا يطابق المعرّف');
      }
      if (await sha256OfFile(dbExpected) != manifest.databaseSha256) {
        throw InvalidOperationException('خوارزمية التحقق SHA-256 لقاعدة البيانات لا تطابق');
      }

      // Verify every managed file against the manifest; reject unknown extra
      // files (unexpected archive content).
      final stagedReceipts = <String>[];
      final seen = <String>{};
      for (final file in manifest.files) {
        final stagedPath = staged[file.relativePath];
        if (stagedPath == null) {
          throw InvalidOperationException('ملف مدرج في المعرّف مفقود من النسخة');
        }
        final f = File(stagedPath);
        if (f.lengthSync() != file.sizeBytes) {
          throw InvalidOperationException('حجم الملف لا يطابق المعرّف: ${file.relativePath}');
        }
        if (await sha256OfFile(stagedPath) != file.sha256) {
          throw InvalidOperationException('خوارزمية التحقق للملف لا تطابق: ${file.relativePath}');
        }
        seen.add(file.relativePath);
        if (file.relativePath.startsWith(
            '${BackupArchiveLayout.filesRoot}/')) {
          stagedReceipts.add(stagedPath);
        }
      }
      // Reject entries not present in the manifest (apart from manifest.json
      // and database.sqlite which are structurally required).
      final required = {
        BackupArchiveLayout.manifestFileName,
        BackupArchiveLayout.databaseFileName,
      };
      for (final name in staged.keys) {
        if (!required.contains(name) && !seen.contains(name)) {
          throw InvalidOperationException('محتوى غير متوقع داخل النسخة: $name');
        }
      }

      return ExtractedBackup(
        manifest: manifest,
        databaseStagedPath: dbExpected,
        stagedReceipts: stagedReceipts,
      );
    } on InvalidOperationException {
      rethrow;
    } catch (_) {
      // Any structural failure (bad zip, broken deflate stream, unreadable
      // entry) means the archive cannot be trusted as a restore source.
      throw InvalidOperationException('النسخة تالفة أو غير صالحة للاستعادة');
    } finally {
      await decoded?.clear();
      await input.close();
    }
  }

  Future<void> _extractEntry(ArchiveFile entry, String target) async {
    final file = File(target);
    await file.create(recursive: true);
    final output = OutputFileStream(target);
    try {
      entry.writeContent(output);
    } finally {
      // Windows keeps the target locked until the handle is closed, even after
      // the underlying copy errored; always close so the staging dir can be
      // cleaned up (and a corrupt entry reports its real error, not a delete
      // failure).
      await output.close();
    }
  }

  Future<void> _snapshotViaVacuumInto(AppDatabase db, String target) async {
    final escaped = target.replaceAll("'", "''");
    await db.customStatement("VACUUM INTO '$escaped'");
  }

  Future<List<_ReceiptOnDisk>> _listReceiptFiles(
      String receiptsDirectory) async {
    final dir = Directory(receiptsDirectory);
    if (!await dir.exists()) return const [];
    final results = <_ReceiptOnDisk>[];
    await for (final entity
        in dir.list(recursive: true, followLinks: false)) {
      if (entity is File) {
        final relative = p.relative(entity.path, from: dir.path);
        results.add(_ReceiptOnDisk(
          filePath: entity.path,
          relativePath: relative,
          fileSize: entity.lengthSync(),
        ));
      }
    }
    return results;
  }

  String _defaultArchiveName() {
    String two(int v) => v.toString().padLeft(2, '0');
    final at = DateTime.now();
    final stamp = '${at.year}${two(at.month)}${two(at.day)}'
        '_${two(at.hour)}${two(at.minute)}${two(at.second)}';
    return '${AppConfig.backupFilePrefix}_$stamp.zip';
  }

  /// Rejects absolute paths, drive-letter paths, and `..` traversal segments.
  String _sanitizeEntryPath(String name) {
    final normalized = name.replaceAll('\\', '/');
    if (normalized.startsWith('/')) {
      throw InvalidOperationException('مسار مطلق داخل النسخة غير مسموح: $name');
    }
    if (normalized.contains(':')) {
      throw InvalidOperationException('مسار بقرص داخل النسخة غير مسموح: $name');
    }
    for (final part in normalized.split('/')) {
      if (part == '..') {
        throw InvalidOperationException('مسار اجتياز غير مسموح داخل النسخة: $name');
      }
    }
    return p.normalize(normalized);
  }

  String _safeJoin(String root, String safeName) {
    final joined = p.join(root, safeName);
    final canonicalRoot = p.canonicalize(root);
    final canonicalTarget = p.canonicalize(joined);
    if (!p.isWithin(canonicalRoot, canonicalTarget)) {
      throw InvalidOperationException('مسار خارج مجلد الاستخراج مرفوض: $safeName');
    }
    return joined;
  }
}

class _ReceiptOnDisk {
  const _ReceiptOnDisk({
    required this.filePath,
    required this.relativePath,
    required this.fileSize,
  });

  final String filePath;
  final String relativePath;
  final int fileSize;
}