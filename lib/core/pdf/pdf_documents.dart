import 'dart:typed_data';

import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

import '../../features/sales/domain/entities/pos_invoice.dart';
import '../../features/sales/domain/entities/z_report.dart';
import '../../shared/models/enums.dart';
import '../money/money.dart';
import 'pdf_arabic.dart';
import 'pdf_fonts.dart';

/// Shared typography/table primitives for the pharmacy documents
/// (receipt / sale invoice / Z-Report). Arabic-shaped, Latin digits,
/// RTL-first — matching the app-wide §23/§31 conventions.
class PdfDocuments {
  PdfDocuments({PdfFonts? fonts, this._deflate}) : _fonts = fonts ?? PdfFonts();

  final PdfFonts _fonts;

  /// Injectable stream deflater (tests pass an identity deflate to keep the
  /// content streams uncompressed and assert on raw bytes).
  final DeflateCallback? _deflate;

  /// Builds a PDF document respecting the configured stream compressor.
  pw.Document document() => pw.Document(deflate: _deflate);

  Future<pw.Font> font() => _fonts.font();

  pw.TextStyle style(pw.Font font,
          {double size = 10,
          pw.FontWeight weight = pw.FontWeight.normal}) =>
      PdfArabic.textStyle(font, size: size, weight: weight);

  /// Shaped, direction-aware text widget.
  pw.Widget text(pw.Font font, String value,
          {double size = 10,
          pw.FontWeight weight = pw.FontWeight.normal}) =>
      pw.Text(
        PdfArabic.shape(value),
        textDirection: PdfArabic.textDirection(value),
        style: style(font, size: size, weight: weight),
      );

  pw.Widget heading(pw.Font font, String value, {double size = 13}) =>
      pw.Align(
        alignment: pw.Alignment.center,
        child: text(font, value, size: size, weight: pw.FontWeight.bold),
      );

  /// Right-to-left label/value line.
  pw.Widget fieldRow(pw.Font font, String label, String value) =>
      pw.Padding(
        padding: const pw.EdgeInsets.only(bottom: 2),
        child: pw.Row(
          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
          children: [text(font, label, size: 9), text(font, value, size: 9)],
        ),
      );

