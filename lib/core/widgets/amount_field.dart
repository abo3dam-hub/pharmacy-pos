import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Money input field, RTL-aware and restricted to a canonical decimal shape
/// (digits + a single dot, at most 4 decimal places — matches `Money` scale).
///
/// Emits the raw normalized text via [onChanged]; screen logic parses it with
/// `Money.parse`. No floating-point is ever produced or stored (§23).
class AmountField extends StatelessWidget {
  const AmountField({
    super.key,
    this.controller,
    this.hintText,
    this.autofocus = false,
    this.enabled = true,
    required this.onChanged,
  });

  final TextEditingController? controller;
  final String? hintText;
  final bool autofocus;
  final bool enabled;
  final ValueChanged<String> onChanged;

  /// Restricts input to `1234.5678`-style with max 4 decimals.
  static final TextInputFormatter _formatter =
      TextInputFormatter.withFunction((oldValue, newValue) {
    const pattern = r'^-?\d*(\.\d{0,4})?$';
    if (RegExp(pattern).hasMatch(newValue.text)) return newValue;
    return oldValue;
  });

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      enabled: enabled,
      autofocus: autofocus,
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
      textInputAction: TextInputAction.done,
      textAlign: TextAlign.start,
      inputFormatters: [_formatter],
      onChanged: onChanged,
      decoration: InputDecoration(
        hintText: hintText,
        prefixIcon: const Icon(Icons.payments_outlined),
      ),
    );
  }
}