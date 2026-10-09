import 'package:flutter/services.dart';
import 'package:pdf/widgets.dart' as pw;

/// Loads the bundled Arabic-capable font for PDF generation.
///
/// Uses Amiri (not Cairo): Amiri includes the Arabic Presentation Forms
/// (U+FE80–U+FEFF) that `arabic_reshaper` emits. Cairo/Tajawal lack those
/// glyphs, so shaped text like (إ) rendered as missing-glyph symbols
/// (Ali, 2026-10-09).
///
/// The loader is injectable so the PDF services stay pure and testable: unit
/// tests read the font from the filesystem and build documents without a
/// running Flutter engine.
class PdfFonts {
  PdfFonts({this.loadBytes});

  static const String assetPath = 'assets/fonts/Amiri-Regular.ttf';

  final Future<Uint8List> Function()? loadBytes;
  pw.Font? _cached;

  Future<pw.Font> font() async {
    final existing = _cached;
    if (existing != null) return existing;
    try {
      Uint8List bytes;
      if (loadBytes != null) {
        bytes = await loadBytes!();
      } else {
        final data = await rootBundle.load(assetPath);
        bytes =
            data.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes);
      }
      return _cached = pw.Font.ttf(
          ByteData.view(bytes.buffer, bytes.offsetInBytes, bytes.lengthInBytes));
    } catch (e) {
      // Fallback to built-in Helvetica if the Arabic font asset is missing.
      // Arabic will not shape, but the PDF will not crash (Ali, 2026-10-09).
      return _cached = pw.Font.helvetica();
    }
  }
}