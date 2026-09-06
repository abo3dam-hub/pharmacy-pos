import 'package:flutter/material.dart';

/// Spacing, radius and layout tokens — a single consistent scale used by every
/// screen and component (8 Spacing & Shape System).
abstract final class AppSpacing {
  static const double xs = 4;
  static const double s = 8;
  static const double m = 12;
  static const double l = 16;
  static const double xl = 20;
  static const double xxl = 24;
  static const double xxxl = 32;
}

/// Corner radii — consistent across cards, dialogs, inputs and tables.
abstract final class AppRadius {
  static const double sm = 6;
  static const double md = 8;
  static const double lg = 12;
}

/// Layout structural constants.
abstract final class AppLayoutTokens {
  /// Right-aligned navigation rail width on wide screens.
  static const double railWidth = 88;

  /// Drawer width on compact screens.
  static const double drawerWidth = 300;

  /// Height of data-grid rows (dense, printed, desktop-appropriate).
  static const double tableRowHeight = 44;
  static const double tableHeaderHeight = 40;

  /// Height of standard controls.
  static const double controlHeight = 44;
}

/// Responsive adaptivity thresholds (§33 Responsive & Desktop / Android UI).
/// Priority: Windows Desktop ≥ 900px, laptop 600–899px, Android tablet,
/// Android phone < 600px.
enum AppLayout {
  desktop,
  tablet,
  compact;

  /// Read the current layout from the ambient `MediaQuery`.
  static AppLayout of(BuildContext context) => AppBreakpoints.of(context);
}

abstract final class AppBreakpoints {
  static const double wide = 900;
  static const double collapse = 600;

  static AppLayout layoutFor(double width) {
    if (width >= wide) return AppLayout.desktop;
    if (width >= collapse) return AppLayout.tablet;
    return AppLayout.compact;
  }

  /// Read the current layout from the ambient `MediaQuery`.
  static AppLayout of(BuildContext context) =>
      layoutFor(MediaQuery.sizeOf(context).width);
}