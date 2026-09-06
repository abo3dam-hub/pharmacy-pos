import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_dimensions.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../l10n/app_localizations.dart';

/// Shown when an authenticated user reaches a section they lack permission
/// for (router redirect target, §16).
class AccessDeniedPage extends StatelessWidget {
  const AccessDeniedPage({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.lock_outline,
                size: 88,
                color: AppColors.warning,
              ),
              const SizedBox(height: AppSpacing.l),
              Text(l10n.accessDeniedTitle, style: context.appTypography.pageTitle),
              const SizedBox(height: AppSpacing.s),
              Text(
                l10n.accessDeniedMessage,
                textAlign: TextAlign.center,
                style: context.appTypography.bodySecondary,
              ),
              const SizedBox(height: AppSpacing.xl),
              FilledButton.icon(
                onPressed: () => context.go('/'),
                icon: const Icon(Icons.dashboard_outlined),
                label: Text(l10n.navDashboard),
              ),
            ],
          ),
        ),
      ),
    );
  }
}