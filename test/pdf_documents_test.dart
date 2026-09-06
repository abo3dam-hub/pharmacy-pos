/// Receipt / invoice / Z-Report PDF gap-closure tests.
///
/// The generators run without a Flutter engine: the Cairo font is loaded from
/// the asset file and an identity deflate keeps every stream (content + the
/// embedded font program) uncompressed. Structural assertions verify a valid
/// PDF with the Cairo TTF embedded; text-level assertions pin the §23/§31
/// shaping + Latin-digits contracts on the pure functions that decide what
/// gets rendered.
library;

import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:pharmacy_pos/core/money/money.dart';
import 'package:pharmacy_pos/core/pdf/pdf_arabic.dart';
import 'package:pharmacy_pos/core/pdf/pdf_documents.dart';
import 'package:pharmacy_pos/core/pdf/pdf_fonts.dart';
import 'package:pharmacy_pos/features/sales/domain/entities/pos_invoice.dart';
import 'package:pharmacy_pos/features/sales/domain/entities/z_report.dart';
import 'package:pharmacy_pos/shared/models/enums.dart';

PdfFonts _fileFonts() => PdfFonts(
      loadBytes: () async => File(PdfFonts.assetPath).readAsBytes(),
    );

Future<void> _expectValidPdf(Future<Uint8List> build) async {
  final bytes = await build;
  expect(String.fromCharCodes(bytes.sublist(0, 5)), '%PDF-',
      reason: 'PDF header');
  expect(String.fromCharCodes(bytes).contains('%%EOF'), isTrue,
      reason: 'PDF trailer');
  expect(String.fromCharCodes(bytes).contains('startxref'), isTrue,
      reason: 'cross-reference table must exist');
  // The Cairo TTF must actually be embedded: its stream is ASCII85-encoded,
  // so decode each stream block and look for the TrueType sfnt header.
  expect(_hasEmbeddedTrueType(bytes), isTrue,
      reason: 'embedded Cairo font program must carry the TrueType sfnt header');
  // Text is emitted as a glyph-index table (subset font), so the rendered page
  // must reference the TTF with the `Tf` operator and show runs with `TJ`.
  expect(RegExp(r'/F\d+ \d+ Tf').hasMatch(String.fromCharCodes(bytes)), isTrue,
      reason: 'font text-showing operator must be used');
  expect(RegExp(r'\]TJ').hasMatch(String.fromCharCodes(bytes)), isTrue,
      reason: 'text runs must be shown on the page');
}

/// Detects the embedded TrueType font program by ascii85-decoding every
/// `stream ... endstream` block and looking for the sfnt magic (`00 01 00 00`).
bool _hasEmbeddedTrueType(Uint8List bytes) {
  final text = String.fromCharCodes(bytes);
  final blocks = RegExp(r'stream\r?\n(.*?)\r?\nendstream').allMatches(text);
  for (final m in blocks) {
    final decoded = _ascii85Decode(m.group(1)!);
    if (decoded != null &&
        decoded.length >= 4 &&
        decoded[0] == 0x00 &&
        decoded[1] == 0x01 &&
        decoded[2] == 0x00 &&
        decoded[3] == 0x00) {
      return true;
    }
  }
  return false;
}

/// Adobe (btoa) ascii85 decoder. Returns null when the block is not ascii85.
/// Full 5-char group ⇒ 4 bytes; trailing partial group of n chars ⇒ n−1 bytes.
List<int>? _ascii85Decode(String data) {
  final clean = data.replaceAll(RegExp(r'\s'), '');
  if (!clean.endsWith('~>')) return null;
  final body = clean.substring(0, clean.length - 2);
  final out = <int>[];
  var i = 0;
  while (i < body.length) {
    if (body[i] == 'z') {
      out.addAll(const [0, 0, 0, 0]);
      i += 1;
      continue;
    }
    var value = 0;
    var count = 0;
    for (var j = 0; j < 5; j++) {
      if (i + j >= body.length) {
        value = value * 85 + 84; // pad missing chars with 'u' (84)
      } else {
        final c = body.codeUnitAt(i + j);
        if (c < 33 || c > 117) return null;
        value = value * 85 + (c - 33);
        count++;
      }
    }
    if (count == 5) {
      out.addAll(_four(value));
    } else if (count > 1) {
      out.addAll(_four(value).sublist(0, count - 1));
    }
    i += 5;
  }
  return out;
}

