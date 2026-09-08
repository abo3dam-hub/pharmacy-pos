import 'package:flutter/widgets.dart';

/// POS workspace intent types (§21 keyboard shortcuts).
///
/// [PosShortcutManager] (core/shortcuts) owns the centralized, settings-backed
/// binding registry; these [Intent] types let the workspace map each action to
/// its contextual handler and let the app shell register the same keys
/// app-wide.
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