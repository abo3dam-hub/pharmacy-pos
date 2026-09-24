/// A batch approaching (or past) its expiry date.
class ExpiryAlert {
  const ExpiryAlert({
    required this.itemId,
    required this.itemName,
    required this.batchNumber,
    required this.expiryDate,
    required this.quantityBase,
    required this.daysRemaining,
    required this.severity,
  });

  final String itemId;
  final String itemName;
  final String batchNumber;
  final DateTime expiryDate;

  /// Quantity still on hand in base units.
  final int quantityBase;

  /// Negative when already expired.
  final int daysRemaining;
  final ExpirySeverity severity;
}

enum ExpirySeverity {
  /// Already expired.
  expired,

  /// Expires within [ReorderSuggestionsService]-style critical window.
  critical,

  /// Expires within the warning window.
  warning,
}
