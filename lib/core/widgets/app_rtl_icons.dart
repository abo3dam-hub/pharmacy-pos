import 'package:flutter/material.dart';

/// Direction-aware icon helpers (§24 RTL).
///
/// Back/forward and pagination chevrons are one-directional glyphs; pinning a
/// fixed icon produces a visual bug in the mirrored layout (e.g. a "previous"
/// chevron pointing away from the previous page in RTL). These helpers resolve
/// the correct glyph from the ambient [Directionality] so pages share one
/// source of truth instead of hand-picking hardcoded icons.
abstract final class AppDirectionalIcons {
  AppDirectionalIcons._();

  /// Back arrow for the current text direction.
  static IconData back(BuildContext context) =>
      Directionality.of(context) == TextDirection.rtl
          ? Icons.arrow_forward
          : Icons.arrow_back;

  /// Previous-page chevron for the current text direction.
  static IconData previous(BuildContext context) =>
      Directionality.of(context) == TextDirection.rtl
          ? Icons.chevron_right
          : Icons.chevron_left;

  /// Next-page chevron for the current text direction.
  static IconData next(BuildContext context) =>
      Directionality.of(context) == TextDirection.rtl
          ? Icons.chevron_left
          : Icons.chevron_right;

  /// Drill-in ("open") arrow for the current text direction.
  static IconData drillIn(BuildContext context) =>
      Directionality.of(context) == TextDirection.rtl
          ? Icons.chevron_left
          : Icons.chevron_right;
}