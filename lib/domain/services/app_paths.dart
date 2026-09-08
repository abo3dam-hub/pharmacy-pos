import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

/// Resolves application-managed persistent paths (§37).
///
/// The live SQLite database lives at `<documents>/pharmacy_pos.sqlite` (the
/// same name Drift opens via `driftDatabase(name: 'pharmacy_pos')`), and
/// expense receipts are stored under `<documents>/expense_receipts/` by
/// `LocalReceiptStorage`. Backup/restore/export all derive their paths here so
/// there is a single source of truth for where data lives.
class AppPaths {
  const AppPaths({Future<String> Function()? documentsDir})
      : _documentsDir = documentsDir ?? _defaultDocumentsDir;

  static const String databaseFileName = 'pharmacy_pos.sqlite';
  static const String receiptsDirectoryName = 'expense_receipts';
  static const String emergencyDirectoryName = 'restore_emergency';
  static const String defaultBackupsDirectoryName = 'backups';

  final Future<String> Function() _documentsDir;

  static Future<String> _defaultDocumentsDir() async {
    final dir = await getApplicationDocumentsDirectory();
    return dir.path;
  }

  Future<String> documentsDir() => _documentsDir();

  Future<String> databasePath() async =>
      p.join(await _documentsDir(), databaseFileName);

  Future<String> receiptsDirectory() async =>
      p.join(await _documentsDir(), receiptsDirectoryName);

  /// Where emergency pre-restore backups are kept (never deleted by restore).
  Future<String> emergencyDirectory() async =>
      p.join(await _documentsDir(), emergencyDirectoryName);

  /// Default destination for user-facing backups when no folder is chosen.
  Future<String> defaultBackupsDirectory() async =>
      p.join(await _documentsDir(), defaultBackupsDirectoryName);
}