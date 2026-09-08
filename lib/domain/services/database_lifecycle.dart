/// Owns the lifetime of the application's single live SQLite connection.
///
/// A restore is destructive at the filesystem level: the running app holds an
/// open SQLite connection (in WAL mode) to the very file being replaced. On
/// Windows an open SQLite file cannot be safely deleted or replaced, and a
/// stale WAL/SHM could otherwise overwrite the restored data. The restore
/// workflow therefore needs an explicit, reliable way to close that single live
/// connection before it replaces any file.
///
/// This abstraction decouples the restore workflow (domain) from where the live
/// connection actually lives (currently the getIt singleton `AppDatabase`), so
/// the responsibility is owned by the workflow and never silently skipped.
abstract interface class DatabaseLifecycle {
  /// True once [close] has fully completed and the connection is no longer
  /// usable. False before close and if close has never run.
  bool get isClosed;

  /// Closes the live database connection, settling any in-flight state.
  ///
  /// Implementations MUST throw if the connection cannot be closed safely, so
  /// callers abort destructive work rather than replace an open file.
  Future<void> close();
}
