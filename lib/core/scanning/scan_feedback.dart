import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/services.dart';

/// Sound + haptic feedback for POS scanning (Ali, 2026-10-08).
///
/// Uses bundled WAV beeps via `audioplayers` (reliable on Android, works
/// regardless of silent mode) instead of `SystemSound`, which is quiet and
/// unreliable on many devices.
class ScanFeedback {
  ScanFeedback._();

  static final AudioPlayer _successPlayer = AudioPlayer();
  static final AudioPlayer _errorPlayer = AudioPlayer();
  static bool _initialized = false;

  static Future<void> _ensureInitialized() async {
    if (_initialized) return;
    _initialized = true;
    // Preload both sounds for instant playback during rapid scans.
    await _successPlayer.setSource(AssetSource('sounds/beep_success.wav'));
    await _errorPlayer.setSource(AssetSource('sounds/beep_error.wav'));
    // Low-latency mode for immediate beep on scan.
    await _successPlayer.setPlayerMode(PlayerMode.lowLatency);
    await _errorPlayer.setPlayerMode(PlayerMode.lowLatency);
  }

  /// Successful scan: high beep + light haptic.
  static Future<void> success() async {
    await _ensureInitialized();
    HapticFeedback.lightImpact();
    await _successPlayer.resume();
  }

  /// Failed scan (unknown barcode / no stock): low double-beep + strong haptic.
  static Future<void> error() async {
    await _ensureInitialized();
    HapticFeedback.vibrate();
    await _errorPlayer.resume();
  }
}
