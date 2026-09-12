import '../../../../core/money/money.dart';
import '../../../../core/util/bilingual_name.dart';

/// Immutable catalog snapshot served to the POS workspace (pure Dart, no
/// Flutter / Drift types). Built by the sales data layer from the master
/// items + unit-conversion tables (§5 POS search panel).
class PosCatalogItem {
  const PosCatalogItem({
    required this.id,
    required this.tradeName,
    this.tradeNameEn,
    this.scientificName,
    this.activeIngredient,
    this.manufacturerId,
    this.relationalIngredientNames = const [],
    this.primaryBarcode,
    this.secondaryBarcode,
    required this.isControlledDrug,
    required this.requiresPrescription,
    required this.isActive,
    required this.sellingPriceMicros,
    required this.vatRateBasisPoints,
    required this.currentStockBase,
    required this.availableStockBase,
    required this.baseUnitId,
    required this.baseUnitName,
    required this.largeUnitId,
    required this.largeUnitName,
    required this.unitsPerLarge,
    required this.partialSaleEnabled,
    this.dose,
    this.pharmaForm,
    this.sizeVolume,
    this.sellablePartUnitId,
    this.sellablePartUnitName,
    this.partsPerFullProduct,
    this.sellablePartBaseQuantity,
    this.partialSaleMarkupBasisPoints,
    this.partialSalePriceMicros,
    this.isRxLinked = false,
    this.rxRemainingBase,
  });

  /// Items master id.
  final String id;
  final String tradeName;
  final String? tradeNameEn;
  final String? scientificName;
  final String? activeIngredient;

  /// Master manufacturer id; used by the smart-alternatives engine as a
  /// secondary (tie-break) similarity signal (§18 Phase 18.1).
  final String? manufacturerId;

  /// Names of the active ingredients linked through `item_active_ingredients`
  /// (§4.2b) — the relational complement of the legacy flat `activeIngredient`
  /// column. Used (with the flat column) by the smart-alternatives tier
  /// engine so items created with only relational ingredients still rank.
  final List<String> relationalIngredientNames;
  final String? primaryBarcode;
  final String? secondaryBarcode;
  final bool isControlledDrug;
  final bool requiresPrescription;
  final bool isActive;

  /// Master retail price per Large/Commercial unit (pricing anchor §8).
  final int sellingPriceMicros;
  final int vatRateBasisPoints;

  /// Cached total stock (base units) + FEFO-available quantity (base units).
  final int currentStockBase;
  final int availableStockBase;

  /// Canonical base unit (`item_units.baseUnitId`) + large/commercial unit.
  final String baseUnitId;
  final String baseUnitName;
  final String largeUnitId;
  final String largeUnitName;
  final int unitsPerLarge;

  /// Composition descriptors reported in the smart-alternatives panels and
  /// receipts (master `items` columns): dose/strength, pharmaceutical form and
  /// pack size/volume. All nullable — many legacy items have no values.
  final String? dose;
  final String? pharmaForm;
  final String? sizeVolume;

  /// Partial-sale configuration (Phase 6 Design Lock) ──────────────────
  final bool partialSaleEnabled;
  final String? sellablePartUnitId;
  final String? sellablePartUnitName;
  final int? partsPerFullProduct;
  final int? sellablePartBaseQuantity;
  final int? partialSaleMarkupBasisPoints;

  /// Manual override for the retail price of ONE part (سعر بيع الجزء), in
  /// micro-units. NULL = automatic mode (derived from the approved formula).
  /// Persisted on the item so a pharmacist-set part price survives reload and
  /// restart until it is explicitly reverted (§P17).
  final int? partialSalePriceMicros;

  /// When this item is currently linked to a prescription item of the active
  /// prescription, the remaining (not-yet-dispensed) base quantity on it.
  final bool isRxLinked;
  final int? rxRemainingBase;

  /// True when the item is fully configured for partial selling.
  bool get partialSaleConfigured =>
      partialSaleEnabled &&
      partsPerFullProduct != null &&
      sellablePartBaseQuantity != null &&
      partialSaleMarkupBasisPoints != null;

  /// Retail price per single base unit (large price ÷ units in large).
  /// Integer micro-units, half-up rounding (anchored in §8/§23).
  int get baseUnitPriceMicros =>
      unitsPerLarge <= 0
          ? 0
          : Money.fromUnits(sellingPriceMicros).divideBy(unitsPerLarge).units;

  /// Best available base-unit retail price: the configured sub-unit price when
  /// present, otherwise the derived [baseUnitPriceMicros].
  int get baseUnitSellingPriceMicros => baseUnitPriceMicros;

  String get primaryLabel => (tradeNameEn?.isNotEmpty ?? false)
      ? tradeNameEn!
      : tradeName;

  /// Arabic + English together ("الاسم (English)"); falls back to barcode.
  String get displayName {
    final name = bilingualName(tradeName, tradeNameEn ?? '');
    if (name.isNotEmpty) return name;
    return primaryBarcode ?? tradeName;
  }

  @override
  String toString() =>
      'PosCatalogItem($tradeName, sellingMicros=$sellingPriceMicros, '
      'unitsPerLarge=$unitsPerLarge, available=$availableStockBase)';
}