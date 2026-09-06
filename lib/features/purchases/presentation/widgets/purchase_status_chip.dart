import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_dimensions.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../../shared/models/enums.dart';

/// Purchase invoice status chip (§24, §12): pending / received / cancelled —
/// always text + icon, never colour-only.
class PurchaseStatusChip extends StatelessWidget {
  const PurchaseStatusChip({super.key, required this.status, this.l10n});

  final PurchaseStatus status;
  final AppLocalizations? l10n;

  @override
  Widget build(BuildContext context) {
    final app = l10n ?? AppLocalizations.of(context);
    final (label, color, bg, icon) = switch (status) {
      PurchaseStatus.pending => (
          app.purchaseStatusPending,
          AppColors.warning,
          AppColors.warningContainer,
          Icons.pending_outlined,
        ),
      PurchaseStatus.received => (
          app.purchaseStatusReceived,
          AppColors.success,
          AppColors.successContainer,
          Icons.check_circle_outline,
        ),
      PurchaseStatus.cancelled => (
          app.purchaseStatusCancelled,
          AppColors.error,
          AppColors.errorContainer,
          Icons.cancel_outlined,
        ),
    };
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
}