import 'money.dart';

/// Fractional percentage expressed as a whole number of basis points
/// (100 basis points = 1%). All rate arithmetic is integer-only.
class Percent implements Comparable<Percent> {
  const Percent(this.basisPoints);

  const Percent.zero() : basisPoints = 0;

  /// Convenience constructor for whole percentages (e.g. `15` → 15%).
  const Percent.percent(int wholePercent) : basisPoints = wholePercent * 100;

  /// A percentage stored as basis points (e.g. `1500` → 15.00%).
  final int basisPoints;

  bool get isZero => basisPoints == 0;

  bool get isNegative => basisPoints < 0;

  /// Returns `basisPoints / 10000` rounded-half-up as a [Money].
  Money of(Money amount) => amount.timesRatio(basisPoints, 10000);

  /// `amount + percent% * amount`.
  Money addTo(Money amount) => amount + of(amount);

  /// `amount - percent% * amount`.
  Money subtractFrom(Money amount) => amount - of(amount);

  Percent operator +(Percent other) =>
      Percent(basisPoints + other.basisPoints);

  Percent operator -(Percent other) =>
      Percent(basisPoints - other.basisPoints);

  Percent operator *(int factor) => Percent(basisPoints * factor);

  Percent normalize() {
    // Clamp into [0, 10000] keeping the sign convention simple for rates.
    if (basisPoints == 0) return this;
    return Percent(((basisPoints % 10000) + 10000) % 10000);
  }

  @override
  int compareTo(Percent other) => basisPoints.compareTo(other.basisPoints);

  @override
  bool operator ==(Object other) =>
      identical(this, other) || (other is Percent && other.basisPoints == basisPoints);

  @override
  int get hashCode => basisPoints.hashCode;

  /// Formats as a decimal percentage string preserving up to two decimals,
  /// e.g. `1500` → `"15.00%"`.
  String format() {
    final major = basisPoints ~/ 100;
    final remainder = (basisPoints % 100).abs();
    final remainderText = (remainder == 0)
        ? '00'
        : remainder.toString().padLeft(2, '0');
    return '$major.$remainderText%';
  }

  @override
  String toString() => 'Percent($basisPoints bp)';
}