import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/errors/exceptions.dart';
import '../../../core/errors/failures.dart';
import '../../../shared/database/app_database.dart';
import '../domain/entities/app_settings_entity.dart';
import '../domain/usecases/settings_use_cases.dart';

enum SettingsStatus { initial, loading, ready, error }

class SettingsViewState {
  const SettingsViewState({
    this.status = SettingsStatus.initial,
    this.settings,
    this.error,
    this.busy = false,
  });

  final SettingsStatus status;

  /// Loaded settings (null until the first successful load).
  final AppSettings? settings;

  final Failure? error;
  final bool busy;

  SettingsViewState copyWith({
    SettingsStatus? status,
    AppSettings? Function()? settings,
    Failure? Function()? error,
    bool? busy,
  }) {
    return SettingsViewState(
      status: status ?? this.status,
      settings: settings != null ? settings() : this.settings,
      error: error != null ? error() : this.error,
      busy: busy ?? this.busy,
    );
  }
}

/// Application-settings controller (Phase 12): loads the aggregate and runs
/// the permission-gated, audited save through the use case.
class SettingsController extends StateNotifier<SettingsViewState> {
  SettingsController(this._get, this._save, this._db)
      : super(const SettingsViewState());

  final GetAppSettingsUseCase _get;
  final SaveAppSettingsUseCase _save;
  final AppDatabase _db;

  Future<void> load({String? actingRoleId}) async {
    state = state.copyWith(status: SettingsStatus.loading, error: () => null);
    try {
      final settings = await _get.call(_db, actingRoleId);
      state = SettingsViewState(
        status: SettingsStatus.ready,
        settings: settings,
      );
    } on AppException catch (e) {
      state = state.copyWith(status: SettingsStatus.error, error: () => e.failure);
    }
  }

  /// Returns null on success (state reloaded), a [Failure] otherwise.
  Future<Failure?> save({
    required AppSettingsDraft draft,
    required String? actingUserId,
    required String? actingRoleId,
  }) async {
    state = state.copyWith(busy: true, error: () => null);
    try {
      final saved = await _save.call(
        _db,
        draft: draft,
        actingUserId: actingUserId,
        actingRoleId: actingRoleId,
      );
      state = state.copyWith(busy: false, settings: () => saved);
      return null;
    } on AppException catch (e) {
      state = state.copyWith(busy: false, error: () => e.failure);
      return e.failure;
    } on Exception {
      state = state.copyWith(busy: false);
      return const DatabaseFailure('حدث خطأ غير متوقع أثناء حفظ الإعدادات');
    }
  }

  void clearError() => state = state.copyWith(error: () => null);
}