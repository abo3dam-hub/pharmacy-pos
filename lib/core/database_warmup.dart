import '../shared/database/app_database.dart';

/// Opens the database before the first frame is drawn.
///
/// drift opens the executor lazily, and the very first page query could
/// otherwise race app startup (database not open yet): the query throws, the
/// page shows an empty list, and it stays empty until the user manually
/// reloads (e.g. touching the search field). Warming up here fixes that race
/// once for every list page in the app — present and future — instead of
/// retrying per page.
///
/// A failing warm-up never blocks startup: pages keep their own
/// error/empty-state handling, exactly as before.
Future<void> warmUpDatabase(AppDatabase db) async {
  for (var attempt = 0; attempt < 3; attempt++) {
    try {
      // Forces the executor open: runs migrations + beforeOpen, then a
      // trivial query proving the database answers.
      await db.customSelect('SELECT 1').get();
      return;
    } catch (_) {
      if (attempt == 2) return;
      await Future<void>.delayed(const Duration(milliseconds: 500));
    }
  }
}