  /// Page-level header shared by invoice / Z-Report pages.
  pw.Widget pageHeader({
    required pw.Font font,
    required String pharmacyName,
    required String docLabel,
    String? serial,
    int? atMillis,
    String? operator,
    String? secondLabel,
  }) =>
      pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.stretch,
        children: [
          heading(font, pharmacyName, size: 16),
          pw.SizedBox(height: 4),
          heading(font, docLabel, size: 12),
          if (secondLabel != null) ...[
            pw.SizedBox(height: 2),
            heading(font, secondLabel, size: 10),
          ],
          pw.SizedBox(height: 8),
          if (serial != null) fieldRow(font, 'رقم الوثيقة', serial),
          if (atMillis != null) fieldRow(font, 'التاريخ', timestamp(atMillis)),
          if (operator != null) fieldRow(font, 'الكاشير', operator),
          pw.SizedBox(height: 6),
          pw.Divider(color: const PdfColor.fromInt(0xFFB0BEC5)),
          pw.SizedBox(height: 10),
        ],
      );

  /// A4 page wrapping [body] under [header].
  pw.Page pageA4({
    required pw.Font font,
    required pw.Widget header,
    required pw.Widget body,
  }) =>
      pw.Page(
        pageTheme: pw.PageTheme(
          pageFormat: PdfPageFormat.a4,
          margin: const pw.EdgeInsets.all(28),
          theme: pw.ThemeData.withFont(base: font),
        ),
        build: (ctx) => pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.stretch,
          children: [header, pw.Expanded(child: body)],
        ),
      );

  /// 80 mm thermal receipt page.
  pw.Page pageReceipt({
    required pw.Font font,
    required pw.Widget body,
    String? pharmacyName,
  }) =>
      pw.Page(
        pageTheme: pw.PageTheme(
          pageFormat: PdfPageFormat(80 * PdfPageFormat.mm, 297 * PdfPageFormat.mm,
              marginAll: 24 * PdfPageFormat.mm),
          theme: pw.ThemeData.withFont(base: font),
        ),
        build: (ctx) => pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.stretch,
          children: [
            if (pharmacyName != null) heading(font, pharmacyName, size: 12),
            pw.SizedBox(height: 6),
            pw.Divider(color: const PdfColor.fromInt(0xFFB0BEC5)),
            pw.SizedBox(height: 6),
            body,
          ],
        ),
      );

  pw.Widget invoiceLinesTable(
    pw.Font font,
    List<PosInvoiceLineView> lines, {
    double fontSize = 8.5,
  }) {
    final headers = ['المنتج', 'الكمية', 'سعر الوحدة', 'الإجمالي'];
    const right = pw.Alignment.centerRight;
    return pw.TableHelper.fromTextArray(
      headers: [for (final h in headers) PdfArabic.shape(h)],
      data: [
        for (final line in lines)
          [
            PdfArabic.shape(
                '${line.itemName}${line.batchNumber.isNotEmpty ? ' (${line.batchNumber})' : ''}'),
            '${line.quantityBaseSigned} ${PdfArabic.shape(line.unitTypeName)}',
            money(line.unitPriceMicros),
            money(line.lineTotalMicros),
          ],
      ],
      cellStyle: style(font, size: fontSize),
      headerStyle: style(font, size: fontSize, weight: pw.FontWeight.bold),
      headerDecoration: const pw.BoxDecoration(color: PdfColor.fromInt(0xFFE3E8F0)),
      cellAlignments: {0: right, 1: right, 2: right, 3: right},
      headerAlignments: {0: right, 1: right, 2: right, 3: right},
    );
  }

  pw.Widget totalsTable(
    pw.Font font, {
    required int subtotalMicros,
    int discountMicros = 0,
    int vatMicros = 0,
    int? totalMicros,
    int? paidMicros,
    int? changeMicros,
  }) {
    final rows = <(String, String)>[
      ('الإجمالي قبل الخصم', money(subtotalMicros)),
      if (discountMicros != 0) ('الخصم', '-${money(discountMicros)}'),
      ('ضريبة القيمة المضافة', money(vatMicros)),
      (
        'المجموع النهائي',
        money(totalMicros ?? (subtotalMicros - discountMicros + vatMicros))
      ),
      if (paidMicros != null) ('المدفوع', money(paidMicros)),
      if (changeMicros != null) ('الباقي', money(changeMicros)),
    ];
    return pw.TableHelper.fromTextArray(
      data: [
        for (final (label, value) in rows)
          [PdfArabic.shape(label), PdfArabic.shape(value)],
      ],
      cellStyle: style(font, size: 9),
      cellAlignments: {0: pw.Alignment.centerRight, 1: pw.Alignment.centerLeft},
      columnWidths: {0: const pw.FlexColumnWidth(3), 1: const pw.FlexColumnWidth(1)},
      border: pw.TableBorder.all(color: const PdfColor.fromInt(0xFFB0BEC5)),
    );
  }

  static pw.Widget spacer8() => pw.SizedBox(height: 8);

  static String timestamp(int millis) {
    final d = DateTime.fromMillisecondsSinceEpoch(millis);
    String p(int v, [int w = 2]) => v.toString().padLeft(w, '0');
    return '${d.year}-${p(d.month)}-${p(d.day)} ${p(d.hour)}:${p(d.minute)}';
  }

  static String money(int micros) => Money.fromUnits(micros).formatArabicDigits();
}

/// Receipt document (80 mm thermal) for POS sales.
class ReceiptPdfService {
  ReceiptPdfService({PdfDocuments? docs}) : _docs = docs ?? PdfDocuments();

  final PdfDocuments _docs;

