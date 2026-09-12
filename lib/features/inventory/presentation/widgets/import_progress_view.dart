import 'package:flutter/material.dart';

import '../../../../core/theme/app_dimensions.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../domain/usecases/excel_use_cases.dart';

/// Body of the blocking overlay while an Excel import is running
/// (progress/cancel workstream). Renders the current phase with a live
/// progress bar (or spinner while no fraction is known), an X/Y counter and a
/// cancel button so a large sheet never leaves the user staring at an
/// unresponsive spinner.
class ImportProgressView extends StatelessWidget {
  const ImportProgressView({
    super.key,
    required this.progress,
    required this.stageLabel,
    required this.progressLabel,
    required this.cancelLabel,
    required this.onCancel,
  });

  final ImportProgress progress;
  final String stageLabel;
  final String progressLabel;
  final String cancelLabel;
  final VoidCallback onCancel;

  @override
  Widget build(BuildContext context) {
    final typography = context.appTypography;
    final fraction = progress.fraction;
    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 360),
      child: Card(
        margin: const EdgeInsets.all(AppSpacing.xl),
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.xl),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(stageLabel, style: typography.body),
              const SizedBox(height: AppSpacing.m),
              fraction == null
                  ? const Center(child: CircularProgressIndicator())
                  : LinearProgressIndicator(
                      value: fraction,
                      minHeight: 8,
                      borderRadius: BorderRadius.circular(4),
                    ),
              const SizedBox(height: AppSpacing.s),
              Text(
                progressLabel,
                textAlign: TextAlign.center,
                style: typography.bodySecondary,
              ),
              const SizedBox(height: AppSpacing.l),
              OutlinedButton.icon(
                onPressed: onCancel,
                icon: const Icon(Icons.close),
                label: Text(cancelLabel),
              ),
            ],
          ),
        ),
      ),
    );
  }
}