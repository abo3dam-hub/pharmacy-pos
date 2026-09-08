import '../entities/app_settings_entity.dart';

/// Settings persistence boundary (Phase 12). The repository reads and writes
/// the `app_settings` key-value table only — it never touches business rows.
abstract interface class SettingsRepository {
  /// Loads the current application settings, applying documented defaults
  /// when keys are absent (first run).
  Future<AppSettings> getSettings();

  /// Persists the draft, preserving any unspecified keys.
  Future<AppSettings> saveSettings(AppSettingsDraft draft);
}