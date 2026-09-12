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

/// Arabic and English trade names shown together: "الاسم (English name)".
/// Falls back to barcode/scientific name/id when both names are empty.
String itemDisplayName(ItemRow item) {
  final ar = item.tradeName.trim();
  final en = item.tradeNameEn?.trim() ?? '';
  if (ar.isEmpty && en.isEmpty) {
    return item.primaryBarcode ?? item.scientificName ?? item.id;
  }
  if (ar.isEmpty) return en;
  if (en.isEmpty) return ar;
  return '$ar ($en)';
}

/// A row of the product's active-ingredient selector: the ingredient's master
/// name plus its optional per-product strength (العيار). Represents one entry
/// of `item_active_ingredients` (§4.2b).
class ItemIngredientRef {
  const ItemIngredientRef({required this.name, this.strength});

  final String name;
  final String? strength;

  @override
  bool operator ==(Object other) =>
      other is ItemIngredientRef &&
      other.name == name &&
      other.strength == strength;

  @override
  int get hashCode => Object.hash(name, strength);
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
    this.activeIngredients = const [],
    this.indicationNames = const [],
  });

  final ItemRow item;
  final ItemUnitRow? units;
  final String? baseUnitName;
  final String? largeUnitName;
  final String? categoryName;
  final String? manufacturerName;

  /// Relational active ingredients (name + per-product strength), §4.2b.
  final List<ItemIngredientRef> activeIngredients;

  /// Relational indication names from `item_indications`, §4.2c.
  final List<String> indicationNames;

  int get unitsPerLarge => units?.unitsPerLarge ?? 1;

  StockStatus get stockStatus =>
      stockStatusFor(item.currentStockBase, item.minimumStockBase);

  /// Current on-hand as a base-unit quantity (derived display, §7).
  Quantity get onHand => Quantity.fromBaseUnits(
        item.currentStockBase,
        unitsPerLarge: unitsPerLarge,
      );

  /// Legacy single-name label (Arabic trade name first, then barcode/scientific
  /// name/id). Kept for confirm dialogs and compact cells.
  String get primaryLabel => item.tradeName.isNotEmpty
      ? item.tradeName
      : (item.primaryBarcode ?? item.scientificName ?? item.id);

  /// Arabic and English trade names shown together: "الاسم (English name)".
  /// Falls back to the legacy [primaryLabel] when the name is empty.
  String get displayName => itemDisplayName(item);
}