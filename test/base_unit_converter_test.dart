import 'package:flutter_test/flutter_test.dart';
import 'package:pharmacy_pos/core/errors/exceptions.dart';
import 'package:pharmacy_pos/domain/services/base_unit_converter.dart';

void main() {
  const converter = BaseUnitConverter();

  group('toBaseUnits', () {
    test('1 box = 10 strips converts 3 boxes + 4 strips to 34 (spec §7)', () {
      expect(converter.toBaseUnits(boxes: 3, strips: 4, unitsPerLarge: 10), 34);
    });

    test('strips convert 1:1', () {
      expect(converter.toBaseUnits(boxes: 0, strips: 7, unitsPerLarge: 10), 7);
    });

    test('rejects negatives', () {
      expect(
        () => converter.toBaseUnits(boxes: -1, strips: 0, unitsPerLarge: 10),
        throwsA(isA<ValidationException>()),
      );
    });

    test('rejects non-positive unitsPerLarge', () {
      expect(
        () => converter.toBaseUnits(boxes: 1, strips: 0, unitsPerLarge: 0),
        throwsA(isA<ValidationException>()),
      );
    });
  });

  group('splitToUnits', () {
    test('34 base units = 3 boxes + 4 strips', () {
      final split = converter.splitToUnits(baseUnits: 34, unitsPerLarge: 10);
      expect(split, const BaseUnitBreakdown(boxes: 3, strips: 4));
      expect(split.baseUnits, 34);
    });

    test('remainder below one box', () {
      expect(
        converter.splitToUnits(baseUnits: 5, unitsPerLarge: 10),
        const BaseUnitBreakdown(boxes: 0, strips: 5),
      );
    });

    test('full boxes stack cleanly', () {
      expect(
        converter.splitToUnits(baseUnits: 100, unitsPerLarge: 10),
        const BaseUnitBreakdown(boxes: 10, strips: 0),
      );
    });
  });
}