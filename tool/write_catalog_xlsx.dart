/// Writes the pharmacy catalog import xlsx using the same `excel` package the
/// app itself uses for export/import, so the file is guaranteed readable by
/// the app's importer (and by desktop Excel).
///
/// Usage: dart run tool/write_catalog_xlsx.dart <catalog.json> <out.xlsx>
import 'dart:convert';
import 'dart:io';

import 'package:excel/excel.dart';

Future<void> main(List<String> args) async {
  if (args.length != 2) {
    stderr.writeln('usage: write_catalog_xlsx.dart <catalog.json> <out.xlsx>');
    exit(2);
  }
  final data =
      jsonDecode(await File(args[0]).readAsString()) as Map<String, dynamic>;
  final headers = (data['headers'] as List).cast<String>();
  final rows = (data['rows'] as List).cast<List>();

  final excel = Excel.createExcel();
  final sheet = excel['products'];
  excel.delete('Sheet1');
  sheet.appendRow([for (final h in headers) TextCellValue(h)]);

  // Column 14 (0-based) is the parts count: integer like the app's export.
  const partsIndex = 14;
  for (final row in rows) {
    final cells = <CellValue>[];
    for (var i = 0; i < headers.length; i++) {
      final v = i < row.length ? row[i] : null;
      if (i == partsIndex) {
        cells.add(v is int ? IntCellValue(v) : TextCellValue(''));
      } else {
        cells.add(TextCellValue(v?.toString() ?? ''));
      }
    }
    sheet.appendRow(cells);
  }

  final bytes = excel.save(fileName: 'pharmacy_catalog_import.xlsx');
  if (bytes == null) {
    stderr.writeln('excel.save returned null');
    exit(1);
  }
  await File(args[1]).writeAsBytes(bytes);
  stdout.writeln('rows: ${rows.length} -> ${args[1]} (${bytes.length} bytes)');
}
