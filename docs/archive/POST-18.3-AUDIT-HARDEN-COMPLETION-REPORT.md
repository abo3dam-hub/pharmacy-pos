# Post-18.3 Audit & Harden — Completion Report

Status: SHIPPED ✓

Branch: `main` · Landing commit: `ba5d1c6`
Local gate: `flutter analyze` clean · `flutter test` **630/630 pass** ·
`PHARMACY_FILE_DB=1` perf regression pass
CI: pushed to `origin/main` → `ci.yml` will verify all four jobs including
`build-apk` and `build-windows`

---

## 1. Scope

This cycle hardens the PosWorkspace / reporting surfaces that surfaced runtime
defects after the 18.3 inventory work: request/sell-unit pricing correctness,
_العروض الصيادلة_ (Smart Alternatives) completeness, a Windows black-screen,
payment-field crashes on malformed input, purchases-list refresh, COGS
accounting integrity, and financials exposure on the landing dashboard.

---

## 2. Shipped in this cycle

### 2.1 Two-mode pricing + sell-unit engine (schema `v13`)

- `sales_invoice_items.unit_base_quantity INTEGER NOT NULL DEFAULT 1` added;
  `kCurrentSupportedSchemaVersion = 13` with the forward-migration kept
  default-safe for legacy rows.
- Sell-unit engine: a line's `quantity` (sell units) × `unitBaseQuantity` =
  base quantity, so `gross = unitPriceMicros × quantity` per sell unit (box full
  price, part partial price) with the exact-slot money allocation (last slot
  takes the remainder).
- Returns reverse stored row money proportionally; `PosLineUnitMode` pruned to
  `largeUnit | sellablePart`.
- Regression coverage lives in `partial_sale_test.dart`, `pos_domain_test.dart`,
  `sale_service_test.dart`, `migration_test.dart`, `pdf_documents_test.dart`,
  `cross_phase_integration_test.dart`, `pos_workspace_page_test.dart`.

### 2.2 Search + Smart Alternatives

- Full-catalog search ordering and package-price-based suggestion ordering
  verified; in-stock-first tiers (`SmartAlternativeTier`) and green/yellow/blue
  grouping confirmed end-to-end.
- **Manufacturer name** added to `PosCatalogItem.manufacturerName` and hydrated
  in a single batched lookup (`PosCatalogDao._manufacturerNamesByItem`); every
  search-suggestion subtitle and the alternatives-dialog subtitle now appends
  ` · manufacturerName` when present. Asserted in
  `smart_alternatives_repo_test.dart`.

### 2.3 POS black-screen (Windows)

- The Alt+S alternatives pick was an unawaited `addToCart` future whose
  rejection surfaced after unmount — a silent blank screen. Now awaited through
  a guarded `_addAlternative` that respects `mounted`, keeps `SnackBar` errors
  localized, and falls back to the controller error message.

### 2.4 Payment-field audit

- Root cause found: `PaymentCalculator.calculate` **throws on negative
  amounts**, and the payment sheet fed raw `TextField` input into it inside
  `build` — typing `-` crashed the sheet.
- `_cashMicros` / `_cardMicros` now null-out malformed/negative input; a new
  `_amountsMalformed` gate disables submit and shows `posInvalidPayment`
  instead of crashing or silently selling for 0. Regression widget test:
  `payment fields: "-" and malformed input never crash or submit`.

### 2.5 Purchases: state refresh + inline supplier create

- Confirmed the purchases list re-fetches on return because the plain
  `ShellRoute` remounts child pages on `go`.
- Added inline supplier create to the purchase form (`_addSupplier` via
  `showSupplierFormDialog` → `createSupplierUseCaseProvider`), gated by
  `suppliersCreate`, selecting the new supplier and surfacing
  `supplierCreatedMessage`.

### 2.6 COGS forensic reconciliation

