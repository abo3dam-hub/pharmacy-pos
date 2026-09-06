import 'dart:async';

import 'package:flutter/material.dart';

/// Debounced, theme-styled search box shared by grids, POS and master lists.
///
/// Emits [onChanged] only after the user pauses typing ([delay]); the trailing
/// clear button resets the query. Direction-sensitive icons mirror in RTL.
class SearchField extends StatefulWidget {
  const SearchField({
    super.key,
    this.controller,
    this.hintText,
    required this.onChanged,
    this.autofocus = false,
    this.enabled = true,
    this.delay = const Duration(milliseconds: 300),
  });

  final TextEditingController? controller;
  final String? hintText;
  final ValueChanged<String> onChanged;
  final bool autofocus;
  final bool enabled;
  final Duration delay;

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

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<TextEditingValue>(
      valueListenable: _controller,
      builder: (context, value, _) => TextField(
        controller: _controller,
        enabled: widget.enabled,
        autofocus: widget.autofocus,
        textInputAction: TextInputAction.search,
        onChanged: _schedule,
        decoration: InputDecoration(
          hintText: widget.hintText,
          prefixIcon: const Icon(Icons.search),
          suffix: value.text.isEmpty
              ? null
              : IconButton(
                  icon: const Icon(Icons.clear),
                  onPressed: () {
                    _controller.clear();
                    _debounce?.cancel();
                    widget.onChanged('');
                  },
                ),
        ),
      ),
    );
  }
}