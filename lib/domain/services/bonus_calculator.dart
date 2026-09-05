import '../../core/errors/exceptions.dart';
import '../../core/money/money.dart';

/// Resolves the true effective cost of a purchased lot after (possibly
/// multiple) bonus quantities are added (§13 of the plan).
///
/// Effective Quantity = paid quantity + all bonuses.
/// Effective Unit Cost = Total Actual Cost ÷ Total Effective Quantity
/// (integer money, rounded half-up).
class BonusCalculator {
  const BonusCalculator();

  /// Sums the paid quantity and bonus quantities into the effective quantity.
  int effectiveQuantity({
    required int purchasedQuantityBase,
    List<int> bonusesBase = const [],
  }) {
    if (purchasedQuantityBase <= 0) {
      throw ValidationException('الكمية المشتراة يجب أن تكون موجبة');
    }
    for (final b in bonusesBase) {
      if (b < 0) {
        throw ValidationException('كمية الهدية لا يمكن أن تكون سالبة');
      }
    }
    return purchasedQuantityBase + bonusesBase.fold(0, (a, b) => a + b);
  }

  /// Effective unit cost in micro-units (scale 4), rounded half-up.
  ///
  /// `totalCostMicros` must be the *actual paid* cost of the purchased lot
  /// (excluding bonuses).
  int effectiveUnitCostMicros({
    required int totalCostMicros,
    required int effectiveQuantityBase,
  }) {
    if (effectiveQuantityBase <= 0) {
      throw ValidationException(
          'الكمية الفعلية يجب أن تكون موجبة لحساب التكلفة');
    }
    return Money.fromUnits(totalCostMicros).divideBy(effectiveQuantityBase).units;
  }

  /// Convenience result bundling both [effectiveQuantity] and
  /// [effectiveUnitCostMicros].
  BonusCalculation calculate({
    required int purchasedQuantityBase,
    required int totalCostMicros,
    List<int> bonusesBase = const [],
  }) {
    final effective = effectiveQuantity(
      purchasedQuantityBase: purchasedQuantityBase,
      bonusesBase: bonusesBase,
    );
    return BonusCalculation(
      purchasedQuantityBase: purchasedQuantityBase,
      bonusesBase: bonusesBase,
      effectiveQuantityBase: effective,
      effectiveUnitCostMicros: effectiveUnitCostMicros(
        totalCostMicros: totalCostMicros,
        effectiveQuantityBase: effective,
      ),
    );
  }
}

class BonusCalculation {
  const BonusCalculation({
    required this.purchasedQuantityBase,
    required this.bonusesBase,
    required this.effectiveQuantityBase,
    required this.effectiveUnitCostMicros,
  });

  final int purchasedQuantityBase;
  final List<int> bonusesBase;
  final int effectiveQuantityBase;
  final int effectiveUnitCostMicros;

  int get bonusQuantityBase => bonusesBase.fold(0, (a, b) => a + b);

  @override
  String toString() =>
      'BonusCalculation(purchased: $purchasedQuantityBase, '
      'bonus: $bonusQuantityBase, effective: $effectiveQuantityBase, '
      'effUnitCostMicros: $effectiveUnitCostMicros)';
}