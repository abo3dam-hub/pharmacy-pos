import 'package:drift/drift.dart';

import '../../../core/constants/account_codes.dart';
import '../../../core/util/bilingual_name.dart';
import '../../../shared/database/app_database.dart';
import '../../../shared/models/enums.dart';
import '../domain/entities/report_models.dart';

/// Read-only reporting DAO (Phase 11).
///
/// Every query is a SELECT over the persisted documents and the journal. This
/// layer never writes: reports are projections that must not mutate accounts,
/// inventory, invoices, cash-box, customers or suppliers. The financial
/// figures reuse the posting engine's sign convention (normalSign) exactly, so
/// a balanced journal yields balanced statements and the balance sheet stays
/// equal in the presence of accumulated profit.
class ReportsDao {
  const ReportsDao(this._db);

  final AppDatabase _db;

  // ── Trial Balance ────────────────────────────────────────────────────────

  /// Period [fromMillis, toMillis): opening balances are the position before
  /// `from`, period movements the drift inside it, and closing the position at
  /// `to` (exclusive).
  Future<TrialBalanceReport> trialBalance({
    int? fromMillis,
    int? toMillis,
  }) async {
    final from = fromMillis ?? 0;
    final to = toMillis ?? DateTime.now().millisecondsSinceEpoch + 1;
    final rows = await _db.customSelect(
      '''
      SELECT
        a.id AS account_id,
        a.code AS code,
        a.name AS name,
        a.account_type AS account_type,
        a.opening_balance_micros AS opening_base,
        COALESCE(SUM(CASE WHEN j.entry_date < ? THEN l.debit_micros ELSE 0 END), 0) AS pre_debit,
        COALESCE(SUM(CASE WHEN j.entry_date < ? THEN l.credit_micros ELSE 0 END), 0) AS pre_credit,
        COALESCE(SUM(CASE WHEN j.entry_date >= ? AND j.entry_date < ? THEN l.debit_micros ELSE 0 END), 0) AS period_debit,
        COALESCE(SUM(CASE WHEN j.entry_date >= ? AND j.entry_date < ? THEN l.credit_micros ELSE 0 END), 0) AS period_credit
      FROM accounts a
      LEFT JOIN journal_entry_lines l ON l.account_id = a.id
      LEFT JOIN journal_entries j ON j.id = l.journal_entry_id
      GROUP BY a.id, a.code, a.name, a.account_type, a.opening_balance_micros
      ORDER BY a.code
      ''',
      variables: [
        Variable<int>(from),
        Variable<int>(from),
        Variable<int>(from),
        Variable<int>(to),
        Variable<int>(from),
        Variable<int>(to),
      ],
    ).get();

    final accounts = rows.map((row) {
      final sign = _normalSign(_accountType(row.read<String>('account_type')));
      return TrialBalanceAccountRow(
        accountId: row.read<String>('account_id'),
        code: row.read<String>('code'),
        name: row.read<String>('name'),
        accountType: _accountType(row.read<String>('account_type')),
        openingBalanceMicros: row.read<int>('opening_base') +
            sign * (row.read<int>('pre_debit') - row.read<int>('pre_credit')),
        periodDebitMicros: row.read<int>('period_debit'),
        periodCreditMicros: row.read<int>('period_credit'),
      );
    }).toList();

    return TrialBalanceReport(
      fromMillis: from,
      toMillis: to,
      accounts: accounts,
    );
  }

  // ── Income Statement ─────────────────────────────────────────────────────

