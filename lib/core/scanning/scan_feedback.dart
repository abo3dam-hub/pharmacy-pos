import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/services.dart';

/// Sound + haptic feedback for POS scanning (Ali, 2026-10-08).
///
/// Radical simplification (2026-10-08): stateless — a fresh player per beep,
/// no preloading, no seek, no static state to get stuck. Falls back to the
/// system sound if audioplayers fails.
class ScanFeedback {
  ScanFeedback._();

  /// Successful scan: high beep + light haptic.
  static Future<void> success() async {
    HapticFeedback.lightImpact();
    await _play('sounds/beep_success.wav', SystemSoundType.alert);
  }

  /// Failed scan (unknown barcode / no stock): low double-beep + strong haptic.
  static Future<void> error() async {
    HapticFeedback.vibrate();
    await _play('sounds/beep_error.wav', SystemSoundType.alert);
  }

  static Future<void> _play(String asset, SystemSoundType fallback) async {
    try {
      await AudioPlayer().play(AssetSource(asset));
    } catch (_) {
      // Last resort: system sound (quiet but better than silence).
      SystemSound.play(fallback);
    }
  }
}
