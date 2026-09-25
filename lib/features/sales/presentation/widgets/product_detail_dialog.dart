import 'package:flutter/material.dart';
import 'dart:math' as math;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/di/providers.dart';
import '../../../../core/money/money.dart';
import '../../../../core/theme/app_dimensions.dart';
import '../../../../l10n/app_localizations.dart';

/// Read-only product detail window opened from the smart-alternatives list.
/// Shows the key product info (names, manufacturer, dose, form, barcodes,
/// prices, stock) so the pharmacist can inspect an alternative without
/// leaving the current screen.
class ProductDetailDialog extends ConsumerWidget {
  const ProductDetailDialog({super.key, required this.itemId});

  final String itemId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    return AlertDialog(
      title: Text(l10n.productDetailTitle),
      content: SizedBox(
        // Viewport-aware width: 480px on desktop, shrinks to the phone
        // screen so rows never overflow horizontally.
        width: math.max(
          280,
          math.min(480, MediaQuery.sizeOf(context).width - 64),
        ),
        child: FutureBuilder(
          future: ref.read(inventoryRepositoryProvider).findItem(itemId),
          builder: (context, snapshot) {
            if (!snapshot.hasData) {
              return const Center(child: CircularProgressIndicator());
            }
            final item = snapshot.data;
            if (item == null) {
              return Center(child: Text(l10n.productDetailNotFound));
            }
            return SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  _row(l10n.productDetailTradeName, item.tradeName,
                      strong: true),
                  if ((item.tradeNameEn ?? '').isNotEmpty)
                    _row(l10n.productDetailTradeNameEn, item.tradeNameEn!),
                  if ((item.scientificName ?? '').isNotEmpty)
                    _row(l10n.productDetailScientific, item.scientificName!),
                  if (item.primaryBarcode?.isNotEmpty ?? false)
                    _row(l10n.productDetailBarcode, item.primaryBarcode!),
                  _row(
                    l10n.productDetailSellPrice,
                    Money.fromUnits(item.sellingPriceMicros).format(),
                  ),
                  _row(
                    l10n.productDetailCost,
                    Money.fromUnits(item.costMicros).format(),
                  ),
                  _row(
                    l10n.productDetailStock,
                    '${item.currentStockBase}',
                  ),
                ],
              ),
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

  Widget _row(String label, String value, {bool strong = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Flexible label column (2:3 ratio) instead of a fixed 140px so
          // the row fits narrow phone screens too.
          Expanded(
            flex: 2,
            child: Text(label),
          ),
          const SizedBox(width: AppSpacing.s),
          Expanded(
            flex: 3,
            child: Text(
              value,
              style: strong
                  ? const TextStyle(fontWeight: FontWeight.bold)
                  : null,
            ),
          ),
        ],
      ),
    );
  }
}

/// Opens the read-only product detail window for [itemId].
Future<void> showProductDetailDialog(BuildContext context, String itemId) {
  return showDialog<void>(
    context: context,
    builder: (_) => ProductDetailDialog(itemId: itemId),
  );
}
