import 'dart:typed_data';

import 'package:excel/excel.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import '../../../../core/money/money.dart';
import '../../../../core/pdf/pdf_arabic.dart';
import '../../../../core/pdf/pdf_documents.dart';

/// Cell kind for [ReportCell]; drives both the PDF and the Excel rendering.
enum ReportCellType { text, money, integer, bool }

/// A single report cell. Money is stored as integer micro-units (never REAL),
/// consistent with the app-wide money scale.
class ReportCell {
  const ReportCell.text(String value)
      : type = ReportCellType.text,
        _text = value,
        _money = 0,
        _integer = 0,
        _bool = false;

  const ReportCell.money(int micros)
      : type = ReportCellType.money,
        _text = null,
        _money = micros,
        _integer = 0,
        _bool = false;

  const ReportCell.integer(int value)
      : type = ReportCellType.integer,
        _text = null,
        _money = 0,
        _integer = value,
        _bool = false;

  const ReportCell.bool(bool value)
      : type = ReportCellType.bool,
        _text = null,
        _money = 0,
        _integer = 0,
        _bool = value;

  final ReportCellType type;
  final String? _text;
  final int _money;
  final int _integer;
  final bool _bool;

  String toText() => switch (type) {
        ReportCellType.text => _text ?? '',
        ReportCellType.money => Money.fromUnits(_money).formatArabicDigits(),
        ReportCellType.integer => _integer.toString(),
        ReportCellType.bool => _bool ? 'نعم' : 'لا',
      };
}

/// A labelled total line rendered under the report table (PDF + Excel).
class ReportTotalRow {
  const ReportTotalRow(this.label, this.cell);

  final String label;
  final ReportCell cell;
}

/// Everything a generic report needs to render PDF and Excel: a title, an
/// optional subtitle (date range / entity), a fixed column list, rows and
/// total lines. Building bytes is pure (no file I/O) so it is fully testable.
class ReportExportRequest {
  const ReportExportRequest({
    required this.title,
    required this.generatedAtMillis,
    this.subtitle,
    this.sheetName = 'report',
    this.columns = const [],
    this.rows = const [],
    this.totals = const [],
    this.pharmacyName,
  });

  final String title;
  final String? subtitle;

  /// Sheet name for Excel (kept ASCII-safe for file names).
  final String sheetName;
  final int generatedAtMillis;
  final List<String> columns;
  final List<List<ReportCell>> rows;
  final List<ReportTotalRow> totals;
  final String? pharmacyName;
}

/// Generic PDF + Excel export for Phase 11 reports.
///
/// Reuses the existing [PdfDocuments]/[PdfArabic] primitives for Arabic-shaped
/// A4 documents and the `excel` package exporters (matching the inventory
/// export). PDF and Excel rendering stays read-only: no repository, no DB.
class ReportExportService {
  const ReportExportService({this.documents});

  final PdfDocuments? documents;

  // ── PDF ──────────────────────────────────────────────────────────────────

  Future<Uint8List> buildPdf(ReportExportRequest request) async {
    final docs = documents ?? PdfDocuments();
    final font = await docs.font();
    final doc = docs.document();

    final headerColumns = <pw.Widget>[
      if (request.pharmacyName != null)
        docs.heading(font, request.pharmacyName!, size: 15),
      docs.heading(font, request.title, size: 13),
      if (request.subtitle != null)
        docs.heading(font, request.subtitle!, size: 9),
      pw.SizedBox(height: 6),
      docs.fieldRow(
        font,
        'وقت التوليد',
        PdfDocuments.timestamp(request.generatedAtMillis),
      ),
      pw.SizedBox(height: 6),
      pw.Divider(color: const PdfColor.fromInt(0xFFB0BEC5)),
      pw.SizedBox(height: 8),
    ];

    final body = pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.stretch,
      children: [
        if (request.columns.isNotEmpty && request.rows.isNotEmpty)
          pw.TableHelper.fromTextArray(
            headers: [
              for (final c in request.columns) PdfArabic.shape(c),
            ],
            data: [
              for (final row in request.rows)
                [for (final cell in row) PdfArabic.shape(cell.toText())],
            ],
            cellStyle: docs.style(font, size: 8),
            headerStyle:
                docs.style(font, size: 8, weight: pw.FontWeight.bold),
            headerDecoration: const pw.BoxDecoration(
                color: PdfColor.fromInt(0xFFE3E8F0)),
            headerAlignments: const {0: pw.Alignment.centerRight},
            border: pw.TableBorder.all(color: const PdfColor.fromInt(0xFFB0BEC5)),
          ),
        if (request.rows.isEmpty) docs.text(font, 'لا توجد بيانات', size: 9),
        pw.SizedBox(height: 10),
        for (final total in request.totals)
          docs.fieldRow(font, total.label, total.cell.toText()),
        if (request.totals.isNotEmpty) ...[
          pw.SizedBox(height: 4),
          pw.Divider(color: const PdfColor.fromInt(0xFFB0BEC5)),
        ],
      ],
    );

    doc.addPage(docs.pageA4(
      font: font,
      header: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.stretch,
        children: headerColumns,
      ),
      body: body,
    ));
    return doc.save();
  }

  // ── Excel ────────────────────────────────────────────────────────────────

  /// Builds `.xlsx` bytes for [request]. Money cells are written as text in
  /// the app's monetary format (consistent with the inventory export) so the
  /// Arabic currency layout stays identical across cells.
  List<int> buildExcel(ReportExportRequest request) {
    final excel = Excel.createExcel();
    final sheet = excel[request.sheetName];
    sheet.appendRow([TextCellValue(request.title)]);
    if (request.subtitle != null) {
      sheet.appendRow([TextCellValue(request.subtitle!)]);
    }

    final headers = request.columns;
    if (headers.isNotEmpty) {
      sheet.appendRow([for (final h in headers) TextCellValue(h)]);
    }
    for (final row in request.rows) {
      sheet.appendRow([
        for (final cell in row)
          switch (cell.type) {
            ReportCellType.text => TextCellValue(cell.toText()),
            ReportCellType.money => TextCellValue(cell.toText()),
            ReportCellType.integer => IntCellValue(cell._integer),
            ReportCellType.bool => BoolCellValue(cell._bool),
          },
      ]);
    }
    if (request.totals.isNotEmpty) {
      sheet.appendRow([]);
      for (final total in request.totals) {
        sheet.appendRow([
          TextCellValue(total.label),
          TextCellValue(total.cell.toText()),
        ]);
      }
    }
    return excel.save(fileName: '${request.sheetName}.xlsx')!;
  }
}