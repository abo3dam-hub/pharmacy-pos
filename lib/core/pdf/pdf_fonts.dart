import 'package:flutter/services.dart';
import 'package:pdf/widgets.dart' as pw;

/// Loads the bundled Arabic-capable font (Cairo TTF) for PDF generation.
///
/// The loader is injectable so the PDF services stay pure and testable: unit
/// tests read `assets/fonts/Cairo-Regular.ttf` from the filesystem and build
/// documents without a running Flutter engine.
class PdfFonts {
  PdfFonts({this.loadBytes});

  static const String assetPath = 'assets/fonts/Cairo-Regular.ttf';

  final Future<Uint8List> Function()? loadBytes;
  pw.Font? _cached;

  Future<pw.Font> font() async {
    final existing = _cached;
    if (existing != null) return existing;
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
  }
}