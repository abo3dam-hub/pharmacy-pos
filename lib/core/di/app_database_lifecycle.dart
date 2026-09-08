import '../../domain/services/database_lifecycle.dart';
import '../../shared/database/app_database.dart';

/// Real [DatabaseLifecycle] over the getIt-registered application singleton.
///
/// `close()` closes the live singleton connection so the restore workflow can
/// safely replace the backing file. Because the wider app's DAOs and
/// controllers hold the singleton, a closed database means the operator must
/// restart the application (matching the documented "restore is a restart
/// operation" model). The emergency backup created before close guarantees the
/// previous data is intact across that restart.
class AppDatabaseLifecycle implements DatabaseLifecycle {
  AppDatabaseLifecycle(this._db);

  final AppDatabase _db;
  bool _closed = false;

  @override
  bool get isClosed => _closed;

  @override
  Future<void> close() async {
    if (_closed) return;
    await _db.close();
    _closed = true;
  }
}
