/// Fixed-point monetary value.
///
/// Money is stored as an integer count of micro-units (10^[_scale] units per
/// currency unit, default scale 4). All arithmetic is integer-only. Floating
/// point (`double`) and SQLite `REAL` columns are deliberately never used for
/// money.
class Money implements Comparable<Money> {
    const Money.zero() : _units = 0;

  /// Creates a [Money] from a canonical micro-unit count.
  const Money.fromUnits(this._units);

  /// Creates a [Money] from an amount given in whole currency units.
  Money.fromMajor(int major) : _units = major * _scaleDivisor();

  /// Creates a [Money] from a decimal string such as `"1250.50"`.
  ///
  /// At most [scale] decimal places are allowed; more fractional digits are
  /// rounded half-up. ASCII grouping commas (e.g. `"10,000.50"`) are accepted
  /// so that values rendered by [format] round-trip back into [parse] — the
  /// documented `"956,000.00"` bug cure (§P17: edit forms failing with the
  /// generic save error because the seeded `format()` output could not be
  /// parsed back).
  factory Money.parse(String value) {
    final normalize = value.trim();
    if (normalize.isEmpty) {
      throw const FormatException('Cannot parse an empty Money string.');
    }
    final isNegative = normalize.startsWith('-');
    final unsigned = isNegative || normalize.startsWith('+')
        ? normalize.substring(1)
        : normalize;
    final dotIndex = unsigned.indexOf('.');
    String majorPart;
    String minorPart;
    if (dotIndex == -1) {
      majorPart = unsigned;
      minorPart = '';
    } else {
      majorPart = unsigned.substring(0, dotIndex);
      minorPart = unsigned.substring(dotIndex + 1);
      if (minorPart.contains('.')) {
        throw FormatException('Invalid Money string: $value');
      }
    }
    // Accept the ASCII thousand-group separators emitted by [format] (e.g.
    // `1,250.50`). Each comma must sit at the head of a 3-digit group in the
    // major part; anything else (`12,50`, `,250`) is rejected. Without this,
    // form fields seeded from `Money.fromUnits(...).format()` could never be
    // re-parsed on save — the round-trip surfaced as a generic save error.
    if (majorPart.contains(',')) {
      final groups = majorPart.split(',');
      final validGrouping = groups.length >= 2 &&
          groups.first.isNotEmpty &&
          groups.skip(1).every((g) => g.length == 3 && _isDigits(g));
      if (!validGrouping) {
        throw FormatException('Invalid Money string: $value');
      }
      majorPart = groups.join();
    }
    final major = int.tryParse(majorPart);
    if (major == null || (minorPart.isNotEmpty && !_isDigits(minorPart))) {
      throw FormatException('Invalid Money string: $value');
    }
    var minor = minorPart.isEmpty ? 0 : int.parse(minorPart);
    if (minorPart.length > scale) {
      // Round half-up to the supported scale.
      final excess = minorPart.substring(scale);
      minor = int.parse(minorPart.substring(0, scale));
      if (int.parse(excess[0]) >= 5) {
        minor += 1;
      }
    } else {
      minor *= _tenPower(scale - minorPart.length);
    }
    final units = major * _scaleDivisor() + minor;
    return Money.fromUnits(isNegative ? -units : units);
  }

  static bool _isDigits(String s) =>
      s.isNotEmpty && s.codeUnits.every((c) => _digitCodes.contains(c));

  static final Set<int> _digitCodes = {
    for (var i = 0x30; i <= 0x39; i++) i,
  };

  /// Number of decimal places supported by [Money] (4 → micro-units).
  static const int scale = 4;

  static const int _scaleDivisorCache = 10000;

  static int _scaleDivisor([int? places]) {
    if (places == null || places == scale) return _scaleDivisorCache;
    final factor = _scaleDivisorCache ~/ _tenPower(places);
    if (factor <= 0) {
      throw ArgumentError.value(places, 'places', 'Unsupported scale');
    }
    return factor;
  }

  static int _tenPower(int n) {
    var result = 1;
    for (var i = 0; i < n; i++) {
      result *= 10;
    }
    return result;
  }

  /// Canonical integer value: count of [scale]inary units.
  final int _units;

  /// Canonical integer micro-unit value.
  int get units => _units;

  int get micros => _units;

  bool get isZero => _units == 0;

  bool get isNegative => _units < 0;

  bool get isPositive => _units > 0;

  Money get abs => Money.fromUnits(_units.abs());

  Money get negate => Money.fromUnits(-_units);