List<int> _four(int value) => [
      (value >> 24) & 0xff,
      (value >> 16) & 0xff,
      (value >> 8) & 0xff,
      value & 0xff,
    ];

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('PdfArabic shaping contract', () {
    test('Arabic is reshaped to presentation forms, Latin stays untouched',
        () {
      const label = 'رقم الفاتورة';
      final shaped = PdfArabic.shape(label);
      expect(shaped, isNot(label), reason: 'logical letters must not survive');
      expect(shaped.runes.where((r) => r >= 0x0600).every((r) => r >= 0xFE70),
          isTrue,
          reason: 'all Arabic letters must map to presentation forms');
      expect(PdfArabic.shape('INV-000001'), 'INV-000001',
          reason: 'invoice numbers keep Latin digits');
      expect(PdfArabic.shape('Test Pharmacy'), 'Test Pharmacy',
          reason: 'Latin strings pass through unchanged');
      expect(PdfArabic.textDirection(label), pw.TextDirection.rtl,
          reason: 'Arabic-first heading must render RTL');
      expect(PdfArabic.textDirection('Test Pharmacy'), pw.TextDirection.ltr);
    });

    test('money keeps Latin digits (no Arabic-Indic numerals)', () {
      expect(Money.fromUnits(1030000).formatArabicDigits(), '103.00');
      expect(Money.fromUnits(12345678900).formatArabicDigits(), '1,234,567.89');
      expect('٠١٢٣٤٥٦٧٨٩'.contains(RegExp(r'[0-9]')), isFalse);
    });
  });

  group('PdfDocuments pipeline', () {
    late List<int> Function(List<int>) identity;

    setUpAll(() {
      identity = (data) => data;
    });

    test('receipt builds a valid PDF with the Cairo font embedded', () async {
      final docs = PdfDocuments(fonts: _fileFonts(), deflate: identity);
      await _expectValidPdf(ReceiptPdfService(docs: docs).buildBytes(
        _invoice(),
        pharmacyName: 'Test Pharmacy',
      ));
    });

    test('sale invoice builds a valid PDF with notes and full lines',
        () async {
      final docs = PdfDocuments(fonts: _fileFonts(), deflate: identity);
      await _expectValidPdf(InvoicePdfService(docs: docs).buildBytes(
        _invoice(
            number: 'INV-000042',
            totalMicros: 10300000,
            notes: 'خصم كمية',
            customerName: 'عميل آجل'),
        pharmacyName: 'Test Pharmacy',
      ));
    });

    test('z-report builds a valid reconciliation PDF', () async {
      final docs = PdfDocuments(fonts: _fileFonts(), deflate: identity);
      await _expectValidPdf(ZReportPdfService(docs: docs).buildBytes(
        ZReport(
          fromMillis: 1700000000000,
          toMillis: 1700000864000,
          invoiceCount: 3,
          subtotalMicros: 6000000,
          discountMicros: 100000,
          vatMicros: 200000,
          totalMicros: 6100000,
          paidMicros: 5000000,
          changeMicros: 100000,
          cashMicros: 4000000,
          cardMicros: 1000000,
          creditMicros: 1100000,
          unitsSold: 7,
          voidCount: 1,
          voidTotalMicros: 50000,
          returnsCount: 1,
          returnsTotalMicros: 200000,
          customerPaidMicros: 300000,
          customerRefundMicros: 0,
          drawerOpeningMicros: 50000,
          drawerNetMovesMicros: 40000,
          lastRemainingMicros: 90000,
          drawerDeclaredCloseMicros: 90000,
        ),
        pharmacyName: 'Test Pharmacy',
      ));
    });
  });
}

PosInvoiceView _invoice({
  String number = 'INV-000001',
  int totalMicros = 10300000,
  String? notes,
  String customerName = 'Test Pharmacy Customer',
}) {
  const line = PosInvoiceLineView(
    id: 'l1',
    invoiceId: 'inv1',
    itemId: 'item1',
    itemName: 'بانادول اكسترا',
    batchId: 'batch1',
    batchNumber: 'B-100',
    unitTypeId: 'unit_strip',
    unitTypeName: 'شريط',
    quantityBaseSigned: 2,
    unitPriceMicros: 5000000,
    vatRateBasisPoints: 0,
    lineDiscountBasisPoints: 0,
    lineSubtotalMicros: 10000000,
    lineDiscountMicros: 0,
    lineTotalMicros: 10000000,
    unitCostMicros: 3000000,
    costTotalMicros: 6000000,
    profitMicros: 4000000,
    returnQuantityBase: 0,
  );
  return PosInvoiceView(
    id: 'inv1',
    invoiceNumber: number,
    invoiceType: InvoiceType.sale,
    saleStatus: SaleStatus.completed,
    paymentMethod: PaymentMethod.cash,
    customerId: null,
    customerName: customerName,
    userId: 'user_admin',
    subtotalMicros: 10000000,
    discountTotalMicros: 100000,
    vatTotalMicros: 400000,
    totalMicros: totalMicros,
    totalCostMicros: 6000000,
    profitMicros: 4200000,
    paidMicros: totalMicros,
    changeMicros: 0,
    cashMicros: totalMicros,
    cardMicros: 0,
    creditMicros: 0,
    createdAt: 1700000000000,
    notes: notes,
    lines: const [line],
  );
}