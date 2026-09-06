import 'package:drift/drift.dart';

import '../../../shared/database/app_database.dart';
import '../../../shared/models/enums.dart';
import '../domain/entities/z_report.dart';

/// Aggregates a report window into a [ZReport] (end-of-session summary).
///
/// Every figure comes straight from the persisted documents (sales invoices,
/// returns, customer payments, cash-box ledger) — the layer never rebuilds
/// totals from scratch, so it stays consistent with the Phase 7.5 financial
/// engine that wrote them.
class ZReportDao {
  const ZReportDao(this._db);

  final AppDatabase _db;

  Future<ZReport> aggregate({
    required int fromMillis,
    required int toMillis,
    String? userId,
  }) async {
    // Drafts never enter the Z-Report; voided invoices are reported separately
    // (and their cash/card/credit splits excluded from the collected totals).
    final nonDraft = _db.salesInvoices.saleStatus
        .equals(SaleStatus.draft.name)
        .not();
    final soldFilter = _and([
      _period(_db.salesInvoices.createdAt, fromMillis, toMillis),
      nonDraft,
      _db.salesInvoices.voidedAt.isNull(),
      userId == null ? null : _db.salesInvoices.userId.equals(userId),
    ]);
    final voidedFilter = _and([
      _period(_db.salesInvoices.createdAt, fromMillis, toMillis),
      nonDraft,
      _db.salesInvoices.voidedAt.isNotNull(),
      userId == null ? null : _db.salesInvoices.userId.equals(userId),
    ]);

    final sold = await _invoiceSums(soldFilter);
    final voided = await _invoiceSums(voidedFilter);

    // Standalone returns documents (signed totals; display as positive refunds).
    final returnsFilter =
        _period(_db.returns.createdAt, fromMillis, toMillis) &
            _db.returns.isVoided.equals(false);
    final returnsTotal = await _returnsTotal(returnsFilter);
    final returnsCount = await _returnsCount(returnsFilter);

    // Customer credit ledger: payments received and refunds issued.
    final payPeriod =
        _period(_db.customerPayments.createdAt, fromMillis, toMillis) &
            _db.customerPayments.isVoided.equals(false);
    final customerPaid = await _paymentsSum(
      payPeriod & _db.customerPayments.amountMicros.isBiggerThanValue(0),
    );
    final customerRefund = await _paymentsSum(
      payPeriod & _db.customerPayments.amountMicros.isSmallerThanValue(0),
    );

    // Cash-box ledger: opening + net moves ⇒ running balance (reconciliation).
    final drawer = await _drawer(fromMillis, toMillis);

    return ZReport(
      fromMillis: fromMillis,
      toMillis: toMillis,
      userId: userId,
      invoiceCount: sold['count']!,
      subtotalMicros: sold['subtotal']!,
      discountMicros: sold['discount']!,
      vatMicros: sold['vat']!,
      totalMicros: sold['total']!,
      paidMicros: sold['paid']!,
      changeMicros: sold['change']!,
      cashMicros: sold['cash']!,
      cardMicros: sold['card']!,
      creditMicros: sold['credit']!,
      unitsSold: await _unitsSold(fromMillis, toMillis, userId),
      voidCount: voided['count']!,
      voidTotalMicros: voided['total']!,
      returnsCount: returnsCount,
      returnsTotalMicros: returnsTotal < 0 ? -returnsTotal : returnsTotal,
      customerPaidMicros: customerPaid,
      customerRefundMicros: customerRefund < 0 ? -customerRefund : customerRefund,
      drawerOpeningMicros: drawer['opening']!,
      drawerNetMovesMicros: drawer['netMoves']!,
      lastRemainingMicros: drawer['lastRemaining']!,
      drawerDeclaredCloseMicros: drawer['declaredClose'],
    );
  }

