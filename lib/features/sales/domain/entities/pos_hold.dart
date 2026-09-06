import '../entities/pos_cart.dart';

/// An immutable hold-bill snapshot (§5 hold bill / F5): the complete workspace
/// state of one customer tab at hold time — cart lines, selected customer and
/// prescription. Holding never mutates stock; restoring re-validates the cart
/// against current availability.
class PosHeldBill {
  const PosHeldBill({
    required this.id,
    required this.label,
    required this.customerId,
    required this.customerName,
    required this.prescriptionId,
    required this.cart,
    required this.heldAtMillis,
  });

  final String id;
  final String label;
  final String? customerId;
  final String? customerName;
  final String? prescriptionId;

  /// Hold preserves the full cart intent (lines + quantities + modes).
  final List<PosCartLine> cart;
  final int heldAtMillis;

  /// Restorable snapshot used by the tab restore action.
  String get timestampLabel =>
      DateTime.fromMillisecondsSinceEpoch(heldAtMillis).toIso8601String();
}