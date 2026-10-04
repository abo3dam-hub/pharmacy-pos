# PHASE18.4 — Sales Management, Routing & Accounting Closure — Completion Report

Date: 2026-09-13 · Branch: `main` · Remote: `abo3dam-hub/pharmacy-pos`

## 1. Executive summary

Phase 18.4 closes the sales-side cycle: the broken `//sale/z-report` /
`//sale/invoice/<id>` URLs that GoRouter could not resolve, the missing
permanent sale-history entry point, the read-only invoice detail (no returns,
no voiding, no status/payment/mode context), and a latent accounting hazard
where a box+part sale's COGS could be derived from the box cost per unit
instead of the batched per-base-unit cost.

Validation: `flutter analyze` clean · **640 tests pass** (full suite) ·
`flutter gen-l10n` clean · new tests: COGS two-mode regression, 19,601 guard,
route-path contract, sales-history widget, plus updated Smart-Alternatives and
fake-repository suites.

## 2. Root causes and fixes

| # | Issue | Root cause | Fix |
| --- | --- | --- | --- |
| 1 | `//sale/...` routes failed | Call sites ran `context.push('/' + AppSection.sale.path + '/...')` producing a double slash that GoRouter could not match | Canonical helpers in `app_sections.dart` — `saleZReportPath()`, `salesHistoryPath()`, `saleInvoiceDetailPath(id)` — used by both the router and every call site (workspace Z-report icon, receipt action, history toolbar icon). Guarded by `test/route_paths_test.dart`. |
| 2 | Receipt «فاتورة البيع» opened a dead page | `context.push` was called while the success dialog was still up → navigation raced the overlay | The dialog action pops itself first, then pushes `saleInvoiceDetailPath(invoice.id)`. |
| 3 | No permanent sales history | Sales could only be inspected right after checkout (receipt popup or Z-report) | New `/sale/history` child route → `SalesHistoryPage`: search + status/payment/cashier/date-range filters applied DB-side, paginated grid/cards, row tap opens detail and reloads on return (mutation-then-refresh, no timers). |
| 4 | Invoice detail read-only & context-poor | Detail page only rendered lines + totals for printing | Header chips (status/payment/cashier/credit-remaining), per-line sale mode where `isPackageSale`/`isPartialSale` are derived at build-time from persisted `unitBaseQuantity` vs hydrated `unitsPerLarge`, **per-line return** dialogs and a **void** action gated by `Perm.salesReturnCreate`/`Perm.returnProducts`/`Perm.salesVoid`, each reloading the view after the mutation. |
| 5 | Smart Alternatives hid out-of-stock items entirely | DAO filtered `availableStockBase > 0` pre-ranking; service `continue`d on `<= 0` | Candidates keep out-of-stock items; the comparator buckets in-stock first then tier/stock/manufacturer/name, so empty-stock options *still appear at the tail* instead of vanishing. Unrelated + inactive still drop. `_addAlternative` surfaces `e.failure.message` (e.g. «المخزون المتاح غير كافٍ…»). |
| 6 | COGS hazard in the two-mode (package+part) sale | A naive reading priced COGS as `sold parts × box unit cost` (44,000) instead of FIFO/FEFO `Σ batch.unitCostMicros × quantityBase` | `test/cogs_mixed_part_regression_test.dart` locks the exact numbers end-to-end (see §4). |
| 7 | F5 / hold labels stale | «حفظ الفاتورة (F5)» / «سلة محفوظة» were outdated | `posHoldBill` = تعليق الفاتورة (F5); held-bill label فاتورة محفوظة; 20 l10n keys added AR+EN, `gen-l10n` regenerated. |

## 3. Architecture changes (reuse-first, no duplication)

- **`lib/core/constants/app_sections.dart`** — sale sub-route helpers (single
  source of truth for sale navigation).
- **`lib/core/router/app_router.dart`** — `history` child route under `/sale`;
  the z-report redirect now uses `saleZReportPath()`.
