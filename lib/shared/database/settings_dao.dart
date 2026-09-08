import 'package:drift/drift.dart';

import 'app_database.dart';

/// Key-value access to `app_settings` (§4 appendix, Phase 12).
///
/// Read path: POS documents, the Z-Report and the settings feature read the
/// pharmacy display name and rates from here. Write path: the Phase 12
/// settings feature (`SettingsRepository`) persists Business Name, Tax and
/// Currency through `setString`/`setInt`; every write records `updatedBy` so
/// settings changes stay auditable.
class SettingsDao {
  const SettingsDao(this._db);

  final AppDatabase _db;

  /// Reads a single settings value, or `null` when the key is absent.
  Future<String?> getString(String key) async {
    final row = await (_db.select(_db.appSettings)
          ..where((s) => s.key.equals(key)))
        .getSingleOrNull();
    return row?.value;
  }

  /// Reads a setting as a whole-number integer, or `null` when absent.
  Future<int?> getInt(String key) async {
    final value = await getString(key);
    if (value == null) return null;
    return int.tryParse(value);
  }

  /// Writes a text setting. `insertOrReplace` keeps the key's single row.
  Future<void> setString(
    String key,
    String value, {
    String? updatedBy,
    int? atMillis,
  }) async {
    await _db.into(_db.appSettings).insert(
          AppSettingsCompanion(
            key: Value(key),
            value: Value(value),
            updatedAt: Value(atMillis ?? DateTime.now().millisecondsSinceEpoch),
            updatedBy: Value(updatedBy),
          ),
          // `app_settings` has `key` as primary key, so this upserts.
          mode: InsertMode.insertOrReplace,
        );
  }

  /// Writes a whole-number setting (stored as a decimal string).
  Future<void> setInt(
    String key,
    int value, {
    String? updatedBy,
    int? atMillis,
  }) =>
      setString(key, value.toString(),
          updatedBy: updatedBy, atMillis: atMillis);

  /// Upserts multiple settings in one transaction (single settings-save).
  Future<void> setAll(
    Map<String, String> values, {
    String? updatedBy,
    int? atMillis,
  }) async {
    final now = atMillis ?? DateTime.now().millisecondsSinceEpoch;
    await _db.transaction(() async {
      for (final entry in values.entries) {
        await _db.into(_db.appSettings).insert(
              AppSettingsCompanion(
                key: Value(entry.key),
                value: Value(entry.value),
                updatedAt: Value(now),
                updatedBy: Value(updatedBy),
              ),
              mode: InsertMode.insertOrReplace,
            );
      }
    });
  }

  /// Reads the full settings map (string values only). Used by settings tests
  /// to assert persistence without a second code path.
  Future<Map<String, String>> getAll() async {
    final rows = await _db.select(_db.appSettings).get();
    return {for (final row in rows) row.key: row.value};
  }
}