  /// Net period movements on revenue/expense accounts.
  Future<IncomeStatementReport> incomeStatement({
    required int fromMillis,
    required int toMillis,
  }) async {
    final rows = await _db.customSelect(
      '''
      SELECT
        a.id AS account_id,
        a.code AS code,
        a.name AS name,
        a.account_type AS account_type,
        COALESCE(SUM(l.debit_micros), 0) AS period_debit,
        COALESCE(SUM(l.credit_micros), 0) AS period_credit
      FROM accounts a
      JOIN journal_entry_lines l ON l.account_id = a.id
      JOIN journal_entries j ON j.id = l.journal_entry_id
      WHERE j.entry_date >= ? AND j.entry_date < ?
        AND a.account_type IN ('revenue', 'expense')
      GROUP BY a.id, a.code, a.name, a.account_type
      ORDER BY a.code
      ''',
      variables: [
        Variable<int>(fromMillis),
        Variable<int>(toMillis),
      ],
    ).get();

    var salesRevenue = 0;
    var returnsContribution = 0;
    var cogs = 0;
    final expenses = <IncomeStatementExpenseRow>[];
    for (final row in rows) {
      final code = row.read<String>('code');
      final accountType = row.read<String>('account_type');
      final debit = row.read<int>('period_debit');
      final credit = row.read<int>('period_credit');
      if (accountType == 'revenue') {
        // Revenue contribution is credit-positive.
        final contribution = credit - debit;
        if (code == SystemAccountCode.salesReturns) {
          returnsContribution += contribution;
        } else if (code == SystemAccountCode.purchaseReturns) {
          // Contra-inventory account is not an income line; ignore in the IS.
        } else {
          salesRevenue += contribution;
        }
      } else {
        // Expense contribution is debit-positive.
        final contribution = debit - credit;
        if (code == SystemAccountCode.costOfGoodsSold) {
          cogs += contribution;
        } else {
          expenses.add(IncomeStatementExpenseRow(
            code: code,
name: bilingualName(row.read<String>('name'),
            row.read<String? >('name_en') ?? ''),
            amountMicros: contribution,
          ));
        }
      }
    }

    return IncomeStatementReport(
      fromMillis: fromMillis,
      toMillis: toMillis,
      salesRevenueMicros: salesRevenue,
      salesReturnsMicros:
          returnsContribution < 0 ? -returnsContribution : 0,
      costOfGoodsSoldMicros: cogs,
      operatingExpenses: List.unmodifiable(expenses),
    );
  }

  // ── Balance Sheet ───────────────────────────────────────────────────────═

  /// Position at `asOfMillis` (exclusive). Equity includes accumulated
  /// retained earnings (Σ revenue − Σ expense as-of) so the identity
  /// Assets = Liabilities + Equity holds with accumulated profit.
  Future<BalanceSheetReport> balanceSheet({required int asOfMillis}) async {
    final rows = await _db.customSelect(
      '''
      SELECT
        a.id AS account_id,
        a.code AS code,
        a.name AS name,
        a.account_type AS account_type,
        a.opening_balance_micros AS opening_base,
        COALESCE(SUM(CASE WHEN j.entry_date < ? THEN l.debit_micros ELSE 0 END), 0) AS all_debit,
        COALESCE(SUM(CASE WHEN j.entry_date < ? THEN l.credit_micros ELSE 0 END), 0) AS all_credit
      FROM accounts a
      LEFT JOIN journal_entry_lines l ON l.account_id = a.id
      LEFT JOIN journal_entries j ON j.id = l.journal_entry_id
      GROUP BY a.id, a.code, a.name, a.account_type, a.opening_balance_micros
      ORDER BY a.code
      ''',
      variables: [Variable<int>(asOfMillis), Variable<int>(asOfMillis)],
    ).get();

    Map<String, List<BalanceSheetItem>> byType() => {
          'asset': <BalanceSheetItem>[],
          'liability': <BalanceSheetItem>[],
          'equity': <BalanceSheetItem>[],
          'revenue': <BalanceSheetItem>[],
          'expense': <BalanceSheetItem>[],
        };
    final sections = byType();
    for (final row in rows) {
      final type = row.read<String>('account_type');
      final sign = _normalSign(_accountType(type));
      final balance = row.read<int>('opening_base') +
          sign * (row.read<int>('all_debit') - row.read<int>('all_credit'));
      final item = BalanceSheetItem(
        code: row.read<String>('code'),
        name: row.read<String>('name'),
        amountMicros: balance,
      );
      sections[type]!.add(item);
    }

    // Retained earnings = accumulated net income = Σ revenue − Σ expense.
    int sum(Iterable<BalanceSheetItem> items) =>
        items.fold(0, (s, i) => s + i.amountMicros);
    final retained = sum(sections['revenue']!) - sum(sections['expense']!);
    final equityItems = [...sections['equity']!];
    if (retained != 0 || sections['equity']!.isEmpty) {
      equityItems.add(BalanceSheetItem(
        code: 'P&L',
        name: 'الأرباح المحتجزة (الأرباح المتراكمة)',
        amountMicros: retained,
        isComputed: true,
      ));
    }

    return BalanceSheetReport(
      asOfMillis: asOfMillis,
      assets: BalanceSheetSection(
        codePrefix: 'asset',
        title: 'الأصول',
        items: List.unmodifiable(sections['asset']!),
      ),
      liabilities: BalanceSheetSection(
        codePrefix: 'liability',
        title: 'الخصوم',
        items: List.unmodifiable(sections['liability']!),
      ),
      equity: BalanceSheetSection(
        codePrefix: 'equity',
        title: 'حقوق الملكية',
        items: List.unmodifiable(equityItems),
      ),
    );
  }

