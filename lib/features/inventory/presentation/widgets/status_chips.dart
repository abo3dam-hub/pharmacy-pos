import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_dimensions.dart';
import '../../../../l10n/app_localizations.dart';
import '../../domain/entities/inventory_item.dart';

/// §24 status chips — always text + icon + badge, never color-only.
class StockStatusChip extends StatelessWidget {
  const StockStatusChip({super.key, required this.status, this.l10n});

  final StockStatus status;
  final AppLocalizations? l10n;

  @override
  Widget build(BuildContext context) {
    final app = l10n ?? AppLocalizations.of(context);
    final (label, color, bg, icon) = switch (status) {
      StockStatus.normal => (app.statusNormal, AppColors.success, AppColors.successContainer, Icons.check_circle_outline),
      StockStatus.low => (app.inventoryLowStock, AppColors.warning, AppColors.warningContainer, Icons.error_outline),
      StockStatus.out => (app.inventoryOutOfStock, AppColors.error, AppColors.errorContainer, Icons.remove_circle_outline),
    };
    return _chip(label, color, bg, icon);
  }
}

/// Batch health status chip (§24): normal / near-expiry / expired.
class BatchStatusChip extends StatelessWidget {
  const BatchStatusChip({super.key, required this.status, this.l10n});

  final BatchStatus status;
  final AppLocalizations? l10n;

  @override
  Widget build(BuildContext context) {
    final app = l10n ?? AppLocalizations.of(context);
    final (label, color, bg, icon) = switch (status) {
      BatchStatus.normal => (app.statusHealthy, AppColors.success, AppColors.successContainer, Icons.check_circle_outline),
      BatchStatus.nearExpiry => (app.statusNearExpiry, AppColors.warning, AppColors.warningContainer, Icons.schedule),
      BatchStatus.expired => (app.statusExpired, AppColors.error, AppColors.errorContainer, Icons.event_busy),
    };
    return _chip(label, color, bg, icon);
  }
}

/// Generic active/inactive pill (§24).
class ActiveStatusChip extends StatelessWidget {
  const ActiveStatusChip({super.key, required this.active, this.l10n});

  final bool active;
  final AppLocalizations? l10n;

  @override
  Widget build(BuildContext context) {
    final app = l10n ?? AppLocalizations.of(context);
    final color = active ? AppColors.success : AppColors.textMuted;
    final bg = active ? AppColors.successContainer : AppColors.surfaceContainer;
    return _chip(
      active ? app.userStatusActive : app.userStatusInactive,
      color,
      bg,
      active ? Icons.circle : Icons.circle_outlined,
    );
  }
}

Widget _chip(String label, Color color, Color bg, IconData icon) {
  return Container(
    padding: const EdgeInsets.symmetric(horizontal: AppSpacing.s, vertical: 4),
    decoration: BoxDecoration(
      color: bg,
      borderRadius: BorderRadius.circular(AppRadius.sm),
    ),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 12, color: color),
        const SizedBox(width: 6),
        Text(label, style: TextStyle(fontSize: 12, color: color)),
      ],
    ),
  );
}