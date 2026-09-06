import 'package:drift/drift.dart';

import '../../core/data_grid/page_request.dart';
import '../../core/util/ids.dart';
import '../../shared/database/app_database.dart';

/// One row of a supplier statement (كشف حساب) — abstracted over the mix of
/// received invoices and purchase returns that move the supplier balance.
class SupplierStatementEntry {
  const SupplierStatementEntry({
    required this.docType,
    required this.refNo,
    required this.refId,
    required this.date,
    required this.note,
    required this.debitMicros,
    required this.creditMicros,
    required this.balanceMicros,
  });

  /// `opening` | `purchase_invoice` | `purchase_return`
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

/// Totals + start balance for a statement range.
class SupplierLedgerTotals {
  const SupplierLedgerTotals({
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

/// Per-supplier derived balance row (summary tab / balance report).
class SupplierBalanceRow {
  const SupplierBalanceRow({
    required this.supplierId,
    required this.name,
    required this.code,
    required this.phone,
    required this.isActive,
    required this.openingMicros,
    required this.invoicesNetMicros,
    required this.returnsNetMicros,
    required this.balanceMicros,
    required this.creditLimitMicros,
  });

  final String supplierId;
  final String name;
  final String? code;
  final String? phone;
  final bool isActive;
  final int openingMicros;

  /// Remaining (total − paid) of received non-voided purchase invoices.
  final int invoicesNetMicros;

  /// Signed total of completed purchase returns (negative money).
  final int returnsNetMicros;
  final int balanceMicros;
  final int creditLimitMicros;
}

/// DAO for the suppliers master (§4.10) and the *derived* supplier ledger:
/// balances are cached on `suppliers.balance_micros` and re-derived from the
/// purchase/return documents — never hand-edited (§25, §27).
class SupplierDao {
  const SupplierDao(this._db);

  final AppDatabase _db;

  Future<SupplierRow?> byId(String id) => (_db.select(_db.suppliers)
        ..where((s) => s.id.equals(id)))
      .getSingleOrNull();

  /// All suppliers (optionally only active) for dropdowns — bounded master set.
  Future<List<SupplierRow>> all({bool activeOnly = true}) async {
    final q = _db.select(_db.suppliers);
    if (activeOnly) q.where((s) => s.isActive.equals(true));
    q.orderBy([(s) => OrderingTerm.asc(s.name)]);
    return q.get();
  }

  /// Paginated supplier master search (§22, §30) — filtering in SQL only.
  Future<PageResult<SupplierRow>> search(
    PageRequest page, {
    bool? onlyActive,
  }) async {
    final q = page.search.trim();
    final countExpr = _db.suppliers.id.count();
    final count = _db.selectOnly(_db.suppliers)..addColumns([countExpr]);
    final query = _db.select(_db.suppliers);
    if (q.isNotEmpty) {
      final like = '%${_escapeLike(q)}%';
      final cond = _db.suppliers.name.like(like) |
          _db.suppliers.phone.like(like) |
          _db.suppliers.contactPerson.like(like) |
          _db.suppliers.code.like(like);
      count.where(cond);
      query.where((s) => cond);
    }
    if (onlyActive != null) {
      count.where(_db.suppliers.isActive.equals(onlyActive));
      query.where((s) => s.isActive.equals(onlyActive));
    }
    final total = (await count.getSingle()).read(countExpr) ?? 0;
    query
      ..orderBy([(s) => OrderingTerm.asc(s.name)])
      ..limit(page.pageSize, offset: page.offset);
    return PageResult(items: await query.get(), total: total, request: page);
  }

  Future<void> insert(SupplierRow supplier) =>
      _db.into(_db.suppliers).insert(supplier);

  Future<void> update(SupplierRow supplier) =>
      (_db.update(_db.suppliers)..where((s) => s.id.equals(supplier.id)))
          .write(supplier.toCompanion(true));

  Future<void> setActive(String id, bool active, {required int at}) =>
      (_db.update(_db.suppliers)..where((s) => s.id.equals(id))).write(
        SuppliersCompanion(
          isActive: Value(active),
          updatedAt: Value(at),
        ),
      );

  /// The three ledger feeds that make up a supplier's derived balance
  /// (§25): received (non-voided) invoice remaining + completed purchase
  /// returns (signed).
  static const String _balanceFeedSnippet = """
      s.opening_balance_micros +
      COALESCE((SELECT SUM(pi.total_micros - pi.paid_micros)
                FROM purchase_invoices pi
                WHERE pi.supplier_id = s.id
                  AND pi.purchase_status = 'received'
                  AND pi.is_voided = 0), 0) +
      COALESCE((SELECT SUM(r.total_micros)
                FROM returns r
                WHERE r.supplier_id = s.id
                  AND r.type = 'purchase_return'
                  AND r.status = 'completed'), 0)""";

  /// Paginated per-supplier derived balances (§25). Invoice remaining and
  /// return totals are aggregated in SQL; the sum is materialized in Dart.
  Future<PageResult<SupplierBalanceRow>> balances(PageRequest page) async {
    final q = page.search.trim();
    final like = '%${_escapeLike(q)}%';
    final where = """
(:search = '' OR s.name LIKE :like OR s.phone LIKE :like
 OR s.code LIKE :like OR s.contact_person LIKE :like)""";
    final count = await _db.customSelect(
      'SELECT COUNT(*) AS c FROM suppliers s WHERE $where',
      variables: [Variable.withString(q), Variable.withString(like)],
    ).getSingle();
    final rows = await _db.customSelect(
      """SELECT s.id AS id, s.name AS name, s.code AS code, s.phone AS phone,
             s.is_active AS is_active, s.credit_limit_micros AS credit_limit,
             s.opening_balance_micros AS opening,
             COALESCE((SELECT SUM(pi.total_micros - pi.paid_micros)
                FROM purchase_invoices pi
                WHERE pi.supplier_id = s.id
                  AND pi.purchase_status = 'received'
                  AND pi.is_voided = 0), 0) AS invoice_net,
             COALESCE((SELECT SUM(r.total_micros)
                FROM returns r
                WHERE r.supplier_id = s.id
                  AND r.type = 'purchase_return'
                  AND r.status = 'completed'), 0) AS returns_net
      FROM suppliers s
      WHERE $where
      ORDER BY s.name ASC LIMIT :limit OFFSET :offset""",
      variables: [
        Variable.withString(q),
        Variable.withString(like),
        Variable.withInt(page.pageSize),
        Variable.withInt(page.offset),
      ],
    ).get();
    final items = <SupplierBalanceRow>[
      for (final r in rows)
        SupplierBalanceRow(
          supplierId: r.read<String>('id'),
          name: r.read<String>('name'),
          code: r.read<String?>('code'),
          phone: r.read<String?>('phone'),
          isActive: r.read<int>('is_active') != 0,
          creditLimitMicros: r.read<int>('credit_limit'),
          openingMicros: r.read<int>('opening'),
          invoicesNetMicros: r.read<int>('invoice_net'),
          returnsNetMicros: r.read<int>('returns_net'),
          balanceMicros: r.read<int>('opening') +
              r.read<int>('invoice_net') +
              r.read<int>('returns_net'),
        ),
    ];
    return PageResult(items: items, total: count.read<int>('c'), request: page);
  }

  /// One page of statement documents for a supplier, ordered by date. Debits
  /// are money owed by the pharmacy (invoice totals), credits are payments
  /// and purchase returns. Running balances are computed in Dart from
  /// [startBalanceMicros].
  Future<List<SupplierStatementEntry>> statementPage(
    String supplierId, {
    required int fromDate,
    required int toDate,
    required int limit,
    required int offset,
  }) async {
    final rows = await _db.customSelect(
      """WITH docs AS (
          SELECT 'purchase_invoice' AS doc_type,
                 pi.invoice_number AS ref_no, pi.id AS ref_id,
                 pi.invoice_date AS d, pi.notes AS note,
                 pi.total_micros AS debit, pi.paid_micros AS credit
          FROM purchase_invoices pi
          WHERE pi.supplier_id = ?1
            AND pi.purchase_status = 'received'
            AND pi.is_voided = 0
          UNION ALL
          SELECT 'purchase_return', r.return_number, r.id,
                 r.created_at, r.reason, 0, -r.total_micros
          FROM returns r
          WHERE r.supplier_id = ?1
            AND r.type = 'purchase_return'
            AND r.status = 'completed'
        )
        SELECT doc_type, ref_no, ref_id, d, note, debit, credit
        FROM docs
        WHERE d >= ?2 AND d <= ?3
        ORDER BY d ASC, doc_type ASC, ref_no ASC
        LIMIT ?4 OFFSET ?5""",
      variables: [
        Variable.withString(supplierId),
        Variable.withInt(fromDate),
        Variable.withInt(toDate),
        Variable.withInt(limit),
        Variable.withInt(offset),
      ],
    ).get();
    return [
      for (final r in rows)
        SupplierStatementEntry(
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
    String supplierId, {
    required int date,
    required String docType,
  }) async {
    final row = await _db.customSelect(
      """SELECT s.opening_balance_micros +
             COALESCE((SELECT SUM(debit - credit) FROM (
                SELECT pi.invoice_date AS d, 'purchase_invoice' AS doc_type,
                       pi.total_micros AS debit, pi.paid_micros AS credit
                FROM purchase_invoices pi
                WHERE pi.supplier_id = ?1
                  AND pi.purchase_status = 'received'
                  AND pi.is_voided = 0
                UNION ALL
                SELECT r.created_at, 'purchase_return', 0, -r.total_micros
                FROM returns r
                WHERE r.supplier_id = ?1
                  AND r.type = 'purchase_return'
                  AND r.status = 'completed'
              ) WHERE (d < ?2) OR (d = ?2 AND doc_type < ?3)), 0) AS start
      FROM suppliers s WHERE s.id = ?1""",
      variables: [
        Variable.withString(supplierId),
        Variable.withInt(date),
        Variable.withString(docType),
      ],
    ).getSingle();
    return row.read<int>('start');
  }

  /// Statement totals + filtered-list metadata for the footer of كشف الحساب.
  Future<SupplierLedgerTotals> statementTotals(
    String supplierId, {
    required int fromDate,
    required int toDate,
  }) async {
    final row = await _db.customSelect(
      """WITH docs AS (
          SELECT 'purchase_invoice' AS doc_type, pi.invoice_date AS d,
                 pi.total_micros AS debit, pi.paid_micros AS credit
          FROM purchase_invoices pi
          WHERE pi.supplier_id = ?1
            AND pi.purchase_status = 'received'
            AND pi.is_voided = 0
          UNION ALL
          SELECT 'purchase_return', r.created_at, 0, -r.total_micros
          FROM returns r
          WHERE r.supplier_id = ?1
            AND r.type = 'purchase_return'
            AND r.status = 'completed'
        )
        SELECT s.opening_balance_micros AS opening,
               (SELECT COALESCE(SUM(debit - credit), 0) FROM docs
                 WHERE d < ?2) AS before_range,
               (SELECT COUNT(*) FROM docs WHERE d >= ?2 AND d <= ?3) AS c,
               (SELECT COALESCE(SUM(debit), 0) FROM docs
                 WHERE d >= ?2 AND d <= ?3) AS d_total,
               (SELECT COALESCE(SUM(credit), 0) FROM docs
                 WHERE d >= ?2 AND d <= ?3) AS c_total
        FROM suppliers s WHERE s.id = ?1""",
      variables: [
        Variable.withString(supplierId),
        Variable.withInt(fromDate),
        Variable.withInt(toDate),
      ],
    ).getSingle();
    final opening = row.read<int>('opening');
    final before = row.read<int>('before_range');
    final count = row.read<int>('c');
    final debit = row.read<int>('d_total');
    final credit = row.read<int>('c_total');
    return SupplierLedgerTotals(
      totalDocs: count,
      openingMicros: opening,
      debitTotalMicros: debit,
      creditTotalMicros: credit,
      closingMicros: opening + before + debit - credit,
    );
  }

  /// Re-derives `suppliers.balance_micros` from the ledger for [supplierId].
  /// Must run inside a transaction so it never shows a partially-applied state.
  Future<void> syncBalance(String supplierId, {required int at}) async {
    final row = await _db.customSelect(
      'SELECT $_balanceFeedSnippet AS balance '
      'FROM suppliers s WHERE s.id = ?1',
      variables: [Variable.withString(supplierId)],
    ).getSingle();
    await (_db.update(_db.suppliers)
          ..where((s) => s.id.equals(supplierId)))
        .write(
      SuppliersCompanion(
        balanceMicros: Value(row.read<int>('balance')),
        updatedAt: Value(at),
      ),
    );
  }

  static String newSupplierId() => newId('sup');

  static String _escapeLike(String value) =>
      value.replaceAll(r'\', r'\\').replaceAll('%', r'\%').replaceAll('_', r'\_');
}