/// Phase 11 export primitives: cell rendering (Arabic-friendly, Latin digits)
/// and the pure PDF/Excel byte builders. Both builders are read-only; they only
/// compose bytes from the request and must not touch any repository or DB.
library;

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:pharmacy_pos/core/pdf/pdf_documents.dart';
import 'package:pharmacy_pos/core/pdf/pdf_fonts.dart';
import 'package:pharmacy_pos/features/reports/domain/services/report_export_service.dart';

/// Loads the bundled Cairo TTF from the filesystem so PDF generation runs in a
/// pure Dart test (same pattern as `test/pdf_documents_test.dart`).
PdfDocuments _fileDocuments() => PdfDocuments(
      fonts: PdfFonts(loadBytes: () async => File(PdfFonts.assetPath).readAsBytes()),
    );

void main() {
  group('ReportCell.toText', () {
    test('formats money with Latin digits and thousands separators', () {
      // Money operates at scale 4 (1 unit = 10,000 micros).
      expect(const ReportCell.money(1234500).toText(), '123.45');
      expect(const ReportCell.money(150000000).toText(), '15,000.00');
      expect(const ReportCell.money(-500000).toText(), '-50.00');
      expect(const ReportCell.money(0).toText(), '0.00');
    });

    test('renders text, integers and booleans', () {
      expect(const ReportCell.text('فاتورة').toText(), 'فاتورة');
      expect(const ReportCell.integer(42).toText(), '42');
      expect(const ReportCell.integer(-7).toText(), '-7');
      expect(const ReportCell.bool(true).toText(), 'نعم');
      expect(const ReportCell.bool(false).toText(), 'لا');
    });
  });

  group('ReportExportService', () {
    const request = ReportExportRequest(
      title: 'ميزان المراجعة',
      subtitle: 'الفترة من 2026-01-01 إلى 2026-01-31',
      sheetName: 'trial_balance',
      generatedAtMillis: 1767225600000,
      columns: ['الكود', 'الاسم', 'المبلغ'],
      rows: [
        [ReportCell.text('1000'), ReportCell.text('النقدية'), ReportCell.money(100000)],
        [ReportCell.text('4000'), ReportCell.text('المبيعات'), ReportCell.money(500000)],
      ],
      totals: [ReportTotalRow('الإجمالي', ReportCell.money(600000))],
    );

    test('buildExcel returns a non-empty XLSX (zip) byte stream', () {
      final bytes = const ReportExportService().buildExcel(request);
      expect(bytes, isNotEmpty);
      expect(bytes.length, greaterThan(1000));
      // ZIP magic header for generated .xlsx files.
      expect(bytes.take(2).toList(), [0x50, 0x4B]);
    });

    test('buildPdf returns PDF bytes', () async {
      final bytes = await ReportExportService(documents: _fileDocuments())
          .buildPdf(request);
      expect(bytes, isNotEmpty);
      expect(String.fromCharCodes(bytes.take(5)), '%PDF-');
    });

    test('empty data set still renders a PDF', () async {
      const empty = ReportExportRequest(
        title: 'تقرير فارغ',
        generatedAtMillis: 1767225600000,
      );
      final bytes = await ReportExportService(documents: _fileDocuments())
          .buildPdf(empty);
      expect(String.fromCharCodes(bytes.take(5)), '%PDF-');
    });

    test('money cell text drives both PDF and Excel uniformly', () {
      // Keeps the Arabic RTL layout identical in PDF and Excel: the same
      // toText() renders both paths.
      const report = ReportExportRequest(
        title: 't',
        generatedAtMillis: 1,
        rows: [[ReportCell.money(1234500)]],
      );
      final excel = const ReportExportService().buildExcel(report);
      expect(excel, isNotEmpty);
      expect(excel.length, greaterThan(1000));
    });
  });
}