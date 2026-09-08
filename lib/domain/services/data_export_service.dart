import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;

import '../../core/config/app_config.dart';
import '../../features/backup/domain/entities/data_export_result.dart';
import '../../shared/database/app_database.dart';

/// Read-only full-data export (§37 env C.2).
///
/// Exports every application table to UTF-8 `.csv` files (with BOM so Excel
/// renders Arabic correctly) inside a timestamped folder, plus a machine
/// readable `export_manifest.json`. Rows are fetched from SQLite with
/// DB-side `LIMIT/OFFSET` paging; nothing is ever written to the database.
class DataExportService {
  const DataExportService();

  static const int _pageSize = 5000;

  /// Tables that must never be exported even if present (SQLite / drift
  /// internals or derived metadata).
  static const Set<String> _excluded = {
    'drift_versions',
    'sqlite_sequence',
    'sqlite_stat1',
  };

  Future<DataExportResult> exportAll({
    required AppDatabase db,
    required String destinationDirectory,
    String? note,
  }) async {
    final dir = Directory(destinationDirectory);
    if (!await dir.exists()) {
      await dir.create(recursive: true);
    }

    final tables = await _userTables(db);
    final exported = <ExportedTableFile>[];
    var totalRows = 0;

    for (final table in tables) {
      final path = p.join(dir.path, '$table.csv');
      final rowCount = await _dumpTable(db, table, path);
      exported.add(ExportedTableFile(
        tableName: table,
        path: path,
        rowCount: rowCount,
        sizeBytes: File(path).lengthSync(),
      ));
      totalRows += rowCount;
    }

    final generatedAt = DateTime.now().millisecondsSinceEpoch;
    final manifest = {
      'format': 'data_export_v1',
      'generated_at_millis': generatedAt,
      'application_version': AppConfig.appVersion,
      'schema_version': db.schemaVersion,
      'note': note,
      'tables': {
        for (final f in exported) f.tableName: f.rowCount,
      },
      'total_rows': totalRows,
    };
    await File(p.join(dir.path, 'export_manifest.json'))
        .writeAsString(const JsonEncoder.withIndent('  ').convert(manifest),
            flush: true);

    return DataExportResult(
      directory: dir.path,
      files: exported,
      tableCount: tables.length,
      totalRows: totalRows,
      generatedAtMillis: generatedAt,
      schemaVersion: db.schemaVersion,
      applicationVersion: AppConfig.appVersion,
    );
  }

  Future<List<String>> _userTables(AppDatabase db) async {
    final rows = await db.customSelect(
      "SELECT name FROM sqlite_master "
      "WHERE type = 'table' AND name NOT LIKE 'sqlite_%' "
      "AND name NOT LIKE 'drift_%' ORDER BY name",
    ).get();
    final tables = rows
        .map((r) => r.data.values.first as String)
        .where((n) => !_excluded.contains(n))
        .toList();
    return tables;
  }

  /// Writes one table to [path] as CSV using `LIMIT/OFFSET` paging. Returns
  /// the number of data rows written (page rows only; the header row is not
  /// counted).
  Future<int> _dumpTable(AppDatabase db, String table, String path) async {
    const header = '\uFEFF'; // UTF-8 BOM.
    final out = File(path).openWrite();
    out.write(header);

    // Column names come from the first page; subsequent pages reuse them so a
    // sparse table row never changes the shape.
    List<String>? columns;
    var offset = 0;
    var rowsCount = 0;

    try {
      while (true) {
        final pages = await db.customSelect(
          'SELECT * FROM "$table" ORDER BY rowid '
          'LIMIT $_pageSize OFFSET $offset',
        ).get();
        if (pages.isEmpty) break;
        if (columns == null) {
          columns = pages.first.data.keys.toList();
          _writeCsvRow(out, columns);
        }
        for (final row in pages) {
          _writeCsvRow(out, [
            for (final c in columns) _encodeValue(row.data[c]),
          ]);
          rowsCount++;
        }
        offset += pages.length;
        if (pages.length < _pageSize) break;
      }
      return rowsCount;
    } finally {
      await out.flush();
      await out.close();
    }
  }

  static String _encodeValue(Object? value) {
    if (value == null) return '';
    if (value is int || value is double) return value.toString();
    if (value is bool) return value ? '1' : '0';
    if (value is List<int>) {
      return value.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
    }
    return value.toString();
  }

  static void _writeCsvRow(IOSink sink, List<String> values) {
    final buffer = StringBuffer();
    for (var i = 0; i < values.length; i++) {
      if (i > 0) buffer.write(',');
      final v = values[i];
      final needsQuote =
          v.contains(',') || v.contains('"') || v.contains('\n') || v.contains('\r');
      if (needsQuote) {
        buffer
          ..write('"')
          ..write(v.replaceAll('"', '""'))
          ..write('"');
      } else {
        buffer.write(v);
      }
    }
    buffer.write('\r\n');
    sink.write(buffer.toString());
  }
}