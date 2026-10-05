import 'package:flutter_test/flutter_test.dart';
import 'package:pharmacy_pos/core/units/package_cost.dart';

/// Display-basis contract: the pharmacist thinks in commercial packages,
/// so quantities are shown per package when they divide evenly.
void main() {
  group('formatBaseQuantity', () {
    test('shows package count when divisible', () {
      expect(formatBaseQuantity(150, 3), '50');
      expect(formatBaseQuantity(144, 3), '48');
      expect(formatBaseQuantity(6, 3), '2');
    });

    test('falls back to base units when not divisible', () {
      expect(formatBaseQuantity(7, 3), '7');
      expect(formatBaseQuantity(1, 3), '1');
    });

    test('handles negatives (movement deltas)', () {
      expect(formatBaseQuantity(-6, 3), '-2');
      expect(formatBaseQuantity(-7, 3), '-7');
    });

    test('unitsPerLarge <= 1 shows raw quantity', () {
      expect(formatBaseQuantity(150, 1), '150');
      expect(formatBaseQuantity(150, 0), '150');
      expect(formatBaseQuantity(150, -2), '150');
    });

    test('zero stays zero', () {
      expect(formatBaseQuantity(0, 3), '0');
    });
  });

  group('baseUnitCostToPackageCost', () {
    test("Ali's scenario: 60 base x 3 = 180 package", () {
      expect(baseUnitCostToPackageCost(60000000, 3), 180000000);
    });

    test('no package means identity', () {
      expect(baseUnitCostToPackageCost(60000000, 1), 60000000);
    });
  });

  group('formatMixedQuantity', () {
    test('whole packages show as a plain count', () {
      expect(formatMixedQuantity(150, 3), '50');
      expect(formatMixedQuantity(90, 3), '30');
      expect(formatMixedQuantity(0, 3), '0');
    });

    test("Ali's scenario: 86 base of a 3-per-box item shows 28/2", () {
      expect(formatMixedQuantity(86, 3), '28/2');
      expect(formatMixedQuantity(83, 3), '27/2');
      expect(formatMixedQuantity(85, 3), '28/1');
    });

    test('unitsPerLarge <= 1 shows raw quantity', () {
      expect(formatMixedQuantity(86, 1), '86');
      expect(formatMixedQuantity(86, 0), '86');
    });
  });
}
