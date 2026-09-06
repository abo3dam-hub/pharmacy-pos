import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

/// Central POS keyboard shortcut registry (§5 keyboard shortcuts).
///
/// Single source of truth for supported workspace actions — the workspace
/// wires ONE [Shortcuts] + [Actions] set from [desktopMap].
///   * F1  — focus the product search field
///   * F2  — toggle the selected cart line unit (box ↔ fraction)
///   * F5  — hold the current bill
///   * F12 — open checkout
///   * Alt+S — show smart alternatives of the selected item
class SearchFocusIntent extends Intent {
  const SearchFocusIntent();
}

class ToggleUnitModeIntent extends Intent {
  const ToggleUnitModeIntent();
}

class HoldBillIntent extends Intent {
  const HoldBillIntent();
}

class CheckoutIntent extends Intent {
  const CheckoutIntent();
}

class ShowAlternativesIntent extends Intent {
  const ShowAlternativesIntent();
}

class PosShortcuts {
  PosShortcuts._();

  static final Map<ShortcutActivator, Intent> desktopMap = {
    const SingleActivator(LogicalKeyboardKey.f1): const SearchFocusIntent(),
    const SingleActivator(LogicalKeyboardKey.f2): const ToggleUnitModeIntent(),
    const SingleActivator(LogicalKeyboardKey.f5): const HoldBillIntent(),
    const SingleActivator(LogicalKeyboardKey.f12): const CheckoutIntent(),
    const SingleActivator(LogicalKeyboardKey.keyS, alt: true):
        const ShowAlternativesIntent(),
  };
}