- **`lib/features/sales/domain/entities/pos_invoice.dart`** — `PosInvoiceView.userName`
  (default `''`, hydrated from `users.full_name`) and
  `PosInvoiceLineView.unitsPerLarge` (default `0`) + read-only getters
  `isPackageSale` / `isPartialSale`.
- **`lib/features/sales/domain/repositories/sales_repository.dart` +
  `data/sales_repository_impl.dart`** — `searchSaleInvoices` extended
  *additively* with `{status, paymentMethod, userId, fromMillis, toMillis}`
  ($dynamic WHERE/Variable list, LIKE escaped, ordered, LIMIT/OFFSET);
  `_buildInvoiceViews` batch-loads `users.full_name` + `item_units.unitsPerLarge`.
- **`pos_workspace_page.dart` / `pos_workspace_controller.dart`** — toolbar
  history icon, router-helper pushes, dialog-pop-then-push receipt, AppException
  surfacing, held-bill label.
- **New pages** — `sales_history_page.dart`, enhanced `pos_invoice_page.dart`
  (reuses `returnSaleLine`/`nextReturnNumber`/`voidInvoice`, `authControllerProvider`
  for permission gating, `InvoicePdfService` for print — no new engines).

Testing surface that had to follow the contract: the `_FakeSalesRepository` in
`pos_domain_test.dart` (new `searchSaleInvoices` signature), and the Smart
Alternatives assertions in `pos_domain_test.dart` + `smart_alternatives_repo_test.dart`
(inverted to the back-ordering behavior).

## 4. Exact-COGS lock (passed)

Box line: 1 sell unit @ 14,000 (= 140,000,000 micros, `quantityBase: 3`).
Part line: 1 sell unit @ 5,600 (= 56,000,000 micros, `quantityBase: 1`).

- `totalMicros` = **196,000,000** (exactly 19,600 units, asserted `isNot(19,601)`).
- Batch: 4 base units @ per-base cost `Money.fromMajor(11,000).divideBy(3)` = **36,666,667**.
- `totalCostMicros` = **146,666,668** (4 × 36,666,667; asserted `isNot(44,000×10,000)`).
- `profitMicros` = **49,333,332**.
- GL COGS (account 5000) = 146,666,668 == Income Statement `costOfGoodsSoldMicros`.
- Stored line money proves the two-mode lock: box row `unitPriceMicros = 140,000,000`,
  `lineTotalMicros = 140,000,000` despite `quantityBaseSigned = 3`.

## 5. Files / tests delivered

- New: `lib/features/sales/presentation/pages/sales_history_page.dart`;
  `test/route_paths_test.dart`, `test/cogs_mixed_part_regression_test.dart`,
  `test/sales_history_page_test.dart`.
- Modified: `app_sections.dart`, `app_router.dart`, `pos_invoice.dart`,
  `sales_repository.dart`, `sales_repository_impl.dart`, `pos_catalog_dao.dart`,
  `smart_alternatives_service.dart`, `pos_workspace_page.dart`,
  `pos_workspace_controller.dart`, `pos_invoice_page.dart`, `app_ar.arb`,
  `app_en.arb` (+ regenerated `app_localizations*`); tests `partial_sale_test.dart`,
  `pos_domain_test.dart`, `smart_alternatives_repo_test.dart`.

## 6. Validation

```
flutter analyze       → No issues found
flutter gen-l10n      → ok (l10n.yaml: app_ar.arb template)
flutter test          → 640 tests, all passed
```

## 7. Remaining debt

1. Sale-mode derivation uses the *current* `unitsPerLarge` at view-build time;
   a persisted `units_per_large` snapshot on the line would decouple history
   rendering from later item/package edits (the per-sell-unit base quantity is
   already stored). See PROJECT_STATUS §7.
2. Windows/Android manual smoke for the routed History/Detail pages (CI covers
   compilation only).