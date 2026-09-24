/// Smart reorder suggestion based on sales velocity.
///
/// Unlike a static min-stock threshold, this looks at how fast the item
/// actually sells and estimates how many days the current stock will last.
class ReorderSuggestion {
  const ReorderSuggestion({
    required this.itemId,
    required this.itemName,
    required this.currentStockBase,
    required this.avgDailySalesBase,
    required this.daysOfCover,
    required this.suggestedQtyBase,
    required this.urgency,
  });

  final String itemId;
  final String itemName;

  /// Current on-hand quantity in base units.
  final int currentStockBase;

  /// Average units sold per day over the analysis window, in base units.
  final double avgDailySalesBase;

  /// Estimated days until stock-out at current velocity.
  /// `double.infinity` when the item has no recent sales.
  final double daysOfCover;

  /// Suggested purchase quantity in base units.
  final int suggestedQtyBase;

  final ReorderUrgency urgency;
}

/// How urgently the item needs reordering.
enum ReorderUrgency {
  /// Out of stock (or will run out within [criticalDays]).
  critical,

  /// Will run out within [warningDays].
  warning,

  /// Below the item's static min-stock but velocity is low.
  low,
}
