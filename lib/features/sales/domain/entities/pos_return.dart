import '../../../../shared/models/enums.dart';

/// A return document row for the returns list (pure Dart, no Drift types).
class PosReturnView {
  const PosReturnView({
    required this.id,
    required this.returnNumber,
    required this.type,
    required this.originalInvoiceId,
    required this.originalInvoiceNumber,
    this.customerName,
    this.userName = '',
    required this.totalMicros,
    this.reason,
    required this.isVoided,
    required this.createdAt,
  });

  final String id;
  final String returnNumber;
  final ReturnType type;
  final String originalInvoiceId;
  final String originalInvoiceNumber;
  final String? customerName;
  final String userName;

  /// Signed total; negative means money returned to the customer.
  final int totalMicros;
  final String? reason;
  final bool isVoided;
  final int createdAt;
}

/// One line of a return document, for the return detail view.
class PosReturnLineView {
  const PosReturnLineView({
    required this.id,
    required this.itemName,
    required this.quantityBase,
    required this.amountMicros,
    this.reason,
  });

  final String id;
  final String itemName;
  final int quantityBase;
  final int amountMicros;
  final String? reason;
}