  // ── Sales Report ─────────────────────────────────────────────────────────

  Future<SalesReport> salesReport({
    required int fromMillis,
    required int toMillis,
    String? customerId,
    String? userId,
  }) async {
    final filter = StringBuffer('iv.sale_status != ? AND iv.voided_at IS NULL '
        'AND iv.created_at >= ? AND iv.created_at < ?');
    final variables = <Variable>[
      const Variable<String>('draft'),
      Variable<int>(fromMillis),
      Variable<int>(toMillis),
    ];
    if (customerId != null) {
      filter.write(' AND iv.customer_id = ?');
      variables.add(Variable<String>(customerId));
    }
    if (userId != null) {
      filter.write(' AND iv.user_id = ?');
      variables.add(Variable<String>(userId));
    }

    final sold = await _db.customSelect(
      '''
      SELECT
        iv.id AS id,
        iv.created_at AS created_at,
        iv.subtotal_micros AS subtotal,
        iv.discount_total_micros AS discount,
        iv.vat_total_micros AS vat,
        iv.total_micros AS total,
        iv.paid_micros AS paid,
        iv.cash_micros AS cash,
        iv.card_micros AS card,
        iv.credit_micros AS credit,
        iv.profit_micros AS profit,
        COALESCE(SUM(CASE WHEN ii.quantity_base_signed > 0 THEN ii.quantity_base_signed ELSE 0 END), 0) AS units
      FROM sales_invoices iv
      LEFT JOIN sales_invoice_items ii ON ii.invoice_id = iv.id
      WHERE $filter
      GROUP BY iv.id
      ''',
      variables: variables,
    ).get();

    final voided = await _db.customSelect(
      '''
      SELECT
        iv.created_at AS created_at,
        iv.total_micros AS total
      FROM sales_invoices iv
      WHERE iv.sale_status != ? AND iv.voided_at IS NOT NULL
        AND iv.created_at >= ? AND iv.created_at < ?
      ''',
      variables: [
        const Variable<String>('draft'),
        Variable<int>(fromMillis),
        Variable<int>(toMillis),
      ],
    ).get();

    final returnFilter = StringBuffer(
        'r.is_voided = 0 AND r.type = ? AND r.created_at >= ? AND r.created_at < ?');
    final returnVars = <Variable>[
      const Variable<String>('sale_return'),
      Variable<int>(fromMillis),
      Variable<int>(toMillis),
    ];
    if (customerId != null) {
      returnFilter.write(' AND r.customer_id = ?');
      returnVars.add(Variable<String>(customerId));
    }
    final returns = await _db.customSelect(
      '''
      SELECT r.created_at AS created_at, r.total_micros AS total
      FROM returns r
      WHERE $returnFilter
      ''',
      variables: returnVars,
    ).get();

    final days = <int, SalesReportDayRow>{};
    void ensure(int key) => days.putIfAbsent(key, () => SalesReportDayRow(
          dayMillis: key,
          invoiceCount: 0,
          unitsSold: 0,
          subtotalMicros: 0,
          discountMicros: 0,
          vatMicros: 0,
          totalMicros: 0,
          paidMicros: 0,
          cashMicros: 0,
          cardMicros: 0,
          creditMicros: 0,
          voidCount: 0,
          voidTotalMicros: 0,
          returnCount: 0,
          returnTotalMicros: 0,
          profitMicros: 0,
        ));

    for (final row in sold) {
      final day = _dayKey(row.read<int>('created_at'));
      ensure(day);
      final existing = days[day]!;
      days[day] = SalesReportDayRow(
        dayMillis: day,
        invoiceCount: existing.invoiceCount + 1,
        unitsSold: existing.unitsSold + row.read<int>('units'),
        subtotalMicros: existing.subtotalMicros + row.read<int>('subtotal'),
        discountMicros: existing.discountMicros + row.read<int>('discount'),
        vatMicros: existing.vatMicros + row.read<int>('vat'),
        totalMicros: existing.totalMicros + row.read<int>('total'),
        paidMicros: existing.paidMicros + row.read<int>('paid'),
        cashMicros: existing.cashMicros + row.read<int>('cash'),
        cardMicros: existing.cardMicros + row.read<int>('card'),
        creditMicros: existing.creditMicros + row.read<int>('credit'),
        voidCount: existing.voidCount,
        voidTotalMicros: existing.voidTotalMicros,
        returnCount: existing.returnCount,
        returnTotalMicros: existing.returnTotalMicros,
        profitMicros: existing.profitMicros + row.read<int>('profit'),
      );
    }
    for (final row in voided) {
      final day = _dayKey(row.read<int>('created_at'));
      ensure(day);
      days[day] = SalesReportDayRow(
        dayMillis: day,
        invoiceCount: days[day]!.invoiceCount,
        unitsSold: days[day]!.unitsSold,
        subtotalMicros: days[day]!.subtotalMicros,
        discountMicros: days[day]!.discountMicros,
        vatMicros: days[day]!.vatMicros,
        totalMicros: days[day]!.totalMicros,
        paidMicros: days[day]!.paidMicros,
        cashMicros: days[day]!.cashMicros,
        cardMicros: days[day]!.cardMicros,
        creditMicros: days[day]!.creditMicros,
        voidCount: days[day]!.voidCount + 1,
        voidTotalMicros: days[day]!.voidTotalMicros + row.read<int>('total'),
        returnCount: days[day]!.returnCount,
        returnTotalMicros: days[day]!.returnTotalMicros,
        profitMicros: days[day]!.profitMicros,
      );
    }
    for (final row in returns) {
      final day = _dayKey(row.read<int>('created_at'));
      ensure(day);
      days[day] = SalesReportDayRow(
        dayMillis: day,
        invoiceCount: days[day]!.invoiceCount,
        unitsSold: days[day]!.unitsSold,
        subtotalMicros: days[day]!.subtotalMicros,
        discountMicros: days[day]!.discountMicros,
        vatMicros: days[day]!.vatMicros,
        totalMicros: days[day]!.totalMicros,
        paidMicros: days[day]!.paidMicros,
        cashMicros: days[day]!.cashMicros,
        cardMicros: days[day]!.cardMicros,
        creditMicros: days[day]!.creditMicros,
        voidCount: days[day]!.voidCount,
        voidTotalMicros: days[day]!.voidTotalMicros,
        returnCount: days[day]!.returnCount + 1,
        returnTotalMicros: days[day]!.returnTotalMicros +
            (row.read<int>('total') < 0 ? -row.read<int>('total') : row.read<int>('total')),
        profitMicros: days[day]!.profitMicros,
      );
    }

    final sorted = days.entries.toList()
      ..sort((a, b) => a.key.compareTo(b.key));
    return SalesReport(
      fromMillis: fromMillis,
      toMillis: toMillis,
      customerId: customerId,
      userId: userId,
      days: List.unmodifiable(sorted.map((e) => e.value)),
    );
  }