  Future<Map<String, int>> _invoiceSums(Expression<bool>? filter) async {
    final t = _db.salesInvoices;
    final q = _db.selectOnly(t)
      ..addColumns([
        t.id.count(),
        t.subtotalMicros.sum(),
        t.discountTotalMicros.sum(),
        t.vatTotalMicros.sum(),
        t.totalMicros.sum(),
        t.paidMicros.sum(),
        t.changeMicros.sum(),
        t.cashMicros.sum(),
        t.cardMicros.sum(),
        t.creditMicros.sum(),
      ]);
    if (filter != null) q.where(filter);
    final r = await q.getSingle();
    return {
      'count': r.read(t.id.count()) ?? 0,
      'subtotal': r.read(t.subtotalMicros.sum()) ?? 0,
      'discount': r.read(t.discountTotalMicros.sum()) ?? 0,
      'vat': r.read(t.vatTotalMicros.sum()) ?? 0,
      'total': r.read(t.totalMicros.sum()) ?? 0,
      'paid': r.read(t.paidMicros.sum()) ?? 0,
      'change': r.read(t.changeMicros.sum()) ?? 0,
      'cash': r.read(t.cashMicros.sum()) ?? 0,
      'card': r.read(t.cardMicros.sum()) ?? 0,
      'credit': r.read(t.creditMicros.sum()) ?? 0,
    };
  }

  Future<int> _returnsTotal(Expression<bool> filter) async {
    final t = _db.returns;
    final q = _db.selectOnly(t)..addColumns([t.totalMicros.sum()])..where(filter);
    final row = await q.getSingle();
    return row.read(t.totalMicros.sum()) ?? 0;
  }

  Future<int> _returnsCount(Expression<bool> filter) async {
    final t = _db.returns;
    final q = _db.selectOnly(t)..addColumns([t.id.count()])..where(filter);
    final row = await q.getSingle();
    return row.read(t.id.count()) ?? 0;
  }

  Future<int> _paymentsSum(Expression<bool> filter) async {
    final t = _db.customerPayments;
    final q = _db.selectOnly(t)
      ..addColumns([t.amountMicros.sum()])
      ..where(filter);
    final row = await q.getSingle();
    return row.read(t.amountMicros.sum()) ?? 0;
  }

  /// Base units sold across the collected invoices. Uses raw SQL for the
  /// invoice ↔ line join so the sum runs in the same snapshot as the rest of
  /// the aggregation.
  Future<int> _unitsSold(int fromMillis, int toMillis, String? userId) async {
    final row = await _db
        .customSelect(
          'SELECT COALESCE(SUM(ii.quantity_base_signed), 0) AS units '
          'FROM sales_invoice_items ii '
          'JOIN sales_invoices iv ON ii.invoice_id = iv.id '
          'WHERE iv.created_at >= ? AND iv.created_at < ? '
          'AND iv.sale_status != ? AND iv.voided_at IS NULL '
          'AND ii.quantity_base_signed > 0'
          '${userId != null ? ' AND iv.user_id = ?' : ''}',
          variables: [
            Variable<int>(fromMillis),
            Variable<int>(toMillis),
            const Variable<String>('draft'),
            if (userId != null) Variable<String>(userId),
          ],
        )
        .getSingle();
    return row.read<int>('units');
  }

  Future<Map<String, int?>> _drawer(int fromMillis, int toMillis) async {
    final t = _db.cashboxTransactions;
    final rows = await (_db.select(t)
          ..where((r) => _period(t.createdAt, fromMillis, toMillis))
          ..orderBy([(_) => OrderingTerm.asc(t.createdAt)]))
        .get();
    var opening = 0;
    int? declaredClose;
    var netMoves = 0;
    for (final row in rows) {
      if (row.type == CashboxTransactionType.open) {
        // Opening is the seed, not a move: `expected = opening + netMoves`.
        opening = row.amountMicros;
      } else if (row.type == CashboxTransactionType.close) {
        // Closing declaration reconciles against the running balance rather
        // than being an independent move (§21 / Z-Report drawer section).
        declaredClose = row.amountMicros;
      } else {
        netMoves += row.amountMicros;
      }
    }
    return {
      'opening': opening,
      'netMoves': netMoves,
      'lastRemaining': rows.isEmpty ? 0 : rows.last.remainingMicros,
      'declaredClose': declaredClose,
    };
  }

  static Expression<bool> _period(
    GeneratedColumn<int> createdAt,
    int fromMillis,
    int toMillis,
  ) =>
      createdAt.isBiggerOrEqualValue(fromMillis) &
          createdAt.isSmallerThanValue(toMillis);

  static Expression<bool>? _and(List<Expression<bool>?> expressions) {
    final present = <Expression<bool>>[];
    for (final e in expressions) {
      if (e != null) present.add(e);
    }
    if (present.isEmpty) return null;
    return present.reduce((a, b) => a & b);
  }
}