- New `test/cogs_forensic_trace_test.dart` drives the real pipeline
  (`SaleService.recordSale` FEFO allocation → `ReturnService.recordSaleReturn`
  partial return → void via `sale_service`) and reconciles COGS from **three
  independent sources**:
  1. the posted invoice cost chain (`totalCostMicros` − returns − voids),
  2. GL account 5000 `balanceMicros` (`FinancialPostingService`),
  3. `ReportsDao.incomeStatement().costOfGoodsSoldMicros`.
- In the sample matrix (batches 5×1,000 + 4×2,000; two invoices, one partial
  return, one void) all three reconcile to **2,000** and the income statement
  breaks into sales 8,000 / returns 4,000.
- The old unverifiable "44,000 / green-box 9,000" anchors were replaced with
  this explicit-arithmetic matrix.

### 2.7 Financial-report exposure — dashboard

- The Income Statement / Balance Sheet / Trial Balance were already exposed in
  the Reports hub; the gap was the landing dashboard.
- Added a per-day income-statement strip fed by
  `ReportsDao.incomeStatement(start-of-day → now)`: إيرادات، مرتجعات، صافي
  الإيرادات، تكلفة البضاعة المباعة، مجمل الربح، صافي الربح — gated by
  `reports.view_profit` so restricted roles see no financials.
- Wiring: `DashboardController` now takes `ReportsDao`; `DashboardSnapshot`
  gained a `DashboardFinancials` read model; new widget tests
  `test/dashboard_page_test.dart` cover both the visible and hidden paths.
- New l10n key `dashboardFinancialSummary` (en/ar) regenerated via
  `flutter gen-l10n`.

---

## 3. Files

- `lib/domain/services/`: `partial_price_calculator.dart`, `return_service.dart`,
  `sale_service.dart`
- `lib/features/sales/`: `pos_catalog_dao.dart`, `pos_catalog_item.dart`,
  `pos_cart.dart`, `pos_invoice.dart`, `pos_pricing.dart`,
  `pos_workspace_controller.dart`, `pos_workspace_page.dart`,
  `pos_invoice_page.dart`, `sales_repository_impl.dart`
- `lib/features/purchases/presentation/pages/purchase_form_page.dart`
- `lib/features/dashboard/`: `dashboard_controller.dart`, `dashboard_dao.dart`,
  `dashboard_snapshot.dart`, `dashboard_page.dart`
- `lib/features/backup/domain/entities/backup_manifest.dart` (schema-version bump)
- `lib/shared/database/`: `app_database.dart` + `.g.dart`,
  `tables/sales_invoice_items.dart`
- `lib/core/di/injection.dart` · `lib/core/pdf/pdf_documents.dart` · `lib/l10n/*`
- Tests: `pos_workspace_page_test.dart`, `smart_alternatives_repo_test.dart`,
  `dashboard_test.dart`, `auth_harness.dart`, plus the new
  `cogs_forensic_trace_test.dart` and `dashboard_page_test.dart`

---

## 4. Verification

- `flutter gen-l10n` — clean (regenerated with the new key).
- `flutter analyze` — **No issues found**.
- `flutter test` — **630 pass / 0 fail** (86 test files; +9 test cases this
  cycle: payment regression, 2 COGS reconciliation, 2 dashboard-gating, plus
  pricing/alternatives regressions).
- `PHARMACY_FILE_DB=1 flutter test test/inventory_perf_regression_test.dart` —
  pass (re-run of 11,300 rows ~17 s, no fsync stall).
- Not runnable on this Linux host: `flutter build apk --release` and
  `flutter build windows --release` (no Android SDK / Windows host) — delegated
  to the pushed `ci.yml` runners, which mirror the exact local gate
  (analyze → test → perf-file-db → apk → windows).

---

## 5. Commands (reproducibility)

```bash
flutter analyze
flutter test
PHARMACY_FILE_DB=1 flutter test test/inventory_perf_regression_test.dart
flutter test test/cogs_forensic_trace_test.dart test/dashboard_page_test.dart
flutter gen-l10n   # after editing app_ar.arb / app_en.arb
```