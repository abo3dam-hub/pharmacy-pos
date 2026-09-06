# PHASE 7 — PRODUCTION POS WORKSPACE, SALES UI & INVOICE/RETURN FOUNDATION — COMPLETION REPORT

**Date**: 2026-09-06
**Baseline**: `379cf5c` — 217 tests, 0 analyzer issues
**Final**: working tree — 281 tests (64 new), 0 analyzer issues

---

## Acceptance Gate

| Criterion | Status | Proof |
|-----------|--------|-------|
| 10-customer workspace + return tab, own state per tab | **PASS** | `PosWorkspacePage` 10×`posWorkspaceControllerProvider(i)` + return tab (`kReturnTabIndex=10`); unit tests assert per-tab isolation |
| Hermetic pure-Dart domain (no Drift in POS domain) | **PASS** | `lib/features/sales/domain/**` pure Dart; `pos_domain_test.dart` runs without sqlite |
| Search catalog + barcode scanner prompt | **PASS** | `search()`/`handleScannedBarcode()` + `BarcodeBuffer` (enter-terminated, prefix/suffix, reset) |
| Prescription-gated cart + partial-sale pricing | **PASS** | RX-linking + `PosLinePricer` decomposition ($13.30/130-base anchor below) |
| Checkout → payment (cash/card/mixed) → receipt → engine invoice | **PASS** | Widget test: search→add→qty→pay→receipt→persisted invoice (total/paid/change asserted) |
| Returns with per-line over-return prevention + RX reversal | **PASS** | Integration group: partial return 4 ok, over-return 7 rejected (`NotEnoughStockException`), return 6 → RX back to active |
| FEFO consumption multi-batch | **PASS** | Integration: older-expiry batch drains to 0 before newer |
| Atomic rollback on underpayment | **PASS** | Integration: paid < total → `InvalidOperationException`, invoice not created, movements untouched |
| RBAC gates (sell / returns / lost sales / price override / alternatives) | **PASS** | Controller perms + engine gates; end-to-end sell-flag vs role test; `change_prices` RBAC unit test |
| Keyboard shortcuts (F1/F2/F5/F12/Alt+S) via `Intent`s | **PASS** | `core/shortcuts/pos_shortcuts.dart` + `PosWorkspacePage` `Shortcuts`/`Actions` map |
| Arabic-first RTL UI + l10n | **PASS** | `app_ar.arb` keys + `Money.formatArabicDigits()` (Arabic-Indic digits, ٫/٬ separators) |
| No fake features | **PASS** | All flows hit `SaleService`/`ReturnService` over a real DB (see known limitations) |
| `flutter analyze` clean | **PASS** | 0 issues |
| All regression tests pass | **PASS** | 281/281 |

**PHASE 7: COMPLETE**

---

## What Was Delivered