  // ── Purchase Report ──────────────────────────────────────────────────────

  Future<PurchaseReport> purchaseReport({
    required int fromMillis,
    required int toMillis,
    String? supplierId,
  }) async {
    final filter = StringBuffer(
        'pi.is_voided = 0 AND pi.invoice_date >= ? AND pi.invoice_date < ?');
    final variables = <Variable>[
      Variable<int>(fromMillis),
      Variable<int>(toMillis),
    ];
    if (supplierId != null) {
      filter.write(' AND pi.supplier_id = ?');
      variables.add(Variable<String>(supplierId));
    }
    final invoices = await _db.customSelect(
      '''
      SELECT
        pi.invoice_date AS invoice_date,
        pi.subtotal_micros AS subtotal,
        pi.discount_total_micros AS discount,
        pi.tax_total_micros AS tax,
        pi.shipping_micros AS shipping,
        pi.total_micros AS total,
        pi.paid_micros AS paid,
        pi.remaining_micros AS remaining
      FROM purchase_invoices pi
      WHERE $filter
      ORDER BY pi.invoice_date
      ''',
      variables: variables,
    ).get();

    final returnFilter = StringBuffer(
        'r.is_voided = 0 AND r.type = ? AND r.created_at >= ? AND r.created_at < ?');
    final returnVars = <Variable>[
      const Variable<String>('purchase_return'),
      Variable<int>(fromMillis),
      Variable<int>(toMillis),
    ];
    if (supplierId != null) {
      returnFilter.write(' AND r.supplier_id = ?');
      returnVars.add(Variable<String>(supplierId));
    }
    final returns = await _db.customSelect(
      '''
      SELECT r.created_at AS created_at, r.total_micros AS total
      FROM returns r
      WHERE $returnFilter
      ''',
      variables: returnVars,
    ).get();

    final days = <int, PurchaseReportDayRow>{};
    void ensure(int key) => days.putIfAbsent(key, () => PurchaseReportDayRow(
          dayMillis: key,
          invoiceCount: 0,
          subtotalMicros: 0,
          discountMicros: 0,
          taxMicros: 0,
          shippingMicros: 0,
          totalMicros: 0,
          paidMicros: 0,
          remainingMicros: 0,
          returnCount: 0,
          returnTotalMicros: 0,
        ));

    for (final row in invoices) {
      final day = _dayKey(row.read<int>('invoice_date'));
      ensure(day);
      final existing = days[day]!;
      days[day] = PurchaseReportDayRow(
        dayMillis: day,
        invoiceCount: existing.invoiceCount + 1,
        subtotalMicros: existing.subtotalMicros + row.read<int>('subtotal'),
        discountMicros: existing.discountMicros + row.read<int>('discount'),
        taxMicros: existing.taxMicros + row.read<int>('tax'),
        shippingMicros: existing.shippingMicros + row.read<int>('shipping'),
        totalMicros: existing.totalMicros + row.read<int>('total'),
        paidMicros: existing.paidMicros + row.read<int>('paid'),
        remainingMicros: existing.remainingMicros + row.read<int>('remaining'),
        returnCount: existing.returnCount,
        returnTotalMicros: existing.returnTotalMicros,
      );
    }
    for (final row in returns) {
      final day = _dayKey(row.read<int>('created_at'));
      ensure(day);
      days[day] = PurchaseReportDayRow(
        dayMillis: day,
        invoiceCount: days[day]!.invoiceCount,
        subtotalMicros: days[day]!.subtotalMicros,
        discountMicros: days[day]!.discountMicros,
        taxMicros: days[day]!.taxMicros,
        shippingMicros: days[day]!.shippingMicros,
        totalMicros: days[day]!.totalMicros,
        paidMicros: days[day]!.paidMicros,
        remainingMicros: days[day]!.remainingMicros,
        returnCount: days[day]!.returnCount + 1,
        returnTotalMicros: days[day]!.returnTotalMicros +
            (row.read<int>('total') < 0 ? -row.read<int>('total') : row.read<int>('total')),
      );
    }

    final sorted = days.entries.toList()
      ..sort((a, b) => a.key.compareTo(b.key));
    return PurchaseReport(
      fromMillis: fromMillis,
      toMillis: toMillis,
      supplierId: supplierId,
      days: List.unmodifiable(sorted.map((e) => e.value)),
    );
  }

