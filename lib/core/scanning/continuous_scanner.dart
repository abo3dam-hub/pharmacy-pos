import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

import '../../l10n/app_localizations.dart';

/// Embedded continuous barcode scanner for mobile POS (Ali, 2026-10-08).
///
/// Unlike [BarcodeScannerPage] (single-shot modal), this widget stays active:
/// every detected barcode is delivered to [onScanned] without closing the
/// preview, enabling rapid consecutive scans by just passing the camera over
/// barcodes. Rapid re-reads of the same barcode are ignored for
/// [duplicateCooldown] so a lingering barcode doesn't add the item repeatedly.
class ContinuousScanner extends StatefulWidget {
  const ContinuousScanner({
    super.key,
    required this.onScanned,
    this.height = 168,
    this.onClose,
  });

  /// Called for every (non-duplicate) detected barcode.
  final ValueChanged<String> onScanned;

  /// Height of the camera preview strip.
  final double height;

  /// Called when the user taps the close button. If null, no close button
  /// is shown (the parent owns the toggle).
  final VoidCallback? onClose;

  @override
  State<ContinuousScanner> createState() => _ContinuousScannerState();
}

class _ContinuousScannerState extends State<ContinuousScanner> {
  late final MobileScannerController _controller;
  String? _lastCode;
  DateTime? _lastTime;

  /// Ignore re-reads of the same barcode within this window.
  static const duplicateCooldown = Duration(milliseconds: 1500);

  @override
  void initState() {
    super.initState();
    _controller = MobileScannerController(
      detectionSpeed: DetectionSpeed.normal,
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _onDetect(BarcodeCapture capture) {
    if (!mounted || capture.barcodes.isEmpty) return;
    final code = capture.barcodes.first.rawValue?.trim();
    if (code == null || code.isEmpty) return;
    final now = DateTime.now();
    if (code == _lastCode &&
        _lastTime != null &&
        now.difference(_lastTime!) < duplicateCooldown) {
      return;
    }
    _lastCode = code;
    _lastTime = now;
    widget.onScanned(code);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return SizedBox(
      height: widget.height,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: Stack(
          fit: StackFit.expand,
          children: [
            MobileScanner(
              controller: _controller,
              onDetect: _onDetect,
              errorBuilder: (context, error) {
                final denied = error.errorCode ==
                    MobileScannerErrorCode.permissionDenied;
                return Container(
                  color: Colors.black87,
                  child: Center(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Text(
                        denied
                            ? l10n.cameraPermissionDenied
                            : l10n.scanError,
                        style: const TextStyle(color: Colors.white),
                        textAlign: TextAlign.center,
                      ),
                    ),
                  ),
                );
              },
            ),
            // Viewfinder frame.
            Center(
              child: Container(
                width: 220,
                height: 90,
                decoration: BoxDecoration(
                  border: Border.all(
                    color: Colors.white.withValues(alpha: 0.85),
                    width: 2,
                  ),
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
            ),
            // Controls overlay.
            Positioned(
              top: 4,
              right: 4,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  IconButton(
                    icon: const Icon(Icons.flash_on, color: Colors.white),
                    tooltip: l10n.scanTorch,
                    onPressed: () => _controller.toggleTorch(),
                  ),
                  if (widget.onClose != null)
                    IconButton(
                      icon: const Icon(Icons.close, color: Colors.white),
                      tooltip: MaterialLocalizations.of(context)
                          .closeButtonTooltip,
                      onPressed: widget.onClose,
                    ),
                ],
              ),
            ),
            Positioned(
              bottom: 6,
              left: 0,
              right: 0,
              child: Text(
                l10n.scanContinuousHint,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 12,
                  shadows: [
                    Shadow(
                      color: Colors.black54,
                      blurRadius: 4,
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
