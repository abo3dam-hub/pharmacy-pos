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
/// Rules (Design Lock §6/§8.4):
///  * partial-sale item, fraction sale: decompose parts into complete products
///    (full retail price, no markup) + remaining parts (partial selling price);
///  * partial-sale item, box sale: full retail price per box (no markup);
///  * non-partial item: boxes at full retail, base units at the base price.
///  * the 10% partial markup is applied exactly once — never to full products.
class PosLinePricer {
  const PosLinePricer({PartialPriceCalculator? partialPrices})
      : _partialPrices = partialPrices ?? const PartialPriceCalculator();

  final PartialPriceCalculator _partialPrices;

  /// Prices a single cart line into engine input lines + money summary.
  PosLinePricing priceLine(PosCartLine line) {
    final item = line.item;
    final unitsPerLarge = item.unitsPerLarge > 0 ? item.unitsPerLarge : 1;

    final override = line.priceOverrideMicros;
    final saleLines = <PosSaleLineInput>[];

    if (item.partialSaleConfigured) {
      final partsPerFull = item.partsPerFullProduct!;
      final sellableBase = item.sellablePartBaseQuantity!;

      if (line.unitMode == PosLineUnitMode.sellablePart) {
        final completeProducts = line.quantity ~/ partsPerFull;
        final remainingParts = line.quantity % partsPerFull;

        // Complete boxes: full retail price per box, never the partial markup.
        if (completeProducts > 0) {
          saleLines.add(PosSaleLineInput(
            itemId: item.id,
            quantityBase: completeProducts * unitsPerLarge,
            unitPriceMicros: override ?? item.baseUnitPriceMicros,
            unitTypeId: item.largeUnitId,
            vatRateBasisPoints: item.vatRateBasisPoints,
            discountBasisPoints: line.discountBasisPoints,
            prescriptionItemId: line.prescriptionItemId,
          ));
        }

        // Remaining strips: partial selling price (markup applied once).
        if (remainingParts > 0) {
          final partialPricePerPart = partialSellingPricePerPart(item);
          final partialPricePerBase =
              Money.fromUnits(partialPricePerPart)
                  .divideBy(sellableBase)
                  .units;
          saleLines.add(PosSaleLineInput(
            itemId: item.id,
            quantityBase: remainingParts * sellableBase,
            unitPriceMicros: partialPricePerBase,
            unitTypeId: item.sellablePartUnitId!,
            vatRateBasisPoints: item.vatRateBasisPoints,
            discountBasisPoints: line.discountBasisPoints,
            prescriptionItemId: line.prescriptionItemId,
            partialSaleUnitPriceMicros: partialPricePerBase,
          ));
        }
      } else {
        // Whole boxes even for partial-sale items → full retail, no markup.
        saleLines.add(PosSaleLineInput(
          itemId: item.id,
          quantityBase: line.quantity * unitsPerLarge,
          unitPriceMicros: item.baseUnitPriceMicros,
          unitTypeId: item.largeUnitId,
          vatRateBasisPoints: item.vatRateBasisPoints,
          discountBasisPoints: line.discountBasisPoints,
          prescriptionItemId: line.prescriptionItemId,
        ));
      }
    } else {
      final isBox = line.unitMode == PosLineUnitMode.largeUnit;
      saleLines.add(PosSaleLineInput(
        itemId: item.id,
        quantityBase: isBox ? line.quantity * unitsPerLarge : line.quantity,
        unitPriceMicros:
            isBox ? item.baseUnitPriceMicros : item.baseUnitSellingPriceMicros,
        unitTypeId: isBox ? item.largeUnitId : item.baseUnitId,
        vatRateBasisPoints: item.vatRateBasisPoints,
        discountBasisPoints: line.discountBasisPoints,
        prescriptionItemId: line.prescriptionItemId,
      ));
    }

    return _summarize(line, saleLines);
  }

  /// Partial selling price per sellable part for the given configured item —
  /// computed through the single approved formula (Design Lock §6).
  int partialSellingPricePerPart(PosCatalogItem item) {
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
      final gross = input.unitPriceMicros * input.quantityBase;
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