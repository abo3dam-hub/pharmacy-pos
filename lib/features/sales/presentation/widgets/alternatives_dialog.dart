import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/di/providers.dart';
import '../../../../core/money/money.dart';
import '../../../../l10n/app_localizations.dart';
import '../../domain/entities/pos_catalog_item.dart';
import '../../domain/entities/smart_alternative.dart';
import 'product_detail_dialog.dart';

/// Shared smart-alternatives dialog.
///
/// Used by the POS workspace (an alternative can be picked straight into the
/// cart via [onPick]) and by the inventory items grid / product tree
/// (browse-only: [onPick] is null). Every row is tappable: in the POS it
/// picks the alternative into the cart; in browse mode it opens the item in
/// the caller's own item window via [onOpenItem] (the inventory edit dialog
/// when opened from the stock view / product tree), falling back to the
/// read-only [ProductDetailDialog] when no opener is supplied.
/// The requested item is loaded by id so callers only need the id, not a
/// hydrated catalog item — the candidate search always spans the whole
/// product master (stock view and product tree alike), in-stock ranked
/// first, out-of-stock still listed.
class AlternativesDialog extends ConsumerWidget {
  const AlternativesDialog({
    super.key,
    required this.requestedItemId,
    this.onPick,
    this.onOpenItem,
  });

  final String requestedItemId;
  final ValueChanged<SmartAlternative>? onPick;

  /// Browse-mode tap handler: opens the tapped alternative's item window in
  /// the caller's context (inventory / product tree). Null in the POS.
  final ValueChanged<String>? onOpenItem;

  Future<({PosCatalogItem item, List<SmartAlternative> alternatives})> _load(
    WidgetRef ref,
  ) async {
    final repo = ref.read(salesRepositoryProvider);
    final item = await repo.itemById(requestedItemId);
    if (item == null) throw StateError('item not found');
    final alternatives = await repo.smartAlternatives(item);
    return (item: item, alternatives: alternatives);
  }

  /// Rich row tooltip: manufacturer + active ingredients (with strengths).
  String _rowTooltip(AppLocalizations l10n, PosCatalogItem item) {
    final lines = <String>[item.displayName];
    final manufacturer = item.manufacturerName;
    if (manufacturer != null && manufacturer.isNotEmpty) {
      lines.add('${l10n.itemManufacturer}: $manufacturer');
    }
    final ingredients = _ingredientLabels(item);
    if (ingredients.isNotEmpty) {
      lines.add('${l10n.itemActiveIngredients}: ${ingredients.join('، ')}');
    }
    return lines.join('\n');
  }

  /// Active-ingredient labels, preferring the relational (name + strength)
  /// data and falling back to the flat imported string.
  List<String> _ingredientLabels(PosCatalogItem item) {
    if (item.relationalIngredientNames.isNotEmpty) {
      return [
        for (final name in item.relationalIngredientNames)
          item.relationalIngredientStrengths[name]?.isNotEmpty ?? false
              ? '$name (${item.relationalIngredientStrengths[name]})'
              : name,
      ];
    }
    final flat = item.activeIngredient;
    if (flat != null && flat.isNotEmpty) return [flat];
    return const [];
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
                final diffBits = <String>[
                  if (alt.strengthDifferences.isNotEmpty)
                    '${l10n.posAlternativesStrengthDiff}: '
                    '${alt.strengthDifferences.join('، ')}',
                  if (alt.extraIngredients.isNotEmpty)
                    '${l10n.posAlternativesExtra}: '
                    '${alt.extraIngredients.join('، ')}',
                  if (alt.missingIngredients.isNotEmpty)
                    '${l10n.posAlternativesMissing}: '
                    '${alt.missingIngredients.join('، ')}',
                ];
                return Tooltip(
                  message: _rowTooltip(l10n, alt.item),
                  child: ListTile(
                    dense: true,
                    leading: TierBadge(tier: alt.tier),
                    title: Text(alt.item.displayName),
                    subtitle: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          '${alt.item.scientificName}'
                          '${(alt.item.manufacturerName?.isNotEmpty ?? false) ? ' · ${alt.item.manufacturerName}' : ''}'
                          '${(alt.item.dose?.isNotEmpty ?? false) ? ' · ${alt.item.dose}' : ''}'
                          '${(alt.item.pharmaForm?.isNotEmpty ?? false) ? ' · ${alt.item.pharmaForm}' : ''}',
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 2),
                        Wrap(
                          spacing: 6,
                          runSpacing: 4,
                          crossAxisAlignment: WrapCrossAlignment.center,
                          children: [
                            _MatchChip(percent: alt.matchPercent),
                            _StockChip(inStock: alt.inStock),
                            Text(
                              '${l10n.posAvailableStock}: '
                              '${alt.item.availableStockBase}',
                              style: Theme.of(context).textTheme.labelSmall,
                            ),
                          ],
                        ),
                        if (diffBits.isNotEmpty)
                          Text(
                            diffBits.join(' · '),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: Theme.of(context)
                                .textTheme
                                .labelSmall
                                ?.copyWith(fontStyle: FontStyle.italic),
                          ),
                      ],
                    ),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          Money.fromUnits(
                            alt.item.sellingPriceMicros,
                          ).formatArabicDigits(),
                        ),
                        IconButton(
                          icon: const Icon(Icons.info_outline),
                          tooltip: l10n.productDetailTitle,
                          onPressed: () =>
                              showProductDetailDialog(context, alt.item.id),
                        ),
                      ],
                    ),
                    // POS: tap picks into the cart. Browse mode (stock view /
                    // product tree): tap opens the item in the caller's own
                    // item window (inventory edit dialog); without an opener
                    // it falls back to the read-only detail dialog.
                    onTap: onPick != null
                        ? () => onPick!(alt)
                        : () {
                            final opener = onOpenItem;
                            if (opener != null) {
                              opener(alt.item.id);
                            } else {
                              showProductDetailDialog(context, alt.item.id);
                            }
                          },
                  ),
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

/// Match-percentage chip (e.g. "100%") colored by closeness.
class _MatchChip extends StatelessWidget {
  const _MatchChip({required this.percent});

  final int percent;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final color = percent >= 100
        ? const Color(0xFF2E7D32)
        : percent >= 70
            ? const Color(0xFFF9A825)
            : const Color(0xFF1976D2);
    return Tooltip(
      message: l10n.posAlternativesMatch,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.15),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color),
        ),
        child: Text(
          '$percent٪',
          style: TextStyle(
            color: color,
            fontWeight: FontWeight.bold,
            fontSize: 12,
          ),
        ),
      ),
    );
  }
}

/// Explicit in-stock / out-of-stock status chip — not just a quantity.
class _StockChip extends StatelessWidget {
  const _StockChip({required this.inStock});

  final bool inStock;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final color = inStock ? const Color(0xFF2E7D32) : const Color(0xFFC62828);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            inStock ? Icons.check_circle : Icons.cancel,
            size: 14,
            color: color,
          ),
          const SizedBox(width: 4),
          Text(
            inStock
                ? l10n.posAlternativesInStock
                : l10n.posAlternativesOutOfStock,
            style: TextStyle(
              color: color,
              fontWeight: FontWeight.bold,
              fontSize: 12,
            ),
          ),
        ],
      ),
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
