import '../../../../shared/models/enums.dart';

/// Read-only report models (Phase 11). None of these entities trigger writes;
/// they are projections of the persisted documents and the journal.
///
/// Balance semantics follow the posting engine exactly:
/// `asOfBalance(account, at) = openingBalanceMicros
/// + normalSign(type) * (Σ debits − Σ credits with entry_date <= at)`
/// with normalSign +1 for asset/expense and −1 for liability/equity/revenue.
/// A positive stored balance is therefore a debit balance for asset/expense
/// accounts and a credit balance for liability/equity/revenue accounts.

// ── Trial Balance ──────────────────────────────────────────────────────────

/// One account row in the trial balance.
class TrialBalanceAccountRow {
  const TrialBalanceAccountRow({
    required this.accountId,
    required this.code,
    required this.name,
    required this.accountType,
    required this.openingBalanceMicros,
    required this.periodDebitMicros,
    required this.periodCreditMicros,
  });

  final String accountId;
  final String code;
  final String name;
  final AccountType accountType;

  /// Signed balance immediately before the reporting range.
  final int openingBalanceMicros;

  /// Total debit activity inside the reporting range.
  final int periodDebitMicros;

  /// Total credit activity inside the reporting range.
  final int periodCreditMicros;

  /// Closing balance = opening + (debits − credits), in the account's natural
  /// sign (positive = debit for asset/expense, credit otherwise).
  int get closingBalanceMicros =>
      openingBalanceMicros + periodDebitMicros - periodCreditMicros;

  int get _classic => switch (accountType) {
        AccountType.asset || AccountType.expense => closingBalanceMicros,
        AccountType.liability ||
        AccountType.equity ||
        AccountType.revenue =>
          -closingBalanceMicros,
      };

  /// Classic debit-column placement (mirrors the ledger book).
  int get debitBalanceMicros => _classic > 0 ? _classic : 0;

  /// Classic credit-column placement.
  int get creditBalanceMicros => _classic < 0 ? -_classic : 0;
}

class TrialBalanceReport {
  const TrialBalanceReport({
    required this.fromMillis,
    required this.toMillis,
    required this.accounts,
  });

  final int fromMillis;
  final int toMillis;
  final List<TrialBalanceAccountRow> accounts;

  int get totalDebitMicros =>
      accounts.fold(0, (sum, a) => sum + a.debitBalanceMicros);
  int get totalCreditMicros =>
      accounts.fold(0, (sum, a) => sum + a.creditBalanceMicros);

  /// True when the classic debit and credit columns agree — the double-entry
  /// invariant for balanced postings and openings.
  bool get isBalanced => totalDebitMicros == totalCreditMicros;
}

// ── Income Statement ───────────────────────────────────────────────────────

class IncomeStatementExpenseRow {
  const IncomeStatementExpenseRow({
    required this.code,
    required this.name,
    required this.amountMicros,
  });

  final String code;
  final String name;
  final int amountMicros;
}

class IncomeStatementReport {
  const IncomeStatementReport({
    required this.fromMillis,
    required this.toMillis,
    required this.salesRevenueMicros,
    required this.salesReturnsMicros,
    required this.costOfGoodsSoldMicros,
    required this.operatingExpenses,
  });

  final int fromMillis;
  final int toMillis;

  /// Net movement on the sales revenue account (4000).
  final int salesRevenueMicros;

  /// Positive refund figure reversing sales (4001).
  final int salesReturnsMicros;

  /// Net movement on the cost of goods sold account (5000).
  final int costOfGoodsSoldMicros;

  /// Remaining expense accounts (5100-family + any user expense accounts).
  final List<IncomeStatementExpenseRow> operatingExpenses;

  int get netRevenueMicros => salesRevenueMicros - salesReturnsMicros;
  int get grossProfitMicros => netRevenueMicros - costOfGoodsSoldMicros;
  int get operatingExpensesMicros =>
      operatingExpenses.fold(0, (sum, e) => sum + e.amountMicros);
  int get netIncomeMicros => grossProfitMicros - operatingExpensesMicros;
}

// ── Balance Sheet ──────────────────────────────────────────────────────────

class BalanceSheetItem {
  const BalanceSheetItem({
    required this.code,
    required this.name,
    required this.amountMicros,
    this.isComputed = false,
  });

  final String code;
  final String name;

  /// Signed amount (positive balances only for presentation).
  final int amountMicros;

  /// Computed lines (e.g. accumulated retained earnings) carry no account id.
  final bool isComputed;
}

