/// One joined row for the expenses grid (§4.20 Phase 9): the expense row
/// flattened with its category name/GL account, operator and supplier display
/// names. Money is integer micro-units (scale 4) — never REAL (§23).
class ExpenseListItem {
  const ExpenseListItem({
    required this.id,
    required this.expenseNumber,
    required this.amountMicros,
    required this.categoryCode,
    required this.categoryName,
    required this.categoryAccountCode,
    required this.description,
    required this.expenseDate,
    this.supplierId,
    this.supplierName,
    this.userId,
    this.userName,
    this.receiptPath,
    this.hasReceipt = false,
    this.notes,
    required this.paymentMethod,
    required this.isVoided,
    required this.createdAt,
    required this.updatedAt,
  });

  final String id;
  final String expenseNumber;
  final int amountMicros;
  final String categoryCode;
  final String categoryName;
  final String categoryAccountCode;
  final String description;
  final int expenseDate;
  final String? supplierId;
  final String? supplierName;
  final String? userId;
  final String? userName;
  final String? receiptPath;
  final bool hasReceipt;
  final String? notes;
  final String paymentMethod;
  final bool isVoided;
  final int createdAt;
  final int updatedAt;
}