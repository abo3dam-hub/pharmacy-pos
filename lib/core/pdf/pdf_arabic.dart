import 'package:arabic_reshaper/arabic_reshaper.dart'
    show ArabicReshaper;
import 'package:pdf/pdf.dart' show PdfColor, PdfColors;
import 'package:pdf/widgets.dart' as pw;

import '../config/app_config.dart';

/// Arabic text shaping for PDF generation.
///
/// The Cairo font ships unshaped Arabic forms (U+0600..U+06FF); presenting
/// them directly renders disconnected letters. [shapeArabic] maps them to
/// presentation forms (U+FE70..) which the embedded font covers, while keeping
/// Latin letters and digits untouched — so all monetary values stay in Latin
/// digits (system-wide Arabic-digit ban, §31).
class PdfArabic {
  PdfArabic._();

  /// Reshapes a mixed string so Arabic text joins correctly in the PDF.
  ///
  /// The `pdf` engine drives its own bidi/ligature composition on top of this
  /// presentation output. Its composition table only spans the Arabic
  /// combining pairs, so feeding it a pre-composed lam-alef glyph (U+FEF5..
  /// U+FEFC) overflows that table and throws during layout. We therefore
  /// decompose lam-alef back to `ل + ZWNJ + ا`; the zero-width joiner keeps
  /// the pair visually separated and stops the downstream composer from
  /// re-joining it. Every other letter keeps the reshaped presentation form.
  static final RegExp _lamAlef = RegExp('[\uFEF5-\uFEFC]');

  static String shape(String value) => ArabicReshaper.instance.reshape(value)
      .replaceAllMapped(_lamAlef, (m) => '\u0644\u200C\u0627');

  /// RTL for Arabic-first headings, LTR otherwise.
  static pw.TextDirection textDirection(String value) =>
      ArabicReshaper.isArabic(value)
          ? pw.TextDirection.rtl
          : pw.TextDirection.ltr;

  /// Typography used across all pharmacy documents (Arabic-first).
  static pw.TextStyle textStyle(
    pw.Font font, {
    double size = 10,
    pw.FontWeight? weight,
    PdfColor? color,
  }) =>
      pw.TextStyle(
        font: font,
        fontSize: size,
        fontWeight: weight ?? pw.FontWeight.normal,
        color: color ?? PdfColors.black,
        fontFallback: [font],
      );
}

/// Default pharmacy display name used when `app_settings.pharmacy_name` is
/// unset (§31; set via the future settings UI).
String pharmacyFallbackName() => AppConfig.appName;

/// Canonical settings key for the pharmacy display name on documents.
const String pharmacyNameSettingKey = 'pharmacy_name';