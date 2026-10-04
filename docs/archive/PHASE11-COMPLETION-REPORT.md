# PHASE 11 — Reports Hub Completion Report

## Summary

Phase 11 delivered the **Reports** feature: a single read-only hub with 9 tabs —
Trial Balance, Income Statement, Balance Sheet, Sales, Purchases, Inventory,
Lost Sales, Customer Statement and Supplier Statement — each with date filters,
PDF/Excel export, permission gates and full DI/router wiring. All figures are
projections over the persisted documents and the *journal* (the single source
of truth, Phase 10.1); the reporting layer never writes, so the balance sheet
and trial balance always reconcile against accumulated profit.

- Analyzer: `flutter analyze` → **No issues found**.
- Tests: **435 passed** (Phase 10.1 baseline 417 + **18 new**). One output bug
  and one PDF-rendering crash found & fixed during the work.
- Schema version: **8 (unchanged** — reports are read-only projections, no
  migration).

## Semantics

- **Sign convention reuses the posting engine exactly**: `normalSign` (+1 asset/
  expense, −1 liability/equity/revenue). Opening balance = `opening_balance_micros
  + sign·(Σ debits − Σ credits before the window)`; period movements and closing
  balances follow the same rule, so a balanced journal yields balanced statements.
- **Balance sheet identity**: Assets = Liabilities + Equity is guaranteed by a
  computed retained-earnings item (code `P&L`, label "الأرباح المحتجزة
  (الأرباح المتراكمة)") equal to Σ revenue balances − Σ expense balances as-of.
- **Income statement**: revenue contribution = credit − debit; `4001`
  (sales-returns) is a contra line surfaced as `salesReturnsMicros`; `4002`
  (purchase-returns) is deliberately ignored; `5000` → COGS; other expense
  accounts become `operatingExpenses`.
- **Date conventions**: sales by `created_at`, purchases by `invoice_date`,
  day-bucketing in local midnight via `_dayKey`. Ranges are `[from, to)`.
- **Sales report**: collected non-draft, non-voided invoices + voids + standalone
  sale returns into per-day rows; optional customer/user filters.
- **Purchase report**: non-voided invoices + purchase returns, supplier filter.
- **Inventory report**: stock snapshot (active items, batches) + movement
  summaries by `MovementType` inside the window.
- **Lost sales report**: `[from, to)` + optional `LostSaleStatus` filter.

## Changes

### Reporting domain / data
- `lib/features/reports/domain/entities/report_models.dart` — report row models
  (trial-balance row, income-statement rows, balance-sheet items/sections,
  sales/purchase/inventory/lost-sales rows).
- `lib/features/reports/data/reports_dao.dart` — `ReportsDao` (7 read-only
  projections: `trialBalance`, `incomeStatement`, `balanceSheet`,
  `salesReport`, `purchaseReport`, `inventoryReport`, `lostSalesReport`).
  Fixed during test work: the *voided-invoices* SELECT omitted `created_at`
  while the aggregation loop read it (Null cast crash).
- `lib/features/reports/domain/services/report_export_service.dart` — generic
  `ReportCell` / `ReportTotalRow` / `ReportExportRequest` + pure `buildPdf` /
  `buildExcel` byte builders. Constructor dependency `documents` made public so
  tests inject a filesystem-backed `PdfDocuments`.
- `lib/features/reports/domain/services/statement_export.dart` +
  `presentation/widgets/report_actions.dart` — statement/Excel + PDF/print
  actions (`saveReportExcel`, `printReportPdf`, `ReportExportBar`).

### Application / state / wiring
- `lib/features/reports/application/reports_controller.dart` — `ReportViewState<T>`
  + `ReportController<T>._run` and 7 controllers (Trial balance, income
  statement, balance sheet, sales, purchases, inventory, lost sales) +
  `LostSalesStatusFilter`.
- `injection.dart` (`_registerPhase11(db)`) + `providers.dart` — `ReportsDao`,
  `ReportExportService` and the 7 controllers registered.
- `app_router.dart` — `/reports` route + hub guard requiring ANY
  `reportsViewSales/Purchases/Inventory/Profit | lostSalesView | accountingView`.

### UI
- `presentation/pages/reports_hub_page.dart` — 9-tab scrollable hub mirroring the
  Accounts hub pattern.
- Tab pages: `trial_balance_tab.dart`, `income_statement_tab.dart`,
  `balance_sheet_tab.dart`, `sales_report_tab.dart` (customer + cashier
  dropdowns), `purchase_report_tab.dart` (supplier dropdown),
  `inventory_report_tab.dart`, `lost_sales_tab.dart` (status dropdown),
  `customer_statement_tab.dart`, `supplier_statement_tab.dart`.
- Customer/supplier statement tabs reuse the existing
  `statementForExport` (full-range, no mutation) instead of duplicating
  controllers; a `null` page maps to `UnauthorizedFailure` → no-permission state.
- `presentation/widgets/report_page.dart` — shared `ReportFilterBar`, `ReportBody`,
  `ReportPage`, `PermissionGate`, and date helpers.
- Permission gates per tab (e.g. TB/IS/BS → `reportsViewProfit`, sales →
  `reportsViewSales`, lost sales → `lostSalesView`, statements →
  `customersView`/`suppliersView` + `reportsViewSales`/`Purchases`).
- l10n: all report + statement keys verified in both `app_ar.arb` / `app_en.arb`;
  `flutter gen-l10n` run.

### Critical bug found during implementation — PDF lam-alef crash
`ReportExportService.buildPdf` (and any PDF text containing a real lam-alef
letter pair `لا` — e.g. the empty-state message "لا توجد بيانات") crashed with
`RangeError … Not in inclusive range 0..12: 13` inside the transitive `bidi`
2.0.13 package during layout. The `arabic_reshaper` output emits pre-composed
lam-alef presentation forms (U+FEF5–U+FEFC) which overflow `bidi`'s 13-entry
Arabic composition table at render time.

**Fix** (`lib/core/pdf/pdf_arabic.dart`): `PdfArabic.shape` now decomposes those
ligature code points to `ل + ZWNJ + ا`. The zero-width non-joiner keeps the pair
visually separate and prevents the downstream composer from re-joining (and
crashing). Every other letter keeps its reshaped presentation form, so existing
document output is unchanged.

### Tests added (18)
- `test/report_export_test.dart` (6) — `ReportCell.toText` money/integer/bool
  rendering (Latin digits, scale-4 micro-units, thousands separators); `buildExcel`
  returns valid ZIP bytes; `buildPdf` returns `%PDF` bytes including the
  empty-dataset path; cell text drives both renderers.
- `test/reports_dao_test.dart` (11) — balanced journal seeded via
  `FinancialPostingService.postJournalEntry`, `SaleService`, `PurchaseService`,
  `ReturnService` + direct `returns`/`lost_sales` rows:
  - trial balance: opening (pre-period) vs period splits by natural sign, prior
    activity never leaks, debit columns = credit columns + classic closing
    columns balance;
  - income statement: revenue/contra-return/COGS/expense numbers and prior-period
    exclusion;
  - balance sheet: Assets = Liabilities + Equity with the `P&L` retained item,
    and point-in-time cutoff;
  - sales: sold + voids + returns per day, customer filter;
  - purchases: invoices + returns, supplier filter, negative-return sign;
  - inventory: stock snapshot + movement summaries;
  - lost sales: date-window and status filters.
- `test/reports_integrity_test.dart` (1) — same dataset through the real sale and
  purchase services, asserting journal row-count zero-mutation, TB debit=credit,
  IS net income == BS retained figure, and the full BS identity.

## Verification

- `flutter analyze` — clean.
- `flutter test` — **435 passed** (full suite), no failures.

## Remaining tech debt

- **`bidi` lam-alef composition remains a latent package bug**: the workaround is
  applied at the shaping layer (correct for all PDF output). If the app ever
  upgrades `bidi` this decomposition (and the guard test in `report_export_test`)
  should be revisited.
- **Reports are projections, not snapshots**: figures recompute from documents on
  every query; there is no materialized report table, so query cost grows with
  journal size (acceptable at pharmacy scale, revisit if reporting volume grows).
- **`4002` purchase-returns liability account** is still seeded/dead (Phase 10.1
  decision); the income statement deliberately ignores it, and its future GL
  treatment would flow through `incomeStatement`/`balanceSheet` untouched.
- **Statement tabs reuse the transactional statement logic** rather than a
  dedicated reports DAO query; this keeps one source of truth but means
  statement exports share the statement page's pagination semantics.