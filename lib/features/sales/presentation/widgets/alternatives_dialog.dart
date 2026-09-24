import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/di/providers.dart';
import '../../../../core/money/money.dart';
import '../../../../l10n/app_localizations.dart';
import '../../domain/entities/pos_catalog_item.dart';
import '../../domain/entities/smart_alternative.dart';

/// Shared smart-alternatives dialog.
///
/// Used by the POS workspace (an alternative can be picked straight into the
/// cart via [onPick]) and by the inventory items grid / product tree
/// (browse-only: [onPick] is null, rows are not tappable). The requested item
/// is loaded by id so callers only need the id, not a hydrated catalog item —
/// the candidate search always spans the whole product master (stock view and
/// product tree alike), in-stock ranked first, out-of-stock still listed.
class AlternativesDialog extends ConsumerWidget {
  const AlternativesDialog({
    super.key,
    required this.requestedItemId,
    this.onPick,
  });

  final String requestedItemId;
  final ValueChanged<SmartAlternative>? onPick;

  Future<({PosCatalogItem item, List<SmartAlternative> alternatives})> _load(
    WidgetRef ref,
  ) async {
    final repo = ref.read(salesRepositoryProvider);
    final item = await repo.itemById(requestedItemId);
    if (item == null) throw StateError('item not found');
    final alternatives = await repo.smartAlternatives(item);
    return (item: item, alternatives: alternatives);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    return AlertDialog(
      title: FutureBuilder(
        future: ref.read(salesRepositoryProvider).itemById(requestedItemId),
        builder: (context, snapshot) {
          final name = snapshot.data?.displayName ?? '…';
          return Text('${l10n.posAlternativesTitle} $name');
        },
      ),
      content: SizedBox(
        width: 460,
        child: FutureBuilder<({PosCatalogItem item, List<SmartAlternative> alternatives})>(
          future: _load(ref),
          builder: (context, snapshot) {
            if (snapshot.connectionState != ConnectionState.done) {
              return const Center(child: CircularProgressIndicator());
            }
            if (snapshot.hasError) {
              return Center(child: Text(l10n.posAlternativesFailed));
            }
            final list =
                snapshot.data?.alternatives ?? const <SmartAlternative>[];
            if (list.isEmpty) {
              return Center(child: Text(l10n.posAlternativesEmpty));
            }
            return ListView.separated(
              shrinkWrap: true,
              itemCount: list.length,
              separatorBuilder: (_, _) => const Divider(height: 1),
              itemBuilder: (context, index) {
                final alt = list[index];
                return ListTile(
                  dense: true,
                  leading: TierBadge(tier: alt.tier),
                  title: Text(alt.item.displayName),
                  subtitle: Text(
                    '${alt.item.scientificName}'
                    '${(alt.item.manufacturerName?.isNotEmpty ?? false) ? ' · ${alt.item.manufacturerName}' : ''}'
                    '${(alt.item.dose?.isNotEmpty ?? false) ? ' · ${alt.item.dose}' : ''}'
                    '${(alt.item.pharmaForm?.isNotEmpty ?? false) ? ' · ${alt.item.pharmaForm}' : ''}'
                    ' · ${l10n.posAvailableStock}: '
                    '${alt.item.availableStockBase}',
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  trailing: Text(
                    Money.fromUnits(
                      alt.item.sellingPriceMicros,
                    ).formatArabicDigits(),
                  ),
                  onTap: onPick == null ? null : () => onPick!(alt),
                );
              },
            );
          },
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(l10n.commonClose),
        ),
      ],
    );
  }
}

/// Colored tier badge (green / yellow / blue) for the alternatives panel.
class TierBadge extends StatelessWidget {
  const TierBadge({super.key, required this.tier});

  final SmartAlternativeTier tier;

  static const _colors = <SmartAlternativeTier, Color>{
    SmartAlternativeTier.tier1: Color(0xFF2E7D32),
    SmartAlternativeTier.tier2: Color(0xFFF9A825),
    SmartAlternativeTier.tier3: Color(0xFF1976D2),
  };

  static const _labels = <SmartAlternativeTier, String>{
    SmartAlternativeTier.tier1: '1',
    SmartAlternativeTier.tier2: '2',
    SmartAlternativeTier.tier3: '3',
  };

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final label = switch (tier) {
      SmartAlternativeTier.tier1 => l10n.posAlternativesTier1,
      SmartAlternativeTier.tier2 => l10n.posAlternativesTier2,
      SmartAlternativeTier.tier3 => l10n.posAlternativesTier3,
    };
    return Tooltip(
      message: label,
      child: Container(
        width: 28,
        height: 28,
        alignment: Alignment.center,
        decoration: BoxDecoration(color: _colors[tier], shape: BoxShape.circle),
        child: Text(
          _labels[tier]!,
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
            fontSize: 12,
          ),
        ),
      ),
    );
  }
}
