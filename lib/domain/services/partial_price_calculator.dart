import '../../core/errors/exceptions.dart';
import '../../core/money/money.dart';

/// Decomposition of a sellable-quantity request into full products + remaining
/// parts for pricing purposes (Design Lock §8.4).
class PartialSaleDecomposition {
  const PartialSaleDecomposition({
    required this.completeProducts,
    required this.remainingParts,
    required this.totalBaseQuantity,
    required this.totalPriceMicros,
  });

  /// Number of complete products (sold at full retail price).
  final int completeProducts;

  /// Number of remaining sellable parts (sold at partial selling price).
  final int remainingParts;

  /// Total base-unit quantity for inventory deduction.
  final int totalBaseQuantity;

  /// Total price in micro-units.
  final int totalPriceMicros;
}

/// Calculates partial-sale pricing and validates partial-sale configuration.
///
/// This service owns the ONLY approved pricing formula (Design Lock §6):
/// ```
/// partialBasePrice = sellingPriceMicros ÷ partsPerFullProduct
/// partialSellingPrice = partialBasePrice × (10000 + markupBasisPoints) ÷ 10000
/// ```
///
/// It also validates the full-product consistency invariant (Design Lock §10.7):
/// ```
/// partsPerFullProduct × sellablePartBaseQuantity = unitsPerLarge
/// ```
class PartialPriceCalculator {
  const PartialPriceCalculator();

  /// Calculates the partial unit selling price in micro-units.
  ///
  /// Formula (§6):
  /// 1. partialBasePrice = sellingPriceMicros ÷ partsPerFullProduct (half-up)
  /// 2. partialSellingPrice = partialBasePrice × (10000 + markupBasisPoints) ÷ 10000 (half-up)
  int calculatePartialPrice({
    required int sellingPriceMicros,
    required int partsPerFullProduct,
    required int markupBasisPoints,
  }) {
    if (partsPerFullProduct <= 1) {
      throw ValidationException(
          'عدد الأجزاء في العبوة يجب أن يكون أكبر من 1');
    }
    if (markupBasisPoints < 0 || markupBasisPoints > 10000) {
      throw ValidationException(
          'نسبة الزيادة يجب أن تكون بين 0% و 100%');
    }

    final basePrice =
        Money.fromUnits(sellingPriceMicros).divideBy(partsPerFullProduct);
    final sellingPrice =
        basePrice.timesRatio(10000 + markupBasisPoints, 10000);
    return sellingPrice.units;
  }

  /// Converts a sellable-part quantity to base-unit quantity for inventory.
  ///
  /// Formula (§10.2):
  /// ```
  /// baseQuantity = sellablePartQuantity × sellablePartBaseQuantity
  /// ```
  int convertToBase({
    required int sellablePartQuantity,
    required int sellablePartBaseQuantity,
  }) {
    if (sellablePartQuantity < 0) {
      throw ValidationException('الكمية لا يمكن أن تكون سالبة');
    }
    if (sellablePartBaseQuantity < 1) {
      throw ValidationException(
          'عدد الوحدات الأساسية في الجزء يجب أن يكون أكبر من أو يساوي 1');
    }
    return sellablePartQuantity * sellablePartBaseQuantity;
  }

