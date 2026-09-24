import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../../core/di/providers.dart';
import '../../../../core/theme/app_dimensions.dart';
import '../../../../l10n/app_localizations.dart';
import '../../domain/entities/expiry_alert.dart';
import '../../domain/services/expiry_alerts_service.dart';

/// Expiry alerts — batches with remaining stock that are expired or
/// expiring soon, sorted by days remaining.
class ExpiryAlertsPage extends ConsumerStatefulWidget {
  const ExpiryAlertsPage({super.key});

  @override
  ConsumerState<ExpiryAlertsPage> createState() => _ExpiryAlertsPageState();
}

class _ExpiryAlertsPageState extends ConsumerState<ExpiryAlertsPage> {
  List<ExpiryAlert> _alerts = [];
  bool _loading = false;

  AppLocalizations get _l10n => AppLocalizations.of(context);

  @override
  void initState() {
    super.initState();
    Future.microtask(() async {
      if (mounted) await _load();
    });
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final service = ExpiryAlertsService(ref.read(databaseProvider));
    final alerts = await service.alerts();
    if (!mounted) return;
    setState(() {
      _alerts = alerts;
      _loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final l10n = _l10n;
    return Column(
      children: [
        Align(
          alignment: AlignmentDirectional.centerEnd,
          child: IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _load,
            tooltip: l10n.refresh,
          ),
        ),
        Expanded(
          child: _loading
          ? const Center(child: CircularProgressIndicator())
          : _alerts.isEmpty
              ? Center(child: Text(l10n.expiryAlertsEmpty))
              : ListView.builder(
                  itemCount: _alerts.length,
                  itemBuilder: (context, index) =>
                      _AlertCard(alert: _alerts[index]),
                ),
        ),
      ],
    );
  }
}

class _AlertCard extends StatelessWidget {
  const _AlertCard({required this.alert});

  final ExpiryAlert alert;

  Color _severityColor(BuildContext context) {
    switch (alert.severity) {
      case ExpirySeverity.expired:
        return Theme.of(context).colorScheme.error;
      case ExpirySeverity.critical:
        return Colors.orange.shade700;
      case ExpirySeverity.warning:
        return Colors.amber.shade800;
    }
  }

  String _severityLabel(AppLocalizations l10n) {
    switch (alert.severity) {
      case ExpirySeverity.expired:
        return l10n.expiryExpired;
      case ExpirySeverity.critical:
        return l10n.expiryCritical;
      case ExpirySeverity.warning:
        return l10n.expiryWarning;
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context);
    final color = _severityColor(context);
    final dateStr = DateFormat('yyyy-MM-dd').format(alert.expiryDate);
    final daysStr = alert.daysRemaining < 0
        ? '${l10n.expiredAgo} ${-alert.daysRemaining} ${l10n.days}'
        : '${alert.daysRemaining} ${l10n.days}';

    return Card(
      margin: const EdgeInsets.symmetric(
        horizontal: AppSpacing.m,
        vertical: AppSpacing.s,
      ),
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.m),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.warning_amber_rounded, color: color, size: 20),
                const SizedBox(width: AppSpacing.s),
                Expanded(
                  child: Text(
                    alert.itemName,
                    style: theme.textTheme.titleSmall,
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.s,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    _severityLabel(l10n),
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: color,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.s),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  '${l10n.batchNumber}: ${alert.batchNumber}',
                  style: theme.textTheme.bodySmall,
                ),
                Text(
                  '${l10n.expiryDate}: $dateStr',
                  style: theme.textTheme.bodySmall,
                ),
              ],
            ),
            const SizedBox(height: 4),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  '${l10n.currentStock}: ${alert.quantityBase}',
                  style: theme.textTheme.bodySmall,
                ),
                Text(
                  daysStr,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: color,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