  Future<Uint8List> buildBytes(
    PosInvoiceView invoice, {
    required String pharmacyName,
  }) async {
    final font = await _docs.font();
    final doc = _docs.document();
    final credit = invoice.paymentMethod == PaymentMethod.credit;
    doc.addPage(_docs.pageReceipt(
      font: font,
      pharmacyName: pharmacyName,
      body: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.stretch,
        children: [
          _docs.fieldRow(font, 'رقم الفاتورة', invoice.invoiceNumber),
          _docs.fieldRow(
              font, 'التاريخ', PdfDocuments.timestamp(invoice.createdAt)),
          if (invoice.customerName.isNotEmpty)
            _docs.fieldRow(font, 'العميل', invoice.customerName),
          PdfDocuments.spacer8(),
          _docs.invoiceLinesTable(font, invoice.lines, fontSize: 8),
          PdfDocuments.spacer8(),
          _docs.totalsTable(font,
              subtotalMicros: invoice.subtotalMicros,
              discountMicros: invoice.discountTotalMicros,
              vatMicros: invoice.vatTotalMicros,
              totalMicros: invoice.totalMicros,
              paidMicros: invoice.paidMicros,
              changeMicros: invoice.changeMicros),
          PdfDocuments.spacer8(),
          _docs.fieldRow(font, 'نقداً', PdfDocuments.money(invoice.cashMicros)),
          _docs.fieldRow(font, 'بطاقة', PdfDocuments.money(invoice.cardMicros)),
          _docs.fieldRow(font, 'آجل', PdfDocuments.money(invoice.creditMicros)),
          if (credit && invoice.totalMicros > invoice.paidMicros) ...[
            PdfDocuments.spacer8(),
            _docs.fieldRow(
              font,
              'المبلغ المتبقي',
              PdfDocuments.money(invoice.totalMicros - invoice.paidMicros),
            ),
          ],
          PdfDocuments.spacer8(),
          pw.Divider(color: const PdfColor.fromInt(0xFFB0BEC5)),
          pw.SizedBox(height: 4),
          _docs.heading(font, 'شكراً لتسوقك معنا', size: 10),
        ],
      ),
    ));
    return doc.save();
  }

  /// Sends the receipt to the platform print dialog.
  Future<void> print(PosInvoiceView invoice, String pharmacyName) async {
    final bytes = await buildBytes(invoice, pharmacyName: pharmacyName);
    await Printing.layoutPdf(onLayout: (_) async => bytes);
  }
}

/// A4 sale invoice document.
class InvoicePdfService {
  InvoicePdfService({PdfDocuments? docs}) : _docs = docs ?? PdfDocuments();

  final PdfDocuments _docs;

  Future<Uint8List> buildBytes(
    PosInvoiceView invoice, {
    required String pharmacyName,
  }) async {
    final font = await _docs.font();
    final doc = _docs.document();
    doc.addPage(_docs.pageA4(
      font: font,
      header: _docs.pageHeader(
        font: font,
        pharmacyName: pharmacyName,
        docLabel: 'فاتورة مبيعات',
        serial: invoice.invoiceNumber,
        atMillis: invoice.createdAt,
        operator: invoice.userId,
        secondLabel: invoice.customerName.isEmpty ? null : invoice.customerName,
      ),
      body: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.stretch,
        children: [
          _docs.invoiceLinesTable(font, invoice.lines),
          PdfDocuments.spacer8(),
          pw.Align(
            alignment: pw.Alignment.centerRight,
            child: pw.SizedBox(
              width: 260,
              child: _docs.totalsTable(font,
                  subtotalMicros: invoice.subtotalMicros,
                  discountMicros: invoice.discountTotalMicros,
                  vatMicros: invoice.vatTotalMicros,
                  totalMicros: invoice.totalMicros,
                  paidMicros: invoice.paidMicros,
                  changeMicros: invoice.changeMicros),
            ),
          ),
          if (invoice.notes != null && invoice.notes!.isNotEmpty) ...[
            PdfDocuments.spacer8(),
            _docs.text(font, 'ملاحظات: ${invoice.notes}', size: 9),
          ],
        ],
      ),
    ));
    return doc.save();
  }

  Future<void> print(PosInvoiceView invoice, String pharmacyName) async {
    final bytes = await buildBytes(invoice, pharmacyName: pharmacyName);
    await Printing.layoutPdf(onLayout: (_) async => bytes);
  }
}

/// Z-Report (end-of-session summary).
class ZReportPdfService {
  ZReportPdfService({PdfDocuments? docs}) : _docs = docs ?? PdfDocuments();

  final PdfDocuments _docs;

