import 'app_database.dart';

/// Read-only key-value access to `app_settings` (§31). PDF documents and the
/// Z-Report read the pharmacy display name from here with a product-name
/// fallback; a settings UI is out of scope for this gap.
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
}