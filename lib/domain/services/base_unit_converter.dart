import '../../core/errors/exceptions.dart';

/// Converts between large/base display units and the single authoritative
/// base-unit integer quantity (§7 of the plan).
///
/// `1` base unit = 1 strip/tablet/fractional unit. A "box" equals
/// [unitsPerLarge] base units, declared per item in `item_units`.
class BaseUnitConverter {
  const BaseUnitConverter();

  /// Converts a mixed display quantity into base units.
  ///
  /// `base = qty_boxes × units_per_large + qty_strips`.
  int toBaseUnits({
    required int boxes,
    required int strips,
    required int unitsPerLarge,
  }) {
    if (boxes < 0 || strips < 0) {
      throw ValidationException('الكميات لا يمكن أن تكون سالبة');
    }
    if (unitsPerLarge <= 0) {
      throw ValidationException('وحدة التعبئة الكبيرة يجب أن تكون موجبة');
    }
    return boxes * unitsPerLarge + strips;
  }

  /// Splits a base-unit quantity into boxes + remainder strips.
  ///
  /// `boxes = base ~/ units_per_large`, `strips = base % units_per_large`.
  BaseUnitBreakdown splitToUnits({
    required int baseUnits,
    required int unitsPerLarge,
  }) {
    if (baseUnits < 0) {
      throw ValidationException('الكمية الأساسية لا يمكن أن تكون سالبة');
    }
    if (unitsPerLarge <= 0) {
      throw ValidationException('وحدة التعبئة الكبيرة يجب أن تكون موجبة');
    }
    return BaseUnitBreakdown(
      boxes: baseUnits ~/ unitsPerLarge,
      strips: baseUnits % unitsPerLarge,
      boxSize: unitsPerLarge,
    );
  }
}

/// A display breakdown derived from a base-unit quantity. Always derived,
/// never stored as two conflicting totals (§7).
class BaseUnitBreakdown {
  const BaseUnitBreakdown({
    required this.boxes,
    required this.strips,
    this.boxSize = 10,
  });

  final int boxes;
  final int strips;

  /// Base units per large (box) unit, required to back-compute [baseUnits].
  final int boxSize;

  int get baseUnits => boxes * boxSize + strips;

  @override
  bool operator ==(Object other) =>
      other is BaseUnitBreakdown &&
      other.boxes == boxes &&
      other.strips == strips &&
      other.boxSize == boxSize;

  @override
  int get hashCode => Object.hash(boxes, strips, boxSize);

  @override
  String toString() => '$boxes boxes + $strips strips';
}