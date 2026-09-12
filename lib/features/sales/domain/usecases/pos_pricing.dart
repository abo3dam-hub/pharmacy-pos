import '../../../../core/money/money.dart';
import '../../../../domain/services/partial_price_calculator.dart';
import '../entities/pos_cart.dart';
import '../entities/pos_catalog_item.dart';

/// The production POS price engine (§5 / Phase 6 Design Lock).
///
/// This is the ONLY sanctioned translation from the cart's "box / fraction"
/// intent into engine-ready sale lines. It replaces the Phase 6 test-only
/// `decomposeIntoSaleLines` helper with the real implementation consumed by the
/// workspace controller.
///
/// Two-mode pricing lock (§5 / Six Sigma Requirement):
///  * box sale (always available): `gross = quantity × full package price` —
///    the commercial selling price, exactly, never reconstructed from the base
///    unit's conversion ratio (that reconstruction is the root cause of the
///    14,000 → 4,667 → 3 × 4,667 = 14,001 → 19,601 bug);
///  * fraction sale (ONLY for products explicitly configured for partial
///    selling): `gross = quantity × partial selling price per part` — never
///    auto-converted back into whole boxes, so 3 parts of a 10-part box are
///    3 × 1,120 = 3,360, not a box;
///  * the explicit part markup (and manual part price) applies only to part
///    sales via [partialSellingPricePerPart] — full boxes never carry it.
class PosLinePricer {
  const PosLinePricer({PartialPriceCalculator? partialPrices})
      : _partialPrices = partialPrices ?? const PartialPriceCalculator();

  final PartialPriceCalculator _partialPrices;

  /// Sells [line] as real sell units: one engine line priced per sell unit
  /// ([PosLineUnitMode.largeUnit] = box at package price, configured
  /// [PosLineUnitMode.sellablePart] = part at partial price). A fraction line
  /// on an item that stopped being partial-configured degrades defensively to
  /// a package line — never to an implicit base-unit sale.
  PosLinePricing priceLine(PosCartLine line) {
    final item = line.item;
    final unitsPerLarge = item.unitsPerLarge > 0 ? item.unitsPerLarge : 1;

    final usePart =
        line.unitMode == PosLineUnitMode.sellablePart && item.partialSaleConfigured;

    final sellUnitBase =
        usePart ? (item.sellablePartBaseQuantity ?? unitsPerLarge) : unitsPerLarge;

    final PosSaleLineInput input;
    if (usePart) {
      input = PosSaleLineInput(
        itemId: item.id,
        quantityBase: line.quantity * sellUnitBase,
        quantity: line.quantity,
        unitBaseQuantity: sellUnitBase,
        unitPriceMicros:
            line.priceOverrideMicros ?? partialSellingPricePerPart(item),
        unitTypeId: item.sellablePartUnitId!,
        vatRateBasisPoints: item.vatRateBasisPoints,
        discountBasisPoints: line.discountBasisPoints,
        prescriptionItemId: line.prescriptionItemId,
      );
    } else {
      input = PosSaleLineInput(
        itemId: item.id,
        quantityBase: line.quantity * sellUnitBase,
        quantity: line.quantity,
        unitBaseQuantity: sellUnitBase,
        unitPriceMicros: line.priceOverrideMicros ?? item.sellingPriceMicros,
        unitTypeId: item.largeUnitId,
        vatRateBasisPoints: item.vatRateBasisPoints,
        discountBasisPoints: line.discountBasisPoints,
        prescriptionItemId: line.prescriptionItemId,
      );
    }

    return _summarize(line, [input]);
  }

  /// Partial selling price per sellable part for the given configured item.
  ///
  /// A pharmacist-set manual price (a persisted [PosCatalogItem.partialSalePriceMicros]
  /// from سعر بيع الجزء) takes precedence until it is cleared; otherwise the
  /// price comes from the single approved formula (Design Lock §6).
  int partialSellingPricePerPart(PosCatalogItem item) {
    final manual = item.partialSalePriceMicros;
    if (manual != null) return manual;
    return _partialPrices.calculatePartialPrice(
      sellingPriceMicros: item.sellingPriceMicros,
      partsPerFullProduct: item.partsPerFullProduct!,
      markupBasisPoints: item.partialSaleMarkupBasisPoints!,
    );
  }

  PosLinePricing _summarize(
    PosCartLine line,
    List<PosSaleLineInput> saleLines,
  ) {
    var grossMicros = 0;
    var discountMicros = 0;
    var vatMicros = 0;
    var quantityBase = 0;
    for (final input in saleLines) {
      final sellUnits = input.quantity ?? input.quantityBase;
      final gross = input.unitPriceMicros * sellUnits;
      final discount = Money.fromUnits(gross)
          .timesRatio(input.discountBasisPoints, 10000)
          .units;
      grossMicros += gross;
      discountMicros += discount;
      vatMicros += Money.fromUnits(gross - discount)
          .timesRatio(input.vatRateBasisPoints, 10000)
          .units;
      quantityBase += input.quantityBase;
    }
    return PosLinePricing(
      line: line,
      lines: saleLines,
      quantityBase: quantityBase,
      grossMicros: grossMicros,
      discountMicros: discountMicros,
      vatMicros: vatMicros,
    );
  }
}