  Future<Uint8List> buildBytes(
    ZReport report, {
    required String pharmacyName,
  }) async {
    final font = await _docs.font();
    final doc = _docs.document();
    final periodText =
        '${PdfDocuments.timestamp(report.fromMillis)} - '
        '${PdfDocuments.timestamp(report.toMillis)}';

    doc.addPage(_docs.pageA4(
      font: font,
      header: _docs.pageHeader(
        font: font,
        pharmacyName: pharmacyName,
        docLabel: 'تقرير نهاية الوردية (Z)',
        secondLabel: periodText,
        atMillis: report.toMillis,
        operator: report.userId,
      ),
      body: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.stretch,
        children: [
          _docs.heading(font, 'ملخص المبيعات', size: 11),
          _docs.fieldRow(font, 'عدد الفواتير', '${report.invoiceCount}'),
          _docs.fieldRow(font, 'الوحدات المباعة', '${report.unitsSold}'),
          _docs.fieldRow(
              font, 'المجموع قبل الخصم', PdfDocuments.money(report.subtotalMicros)),
          _docs.fieldRow(font, 'الخصم', PdfDocuments.money(report.discountMicros)),
          _docs.fieldRow(
              font, 'ضريبة القيمة المضافة', PdfDocuments.money(report.vatMicros)),
          _docs.fieldRow(
              font, 'إجمالي المبيعات', PdfDocuments.money(report.totalMicros)),
          _docs.fieldRow(font, 'نقداً', PdfDocuments.money(report.cashMicros)),
          _docs.fieldRow(font, 'بطاقة', PdfDocuments.money(report.cardMicros)),
          _docs.fieldRow(font, 'آجل (ذمم)', PdfDocuments.money(report.creditMicros)),
          _docs.fieldRow(
              font, 'المبلغ المدفوع', PdfDocuments.money(report.paidMicros)),
          _docs.fieldRow(
              font, 'الباقي (الصرف)', PdfDocuments.money(report.changeMicros)),
          PdfDocuments.spacer8(),
          pw.Divider(color: const PdfColor.fromInt(0xFFB0BEC5)),
          PdfDocuments.spacer8(),
          _docs.heading(font, 'المرتجعات والإلغاءات', size: 11),
          _docs.fieldRow(font, 'المرتجعات (عدد / قيمة)',
              '${report.returnsCount} / ${PdfDocuments.money(report.returnsTotalMicros)}'),
          _docs.fieldRow(font, 'الفواتير الملغاة (عدد / قيمة)',
              '${report.voidCount} / ${PdfDocuments.money(report.voidTotalMicros)}'),
          _docs.fieldRow(font, 'تحصيل ذمم العملاء',
              PdfDocuments.money(report.customerPaidMicros)),
          _docs.fieldRow(font, 'استرداد ذمم العملاء',
              PdfDocuments.money(report.customerRefundMicros)),
          PdfDocuments.spacer8(),
          pw.Divider(color: const PdfColor.fromInt(0xFFB0BEC5)),
          PdfDocuments.spacer8(),
          _docs.heading(font, 'تسوية الخزينة', size: 11),
          _docs.fieldRow(font, 'رصيد الافتتاح',
              PdfDocuments.money(report.drawerOpeningMicros)),
          _docs.fieldRow(font, 'صافي الحركات',
              PdfDocuments.money(report.drawerNetMovesMicros)),
          _docs.fieldRow(font, 'الرصيد المتوقع (نهاية الفترة)',
              PdfDocuments.money(report.expectedClosingMicros)),
          _docs.fieldRow(font, 'الرصيد الجاري (سجل الخزينة)',
              PdfDocuments.money(report.lastRemainingMicros)),
          if (report.drawerDeclaredCloseMicros != null) ...[
            _docs.fieldRow(font, 'الإغلاق المعلن',
                PdfDocuments.money(report.drawerDeclaredCloseMicros!)),
            _docs.fieldRow(
                font,
                'فرق الخزينة',
                PdfDocuments.money(report.drawerDifferenceMicros ?? 0)),
          ],
        ],
      ),
    ));
    return doc.save();
  }

  Future<void> print(ZReport report, String pharmacyName) async {
    final bytes = await buildBytes(report, pharmacyName: pharmacyName);
    await Printing.layoutPdf(onLayout: (_) async => bytes);
  }
}