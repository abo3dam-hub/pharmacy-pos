import '../../core/errors/exceptions.dart';
import '../../core/money/money.dart';

/// Calculates partial-sale pricing and validates partial-sale configuration.
///
/// This service owns the ONLY approved pricing formula (Design Lock §6):
/// ```
/// partialBasePrice = sellingPriceMicros ÷ partsPerFullProduct
/// partialSellingPrice = partialBasePrice × (10000 + markupBasisPoints) ÷ 10000
/// ```
/// It is the price-per-sellable-part source for [PosLinePricer]; it never
/// runs a sellable-part quantity backwards into whole boxes (two-mode pricing
/// lock — "3 parts" is always 3 × the part price, never 1 box).
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
      throw ValidationException('عدد الأجزاء في العبوة يجب أن يكون أكبر من 1');
    }
    if (markupBasisPoints < 0 || markupBasisPoints > 10000) {
      throw ValidationException('نسبة الزيادة يجب أن تكون بين 0% و 100%');
    }

    final basePrice = Money.fromUnits(
      sellingPriceMicros,
    ).divideBy(partsPerFullProduct);
    final sellingPrice = basePrice.timesRatio(10000 + markupBasisPoints, 10000);
    return sellingPrice.units;
  }

  /// Converts a sellable-part quantity to base-unit quantity for inventory.
  ///
  /// Formula (§10.2):
  /// ```
  /// baseQuantity = sellablePartQuantity × sellablePartBaseQuantity
  /// ```
  /// Quantity-only conversion — never money, never part→box reconstruction.
  int convertToBase({
    required int sellablePartQuantity,
    required int sellablePartBaseQuantity,
  }) {
    if (sellablePartQuantity < 0) {
      throw ValidationException('الكمية لا يمكن أن تكون سالبة');
    }
    if (sellablePartBaseQuantity < 1) {
      throw ValidationException(
        'عدد الوحدات في الجزء يجب أن يكون أكبر من أو يساوي 1',
      );
    }
    return sellablePartQuantity * sellablePartBaseQuantity;
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
          'وحدة البيع الجزئي يجب أن تكون فارغة عند تعطيل البيع الجزئي',
        );
      }
      if (partsPerFullProduct != null) {
        throw ValidationException(
          'عدد الأجزاء يجب أن يكون فارغاً عند تعطيل البيع الجزئي',
        );
      }
      if (sellablePartBaseQuantity != null) {
        throw ValidationException(
          'عدد الوحدات يجب أن يكون فارغاً عند تعطيل البيع الجزئي',
        );
      }
      if (partialSaleMarkupBasisPoints != null) {
        throw ValidationException(
          'نسبة الزيادة يجب أن تكون فارغة عند تعطيل البيع الجزئي',
        );
      }
      return;
    }

    // When enabled, all fields are mandatory.
    if (sellablePartUnitId == null || sellablePartUnitId.isEmpty) {
      throw ValidationException('وحدة البيع الجزئي مطلوبة');
    }
    if (partsPerFullProduct == null || partsPerFullProduct <= 1) {
      throw ValidationException('عدد الأجزاء في العبوة يجب أن يكون أكبر من 1');
    }
    if (sellablePartBaseQuantity == null || sellablePartBaseQuantity < 1) {
      throw ValidationException(
        'عدد الوحدات في الجزء يجب أن يكون أكبر من أو يساوي 1',
      );
    }
    if (partialSaleMarkupBasisPoints == null ||
        partialSaleMarkupBasisPoints < 0 ||
        partialSaleMarkupBasisPoints > 10000) {
      throw ValidationException('نسبة الزيادة يجب أن تكون بين 0% و 100%');
    }

    // Full-product consistency invariant (§10.7).
    if (unitsPerLarge != null && unitsPerLarge > 0) {
      final expected = partsPerFullProduct * sellablePartBaseQuantity;
      if (expected != unitsPerLarge) {
        throw ValidationException(
          'خطأ في التنسيق: $partsPerFullProduct × $sellablePartBaseQuantity '
          '= $expected ≠ $unitsPerLarge وحدة في العبوة الكبيرة',
        );
      }
    }
  }
}
