import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:drift/drift.dart';

import '../../core/config/app_config.dart';
import '../../shared/database/app_database.dart';
import '../../shared/models/enums.dart';
import 'audit_service.dart';

/// The SHA-256 body (hex) of a backed-up database file — used to verify
/// restore integrity (§37).
Future<String> sha256OfFile(String path) async {
  final file = File(path);
  final digest = await sha256.bind(file.openRead()).first;
  return digest.toString();
}

class RestoreVerification {
  const RestoreVerification({
    required this.ok,
    required this.filePath,
    required this.schemaVersion,
    required this.backupCount,
    required this.latestChecksumMatches,
  });

  final bool ok;
  final String filePath;
  final int schemaVersion;
  final int backupCount;

  /// `true` when the stored backup checksum matches the restored file bytes.
  final bool latestChecksumMatches;
}

/// Backups ledger (§37) + restore round-trip helpers.
///
/// The phase-1 scope is the *metadata record*: every successful file backup
/// registers one `BackupRow(completed)` and an audit entry (`backup`); a
/// restore re-opens the file copy and verifies integrity + checksum, keeping
/// `backup`/`restore_backup` in the audit trail (§17).
class BackupService {
  const BackupService({AuditService? audit})
      : _audit = audit ?? const AuditService();

  final AuditService _audit;

  /// Records a completed backup of [filePath] into the ledger and audits it.
  Future<BackupRow> recordCompleted(
    AppDatabase db, {
    required String filePath,
    required int sizeBytes,
    String? fileName,
    String? note,
    String? userId,
  }) async {
    final name = fileName ?? _defaultName(DateTime.now());
    final file = File(filePath);
    if (!await file.exists()) {
      throw FileSystemException('Backup file not found', filePath);
    }

    final row = await db.transaction(() async {
      final now = DateTime.now().millisecondsSinceEpoch;
      final idBytes = sha256.convert(utf8.encode('$filePath@$now')).toString();
      final id = 'backup_${idBytes.substring(0, 16)}';
      final checksum = await sha256OfFile(filePath);
      await db.into(db.backups).insert(BackupsCompanion.insert(
            id: id,
            filePath: filePath,
            fileName: name,
            createdAt: now,
            appVersion: const Value(AppConfig.appVersion),
            schemaVersion: db.schemaVersion,
            sizeBytes: sizeBytes,
            checksumSha256: Value(checksum),
            status: BackupStatus.completed,
            note: note != null ? Value(note) : const Value(null),
          ));
      final saved = await (db.select(db.backups)
            ..where((b) => b.id.equals(id)))
          .getSingle();
      await _audit.write(
        db,
        userId: userId ?? 'user_admin',
        action: AuditAction.backup,
        entityType: 'backup',
        entityId: id,
        after: {'file_name': name, 'size_bytes': sizeBytes},
        note: 'Backup recorded',
      );
      return saved;
    });
    return row;
  }

  /// Backup ledger, newest first.
  Future<List<BackupRow>> history(AppDatabase db, {int? limit}) {
    final q = db.select(db.backups)
      ..orderBy([(b) => OrderingTerm.desc(b.createdAt)]);
    if (limit != null) q.limit(limit);
    return q.get();
  }

  Future<BackupRow?> latest(AppDatabase db) async {
    final list = await history(db, limit: 1);
    return list.isEmpty ? null : list.first;
  }

  /// Re-opens the backup file copy, runs `PRAGMA integrity_check`, resolves the
  /// restored DB schema version and verifies the latest checksum record.
  Future<RestoreVerification> verifyRestore(
    String filePath, {
    String? expectedChecksum,
  }) async {
    final database = AppDatabase.fromFilePath(filePath);
    try {
      await database.customStatement('PRAGMA foreign_keys = ON');
      dynamic integrity = await database.customSelect(
        'PRAGMA integrity_check',
      ).getSingle();
      final integrityOk = integrity.data.values.first == 'ok';
      final schemaVersion = await _userVersion(database);
      final rows = await database.select(database.backups).get().onError(
          (Object _, StackTrace _) => <BackupRow>[]);
      final latest = rows.isEmpty ? null : rows.first;
      var checksumMatch = false;
      if (expectedChecksum != null) {
        checksumMatch = await sha256OfFile(filePath) == expectedChecksum;
      } else if (latest != null && latest.checksumSha256 != null) {
        checksumMatch = await sha256OfFile(filePath) == latest.checksumSha256;
      }
      return RestoreVerification(
        ok: integrityOk,
        filePath: filePath,
        schemaVersion: schemaVersion,
        backupCount: rows.length,
        latestChecksumMatches: checksumMatch,
      );
    } finally {
      await database.close();
    }
  }

  Future<int> _userVersion(AppDatabase db) async {
    final row = await db.customSelect('PRAGMA user_version').getSingle();
    return row.data.values.first as int;
  }

  String _defaultName(DateTime at) {
    String two(int v) => v.toString().padLeft(2, '0');
    final stamp = '${at.year}${two(at.month)}${two(at.day)}'
        '_${two(at.hour)}${two(at.minute)}${two(at.second)}';
    return '${AppConfig.backupFilePrefix}_$stamp.db';
  }
}