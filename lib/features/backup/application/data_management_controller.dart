import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/errors/exceptions.dart';
import '../../../core/errors/failures.dart';
import '../../../domain/services/app_paths.dart';
import '../../../domain/services/database_lifecycle.dart';
import '../../../shared/database/app_database.dart';
import '../domain/entities/backup_results.dart';
import '../domain/entities/data_export_result.dart';
import '../domain/usecases/backup_use_cases.dart';

enum DataManagementStatus { idle, working, success, error }

/// Data Management page state (§37 env C): backup / restore / export.
class DataManagementState {
  const DataManagementState({
    this.status = DataManagementStatus.idle,
    this.busy = false,
    this.error,
    this.lastBackup,
    this.lastRestore,
    this.lastExport,
    this.dbClosed = false,
  });

  final DataManagementStatus status;
  final bool busy;
  final Failure? error;
  final BackupArchiveResult? lastBackup;
  final RestoreResult? lastRestore;
  final DataExportResult? lastExport;

  /// True once the live database connection was closed by a restore attempt.
  /// When true, the application must be restarted (the data on disk is safe —
  /// restored, or rolled back to the emergency backup — but the in-memory
  /// connection is no longer usable).
  final bool dbClosed;

  DataManagementState copyWith({
    DataManagementStatus? status,
    bool? busy,
    Failure? Function()? error,
    BackupArchiveResult? Function()? lastBackup,
    RestoreResult? Function()? lastRestore,
    DataExportResult? Function()? lastExport,
    bool? applyDbClosed,
  }) {
    return DataManagementState(
      status: status ?? this.status,
      busy: busy ?? this.busy,
      error: error != null ? error() : this.error,
      lastBackup: lastBackup != null ? lastBackup() : this.lastBackup,
      lastRestore: lastRestore != null ? lastRestore() : this.lastRestore,
      lastExport: lastExport != null ? lastExport() : this.lastExport,
      dbClosed: applyDbClosed ?? dbClosed,
    );
  }
}

/// Data management controller (§37): runs the permission-gated use cases,
/// resolving app paths and surfacing typed failures to the UI.
class DataManagementController extends StateNotifier<DataManagementState> {
  DataManagementController(
    this._create,
    this._preview,
    this._restore,
    this._export,
    this._paths,
    this._db,
    this._lifecycle,
  ) : super(const DataManagementState());

  final CreateBackupUseCase _create;
  final PreviewRestoreUseCase _preview;
  final RestoreBackupUseCase _restore;
  final ExportDataUseCase _export;
  final AppPaths _paths;
  final AppDatabase _db;

  /// Owns the live database connection that a restore must close (and that a
  /// failed restore then requires a restart to recover from).
  final DatabaseLifecycle _lifecycle;

  Future<Failure?> createBackup({
    required String? actingRoleId,
    required String? actingUserId,
    String? destinationDirectory,
    String? fileName,
  }) async {
    state = state.copyWith(
        busy: true, status: DataManagementStatus.working, error: () => null);
    try {
      final result = await _create.call(
        _db,
        actingRoleId: actingRoleId,
        databasePath: await _paths.databasePath(),
        receiptsDirectory: await _paths.receiptsDirectory(),
        destinationDirectory:
            destinationDirectory ?? await _paths.defaultBackupsDirectory(),
        userId: actingUserId,
        fileName: fileName,
      );
      state = state.copyWith(
        busy: false,
        status: DataManagementStatus.success,
        lastBackup: () => result,
      );
      return null;
    } on AppException catch (e) {
      state = state.copyWith(
          busy: false, status: DataManagementStatus.error, error: () => e.failure);
      return e.failure;
    } on Exception catch (e) {
      state = state.copyWith(
          busy: false, status: DataManagementStatus.error);
      return DatabaseFailure('حدث خطأ غير متوقع أثناء إنشاء النسخة الاحتياطية',
          cause: e);
    }
  }

  Future<RestorePreview> preview({
    required String? actingRoleId,
    required String archivePath,
  }) {
    return _preview.call(
      _db,
      actingRoleId: actingRoleId,
      archivePath: archivePath,
    );
  }

  Future<Failure?> restore({
    required String? actingRoleId,
    required String? actingUserId,
    required String archivePath,
  }) async {
    state = state.copyWith(
        busy: true, status: DataManagementStatus.working, error: () => null);
    try {
      final result = await _restore.call(
        _db,
        actingRoleId: actingRoleId,
        archivePath: archivePath,
        liveDatabasePath: await _paths.databasePath(),
        receiptsDirectory: await _paths.receiptsDirectory(),
        emergencyDirectory: await _paths.emergencyDirectory(),
        userId: actingUserId,
        // The live SQLite connection must be closed BEFORE any file is
        // replaced, otherwise Windows cannot safely delete/replace the open
        // database (and a stale WAL/SHM could corrupt the restored data).
        // Throwing here (unclosable connection) aborts the restore before any
        // destruction; the emergency backup remains available.
        onBeforeReplace: () => _lifecycle.close(),
      );
      final dbClosed = _lifecycle.isClosed;
      state = state.copyWith(
        busy: false,
        status: DataManagementStatus.success,
        applyDbClosed: dbClosed,
        lastRestore: () => result,
      );
      return null;
    } on AppException catch (e) {
      state = state.copyWith(
        busy: false,
        status: DataManagementStatus.error,
        applyDbClosed: _lifecycle.isClosed,
        error: () => e.failure,
      );
      return e.failure;
    } on Exception catch (e) {
      state = state.copyWith(
        busy: false,
        status: DataManagementStatus.error,
        applyDbClosed: _lifecycle.isClosed,
      );
      return DatabaseFailure('حدث خطأ غير متوقع أثناء الاستعادة', cause: e);
    }
  }

  Future<Failure?> exportData({
    required String? actingRoleId,
    required String destinationDirectory,
  }) async {
    state = state.copyWith(
        busy: true, status: DataManagementStatus.working, error: () => null);
    try {
      final result = await _export.call(
        _db,
        actingRoleId: actingRoleId,
        destinationDirectory: destinationDirectory,
      );
      state = state.copyWith(
        busy: false,
        status: DataManagementStatus.success,
        lastExport: () => result,
      );
      return null;
    } on AppException catch (e) {
      state = state.copyWith(
          busy: false, status: DataManagementStatus.error, error: () => e.failure);
      return e.failure;
    } on Exception catch (e) {
      state = state.copyWith(
          busy: false, status: DataManagementStatus.error);
      return DatabaseFailure('حدث خطأ غير متوقع أثناء تصدير البيانات', cause: e);
    }
  }

  void clearMessage() =>
      state = state.copyWith(error: () => null);
}