/// End-of-session report (Z-Report) summary.
///
/// Aggregates a time window across the POS documents: sales invoices
/// (completed / partially-returned, drafts excluded), standalone returns,
/// customer credit payments, voids and the cash-box movements. Drawer values
/// reconcile `opening + net moves = running balance` (cashbox ledger).
class ZReport {
  const ZReport({
    required this.fromMillis,
    required this.toMillis,
    this.userId,
    required this.invoiceCount,
    required this.subtotalMicros,
    required this.discountMicros,
    required this.vatMicros,
    required this.totalMicros,
    required this.paidMicros,
    required this.changeMicros,
    required this.cashMicros,
    required this.cardMicros,
    required this.creditMicros,
    required this.unitsSold,
    required this.voidCount,
    required this.voidTotalMicros,
    required this.returnsCount,
    required this.returnsTotalMicros,
    required this.customerPaidMicros,
    required this.customerRefundMicros,
    required this.drawerOpeningMicros,
    required this.drawerNetMovesMicros,
    required this.lastRemainingMicros,
    this.drawerDeclaredCloseMicros,
  });

  final int fromMillis;
  final int toMillis;
  final String? userId;

  final int invoiceCount;
  final int subtotalMicros;
  final int discountMicros;
  final int vatMicros;
  final int totalMicros;
  final int paidMicros;
  final int changeMicros;
  final int cashMicros;
  final int cardMicros;
  final int creditMicros;
  final int unitsSold;

  final int voidCount;
  final int voidTotalMicros;

  /// Number of (non-voided) return documents and their total reversed amount
  /// as a positive figure.
  final int returnsCount;
  final int returnsTotalMicros;

  /// Customer credit ledger: money received / refunded in the period.
  final int customerPaidMicros;
  final int customerRefundMicros;

  /// Drawer reconciliation over the cash-box ledger.
  final int drawerOpeningMicros;
  final int drawerNetMovesMicros;
  final int lastRemainingMicros;
  final int? drawerDeclaredCloseMicros;

  /// Expected drawer balance at the end of the period.
  int get expectedClosingMicros => drawerOpeningMicros + drawerNetMovesMicros;

  /// Delegated closing minus the expected running balance (null when the
  /// cashier did not declare a closing amount).
  int? get drawerDifferenceMicros => drawerDeclaredCloseMicros == null
      ? null
      : drawerDeclaredCloseMicros! - expectedClosingMicros;
}