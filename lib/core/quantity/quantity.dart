/// Stock quantity expressed exclusively in base units.
///
/// The base unit is the single source of truth: all stored stock values use
/// `baseUnits`. Higher-level counts (boxes / fractions) are always derived:
///
/// `boxes = baseUnits ~/ unitsPerLarge`, `fractions = baseUnits % unitsPerLarge`
///
/// A [Quantity] is never negative. Use [QuantityDelta] for signed ledger
/// movements and returns.
class Quantity implements Comparable<Quantity> {
  const Quantity._(this.baseUnits, {required this.unitsPerLarge});

  /// Creates a quantity in base units. [unitsPerLarge] is the number of base
  /// units that make up one "large" unit (e.g. one box = 25 strips).
  factory Quantity.fromBaseUnits(int baseUnits, {int unitsPerLarge = 1}) {
    if (baseUnits < 0) {
      throw ArgumentError.value(
        baseUnits,
        'baseUnits',
        'Quantity cannot be negative. Use QuantityDelta for signed amounts.',
      );
    }
    if (unitsPerLarge <= 0) {
      throw ArgumentError.value(unitsPerLarge, 'unitsPerLarge', 'Must be > 0');
    }
    return Quantity._(baseUnits, unitsPerLarge: unitsPerLarge);
  }

  /// Creates a quantity from whole large units plus a fraction remainder,
  /// e.g. `Quantity.fromBoxesAndFractions(boxes: 3, fractions: 4)` where
  /// `unitsPerLarge` describes how many base units fit in one box.
  factory Quantity.fromBoxesAndFractions({
    required int boxes,
    required int fractions,
    required int unitsPerLarge,
  }) {
    if (boxes < 0 || fractions < 0) {
      throw ArgumentError('boxes and fractions must both be non-negative.');
    }
    if (unitsPerLarge <= 0) {
      throw ArgumentError.value(unitsPerLarge, 'unitsPerLarge', 'Must be > 0');
    }
    if (fractions >= unitsPerLarge) {
      throw ArgumentError(
        'fractions ($fractions) must be < unitsPerLarge ($unitsPerLarge). '
        'Normalize your input first.',
      );
    }
    return Quantity._(
      boxes * unitsPerLarge + fractions,
      unitsPerLarge: unitsPerLarge,
    );
  }

  /// Total base units.
  final int baseUnits;

  /// Base units contained in one "large" unit.
  final int unitsPerLarge;

  int get boxes => baseUnits ~/ unitsPerLarge;

  int get fractions => baseUnits % unitsPerLarge;

  bool get isZero => baseUnits == 0;

  bool get isPositive => baseUnits > 0;

  Quantity operator +(Quantity other) {
    _ensureSameUnits(other);
    return Quantity.fromBaseUnits(
      baseUnits + other.baseUnits,
      unitsPerLarge: unitsPerLarge,
    );
  }

  Quantity operator -(Quantity other) {
    _ensureSameUnits(other);
    return Quantity.fromBaseUnits(
      baseUnits - other.baseUnits,
      unitsPerLarge: unitsPerLarge,
    );
  }

  Quantity operator *(int factor) =>
      Quantity.fromBaseUnits(baseUnits * factor, unitsPerLarge: unitsPerLarge);

  /// Returns a quantity with the same amount expressed in a different
  /// [unitsPerLarge] partitioning.
  Quantity withUnitsPerLarge(int newUnitsPerLarge) => Quantity.fromBaseUnits(
        baseUnits,
        unitsPerLarge: newUnitsPerLarge,
      );

  void _ensureSameUnits(Quantity other) {
    if (unitsPerLarge != other.unitsPerLarge) {
      throw ArgumentError(
        'Cannot combine quantities with different unitsPerLarge '
        '($unitsPerLarge vs ${other.unitsPerLarge}). '
        'Normalize using withUnitsPerLarge first.',
      );
    }
  }

  /// Whether subtracting [other] would keep the result non-negative.
  bool canSubtract(Quantity other) => baseUnits >= other.baseUnits;

  /// Human readable breakdown, e.g. `"3 علب + 4 شرائط"` when labels are given.
  String display({required String boxLabel, required String fractionLabel}) {
    if (isZero) return '0';
    if (fractions == 0) return '$boxes $boxLabel';
    if (boxes == 0) return '$fractions $fractionLabel';
    return '$boxes $boxLabel + $fractions $fractionLabel';
  }

  @override
  int compareTo(Quantity other) => baseUnits.compareTo(other.baseUnits);

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is Quantity &&
          other.baseUnits == baseUnits &&
          other.unitsPerLarge == unitsPerLarge);

  @override
  int get hashCode => Object.hash(baseUnits, unitsPerLarge);

  @override
  String toString() => 'Quantity($baseUnits base, $unitsPerLarge/large)';
}

/// A signed quantity delta used for stock movements, returns and adjustments.
class QuantityDelta implements Comparable<QuantityDelta> {
  const QuantityDelta._(this.baseUnits);

  /// Creates a signed delta; may be negative.
  factory QuantityDelta.fromBaseUnits(int baseUnits) =>
      QuantityDelta._(baseUnits);

  /// A positive delta of [quantity] base units.
  factory QuantityDelta.adding(Quantity quantity) =>
      QuantityDelta._(quantity.baseUnits);

  /// A negative delta of [quantity] base units.
  factory QuantityDelta.removing(Quantity quantity) =>
      QuantityDelta._(-quantity.baseUnits);

  final int baseUnits;

  bool get isZero => baseUnits == 0;

  bool get isPositive => baseUnits > 0;

  bool get isNegative => baseUnits < 0;

  QuantityDelta operator +(QuantityDelta other) =>
      QuantityDelta._(baseUnits + other.baseUnits);

  QuantityDelta operator -(QuantityDelta other) =>
      QuantityDelta._(baseUnits - other.baseUnits);

  QuantityDelta negate() => QuantityDelta._(-baseUnits);

  QuantityDelta abs() => QuantityDelta._(baseUnits.abs());

  Quantity toQuantity({int unitsPerLarge = 1}) {
    if (isNegative) {
      throw StateError('Cannot convert a negative delta to a Quantity.');
    }
    return Quantity.fromBaseUnits(baseUnits, unitsPerLarge: unitsPerLarge);
  }

  @override
  int compareTo(QuantityDelta other) => baseUnits.compareTo(other.baseUnits);

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is QuantityDelta && other.baseUnits == baseUnits);

  @override
  int get hashCode => baseUnits.hashCode;

  @override
  String toString() => 'QuantityDelta($baseUnits)';
}