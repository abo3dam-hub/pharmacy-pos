import 'package:flutter/material.dart';

import '../theme/app_dimensions.dart';
import '../theme/app_text_styles.dart';

/// Compact form layout kit — dense multi-column forms so every dialog fits
/// the screen without scrolling (explicit user requirement).
///
/// Usage: replace single-column `Column(children: [field, SizedBox, field])`
/// layouts with [FormGrid], and loose section headers with [CompactSection].
/// Field density itself comes from the global [InputDecorationTheme] in
/// `app_theme.dart` (compact content padding).

/// Responsive multi-column grid for form fields.
///
/// Computes the column count from the available width: as many columns of at
/// least [minColumnWidth] as fit. Each child is wrapped in [Expanded] so a
/// row always fills the width — fields share space instead of wasting it.
/// An incomplete last row is padded with spacers so its fields keep the same
/// column width instead of stretching.
class FormGrid extends StatelessWidget {
  const FormGrid({
    super.key,
    required this.children,
    this.minColumnWidth = 150,
    this.spacing = AppSpacing.s,
    this.runSpacing = AppSpacing.s,
  });

  final List<Widget> children;
  final double minColumnWidth;
  final double spacing;
  final double runSpacing;

  @override
  Widget build(BuildContext context) {
    if (children.isEmpty) return const SizedBox.shrink();
    return LayoutBuilder(
      builder: (context, constraints) {
        final maxWidth = constraints.maxWidth.isFinite
            ? constraints.maxWidth
            : MediaQuery.sizeOf(context).width;
        var columns = ((maxWidth + spacing) / (minColumnWidth + spacing))
            .floor();
        columns = columns.clamp(1, children.length);
        final rows = <Widget>[];
        for (var i = 0; i < children.length; i += columns) {
          final end = (i + columns).clamp(0, children.length);
          final rowChildren = children.sublist(i, end);
          rows.add(
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                for (var j = 0; j < rowChildren.length; j++) ...[
                  if (j > 0) SizedBox(width: spacing),
                  Expanded(child: rowChildren[j]),
                ],
                for (var j = rowChildren.length; j < columns; j++) ...[
                  SizedBox(width: spacing),
                  const Expanded(child: SizedBox.shrink()),
                ],
              ],
            ),
          );
          if (end < children.length) {
            rows.add(SizedBox(height: runSpacing));
          }
        }
        return Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: rows,
        );
      },
    );
  }
}

/// Tight section header for compact forms.
class CompactSection extends StatelessWidget {
  const CompactSection(this.title, {super.key});

  final String title;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: AppSpacing.m, bottom: AppSpacing.xs),
      child: Text(title, style: context.appTypography.sectionTitle),
    );
  }
}
