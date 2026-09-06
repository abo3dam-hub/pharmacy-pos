import '../entities/pos_cart.dart';
import 'pos_pricing.dart';

/// Builds aggregate cart totals for the current [PosCartLine] list using the
/// production price engine. Pure Dart — consumed by the workspace controller
/// and the payment panel preview.
class PosCartTotalsBuilder {
  const PosCartTotalsBuilder({PosLinePricer? pricer})
      : _pricer = pricer ?? const PosLinePricer();

  final PosLinePricer _pricer;

  List<PosLinePricing> priceLines(List<PosCartLine> cart) =>
      [for (final line in cart) _pricer.priceLine(line)];

  PosCartTotals totals(List<PosCartLine> cart) {
    var subtotal = 0;
    var discount = 0;
    var vat = 0;
    var baseQty = 0;
    for (final p in priceLines(cart)) {
      subtotal += p.grossMicros;
      discount += p.discountMicros;
      vat += p.vatMicros;
      baseQty += p.quantityBase;
    }
    return PosCartTotals(
      subtotalMicros: subtotal,
      discountTotalMicros: discount,
      vatTotalMicros: vat,
      totalMicros: subtotal - discount + vat,
      totalBaseQuantity: baseQty,
    );
  }

  /// Flat engine-ready line list for a whole cart (used to build the
  /// checkout command). Preserves rotation order for FEFO allocation.
  List<PosSaleLineInput> flatten(List<PosCartLine> cart) =>
      [for (final p in priceLines(cart)) ...p.lines];
}