  /// Decomposes a quantity of sellable parts into full products + remainder
  /// and calculates the total price.
  ///
  /// Algorithm (§8.4):
  /// ```
  /// completeProducts = quantity ÷ partsPerFullProduct
  /// remainingParts = quantity % partsPerFullProduct
  /// total = (completeProducts × fullRetailPrice) + (remainingParts × partialSellingPrice)
  /// ```
  ///
  /// Inventory deduction:
  /// ```
  /// totalBaseQuantity = quantity × sellablePartBaseQuantity
  /// ```
  PartialSaleDecomposition decompose({
    required int quantityParts,
    required int partsPerFullProduct,
    required int sellablePartBaseQuantity,
    required int fullRetailPriceMicros,
    required int partialSellingPriceMicros,
  }) {
    if (quantityParts <= 0) {
      throw ValidationException('الكمية المطلوبة يجب أن تكون موجبة');
    }
    if (partsPerFullProduct <= 1) {
      throw ValidationException(
          'عدد الأجزاء في العبوة يجب أن يكون أكبر من 1');
    }
    if (sellablePartBaseQuantity < 1) {
      throw ValidationException(
          'عدد الوحدات الأساسية في الجزء يجب أن يكون أكبر من أو يساوي 1');
    }

    final completeProducts = quantityParts ~/ partsPerFullProduct;
    final remainingParts = quantityParts % partsPerFullProduct;

    final fullProductTotal = completeProducts * fullRetailPriceMicros;
    final partialTotal = remainingParts * partialSellingPriceMicros;
    final totalPrice = fullProductTotal + partialTotal;

    final totalBaseQuantity = quantityParts * sellablePartBaseQuantity;

    return PartialSaleDecomposition(
      completeProducts: completeProducts,
      remainingParts: remainingParts,
      totalBaseQuantity: totalBaseQuantity,
      totalPriceMicros: totalPrice,
    );
  }

  /// Validates a partial-sale configuration for an item.
  ///
  /// When [partialSaleEnabled] is false, all partial-sale fields must be null.
  /// When true, all fields are mandatory and must satisfy constraints.
  ///
  /// Also validates the full-product consistency invariant (§10.7) when
  /// [unitsPerLarge] is provided.
  void validate({
    required bool partialSaleEnabled,
    String? sellablePartUnitId,
    int? partsPerFullProduct,
    int? sellablePartBaseQuantity,
    int? partialSaleMarkupBasisPoints,
    int? unitsPerLarge,
  }) {
    if (!partialSaleEnabled) {
      // When disabled, partial-sale fields must be null.
      if (sellablePartUnitId != null) {
        throw ValidationException(
            'وحدة البيع الجزئي يجب أن تكون فارغة عند تعطيل البيع الجزئي');
      }
      if (partsPerFullProduct != null) {
        throw ValidationException(
            'عدد الأجزاء يجب أن يكون فارغاً عند تعطيل البيع الجزئي');
      }
      if (sellablePartBaseQuantity != null) {
        throw ValidationException(
            'عدد الوحدات الأساسية يجب أن يكون فارغاً عند تعطيل البيع الجزئي');
      }
      if (partialSaleMarkupBasisPoints != null) {
        throw ValidationException(
            'نسبة الزيادة يجب أن تكون فارغة عند تعطيل البيع الجزئي');
      }
      return;
    }

    // When enabled, all fields are mandatory.
    if (sellablePartUnitId == null || sellablePartUnitId.isEmpty) {
      throw ValidationException('وحدة البيع الجزئي مطلوبة');
    }
    if (partsPerFullProduct == null || partsPerFullProduct <= 1) {
      throw ValidationException(
          'عدد الأجزاء في العبوة يجب أن يكون أكبر من 1');
    }
    if (sellablePartBaseQuantity == null || sellablePartBaseQuantity < 1) {
      throw ValidationException(
          'عدد الوحدات الأساسية في الجزء يجب أن يكون أكبر من أو يساوي 1');
    }
    if (partialSaleMarkupBasisPoints == null ||
        partialSaleMarkupBasisPoints < 0 ||
        partialSaleMarkupBasisPoints > 10000) {
      throw ValidationException(
          'نسبة الزيادة يجب أن تكون بين 0% و 100%');
    }

    // Full-product consistency invariant (§10.7).
    if (unitsPerLarge != null && unitsPerLarge > 0) {
      final expected = partsPerFullProduct * sellablePartBaseQuantity;
      if (expected != unitsPerLarge) {
        throw ValidationException(
            'خطأ في التنسيق: $partsPerFullProduct × $sellablePartBaseQuantity '
            '= $expected ≠ $unitsPerLarge وحدة في العبوة الكبيرة');
      }
    }
  }
}