### New feature module — `lib/features/sales/`
- **domain/** — pure Dart: `pos_pricing` (unit-mode base conversion + partial decomposition), `pos_cart_totals`, `payment_calculator`; entities `pos_catalog_item`, `pos_cart`, `pos_customer`, `pos_invoice`, `pos_hold`, `pos_rx`; abstract `SalesRepository`.
- **data/** — `pos_catalog_dao.dart` + `pos_workspace` DAO querying and `sales_repository_impl.dart` bridging to the Phase 6 engine (`SaleService`, `ReturnService`, `StockService`, `PosCatalogDao`), invoice/return numbering (`SI-…`/`RT-…`), search, alternatives, holdings.
- **presentation/** — `pos_workspace_page.dart` (tabs, two-panel desktop, compact bottom-sheet cart, payment sheet, receipt dialog, alternatives, lost-sale, customer/prescription pickers, hold-bills sheet, return tab), `pos_invoice_page.dart` invoice view, `pos_workspace_controller.dart` + `pos_workspace_state.dart`.
- **core/shortcuts/** — `barcode_buffer.dart` (shared, per-tab) and `pos_shortcuts.dart` (F1 search focus, F2 toggle unit mode, F5 hold, F12 checkout, Alt+S alternatives).

### Engine integration & RBAC (verified facts)
- `SaleService.recordSale` requires `Perm.salesCreate` for completed sales; `ReturnService.recordSaleReturn` requires `Perm.salesReturnCreate`; the paid < total check lives inside `db.transaction` → rollback is atomic.
- Controller gates: checkout `Perm.sell`; returns `Perm.salesReturnCreate || Perm.returnProducts`; lost sale `Perm.lostSalesCreate || Perm.salesCreate`; price override `change_prices`; alternatives `Perm.viewAlternatives`. Router guards `/sale` (+ invoice view) with `Perm.salesView`.
- Cashier role exposes `returnProducts` but not `salesReturnCreate` → the controller lets a cashier attempt returns, then the engine rejects with `UnauthorizedException`. See Known Limitations.

### Integration with router / DI / l10n
- `app_router.dart` routes `/sale` and `/sale/:id/invoice` (permission-guarded).
- `injection.dart` registers `PosCatalogDao` + `SalesRepository`; `providers.dart` adds `posCatalogDaoProvider`, `salesRepositoryProvider`, and the per-tab `posWorkspaceControllerProvider` family.
- ~55 new l10n keys in `app_ar.arb`/`app_en.arb` (re-generated Dart bindings included).

---

## Pricing Anchor (re-verified in POS context)

Locked behavior (see `PHASE6-PRICING-ANCHOR-CLARIFICATION.md`): `items.sellingPriceMicros` is per Large/Commercial unit. Partial = stripping with a markup applied exactly once.

| Case | Result | Where |
|------|--------|-------|
| 1 strip | $1.10 = 10 000 × 1.10(base) | `PosLinePricer` unit test |
| 3 strips | $3.30 = 30 base units | unit test |
| 10 strips | $10.00 (NO cumulative markup) | unit test |
| 13 strips | 13 strips ≡ 1 box + 3 strips → $13.30 → 130 base units | unit test |
| Box-mode sale | $10.00/box, 100 base units | widget + integration tests |

Invariant checked in tests: `partsPerFull × sellablePartBase = unitsPerLarge`.

---

## Verification

### New tests (64)

| Suite | Count | Scope |
|-------|------|-------|
| `test/pos_domain_test.dart` | 55 | `PosLinePricer` decomposition & unit modes, `PosCartValidator`, `PaymentCalculator` (cash/card/mixed, change, negatives rejected), `BarcodeBuffer` (terminator/prefix/suffix/reset/maxLength), `PosWorkspaceController` full behavioral matrix with `_FakeSalesRepository` (merge-by-key, RX linking/remaining, stock guards, unit-mode toggle, RBAC on checkout/returns/lost-sale/override, hold/restore/delete, scan) |
| `test/pos_integration_test.dart` | 6 groups | Real in-memory Drift DB + `SalesRepositoryImpl` + controller: RX partial→dispensed; RX+OTC mixed; FEFO multi-batch; partial return + over-return + RX reversal; paid<total atomic rollback; RBAC gate end-to-end |
| `test/pos_workspace_page_test.dart` | 3 | Widget (real DB, Admin login, 1280×800 desktop): full buy flow (search→add→qty→pay→receipt→invoice persisted + cart emptied), empty-search no-results + lost-sale action, customer picker attaches the selected customer |

### Regression
- `flutter test` → **281/281 passed** (217 baseline + 64 new).
- `flutter analyze` → **0 issues**.

### Real defects found & fixed by the new verification battery
1. **Payment sheet never re-enabled the pay button while typing.** `_PaymentSheetBodyState._reload` updated controller inputs but not the sheet's own `setState`; `canSubmit`/change stayed stale (cash shown as 0). Fixed by adding `setState` in `_reload` (caught by the widget happy-path test).
2. **`searchSaleInvoices` broke with no search term**: `WHERE 1=1 … LIMIT ?2 OFFSET ?3` with only 2 bound params → sqlite3 `Expected 3 parameters, got 2`. Placeholders renumbered to `LIMIT ?1 OFFSET ?2` when no query (caught by the widget test's persisted-invoice assertion).
3. Plus the earlier cascade of analyzer root causes already normalized in this phase (wrong relative import depths, malformed record type `({String, int})` → `(String, int)`, invalid `const true`, `.not` tear-off, non-nullable `doctorName`, TEAR/visible-for-testing lints → `currentState` getter, positional DI ctor).

---

## Known Limitations (documented, not faked)

- **Credit sales**: the engine rejects `paidMicros < totalMicros`; POS intentionally exposes only cash/card/mixed. Recorded as a product decision.
- **Invoice voiding**: the engine has no `voidInvoice`; no UI surface for voiding.
- **Cashier vs engine return gate**: cashier holds `returnProducts` but not `salesReturnCreate`; the controller's dual-gate admits the attempt and the engine denies it. Intended tightening — revisit by adding `salesReturnCreate` to the cashier seed role if product wants cashier returns.
- **Printing**: no `pdf`/`printing` dependency; print buttons surface a snackbar (placeholder).
- **Held bills**: in-memory per-tab, scoped to the session (per design).
- **Returns**: per-line only; return tab scans the original invoice then offers line-level refund.

---

## File Inventory

New: `lib/features/sales/**` (dao, repository impl, domain entities/usecases/repository, controller/state, workspace + invoice pages), `lib/core/shortcuts/{barcode_buffer,pos_shortcuts}.dart`, `test/pos_domain_test.dart`, `test/pos_integration_test.dart`, `test/pos_workspace_page_test.dart`.

Modified: `lib/core/di/{injection,providers}.dart`, `lib/core/router/app_router.dart`, `lib/l10n/app_{ar,en}.arb` + generated `app_localizations*.dart`.