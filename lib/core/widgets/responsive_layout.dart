import 'package:flutter/material.dart';

import '../theme/app_dimensions.dart';

/// Adapts the shell between Windows Desktop, laptop, tablet and phone (§33).
///
/// Use `AppLayout.of(context)` or `AppBreakpoints.layoutFor(width)` for logic;
/// [AppResponsiveLayout] selects the matching child widget at build time.
///
/// - Desktop (≥ 900px): persistent sidebar + content.
/// - Tablet (600–899px): compact navigation (collapsed rail style).
/// - Compact (< 600px): drawer / bottom-sheet navigation.
class AppResponsiveLayout extends StatelessWidget {
  const AppResponsiveLayout({
    super.key,
    required this.desktop,
    required this.tablet,
    required this.compact,
  });

  final Widget desktop;
  final Widget tablet;
  final Widget compact;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        return switch (AppBreakpoints.layoutFor(constraints.maxWidth)) {
          AppLayout.desktop => desktop,
          AppLayout.tablet => tablet,
          AppLayout.compact => compact,
        };
      },
    );
  }
}