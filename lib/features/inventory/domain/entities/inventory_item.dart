import '../../../../core/quantity/quantity.dart';
import '../../../../shared/database/app_database.dart';

/// Threshold (days) used to derive `nearExpiry` from `batch.expiryDate`.
/// Deliberately a module constant so the UI and the domain agree (§24).
const int nearExpiryDays = 90;

/// Stock status flags derived from counts versus limits. Statuses are never
/// color-only — the UI renders text + icon + badge for each (§24).
enum StockStatus { normal, low, out }

/// Batch health status derived from expiry/`has_expiry` (§24).
enum BatchStatus { normal, nearExpiry, expired }

StockStatus stockStatusFor(int currentBase, int minimumBase) {
  if (currentBase <= 0) return StockStatus.out;
  if (minimumBase > 0 && currentBase < minimumBase) return StockStatus.low;
  return StockStatus.normal;
}

/// A batch is expired when its expiry precedes today; it is near-expiry when it
/// falls inside the [nearExpiryDays] window. Non-expiring batches are always
/// [BatchStatus.normal] (FEFO degrades to FIFO, §6).
BatchStatus batchStatusFor(BatchRow batch, {int? atMillis}) {
  final expiry = batch.expiryDate;
  if (expiry == null) return BatchStatus.normal;
  final now = atMillis ?? DateTime.now().millisecondsSinceEpoch;
  if (expiry < now) return BatchStatus.expired;
  if (expiry - now <= nearExpiryDays * 24 * 60 * 60 * 1000) {
    return BatchStatus.nearExpiry;
  }
  return BatchStatus.normal;
}

/// Presentation-friendly item row enriched with the names of its FK lookups
/// and its base/large unit relation (§4.7, §5). Quantity remains a single
/// authoritative base-unit integer; display splits are derived (§7).
class InventoryItemView {
  const InventoryItemView({
    required this.item,
    this.units,
    this.baseUnitName,
    this.largeUnitName,
    this.categoryName,
    this.manufacturerName,
    this.groupName,
  });

  final ItemRow item;
  final ItemUnitRow? units;
  final String? baseUnitName;
  final String? largeUnitName;
  final String? categoryName;
  final String? manufacturerName;
  final String? groupName;

  int get unitsPerLarge => units?.unitsPerLarge ?? 1;

  StockStatus get stockStatus =>
      stockStatusFor(item.currentStockBase, item.minimumStockBase);

  /// Current on-hand as a base-unit quantity (derived display, §7).
  Quantity get onHand => Quantity.fromBaseUnits(
        item.currentStockBase,
        unitsPerLarge: unitsPerLarge,
      );

  String get primaryLabel => item.tradeName.isNotEmpty
      ? item.tradeName
      : (item.primaryBarcode ?? item.scientificName ?? item.id);
}