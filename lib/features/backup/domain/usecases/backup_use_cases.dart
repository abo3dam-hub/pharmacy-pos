import '../../../../core/constants/permission_codes.dart';
import '../../../../domain/services/backup_archive_service.dart';
import '../../../../domain/services/data_export_service.dart';
import '../../../../domain/services/permission_service.dart';
import '../../../../domain/services/restore_service.dart';
import '../../../../shared/database/app_database.dart';
import '../entities/backup_results.dart';
import '../entities/data_export_result.dart';

/// Creates a self-contained backup archive. Requires `backup`.
class CreateBackupUseCase {
  const CreateBackupUseCase(this._archiver, this._permissions);

  final BackupArchiveService _archiver;
  final PermissionService _permissions;

  Future<BackupArchiveResult> call(
    AppDatabase db, {
    required String? actingRoleId,
    required String databasePath,
    required String receiptsDirectory,
    required String destinationDirectory,
    String? userId,
    String? fileName,
  }) async {
    await _permissions.requireRolePermission(db, actingRoleId, Perm.backup);
    return _archiver.createBackup(
      db: db,
      databasePath: databasePath,
      receiptsDirectory: receiptsDirectory,
      destinationDirectory: destinationDirectory,
      userId: userId,
      fileName: fileName,
    );
  }
}

/// Read-only archive inspection before a destructive restore.
/// Requires `backup.restore`.
class PreviewRestoreUseCase {
  const PreviewRestoreUseCase(this._restore, this._permissions);

  final RestoreService _restore;
  final PermissionService _permissions;

  Future<RestorePreview> call(
    AppDatabase db, {
    required String? actingRoleId,
    required String archivePath,
  }) async {
    await _permissions.requireRolePermission(
        db, actingRoleId, Perm.backupRestore);
    return _restore.preview(archivePath);
  }
}

/// Fully validated + activated restore (§37 env C). Requires `backup.restore`.
///
/// After activation the caller must restart the app (a restart in the app's
/// own login session re-opens the replaced database file).
class RestoreBackupUseCase {
  const RestoreBackupUseCase(this._restore, this._permissions);

  final RestoreService _restore;
  final PermissionService _permissions;

  Future<RestoreResult> call(
    AppDatabase db, {
    required String? actingRoleId,
    required String archivePath,
    required String liveDatabasePath,
    required String receiptsDirectory,
    required String emergencyDirectory,
    required String? userId,
    Future<void> Function()? onBeforeReplace,
  }) async {
    await _permissions.requireRolePermission(
        db, actingRoleId, Perm.backupRestore);
    return _restore.restore(
      archivePath: archivePath,
      liveDb: db,
      liveDatabasePath: liveDatabasePath,
      receiptsDirectory: receiptsDirectory,
      emergencyDirectory: emergencyDirectory,
      userId: userId,
      onBeforeReplace: onBeforeReplace,
    );
  }
}

/// Read-only full-data export. Requires `export.data`.
class ExportDataUseCase {
  const ExportDataUseCase(this._export, this._permissions);

  final DataExportService _export;
  final PermissionService _permissions;

  Future<DataExportResult> call(
    AppDatabase db, {
    required String? actingRoleId,
    required String destinationDirectory,
  }) async {
    await _permissions.requireRolePermission(
        db, actingRoleId, Perm.exportData);
    return _export.exportAll(
      db: db,
      destinationDirectory: destinationDirectory,
    );
  }
}