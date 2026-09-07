/// Cash Box session state (حالة الصندوق) — the drawer summary consumed by the
/// Phase 8 dashboard. Derived from the `cashbox_transactions` ledger using the
/// reconciliation contract shared with the Z-Report:
///   expectedClosing = opening + netMoves   |   difference = declared − expected
library;

import '../../../../shared/models/enums.dart';

/// Drawer lifecycle state (§41 Phase 8): no session, open session, closed.
enum CashboxStatus { notOpened, open, closed }

/// Placement of a cash movement inside the drawer summary.
enum CashboxDirection { inflow, outflow }

/// Immutable cash-box session snapshot for one drawer opening → closing window.
class CashboxSession {
  const CashboxSession({
    required this.status,
    this.openedByUserId,
    this.openedByUserName,
    this.openedAtMillis,
    required this.openingMicros,
    required this.salesCashMicros,
    required this.refundMicros,
    required this.paymentsMicros,
    required this.depositsMicros,
    required this.withdrawalsMicros,
    required this.expensesMicros,
    required this.adjustmentsMicros,
    required this.netMovesMicros,
    required this.expectedClosingMicros,
    this.closedByUserId,
    this.closedByUserName,
    this.closedAtMillis,
    this.declaredCloseMicros,
    this.differenceMicros,
  });

  /// Empty "no session yet" snapshot (رصيد صفري، لا جلسة مفتوحة).
  factory CashboxSession.notOpened() => const CashboxSession(
        status: CashboxStatus.notOpened,
        openingMicros: 0,
        salesCashMicros: 0,
        refundMicros: 0,
        paymentsMicros: 0,
        depositsMicros: 0,
        withdrawalsMicros: 0,
        expensesMicros: 0,
        adjustmentsMicros: 0,
        netMovesMicros: 0,
        expectedClosingMicros: 0,
      );

  final CashboxStatus status;

  // ── Opening ──
  final String? openedByUserId;
  final String? openedByUserName;
  final int? openedAtMillis;
  final int openingMicros;

  // ── Movements (signed ledger sums for the session window) ──
  /// Net cash taken in by completed cash sales (positive).
  final int salesCashMicros;

  /// Cash refunded out of the drawer (returns / customer refunds / void
  /// reversals) — recorded negative in the ledger.
  final int refundMicros;

  /// Customer on-account collections (cash) — positive.
  final int paymentsMicros;

  /// Manual deposits — positive.
  final int depositsMicros;

  /// Manual withdrawals — negative in the ledger.
  final int withdrawalsMicros;

  /// Expense outflows — negative in the ledger.
  final int expensesMicros;

  /// Authorized adjustments (±).
  final int adjustmentsMicros;

  final int netMovesMicros;
  final int expectedClosingMicros;

  // ── Closing ──
  final String? closedByUserId;
  final String? closedByUserName;
  final int? closedAtMillis;
  final int? declaredCloseMicros;
  final int? differenceMicros;

  /// Cash inflows into the drawer (المقبوضات): sales + deposits + collections
  /// + positive adjustments.
  int get inflowsMicros =>
      salesCashMicros +
      depositsMicros +
      paymentsMicros +
      (adjustmentsMicros > 0 ? adjustmentsMicros : 0);

  /// Cash outflows from the drawer (المدفوعات): refunds + withdrawals +
  /// expenses + negative adjustments, as a positive magnitude.
  int get outflowsMicros =>
      (-refundMicros).clamp(0, 1 << 62) +
      (-withdrawalsMicros).clamp(0, 1 << 62) +
      (-expensesMicros).clamp(0, 1 << 62) +
      (adjustmentsMicros < 0 ? -adjustmentsMicros : 0);

  /// Current running balance shown by the dashboard: the expected closing for
  /// an open session, the declared amount once declared, otherwise expected.
  int get runningBalanceMicros => status == CashboxStatus.closed
      ? (declaredCloseMicros ?? expectedClosingMicros)
      : expectedClosingMicros;

  /// True when the declared closing differs from the expected balance.
  bool get hasDifference => differenceMicros != null && differenceMicros != 0;
}

/// One paged row of the cash-box ledger history (حركة الصندوق) with the
/// operator's display name resolved from the users table.
class CashboxHistoryEntry {
  const CashboxHistoryEntry({
    required this.id,
    required this.type,
    required this.amountMicros,
    required this.remainingMicros,
    required this.refType,
    required this.refId,
    required this.note,
    required this.userId,
    required this.userName,
    required this.createdAt,
  });

  final String id;
  final CashboxTransactionType? type;
  final int amountMicros;
  final int remainingMicros;
  final String? refType;
  final String? refId;
  final String? note;
  final String userId;
  final String userName;
  final int createdAt;

  CashboxDirection get direction =>
      amountMicros < 0 ? CashboxDirection.outflow : CashboxDirection.inflow;

  bool get isDeclaration =>
      type == CashboxTransactionType.open ||
      type == CashboxTransactionType.close;
}