import 'package:flutter/material.dart';

import '../../../../core/theme/app_dimensions.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../l10n/app_localizations.dart';
import '../../domain/entities/audit_entry.dart';
import 'audit_labels.dart';

/// Read-only detail view of one audit row (§17). Shows the full snapshot
/// fields; JSON before/after snapshots are shown in a monospace block so
/// field diffs are easy to scan.
Future<void> showAuditDetailDialog(
  BuildContext context,
  AuditEntry entry,
) {
  return showDialog<void>(
    context: context,
    builder: (context) => _AuditDetailDialog(entry),
  );
}

class _AuditDetailDialog extends StatelessWidget {
  const _AuditDetailDialog(this.entry);

  final AuditEntry entry;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final typography = context.appTypography;
    return AlertDialog(
      title: Text(
        l10n.auditDetailTitle,
        style: context.appTypography.sectionTitle,
      ),
      content: SizedBox(
        width: 480,
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              _field(context, l10n.auditActionLabel(entry.action), l10n.auditColumnAction),
              _field(context, l10n.auditEntityTypeLabel(entry.entityType), l10n.auditColumnEntity),
              _field(context, entry.entityId, l10n.auditColumnEntityId),
              _field(
                context,
                '${entry.actorLabel}'
                    '${entry.userFullName == null ? '' : ' (${entry.userFullName})'}',
                l10n.auditColumnUser,
              ),
              _field(context, _formatDateTime(entry.createdAt), l10n.auditColumnDate),
              if (entry.ipAddress != null) _field(context, entry.ipAddress!, 'IP'),
              if (entry.note != null && entry.note!.isNotEmpty)
                _field(context, entry.note!, l10n.auditColumnNote),
              const SizedBox(height: AppSpacing.l),
              if (entry.beforeData != null || entry.afterData != null) ...[
                Text(l10n.auditSnapshotsTitle, style: typography.label),
                const SizedBox(height: AppSpacing.s),
                if (entry.beforeData != null) ...[
                  _snapshotBlock(
                    context,
                    l10n.auditBeforeLabel,
                    entry.beforeData!,
                  ),
                  const SizedBox(height: AppSpacing.m),
                ],
                if (entry.afterData != null)
                  _snapshotBlock(context, l10n.auditAfterLabel, entry.afterData!),
              ],
            ],
          ),
        ),
      ),
      actions: [
        FilledButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(l10n.commonClose),
        ),
      ],
    );
  }

  Widget _field(BuildContext context, String value, String label) {
    final typography = context.appTypography;
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.s),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: typography.labelSmall),
          const SizedBox(height: 2),
          Text(value, style: typography.bodySecondary),
        ],
      ),
    );
  }

  Widget _snapshotBlock(BuildContext context, String label, String jsonRaw) {
    final typography = context.appTypography;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.m),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(AppRadius.sm),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: typography.labelSmall),
          const SizedBox(height: 4),
          Text(
            jsonRaw,
            style: typography.bodySecondary.copyWith(fontFamily: 'monospace'),
          ),
        ],
      ),
    );
  }

  static String _formatDateTime(int millis) {
    final d = DateTime.fromMillisecondsSinceEpoch(millis);
    String two(int n) => n.toString().padLeft(2, '0');
    return '${d.year}-${two(d.month)}-${two(d.day)} '
        '${two(d.hour)}:${two(d.minute)}:${two(d.second)}';
  }
}