import '../../../../core/config/app_config.dart';
import '../../../../core/constants/settings_keys.dart';
import '../../../../core/money/percent.dart';
import '../../../../shared/database/app_database.dart';
import '../../../../shared/database/settings_dao.dart';
import '../domain/entities/app_settings_entity.dart';
import '../domain/repositories/settings_repository.dart';

/// Drift-backed settings repository over the existing `app_settings` table
/// (§B Settings). Read-through with documented defaults; writes upsert the
/// stable keys so the POS documents pick up the business name immediately.
class SettingsRepositoryImpl implements SettingsRepository {
  const SettingsRepositoryImpl(this._dao, this._db);

  final SettingsDao _dao;
  final AppDatabase _db;

  @override
  Future<AppSettings> getSettings() async {
    final businessName = await _dao.getString(SettingsKeys.businessName) ??
        AppConfig.appName;
    final taxBp =
        (await _dao.getInt(SettingsKeys.taxRateBasisPoints)) ??
            SettingsKeys.defaultTaxRateBasisPoints;
    final currency = await _dao.getString(SettingsKeys.currencyCode) ??
        SettingsKeys.defaultCurrencyCode;
    final row = await _settingsRow();
    return AppSettings(
      businessName: businessName.trim(),
      taxRate: Percent(taxBp),
      currencyCode: currency,
      updatedAt: row?.updatedAt,
    );
  }

  @override
  Future<AppSettings> saveSettings(AppSettingsDraft draft) async {
    final now = DateTime.now().millisecondsSinceEpoch;
    await _dao.setAll(
      {
        SettingsKeys.businessName: draft.businessName.trim(),
        SettingsKeys.taxRateBasisPoints: '${draft.taxRateBasisPoints}',
        SettingsKeys.currencyCode: draft.currencyCode,
      },
      updatedBy: 'settings',
      atMillis: now,
    );
    return AppSettings(
      businessName: draft.businessName.trim(),
      taxRate: Percent(draft.taxRateBasisPoints),
      currencyCode: draft.currencyCode,
      updatedAt: now,
    );
  }

  Future<AppSettingRow?> _settingsRow() => (_db.select(_db.appSettings)
        ..where((s) => s.key.equals(SettingsKeys.businessName)))
      .getSingleOrNull();
}