  // ── Inventory Report ─────────────────────────────────────────────────────

  /// Stock snapshot as of now plus movement summary inside the period.
  Future<InventoryReport> inventoryReport({
    required int fromMillis,
    required int toMillis,
  }) async {
    final itemRows = await _db.customSelect(
      '''
      SELECT
        i.id AS item_id,
        i.primary_barcode AS barcode,
        i.trade_name AS name,
        i.trade_name_en AS name_en,
        i.current_stock_base AS current_stock,
        i.minimum_stock_base AS minimum_stock,
        i.maximum_stock_base AS maximum_stock,
        COALESCE(SUM(b.quantity_base), 0) AS qty_sum,
        COALESCE(SUM(b.quantity_base * b.unit_cost_micros), 0) AS value_sum,
        i.cost_micros AS item_cost
      FROM items i
      LEFT JOIN batches b ON b.item_id = i.id AND b.is_voided = 0
      WHERE i.is_active = 1
      GROUP BY i.id
      ORDER BY i.trade_name
      ''',
    ).get();

    final items = itemRows.map((row) {
      final qty = row.read<int>('qty_sum');
      final value = row.read<int>('value_sum');
      return InventoryReportItemRow(
        itemId: row.read<String>('item_id'),
        barcode: row.read<String? >('barcode'),
        name: row.read<String>('name'),
        currentStockBase: row.read<int>('current_stock'),
        minimumStockBase: row.read<int>('minimum_stock'),
        maximumStockBase: row.read<int>('maximum_stock'),
        unitCostMicros: qty > 0 ? value ~/ qty : row.read<int>('item_cost'),
        stockValueMicros: value,
      );
    }).toList();

    final movementRows = await _db.customSelect(
      '''
      SELECT
        movement_type AS type,
        COUNT(*) AS count,
        COALESCE(SUM(quantity_base_signed), 0) AS qty,
        COALESCE(SUM(total_micros), 0) AS total
      FROM stock_movements
      WHERE created_at >= ? AND created_at < ?
      GROUP BY movement_type
      ORDER BY movement_type
      ''',
      variables: [
        Variable<int>(fromMillis),
        Variable<int>(toMillis),
      ],
    ).get();

    final movements = movementRows.map((row) {
      final typeText = row.read<String>('type');
      return InventoryMovementSummary(
        movementType: _movementTypeOr(typeText, MovementType.manual_correction),
        movementCount: row.read<int>('count'),
        quantityBaseSigned: row.read<int>('qty'),
        totalMicros: row.read<int>('total'),
      );
    }).toList();

    return InventoryReport(
      generatedMillis: DateTime.now().millisecondsSinceEpoch,
      fromMillis: fromMillis,
      toMillis: toMillis,
      items: List.unmodifiable(items),
      movements: List.unmodifiable(movements),
    );
  }