  Money operator +(Money other) => Money.fromUnits(_units + other._units);

  Money operator -(Money other) => Money.fromUnits(_units - other._units);

  Money operator *(int factor) => Money.fromUnits(_units * factor);

  /// Divides by an integer factor, rounding half-up.
  Money divideBy(int factor) {
    if (factor <= 0) {
      throw ArgumentError.value(factor, 'factor', 'Must be positive');
    }
    return Money.fromUnits(_roundDiv(_units, factor));
  }

  /// Multiplies by the ratio [numerator]/[denominator], rounding half-up.
  ///
  /// Used by [Percent] and for proportional cost allocation without ever
  /// leaving the integer domain.
  Money timesRatio(int numerator, int denominator) {
    if (denominator <= 0) {
      throw ArgumentError.value(denominator, 'denominator', 'Must be positive');
    }
    return Money.fromUnits(_roundDiv(_units * numerator, denominator));
  }

  /// Rounds this amount to [decimalPlaces] decimals (half-up). The result is
  /// still represented in canonical micro-units.
  Money roundTo(int decimalPlaces) {
    if (decimalPlaces < 0 || decimalPlaces > scale) {
      throw ArgumentError.value(decimalPlaces, 'decimalPlaces');
    }
    final step = _tenPower(scale - decimalPlaces);
    if (step == 1) return this;
    return Money.fromUnits(_roundDiv(_units, step) * step);
  }

  /// Largest amount not exceeding this amount that is a whole multiple of
  /// [decimalPlaces] decimals. Mirrors `SQL ROUND(..., mode)` floor.
  Money floorTo(int decimalPlaces) {
    final step = _tenPower(scale - decimalPlaces);
    final floored = _units >= 0 ? _units ~/ step * step : -((-_units) ~/ step) * step;
    return Money.fromUnits(floored);
  }

  /// Sum of this amount plus `percent` of it.
  Money addPercent(int basisPoints) =>
      this + timesRatio(basisPoints, 10000);

  /// This amount minus `percent` of it.
  Money minusPercent(int basisPoints) =>
      this - timesRatio(basisPoints, 10000);

  bool operator >(Money other) => _units > other._units;
  bool operator >=(Money other) => _units >= other._units;
  bool operator <(Money other) => _units < other._units;
  bool operator <=(Money other) => _units <= other._units;

  @override
  int compareTo(Money other) => _units.compareTo(other._units);

  @override
  bool operator ==(Object other) =>
      identical(this, other) || (other is Money && other._units == _units);

  @override
  int get hashCode => _units.hashCode;

  /// Formats with a fixed number of decimal places, e.g. `"1250.50"`.
  String format([int decimalPlaces = 2]) {
    if (decimalPlaces < 0 || decimalPlaces > scale) {
      throw ArgumentError.value(decimalPlaces, 'decimalPlaces');
    }
    final step = _tenPower(scale - decimalPlaces);
    final scaled = _roundDiv(_units, step);
    final factor = _tenPower(decimalPlaces);
    final magMajor = scaled.abs() ~/ factor;
    final magMinor = scaled.abs() % factor;
    final minorText = decimalPlaces == 0
        ? ''
        : magMinor.toString().padLeft(decimalPlaces, '0');
    final digits = magMajor.toString().replaceAllMapped(
        RegExp(r'(\d)(?=(\d{3})+(?!\d))'), (m) => '${m[1]},');
    final isNegative = _units < 0;
    if (minorText.isEmpty) return isNegative ? '-$digits' : digits;
    return isNegative ? '-$digits.$minorText' : '$digits.$minorText';
  }

  /// Formats an amount for an Arabic UI string while keeping Western/Latin
  /// digits (0-9) and the ASCII separators (`,`/`.`), per §23: Arabic-first
  /// UI + RTL layout, but numbers are always written in Latin digits — the
  /// Arabic-Indic digit set (٠-٩) is never emitted. Kept as a named hook so
  /// call sites express intent; it equals [format].
  String formatArabicDigits([int decimalPlaces = 2]) =>
      format(decimalPlaces);

  /// Rounds half-up to whole currency units.
  Money roundToWhole() => roundTo(0);

  @override
  String toString() => 'Money(${format(scale)})';
}

int _roundDiv(int a, int b) {
  if (b <= 0) {
    throw ArgumentError.value(b, 'b', 'Must be positive');
  }
  final half = b ~/ 2;
  if (a >= 0) {
    return (a + half) ~/ b;
  }
  return -((-a + half) ~/ b);
}