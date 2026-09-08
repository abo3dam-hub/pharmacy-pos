import '../../../../shared/database/app_database.dart';
import 'backup_manifest.dart';

/// Success payload of a completed self-contained backup (Phase 13).
class BackupArchiveResult {
  const BackupArchiveResult({
    required this.archivePath,
    required this.fileName,
    required this.archiveSizeBytes,
    required this.archiveSha256,
    required this.manifest,
    required this.ledger,
  });

  final String archivePath;
  final String fileName;
  final int archiveSizeBytes;
  final String archiveSha256;

  /// Integrity manifest embedded in the archive.
  final BackupManifest manifest;

  /// Ledger row recorded in the `backups` table.
  final BackupRow ledger;
}

/// Result of a fully validated + activated restore (Phase 13).
class RestoreResult {
  const RestoreResult({
    required this.archivePath,
    required this.manifest,
    required this.emergencyBackupPath,
    required this.schemaAfterRestore,
    required this.restoredReceiptCount,
    required this.databaseIntegrityOk,
  });

  final String archivePath;
  final BackupManifest manifest;

  /// Absolute path of the pre-restore emergency backup (preserved on disk).
  final String emergencyBackupPath;

  final int schemaAfterRestore;
  final int restoredReceiptCount;
  final bool databaseIntegrityOk;
}

/// Read-only preview of a backup archive before a destructive restore.
class RestorePreview {
  const RestorePreview({
    required this.archivePath,
    this.manifest,
    required this.valid,
    this.reason = '',
  });

  final String archivePath;
  final BackupManifest? manifest;
  final bool valid;
  final String? reason;
}

/// Reason codes for rejected backups (restore compatibility rules §10).
enum RestoreRejection {
  malformedArchive,
  malformedManifest,
  checksumMismatch,
  newerSchema,
  unsupportedFormat,
  invalidDatabase,
  missingFiles,
  other,
}