import 'package:drift/drift.dart';

import '../../core/data_grid/page_request.dart';
import '../../core/util/ids.dart';
import '../../shared/database/app_database.dart';

/// One row of a customer statement (كشف حساب العميل) — abstracted over the
/// mix of completed sales invoices and sale returns that move the balance.
class CustomerStatementEntry {
  const CustomerStatementEntry({
    required this.docType,
    required this.refNo,
    required this.refId,
    required this.date,
    required this.note,
    required this.debitMicros,
    required this.creditMicros,
    required this.balanceMicros,
  });

  /// `opening` | `sale_invoice` | `sale_return`
  final String docType;
  final String refNo;
  final String refId;
  final int date;
  final String? note;
  final int debitMicros;
  final int creditMicros;

  /// Cumulative running balance after this row (>= opening on page 1).
  final int balanceMicros;

  /// Signed contribution of this row to the running balance.
  int get netMicros => debitMicros - creditMicros;
}

/// Totals + start balance for a customer statement range.
class CustomerLedgerTotals {
  const CustomerLedgerTotals({
    required this.totalDocs,
    required this.openingMicros,
    required this.debitTotalMicros,
    required this.creditTotalMicros,
    required this.closingMicros,
  });

  final int totalDocs;
  final int openingMicros;
  final int debitTotalMicros;
  final int creditTotalMicros;
  final int closingMicros;
}

/// DAO for the customers / patients master (§4.11) and the *derived* customer
/// ledger: balances are cached on `customers.balance_micros` and re-derived
/// from the sales documents — never hand-edited (§25, §27).
class CustomerDao {
  const CustomerDao(this._db);

  final AppDatabase _db;

  Future<CustomerRow?> byId(String id) => (_db.select(_db.customers)
        ..where((c) => c.id.equals(id)))
      .getSingleOrNull();

  /// All customers (optionally only active) for dropdowns — bounded master set.
  Future<List<CustomerRow>> all({bool activeOnly = true}) async {
    final q = _db.select(_db.customers);
    if (activeOnly) q.where((c) => c.isActive.equals(true));
    q.orderBy([(c) => OrderingTerm.asc(c.name)]);
    return q.get();
  }

  /// Paginated customer master search (§22, §30) — filtering in SQL only.
  Future<PageResult<CustomerRow>> search(
    PageRequest page, {
    bool? onlyActive,
  }) async {
    final q = page.search.trim();
    final countExpr = _db.customers.id.count();
    final count = _db.selectOnly(_db.customers)..addColumns([countExpr]);
    final query = _db.select(_db.customers);
    if (q.isNotEmpty) {
      final like = '%${_escapeLike(q)}%';
      final cond = _db.customers.name.like(like) |
          _db.customers.phone.like(like) |
          _db.customers.email.like(like) |
          _db.customers.taxVatNumber.like(like);
      count.where(cond);
      query.where((c) => cond);
    }
    if (onlyActive != null) {
      count.where(_db.customers.isActive.equals(onlyActive));
      query.where((c) => c.isActive.equals(onlyActive));
    }
    final total = (await count.getSingle()).read(countExpr) ?? 0;
    query
      ..orderBy([(c) => OrderingTerm.asc(c.name)])
      ..limit(page.pageSize, offset: page.offset);
    return PageResult(items: await query.get(), total: total, request: page);
  }

  Future<void> insert(CustomerRow customer) =>
      _db.into(_db.customers).insert(customer);

  Future<void> update(CustomerRow customer) =>
      (_db.update(_db.customers)..where((c) => c.id.equals(customer.id)))
          .write(customer.toCompanion(true));

  Future<void> setActive(String id, bool active, {required int at}) =>
      (_db.update(_db.customers)..where((c) => c.id.equals(id))).write(
        CustomersCompanion(
          isActive: Value(active),
          updatedAt: Value(at),
        ),
      );

  /// Enables/disables the credit account for a customer (§4.11 `has_account`).
  Future<void> setAccount(String id, bool enabled, {required int at}) =>
      (_db.update(_db.customers)..where((c) => c.id.equals(id))).write(
        CustomersCompanion(
          hasAccount: Value(enabled),
          updatedAt: Value(at),
        ),
      );

  /// The two ledger feeds that make up a customer's derived balance (§25):
  /// completed (non-voided) sales invoice remaining + completed sale returns
  /// (signed negative money).
  static const String _balanceFeedSnippet = """
      c.opening_balance_micros +
      COALESCE((SELECT SUM(si.total_micros - si.paid_micros)
                FROM sales_invoices si
                WHERE si.customer_id = c.id
                  AND si.sale_status = 'completed'), 0) +
      COALESCE((SELECT SUM(r.total_micros)
                FROM returns r
                WHERE r.customer_id = c.id
                  AND r.type = 'sale_return'
                  AND r.status = 'completed'), 0)""";