  // ── Lost Sales Report ────────────────────────────────────────────────────

  Future<LostSalesReport> lostSalesReport({
    required int fromMillis,
    required int toMillis,
    LostSaleStatus? status,
  }) async {
    final filter = StringBuffer('ls.created_at >= ? AND ls.created_at < ?');
    final variables = <Variable>[
      Variable<int>(fromMillis),
      Variable<int>(toMillis),
    ];
    if (status != null) {
      filter.write(' AND ls.status = ?');
      variables.add(Variable<String>(status.name));
    }
    final rows = await _db.customSelect(
      '''
      SELECT
        ls.id AS id,
        ls.created_at AS created_at,
        ls.requested_item_name AS item_name,
        ls.barcode AS barcode,
        ls.scientific_name AS scientific_name,
        ls.quantity_requested AS quantity,
        ls.customer_name AS customer_name,
        ls.customer_phone AS customer_phone,
        ls.status AS status,
        ls.note AS note
      FROM lost_sales ls
      WHERE $filter
      ORDER BY ls.created_at DESC
      ''',
      variables: variables,
    ).get();

    return LostSalesReport(
      fromMillis: fromMillis,
      toMillis: toMillis,
      status: status,
      rows: List.unmodifiable(rows.map((row) {
        final statusText = row.read<String>('status');
        return LostSalesReportRow(
          id: row.read<String>('id'),
          createdAt: row.read<int>('created_at'),
          requestedItemName: row.read<String>('item_name'),
          barcode: row.read<String? >('barcode'),
          scientificName: row.read<String? >('scientific_name'),
          quantityRequested: row.read<int>('quantity'),
          customerName: row.read<String? >('customer_name'),
          customerPhone: row.read<String? >('customer_phone'),
          status: _lostSaleStatusOr(statusText, LostSaleStatus.open),
          note: row.read<String? >('note'),
        );
      })),
    );
  }

  // ── helpers ──────────────────────────────────────────────────────────────

  static int _normalSign(AccountType type) => switch (type) {
        AccountType.asset || AccountType.expense => 1,
        AccountType.liability ||
        AccountType.equity ||
        AccountType.revenue =>
          -1,
      };

  static AccountType _accountType(String value) =>
      AccountType.values.asNameMap()[value] ??
      (throw ArgumentError.value(value, 'account_type'));

  static int _dayKey(int millis) {
    final date = DateTime.fromMillisecondsSinceEpoch(millis);
    return DateTime(date.year, date.month, date.day)
        .millisecondsSinceEpoch;
  }

  static MovementType _movementTypeOr(String name, MovementType fallback) {
    for (final value in MovementType.values) {
      if (value.name == name) return value;
    }
    return fallback;
  }

  static LostSaleStatus _lostSaleStatusOr(
      String name, LostSaleStatus fallback) {
    for (final value in LostSaleStatus.values) {
      if (value.name == name) return value;
    }
    return fallback;
  }
}