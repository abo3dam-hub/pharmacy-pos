PHASE 16 — PRODUCT MASTER SWEEP: COMPLETION REPORT

Status: SHIPPED ✓

Commit: `1f135b1` — "feat(phase16): product-master sweep — smart search, bulk price modes, dashboard, obsolete-field removal"
Branch: `main` (pushed: `94d6ed5..1f135b1`)
CI: `analyze-test` workflow — success ✓
Full details: see `PHASE16-PRODUCT-MASTER-SWEEP-AUDIT.MD`.

---

Shipped in this sweep

1. Smart search (Arabic-normalized)
   - `SmartSearch.normalize()` (diacritics, Arabic letter unification, ة→ه, hamza removal) wired into the items grid and POS catalog search.
   - Contract pinned by `test/smart_search_test.dart` (5 tests).

2. Bulk price increase — catalog-wide modes
   - `BulkPriceScope {all, manufacturer, supplier, manual}` in `bulk_use_cases.dart`.
   - Scope-aware validation and operating-set resolution; `itemIdsForSupplier` added to the item-supplier DAO/repository.
   - Dialog scope selector + conditional manufacturer/supplier dropdowns; `lastBulkUpdatedCount` drives the success SnackBar.
   - Combined-coverage `test/bulk_price_scope_test.dart` (6 tests).

3. Real-data dashboard at `/`
   - New `features/dashboard/` feature (entity → DAO → controller → page), wired via DI + Riverpod + router.
   - Reuses `ZReportDao` for the today window; profit computed by a dedicated non-draft/non-voided query.
   - `test/dashboard_test.dart` (4 tests).

4. Obsolete-field removal sweep
   - Removed `printBarcodeLabel`, `isOtc`, `scaleBarcodeAlert` (schema, ItemDraft, companions, bulk pass-through, dead `PosCatalogItem` mapping, item form UI, ARB keys, fixtures) — confirmed zero readers beforehand.
   - Non-destructive: schema stays v10, fresh DBs omit the columns, old v10 stores keep inert orphans (future DROP COLUMN noted as follow-up).

Verification

- `flutter analyze`: No issues found.
- `flutter test`: 554 tests — All tests passed.
- Adjusted tests during the sweep: `item_form_ux_test.dart` inline-add count 5 → 7 (Milestone B fields), auth harness dashboard override, `pos_domain_test.dart` fixture cleanup.

Follow-ups

- Physical `DROP COLUMN` for the removed `items` columns in a future destructive schema bump (v11).
- Optional widget-level smoke test for `DashboardPage`.