class BalanceSheetSection {
  const BalanceSheetSection({
    required this.codePrefix,
    required this.title,
    required this.items,
  });

  final String codePrefix;
  final String title;
  final List<BalanceSheetItem> items;

  int get totalMicros => items.fold(0, (sum, i) => sum + i.amountMicros);
}

class BalanceSheetReport {
  const BalanceSheetReport({
    required this.asOfMillis,
    required this.assets,
    required this.liabilities,
    required this.equity,
  });

  final int asOfMillis;
  final BalanceSheetSection assets;
  final BalanceSheetSection liabilities;
  final BalanceSheetSection equity;

  int get totalAssetsMicros => assets.totalMicros;
  int get totalLiabilitiesMicros => liabilities.totalMicros;
  int get totalEquityMicros => equity.totalMicros;

  /// The report balances when Assets = Liabilities + Equity.
  bool get isBalanced =>
      totalAssetsMicros == totalLiabilitiesMicros + totalEquityMicros;
}

// ── Sales Report ───────────────────────────────────────────────────────────

class SalesReportDayRow {
  const SalesReportDayRow({
    required this.dayMillis,
    required this.invoiceCount,
    required this.unitsSold,
    required this.subtotalMicros,
    required this.discountMicros,
    required this.vatMicros,
    required this.totalMicros,
    required this.paidMicros,
    required this.cashMicros,
    required this.cardMicros,
    required this.creditMicros,
    required this.voidCount,
    required this.voidTotalMicros,
    required this.returnCount,
    required this.returnTotalMicros,
    required this.profitMicros,
  });

  /// Start of the business day (local midnight) for the bucket.
  final int dayMillis;
  final int invoiceCount;
  final int unitsSold;
  final int subtotalMicros;
  final int discountMicros;
  final int vatMicros;
  final int totalMicros;
  final int paidMicros;
  final int cashMicros;
  final int cardMicros;
  final int creditMicros;
  final int voidCount;
  final int voidTotalMicros;
  final int returnCount;

  /// Gross profit persisted on the invoices (total − cost of goods).
  final int profitMicros;

  /// Positive refund amount for the bucket (returns.totalMicros is signed).
  final int returnTotalMicros;

  /// Gross sales reduced by refunds issued in the same window.
  int get netSalesMicros => totalMicros - returnTotalMicros;
}

class SalesReport {
  const SalesReport({
    required this.fromMillis,
    required this.toMillis,
    this.customerId,
    this.userId,
    required this.days,
  });

  final int fromMillis;
  final int toMillis;
  final String? customerId;
  final String? userId;
  final List<SalesReportDayRow> days;

  int get invoiceCount => days.fold(0, (s, d) => s + d.invoiceCount);
  int get unitsSold => days.fold(0, (s, d) => s + d.unitsSold);
  int get subtotalMicros => days.fold(0, (s, d) => s + d.subtotalMicros);
  int get discountMicros => days.fold(0, (s, d) => s + d.discountMicros);
  int get vatMicros => days.fold(0, (s, d) => s + d.vatMicros);
  int get totalMicros => days.fold(0, (s, d) => s + d.totalMicros);
  int get paidMicros => days.fold(0, (s, d) => s + d.paidMicros);
  int get cashMicros => days.fold(0, (s, d) => s + d.cashMicros);
  int get cardMicros => days.fold(0, (s, d) => s + d.cardMicros);
  int get creditMicros => days.fold(0, (s, d) => s + d.creditMicros);
  int get voidCount => days.fold(0, (s, d) => s + d.voidCount);
  int get voidTotalMicros => days.fold(0, (s, d) => s + d.voidTotalMicros);
  int get returnCount => days.fold(0, (s, d) => s + d.returnCount);
  int get returnTotalMicros =>
      days.fold(0, (s, d) => s + d.returnTotalMicros);
  int get netSalesMicros => totalMicros - returnTotalMicros;
  int get grossProfitMicros => days.fold(0, (s, d) => s + d.profitMicros);
}

// ── Purchase Report ────────────────────────────────────────────────────────

class PurchaseReportDayRow {
  const PurchaseReportDayRow({
    required this.dayMillis,
    required this.invoiceCount,
    required this.subtotalMicros,
    required this.discountMicros,
    required this.taxMicros,
    required this.shippingMicros,
    required this.totalMicros,
    required this.paidMicros,
    required this.remainingMicros,
    required this.returnCount,
    required this.returnTotalMicros,
  });

