import 'package:drift/drift.dart';

import '../../../core/data_grid/page_request.dart';
import '../../../shared/database/app_database.dart';
import '../../../shared/models/enums.dart';
import '../domain/entities/cashbox_session.dart';

/// Read side of the cash-box ledger (§4.21): derives the drawer session
/// (not opened / open / closed), the reconciliation summary and a paged,
/// DB-side-filtered transaction history.
///
/// The reconciliation formula is identical to the Z-Report DAO contract:
/// `expectedClosing = drawerOpening + drawerNetMoves`,
/// `difference = declaredClose − expectedClosing`. `open` seeds the drawer;
/// `close` is a declaration snapshot and never joins `netMoves`.
class CashboxDao {
  const CashboxDao(this._db);

  final AppDatabase _db;

  /// Derives the current drawer session from the ledger, newest to oldest.
  Future<CashboxSession> currentSession() async {
    final opens = await (_db.select(_db.cashboxTransactions)
          ..where((t) => t.type.equalsValue(CashboxTransactionType.open))
          ..orderBy([(t) => OrderingTerm.desc(t.createdAt)])
          ..limit(1))
        .get();
    if (opens.isEmpty) return CashboxSession.notOpened();
    final open = opens.single;

    final closes = await (_db.select(_db.cashboxTransactions)
          ..where((t) =>
              t.type.equalsValue(CashboxTransactionType.close) &
              t.createdAt.isBiggerThanValue(open.createdAt))
          ..orderBy([(t) => OrderingTerm.desc(t.createdAt)])
          ..limit(1))
        .get();
    final close = closes.isEmpty ? null : closes.single;

    final windowEnd = close?.createdAt ?? _nowMillis();
    final sums = await _typeSums(open.createdAt, windowEnd);

    final opening = open.amountMicros;
    final sales = sums[CashboxTransactionType.sale] ?? 0;
    final refunds = sums[CashboxTransactionType.refund] ?? 0;
    final payments = sums[CashboxTransactionType.payment] ?? 0;
    final deposits = sums[CashboxTransactionType.deposit] ?? 0;
    final withdrawals = sums[CashboxTransactionType.withdraw] ?? 0;
    final expenses = sums[CashboxTransactionType.expense] ?? 0;
    final adjustments = sums[CashboxTransactionType.adjustment] ?? 0;
    final netMoves =
        sales + refunds + payments + deposits + withdrawals + expenses +
        adjustments;
    final expected = opening + netMoves;

    final openedBy = await _userName(open.userId);
    final closedBy = close == null ? null : await _userName(close.userId);

    if (close == null) {
      return CashboxSession(
        status: CashboxStatus.open,
        openedByUserId: open.userId,
        openedByUserName: openedBy,
        openedAtMillis: open.createdAt,
        openingMicros: opening,
        salesCashMicros: sales,
        refundMicros: refunds,
        paymentsMicros: payments,
        depositsMicros: deposits,
        withdrawalsMicros: withdrawals,
        expensesMicros: expenses,
        adjustmentsMicros: adjustments,
        netMovesMicros: netMoves,
        expectedClosingMicros: expected,
      );
    }

    return CashboxSession(
      status: CashboxStatus.closed,
      openedByUserId: open.userId,
      openedByUserName: openedBy,
      openedAtMillis: open.createdAt,
      openingMicros: opening,
      salesCashMicros: sales,
      refundMicros: refunds,
      paymentsMicros: payments,
      depositsMicros: deposits,
      withdrawalsMicros: withdrawals,
      expensesMicros: expenses,
      adjustmentsMicros: adjustments,
      netMovesMicros: netMoves,
      expectedClosingMicros: expected,
      closedByUserId: close.userId,
      closedByUserName: closedBy,
      closedAtMillis: close.createdAt,
      declaredCloseMicros: close.amountMicros,
      differenceMicros: close.amountMicros - expected,
    );
  }

  /// Per-type signed ledger sums in the window `[fromMillis, toMillis)`.
  Future<Map<CashboxTransactionType, int>> _typeSums(
    int fromMillis,
    int toMillis,
  ) async {
    final rows = await _db.customSelect(
      'SELECT t.type AS type, COALESCE(SUM(t.amount_micros), 0) AS s '
      'FROM cashbox_transactions t '
      'WHERE t.created_at >= ? AND t.created_at < ? '
      'GROUP BY t.type',
      variables: [Variable.withInt(fromMillis), Variable.withInt(toMillis)],
    ).get();
    final sums = <CashboxTransactionType, int>{};
    for (final r in rows) {
      final type = _readType(r.read<String>('type'));
      if (type == null) continue;
      sums[type] = r.read<int>('s');
    }
    return sums;
  }

  /// Paged, DB-side-filtered transaction history (newest first) joined with
  /// operator display names. Uses LIMIT/OFFSET so large ledgers stay cheap.
  Future<PageResult<CashboxHistoryEntry>> history({
    required PageRequest page,
    CashboxTransactionType? type,
    int? fromMillis,
    int? toMillis,
  }) async {
    final where = <String>[];
    final args = <Object>[];
    if (type != null) {
      where.add('t.type = ?');
      args.add(type.name);
    }
    if (fromMillis != null) {
      where.add('t.created_at >= ?');
      args.add(fromMillis);
    }
    if (toMillis != null) {
      where.add('t.created_at < ?');
      args.add(toMillis);
    }
    final condition = where.isEmpty ? '' : 'WHERE ${where.join(' AND ')}';

    final countRow = await _db.customSelect(
      'SELECT COUNT(*) AS c FROM cashbox_transactions t $condition',
      variables: [for (final a in args) _variable(a)],
    ).getSingle();
    final total = countRow.read<int>('c');

    final rows = await _db.customSelect(
      'SELECT t.*, u.full_name AS user_name '
      'FROM cashbox_transactions t '
      'LEFT JOIN users u ON u.id = t.user_id '
      '$condition '
      'ORDER BY t.created_at DESC, t.id DESC '
      'LIMIT ? OFFSET ?',
      variables: [
        for (final a in args) _variable(a),
        Variable.withInt(page.pageSize),
        Variable.withInt(page.offset),
      ],
    ).get();

    return PageResult(
      items: [
        for (final r in rows)
          CashboxHistoryEntry(
            id: r.read<String>('id'),
            type: _readType(r.read<String>('type')),
            amountMicros: r.read<int>('amount_micros'),
            remainingMicros: r.read<int>('remaining_micros'),
            refType: r.read<String?>('ref_type'),
            refId: r.read<String?>('ref_id'),
            note: r.read<String?>('note'),
            userId: r.read<String>('user_id'),
            userName: r.read<String?>('user_name') ?? '',
            createdAt: r.read<int>('created_at'),
          ),
      ],
      total: total,
      request: page,
    );
  }

  Future<String?> _userName(String userId) async {
    final row = await (_db.select(_db.users)
          ..where((u) => u.id.equals(userId)))
        .getSingleOrNull();
    return row?.fullName;
  }

  static int _nowMillis() => DateTime.now().millisecondsSinceEpoch;

  static CashboxTransactionType? _readType(String value) {
    for (final t in CashboxTransactionType.values) {
      if (t.name == value) return t;
    }
    return null;
  }

  static Variable<Object> _variable(Object value) {
    if (value is int) return Variable.withInt(value);
    return Variable.withString('$value');
  }
}