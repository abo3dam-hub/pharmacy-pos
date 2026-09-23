import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import 'barcode_scanner_page.dart';

/// Entry point for camera-based barcode scanning.
///
/// Camera scanning is only offered where the device can actually do it
/// (Android/iOS). Desktop keeps the existing hardware-scanner (HID keyboard
/// wedge) pipeline in `lib/core/shortcuts/barcode_buffer.dart`.
///
/// `current` and [isCameraScanSupported] are replaceable so widget tests can
/// inject a fake without a real camera.
class BarcodeScanService {
  BarcodeScanService();

  /// The instance used by [ScanBarcodeButton].
  static BarcodeScanService current = BarcodeScanService();

  /// Whether this device can scan barcodes with its camera.
  /// Overridable in tests.
  static bool Function() isCameraScanSupported = _defaultSupport;

  static bool _defaultSupport() =>
      !kIsWeb && (Platform.isAndroid || Platform.isIOS);

  /// Opens the camera scanner page. Returns the scanned code, or `null` when
  /// scanning is unsupported or the user cancelled.
  Future<String?> scan(BuildContext context) {
    if (!isCameraScanSupported()) return Future.value();
    return Navigator.of(context).push<String>(
      MaterialPageRoute(builder: (_) => const BarcodeScannerPage()),
    );
  }
}
