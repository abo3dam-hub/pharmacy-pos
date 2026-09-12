import 'package:flutter/material.dart';

import '../theme/app_text_styles.dart';

/// Wraps [child] with a semi-transparent blocking barrier while [visible].
///
/// Used by screens to overlay a *calm* progress state on top of existing
/// content (searching, submitting, printing); label is optional and localized
/// by the caller. When [progress] is supplied it replaces the circular
/// indicator so a long-running operation (e.g. Excel import) can paint a live
/// progress bar and a cancel affordance without leaving the overlay.
class LoadingOverlay extends StatelessWidget {
  const LoadingOverlay({
    super.key,
    required this.visible,
    required this.child,
    this.label,
    this.progress,
  });

  final bool visible;
  final Widget child;
  final String? label;
  final Widget? progress;

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
                child: progress ??
                    Column(
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