/// Global application non-secret configuration (§31 app settings).
library;

/// Product/metadata constants shared across the app.
abstract final class AppConfig {
  /// App display name (Arabic-first).
  static const String appName = 'نظام الصيدلية';

  /// Default UI locale for the app shell.
  static const String defaultLocale = 'ar';

  /// Default Material font family (`Cairo` ships in the assets).
  static const String fontFamilyArabic = 'Cairo';

  /// Fallback font for Latin text.
  static const String fontFamilyFallback = 'Tajawal';

  /// Published app version (`pubspec.yaml` `1.0.0+1`).
  static const String appVersion = '1.0.0+1';

  /// Backup file prefix per §37 (`pharmacy_backup_YYYYMMDD_HHmmss.db`).
  static const String backupFilePrefix = 'pharmacy_backup';

  /// Development-only seed password for the `admin` account. Locked out of
  /// production builds; the real password is set at first-run setup (Phase 4).
  static const String devAdminPassword = 'Admin@123';
}