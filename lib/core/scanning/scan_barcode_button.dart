import 'package:flutter/material.dart';

import '../../l10n/app_localizations.dart';
import 'barcode_scan_service.dart';

/// Camera scan button for barcode fields.
///
/// Renders nothing on platforms without camera scanning (desktop, web), so
/// callers can drop it into any barcode search/field unconditionally. When a
/// code is scanned it is delivered to [onScanned].
class ScanBarcodeButton extends StatelessWidget {
  const ScanBarcodeButton({super.key, required this.onScanned});

  final ValueChanged<String> onScanned;

  Future<void> _scan(BuildContext context) async {
    final code = await BarcodeScanService.current.scan(context);
    if (code == null || code.isEmpty || !context.mounted) return;
    onScanned(code);
  }

  @override
  Widget build(BuildContext context) {
    if (!BarcodeScanService.isCameraScanSupported()) {
      return const SizedBox.shrink();
    }
    return IconButton(
      icon: const Icon(Icons.qr_code_scanner),
      tooltip: AppLocalizations.of(context).scanBarcode,
      onPressed: () => _scan(context),
    );
  }
}
