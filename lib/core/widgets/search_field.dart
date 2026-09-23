import 'dart:async';

import 'package:flutter/material.dart';

import '../scanning/scan_barcode_button.dart';

/// Debounced, theme-styled search box shared by grids, POS and master lists.
///
/// Emits [onChanged] only after the user pauses typing ([delay]); the trailing
/// clear button resets the query. When [onScan] is provided, a camera barcode
/// scan button is shown too (hidden automatically where camera scanning is
/// unsupported, e.g. desktop). Direction-sensitive icons mirror in RTL.
class SearchField extends StatefulWidget {
  const SearchField({
    super.key,
    this.controller,
    this.hintText,
    required this.onChanged,
    this.autofocus = false,
    this.enabled = true,
    this.delay = const Duration(milliseconds: 300),
    this.onScan,
  });

  final TextEditingController? controller;
  final String? hintText;
  final ValueChanged<String> onChanged;
  final bool autofocus;
  final bool enabled;
  final Duration delay;

  /// When non-null, a camera scan button appears; the scanned barcode is set
  /// as the query and reported immediately (no debounce).
  final ValueChanged<String>? onScan;

  @override
  State<SearchField> createState() => _SearchFieldState();
}

class _SearchFieldState extends State<SearchField> {
  Timer? _debounce;
  late final TextEditingController _controller =
      widget.controller ?? TextEditingController();

  @override
  void dispose() {
    _debounce?.cancel();
    if (widget.controller == null) _controller.dispose();
    super.dispose();
  }

  void _schedule(String value) {
    _debounce?.cancel();
    _debounce = Timer(widget.delay, () => widget.onChanged(value));
  }

  void _onScanPressed(String code) {
    _debounce?.cancel();
    _controller.text = code;
    final onScan = widget.onScan;
    if (onScan != null) onScan(code);
    widget.onChanged(code);
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<TextEditingValue>(
      valueListenable: _controller,
      builder: (context, value, _) {
        final trailing = <Widget>[];
        if (widget.onScan != null) {
          trailing.add(ScanBarcodeButton(onScanned: _onScanPressed));
        }
        if (value.text.isNotEmpty) {
          trailing.add(
            IconButton(
              icon: const Icon(Icons.clear),
              tooltip: MaterialLocalizations.of(context).clearButtonTooltip,
              onPressed: () {
                _controller.clear();
                _debounce?.cancel();
                widget.onChanged('');
              },
            ),
          );
        }
        return TextField(
          controller: _controller,
          enabled: widget.enabled,
          autofocus: widget.autofocus,
          textInputAction: TextInputAction.search,
          onChanged: _schedule,
          decoration: InputDecoration(
            hintText: widget.hintText,
            prefixIcon: const Icon(Icons.search),
            suffixIcon: trailing.isEmpty
                ? null
                : Row(mainAxisSize: MainAxisSize.min, children: trailing),
          ),
        );
      },
    );
  }
}