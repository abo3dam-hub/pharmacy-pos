import 'package:flutter_test/flutter_test.dart';
import 'package:pharmacy_pos/core/errors/exceptions.dart';
import 'package:pharmacy_pos/domain/services/bonus_calculator.dart';

void main() {
  const calc = BonusCalculator();

  group('BonusCalculator effective quantity (§13)', () {
    test('100 + 10 + 5 + 2 = 117', () {
      final r = calc.calculate(
        purchasedQuantityBase: 100,
        bonusesBase: [10, 5, 2],
        totalCostMicros: 1_000_000,
      );
      expect(r.effectiveQuantityBase, 117);
      expect(r.bonusQuantityBase, 17);
    });

    test('no bonuses = purchased quantity', () {
      expect(
        calc.effectiveQuantity(purchasedQuantityBase: 50),
        50,
      );
    });

    test('rejects unpaid quantity', () {
      expect(
        () => calc.calculate(
            purchasedQuantityBase: 0, totalCostMicros: 0),
        throwsA(isA<ValidationException>()),
      );
    });
  });

  group('true effective unit cost', () {
    test('117 units for 100.00 → ≈0.8547 each (integer half-up)', () {
      const totalCostMicros = 100 * 10000; // 100.00
      final cost = calc.effectiveUnitCostMicros(
        totalCostMicros: totalCostMicros,
        effectiveQuantityBase: 117,
      );
      // 1,000,000 / 117 = 8547.0085… → 8547 micros
      expect(cost, 8547);
      // Batch must never be valued above what was actually paid (§8/§13).
      final reconstructed = cost * 117;
      expect(reconstructed, lessThanOrEqualTo(totalCostMicros));
      expect(reconstructed, greaterThanOrEqualTo(totalCostMicros - 116));
    });

    test('flat cost splits evenly', () {
      expect(
        calc.effectiveUnitCostMicros(
          totalCostMicros: 90_000, // 9.00
          effectiveQuantityBase: 9,
        ),
        10_000, // 1.00 each
      );
    });
  });
}