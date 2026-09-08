/// Result of a read-only full-data export (Phase 13).
class DataExportResult {
  const DataExportResult({
    required this.directory,
    required this.files,
    required this.tableCount,
    required this.totalRows,
    required this.generatedAtMillis,
    required this.schemaVersion,
    required this.applicationVersion,
  });

  /// Absolute path of the export folder.
  final String directory;

  final List<ExportedTableFile> files;

  final int tableCount;
  final int totalRows;
  final int generatedAtMillis;
  final int schemaVersion;
  final String applicationVersion;

  int get totalBytes =>
      files.fold(0, (sum, f) => sum + f.sizeBytes);
}

/// One exported `.csv` file (an application table snapshot).
class ExportedTableFile {
  const ExportedTableFile({
    required this.tableName,
    required this.path,
    required this.rowCount,
    required this.sizeBytes,
  });

  final String tableName;
  final String path;
  final int rowCount;
  final int sizeBytes;
}