  final int dayMillis;
  final int invoiceCount;
  final int subtotalMicros;
  final int discountMicros;
  final int taxMicros;
  final int shippingMicros;
  final int totalMicros;
  final int paidMicros;
  final int remainingMicros;
  final int returnCount;

  /// Positive return amount (purchase returns reverse the supplier balance).
  final int returnTotalMicros;

  int get netTotalMicros => totalMicros - returnTotalMicros;
}

class PurchaseReport {
  const PurchaseReport({
    required this.fromMillis,
    required this.toMillis,
    this.supplierId,
    required this.days,
  });

  final int fromMillis;
  final int toMillis;
  final String? supplierId;
  final List<PurchaseReportDayRow> days;

  int get invoiceCount => days.fold(0, (s, d) => s + d.invoiceCount);
  int get subtotalMicros => days.fold(0, (s, d) => s + d.subtotalMicros);
  int get discountMicros => days.fold(0, (s, d) => s + d.discountMicros);
  int get taxMicros => days.fold(0, (s, d) => s + d.taxMicros);
  int get shippingMicros => days.fold(0, (s, d) => s + d.shippingMicros);
  int get totalMicros => days.fold(0, (s, d) => s + d.totalMicros);
  int get paidMicros => days.fold(0, (s, d) => s + d.paidMicros);
  int get remainingMicros => days.fold(0, (s, d) => s + d.remainingMicros);
  int get returnCount => days.fold(0, (s, d) => s + d.returnCount);
  int get returnTotalMicros =>
      days.fold(0, (s, d) => s + d.returnTotalMicros);
  int get netTotalMicros => totalMicros - returnTotalMicros;
}

// ── Inventory Report ───────────────────────────────────────────────────────

class InventoryMovementSummary {
  const InventoryMovementSummary({
    required this.movementType,
    required this.movementCount,
    required this.quantityBaseSigned,
    required this.totalMicros,
  });

  final MovementType movementType;
  final int movementCount;
  final int quantityBaseSigned;
  final int totalMicros;
}

class InventoryReportItemRow {
  const InventoryReportItemRow({
    required this.itemId,
    required this.barcode,
    required this.name,
    required this.currentStockBase,
    required this.minimumStockBase,
    required this.maximumStockBase,
    required this.unitCostMicros,
    required this.stockValueMicros,
  });

  final String itemId;
  final String? barcode;
  final String name;
  final int currentStockBase;
  final int minimumStockBase;
  final int maximumStockBase;

  /// Historic batch unit cost (FIFO per batch) used for valuation.
  final int unitCostMicros;
  final int stockValueMicros;

  bool get isLowStock =>
      minimumStockBase > 0 && currentStockBase < minimumStockBase;
  bool get isOutOfStock => currentStockBase <= 0;
}

class InventoryReport {
  const InventoryReport({
    required this.generatedMillis,
    required this.fromMillis,
    required this.toMillis,
    required this.items,
    required this.movements,
  });

  final int generatedMillis;
  final int fromMillis;
  final int toMillis;
  final List<InventoryReportItemRow> items;
  final List<InventoryMovementSummary> movements;

  int get itemCount => items.length;
  int get totalStockBase => items.fold(0, (s, i) => s + i.currentStockBase);
  int get stockValueMicros =>
      items.fold(0, (s, i) => s + i.stockValueMicros);
  int get lowStockCount => items.where((i) => i.isLowStock).length;
  int get outOfStockCount => items.where((i) => i.isOutOfStock).length;
}

// ── Lost Sales Report ──────────────────────────────────────────────────────

class LostSalesReportRow {
  const LostSalesReportRow({
    required this.id,
    required this.createdAt,
    required this.requestedItemName,
    required this.barcode,
    required this.scientificName,
    required this.quantityRequested,
    required this.customerName,
    required this.customerPhone,
    required this.status,
    required this.note,
  });

  final String id;
  final int createdAt;
  final String requestedItemName;
  final String? barcode;
  final String? scientificName;
  final int quantityRequested;
  final String? customerName;
  final String? customerPhone;
  final LostSaleStatus status;
  final String? note;
}

class LostSalesReport {
  const LostSalesReport({
    required this.fromMillis,
    required this.toMillis,
    this.status,
    required this.rows,
  });

  final int fromMillis;
  final int toMillis;

  /// Optional status filter (null = all statuses).
  final LostSaleStatus? status;
  final List<LostSalesReportRow> rows;

  int get requestCount => rows.length;
  int get totalQuantityRequested =>
      rows.fold(0, (s, r) => s + r.quantityRequested);

  int countBy(LostSaleStatus status) =>
      rows.where((r) => r.status == status).length;
}