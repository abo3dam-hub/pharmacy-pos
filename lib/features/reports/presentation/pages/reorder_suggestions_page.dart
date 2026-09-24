import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/di/providers.dart';
import '../../../../core/theme/app_dimensions.dart';
import '../../../../l10n/app_localizations.dart';
import '../../domain/entities/reorder_suggestion.dart';
import '../../domain/services/reorder_suggestions_service.dart';

/// Smart reorder suggestions based on sales velocity.
///
/// Shows items running low (or out) ordered by urgency, with the estimated
/// days of cover left and a suggested purchase quantity.
class ReorderSuggestionsPage extends ConsumerStatefulWidget {
  const ReorderSuggestionsPage({super.key});

  @override
  ConsumerState<ReorderSuggestionsPage> createState() =>
      _ReorderSuggestionsPageState();
}

class _ReorderSuggestionsPageState
    extends ConsumerState<ReorderSuggestionsPage> {
  List<ReorderSuggestion> _suggestions = [];
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
    final service =
        ReorderSuggestionsService(ref.read(databaseProvider));
    final suggestions = await service.suggestions();
    if (!mounted) return;
    setState(() {
      _suggestions = suggestions;
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
          : _suggestions.isEmpty
              ? Center(child: Text(l10n.reorderSuggestionsEmpty))
              : ListView.builder(
                  itemCount: _suggestions.length,
                  itemBuilder: (context, index) =>
                      _SuggestionCard(suggestion: _suggestions[index]),
                ),
        ),
      ],
    );
  }
}

class _SuggestionCard extends StatelessWidget {
  const _SuggestionCard({required this.suggestion});

  final ReorderSuggestion suggestion;

  Color _urgencyColor(BuildContext context) {
    switch (suggestion.urgency) {
      case ReorderUrgency.critical:
        return Theme.of(context).colorScheme.error;
      case ReorderUrgency.warning:
        return Colors.orange.shade700;
      case ReorderUrgency.low:
        return Colors.blue.shade700;
    }
  }

  String _urgencyLabel(AppLocalizations l10n) {
    switch (suggestion.urgency) {
      case ReorderUrgency.critical:
        return l10n.reorderUrgencyCritical;
      case ReorderUrgency.warning:
        return l10n.reorderUrgencyWarning;
      case ReorderUrgency.low:
        return l10n.reorderUrgencyLow;
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context);
    final color = _urgencyColor(context);
    final cover = suggestion.daysOfCover.isInfinite
        ? '—'
        : '${suggestion.daysOfCover.toStringAsFixed(1)} يوم';

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
                Container(
                  width: 12,
                  height: 12,
                  decoration: BoxDecoration(
                    color: color,
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: AppSpacing.s),
                Expanded(
                  child: Text(
                    suggestion.itemName,
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
                    _urgencyLabel(l10n),
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
                  '${l10n.currentStock}: ${suggestion.currentStockBase}',
                  style: theme.textTheme.bodySmall,
                ),
                Text(
                  '${l10n.daysOfCover}: $cover',
                  style: theme.textTheme.bodySmall,
                ),
              ],
            ),
            const SizedBox(height: 4),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  '${l10n.avgDailySales}: '
                  '${suggestion.avgDailySalesBase.toStringAsFixed(1)}',
                  style: theme.textTheme.bodySmall,
                ),
                Text(
                  '${l10n.suggestedQty}: ${suggestion.suggestedQtyBase}',
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
