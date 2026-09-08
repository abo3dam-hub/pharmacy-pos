import 'dart:async';

/// Central barcode scanner buffer (§5 scanner pipeline).
///
/// A single manager instance is shared by the POS workspace: the focused
/// search field feeds keystrokes and the buffer decides when a *complete*
/// barcode has arrived (terminator key, configured prefix/suffix) and emits it
/// once. No ad-hoc listeners anywhere else.
///
/// Pure Dart (works on desktop/kiosk keyboards that emulate a HID scanner).
class BarcodeBuffer {
  BarcodeBuffer({
    this.prefix,
    this.suffix,
    this.terminator = '\n',
    this.timeout = const Duration(milliseconds: 400),
    this.maxLength = 48,
  });

  /// Optional scanner prefix (e.g. `!`) — stripped from the emitted code.
  final String? prefix;

  /// Optional scanner suffix (e.g. `-`) — stripped from the emitted code.
  final String? suffix;

  /// Key that terminates a scan (hardware scanners usually send Enter).
  final String terminator;

  /// Idle time after which a partial scan is discarded.
  final Duration timeout;

  /// Hard safety cap (soft scanners can keep feeding).
  final int maxLength;

  final StringBuffer _buffer = StringBuffer();
  Timer? _idle;

  /// Single consumer callback — fires at most once per completed scan.
  void Function(String barcode)? onBarcode;

  bool get hasPartial => _buffer.isNotEmpty;

  String get partial => _buffer.toString();

  /// Feeds one printable character from the scanner stream. Returns `true`
  /// when a complete barcode was emitted (terminator reached or the [maxLength]
  /// cap triggered) — callers keep priority for the scan path in that case.
  bool feed(String char) {
    if (char.isEmpty) return false;
    _idle?.cancel();
    if (char == terminator) {
      return _complete();
    }
    _buffer.write(char);
    if (_buffer.length > maxLength) {
      return _complete();
    }
    _idle = Timer(timeout, reset);
    return false;
  }

  /// Explicitly completes/resets (e.g. focus lost or scan cancelled).
  void reset() {
    _idle?.cancel();
    _idle = null;
    _buffer.clear();
  }

  /// Emits the buffered code once. Returns `true` when a non-empty barcode was
  /// actually delivered to [onBarcode] (empty/false starts emit nothing).
  bool _complete() {
    _idle?.cancel();
    _idle = null;
    final raw = _buffer.toString();
    _buffer.clear();
    var code = raw;
    final p = prefix;
    final s = suffix;
    if (p != null && p.isNotEmpty && code.startsWith(p)) {
      code = code.substring(p.length);
    }
    if (s != null && s.isNotEmpty && code.endsWith(s)) {
      code = code.substring(0, code.length - s.length);
    }
    code = code.trim();
    final cb = onBarcode;
    reset();
    if (code.isEmpty) return false;
    cb?.call(code);
    return true;
  }

  /// Convenience collation — real scanners may deliver a multi-char chunk.
  void feedString(String chunk) => chunk.split('').forEach(feed);

  void dispose() {
    _idle?.cancel();
    _idle = null;
    _buffer.clear();
  }
}