  /// One page of statement documents for a customer, ordered by date. Debits
  /// are amounts the customer owes (sales invoice remaining), credits are
  /// payments and sale returns (money returned). Running balances are computed
  /// in Dart from [startBalanceMicros].
  Future<List<CustomerStatementEntry>> statementPage(
    String customerId, {
    required int fromDate,
    required int toDate,
    required int limit,
    required int offset,
  }) async {
    final rows = await _db.customSelect(
      """WITH docs AS (
          SELECT 'sale_invoice' AS doc_type,
                 si.invoice_number AS ref_no, si.id AS ref_id,
                 si.created_at AS d, si.notes AS note,
                 si.total_micros AS debit, si.paid_micros AS credit
          FROM sales_invoices si
          WHERE si.customer_id = ?1
            AND si.sale_status = 'completed'
          UNION ALL
          SELECT 'sale_return', r.return_number, r.id,
                 r.created_at, r.reason, 0, -r.total_micros
          FROM returns r
          WHERE r.customer_id = ?1
            AND r.type = 'sale_return'
            AND r.status = 'completed'
        )
        SELECT doc_type, ref_no, ref_id, d, note, debit, credit
        FROM docs
        WHERE d >= ?2 AND d <= ?3
        ORDER BY d ASC, doc_type ASC, ref_no ASC
        LIMIT ?4 OFFSET ?5""",
      variables: [
        Variable.withString(customerId),
        Variable.withInt(fromDate),
        Variable.withInt(toDate),
        Variable.withInt(limit),
        Variable.withInt(offset),
      ],
    ).get();
    return [
      for (final r in rows)
        CustomerStatementEntry(
          docType: r.read<String>('doc_type'),
          refNo: r.read<String>('ref_no'),
          refId: r.read<String>('ref_id'),
          date: r.read<int>('d'),
          note: r.read<String?>('note'),
          debitMicros: r.read<int>('debit'),
          creditMicros: r.read<int>('credit'),
          balanceMicros: 0,
        ),
    ];
  }

  /// Running balance immediately before the first row of a page — opening plus
  /// every document strictly before the page's first row (keyset on the same
  /// `(date, doc_type)` ordering used by [statementPage]).
  Future<int> startBalanceMicros(
    String customerId, {
    required int date,
    required String docType,
  }) async {
    final row = await _db.customSelect(
      """SELECT c.opening_balance_micros +
             COALESCE((SELECT SUM(debit - credit) FROM (
                SELECT si.created_at AS d, 'sale_invoice' AS doc_type,
                       si.total_micros AS debit, si.paid_micros AS credit
                FROM sales_invoices si
                WHERE si.customer_id = ?1
                  AND si.sale_status = 'completed'
                UNION ALL
                SELECT r.created_at, 'sale_return', 0, -r.total_micros
                FROM returns r
                WHERE r.customer_id = ?1
                  AND r.type = 'sale_return'
                  AND r.status = 'completed'
              ) WHERE (d < ?2) OR (d = ?2 AND doc_type < ?3)), 0) AS start
      FROM customers c WHERE c.id = ?1""",
      variables: [
        Variable.withString(customerId),
        Variable.withInt(date),
        Variable.withString(docType),
      ],
    ).getSingle();
    return row.read<int>('start');
  }

  /// Statement totals + filtered-list metadata for the footer of كشف الحساب.
  Future<CustomerLedgerTotals> statementTotals(
    String customerId, {
    required int fromDate,
    required int toDate,
  }) async {
    final row = await _db.customSelect(
      """WITH docs AS (
          SELECT 'sale_invoice' AS doc_type, si.created_at AS d,
                 si.total_micros AS debit, si.paid_micros AS credit
          FROM sales_invoices si
          WHERE si.customer_id = ?1
            AND si.sale_status = 'completed'
          UNION ALL
          SELECT 'sale_return', r.created_at, 0, -r.total_micros
          FROM returns r
          WHERE r.customer_id = ?1
            AND r.type = 'sale_return'
            AND r.status = 'completed'
        )
        SELECT c.opening_balance_micros AS opening,
               (SELECT COALESCE(SUM(debit - credit), 0) FROM docs
                 WHERE d < ?2) AS before_range,
               (SELECT COUNT(*) FROM docs WHERE d >= ?2 AND d <= ?3) AS c,
               (SELECT COALESCE(SUM(debit), 0) FROM docs
                 WHERE d >= ?2 AND d <= ?3) AS d_total,
               (SELECT COALESCE(SUM(credit), 0) FROM docs
                 WHERE d >= ?2 AND d <= ?3) AS c_total
        FROM customers c WHERE c.id = ?1""",
      variables: [
        Variable.withString(customerId),
        Variable.withInt(fromDate),
        Variable.withInt(toDate),
      ],
    ).getSingle();
    final opening = row.read<int>('opening');
    final before = row.read<int>('before_range');
    final count = row.read<int>('c');
    final debit = row.read<int>('d_total');
    final credit = row.read<int>('c_total');
    return CustomerLedgerTotals(
      totalDocs: count,
      openingMicros: opening,
      debitTotalMicros: debit,
      creditTotalMicros: credit,
      closingMicros: opening + before + debit - credit,
    );
  }

  /// Re-derives `customers.balance_micros` from the ledger for [customerId].
  /// Must run inside a transaction so it never shows a partially-applied state.
  Future<void> syncBalance(String customerId, {required int at}) async {
    final row = await _db.customSelect(
      'SELECT $_balanceFeedSnippet AS balance '
      'FROM customers c WHERE c.id = ?1',
      variables: [Variable.withString(customerId)],
    ).getSingle();
    await (_db.update(_db.customers)
          ..where((c) => c.id.equals(customerId)))
        .write(
      CustomersCompanion(
        balanceMicros: Value(row.read<int>('balance')),
        updatedAt: Value(at),
      ),
    );
  }

  static String newCustomerId() => newId('cus');

  static String _escapeLike(String value) =>
      value.replaceAll(r'\', r'\\').replaceAll('%', r'\%').replaceAll('_', r'\_');
}