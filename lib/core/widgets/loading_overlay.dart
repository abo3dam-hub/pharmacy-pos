import 'package:flutter/material.dart';

import '../theme/app_text_styles.dart';

/// Wraps [child] with a semi-transparent blocking barrier while [visible].
///
/// Used by screens to overlay a *calm* progress state on top of existing
/// content (searching, submitting, printing); label is optional and localized
/// by the caller.
class LoadingOverlay extends StatelessWidget {
  const LoadingOverlay({
    super.key,
    required this.visible,
    required this.child,
    this.label,
  });

  final bool visible;
  final Widget child;
  final String? label;

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        child,
        if (visible)
          Positioned.fill(
            child: ColoredBox(
              color: Theme.of(context).colorScheme.surface.withValues(alpha: 0.55),
              child: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const CircularProgressIndicator(),
                    if (label != null) ...[
                      const SizedBox(height: 16),
                      Text(label!, style: context.appTypography.bodySecondary),
                    ],
                  ],
                ),
              ),
            ),
          ),
      ],
    );
  }
}