PHASE 16 — PRODUCT MASTER SWEEP: AUDIT & COMPLETION

Scope: smart search, bulk price modes (catalog-wide), real-data dashboard, obsolete-field removal. Companion to `PHASE16-PROMIT.MD` (release launch) and `PHASE16-COMPLETION-REPORT.MD` (release-launch outcome). This document covers the independent product-master sweep delivered on top of them.

---

1. SMART SEARCH (Arabic-normalized)

Implemented
- `lib/core/util/smart_search.dart` — `normalize()`: strip diacritics, unify Arabic letters, transform ة→ه and أ/إ/آ→ا, optional remove spaces, lowercase.
- DAO integration in `lib/data/daos/item_dao.dart`, `lib/data/daos/smart_search_dao.dart`, and the POS catalog facade `lib/features/sales/data/pos_catalog_dao.dart` so the items grid and the POS search panel resolve Arabic queries without letter-for-letter typing.

Arabic normalization contract (asserted by tests)
- `normalize('إبرة')` == `'ابره'` (ة→ه + remove hamza) — the original expectation `'ابرة'` was wrong and corrected in the test.

Verification
- `test/smart_search_test.dart` (5 tests) — green.
- Combined suite runs green (`00:03 +87 All tests passed!`); `flutter analyze` clean.

---

2. BULK PRICE INCREASE — CATALOG-WIDE MODES

New scope model: `enum BulkPriceScope { all, manufacturer, supplier, manual }` in `lib/features/inventory/domain/usecases/bulk_use_cases.dart`.

Behavior (`BulkUpdateItemsUseCase.call`)
- `manual` — operates on an explicit item selection (`input.itemIds`); unchanged legacy path.
- `all` — resolves the whole catalog (`repo.searchItems(PageRequest(page:1, pageSize:1000000))`).
- `manufacturer` — requires `priceManufacturerId`; resolves all items of that manufacturer.
- `supplier` — requires `priceSupplierId`; resolves via new `repo.itemIdsForSupplier(...)`.
- Validation is scope-aware: permanently empty selections are rejected for `manual` only; price-percent operations (which mutate rather than replace prices) are allowed with an empty selection for catalog scopes.
- Audit `after` metadata now records `operation`, `price_scope`, `price_manufacturer_id`, `price_supplier_id`, `target`, `selection`, `updated`, `basis_points`, plus original audit keys; the audit note includes the scope name.

Data-layer addition
- `ItemSupplierDao.itemIdsForSupplier(String)` added and exposed on `InventoryRepository` + `InventoryRepositoryImpl`.

UI
- `showBulkDialog` gained `manufacturers` and `suppliers`; a `RadioGroup<BulkPriceScope>` selects the scope and a conditional manufacturer/supplier dropdown appears; submit validates per scope.

Controller
- `InventoryController.bulk` exposes `lastBulkUpdatedCount` so the success SnackBar reports the real number of updated items (`l10n.bulkDone(n)`), not the selection size.

Localization
- New keys in both ARBs (with placeholder metadata): `bulkPriceScopeTitle`, `bulkPriceScopeAll`, `bulkPriceScopeManufacturer`, `bulkPriceScopeSupplier`, `bulkPriceScopeManual`; `gen-l10n` regenerated.

Verification
- `test/bulk_price_scope_test.dart` (6 tests) — covers accept/reject per scope and price application; green.
- Affected regression suites green (`+19 All tests passed!`); `flutter analyze` clean.

---

3. REAL-DATA DASHBOARD AT `/`

Decision (recorded for audit)
- Dashboard is a real Drift-backed read feature, not a placeholder. Today window = start-of-day → now. Z-Report totals are reused from `ZReportDao.aggregate`; today's profit has no `ZReport` field, so it is computed by a dedicated `DashboardDao._todayProfit` query (non-draft, non-voided sales in the window).

New files
- `lib/features/dashboard/domain/entities/dashboard_snapshot.dart` — `DashboardSnapshot` (KPIs + lists), `LowStockItem`, `NearExpiryBatch` (has `batchId` row id), `RecentInvoice`.
- `lib/features/dashboard/data/dashboard_dao.dart` — all reads: active items, customers, suppliers, stock value (non-voided batches, positive quantity), low / out-of-stock counts derived from policy bounds (`min>0` and `current < min`), top low-stock (8), near-expiry within a 90-day horizon (8, ascending), recent sales (6), recent purchases (6), today's profit.
- `lib/features/dashboard/application/dashboard_controller.dart` — `DashboardStatus {initial, loading, ready, error}` + `DashboardViewState`; `load()` and `refresh()`.
- `lib/features/dashboard/presentation/dashboard_page.dart` — KPI grid (today sales, today orders, today profit, units sold, active items, stock value), low-stock + near-expiry cards, recent activity (sales/purchases), loading/error/retry states; uses `Money`, app typography and spacing tokens.

Wiring
- `lib/core/di/injection.dart` — `_registerDashboard(db)` (registers DAO + controller).
- `lib/core/di/providers.dart` — `dashboardControllerProvider`.
- `lib/core/router/app_router.dart` — `AppSection.dashboard` now renders `const DashboardPage()` instead of the placeholder.

Localization
- Reused existing keys (`dashboardDailySales`, `dashboardTodayOrders`, `dashboardProfitToday`, `dashboardLowStock`); new keys in both ARBs: `dashboardKpis`, `dashboardUnitsSold`, `dashboardActiveItems`, `dashboardStockValue`, `dashboardLowStockEmpty`, `dashboardNearExpiry`, `dashboardNearExpiryEmpty`, `dashboardRecentSales`, `dashboardRecentPurchases`, `dashboardRecentEmpty`, `dashboardError`, `dashboardRetry`; `gen-l10n` regenerated.

Verification
- `test/dashboard_test.dart` (4 tests) — snapshot totals, low/out-of-stock counters, near-expiry window, recent-sales ordering; green.
- `flutter analyze` clean.

Drift note (captured for future schema work)
- drift 2.31.0: column-vs-column comparisons use `isSmallerThan(Expression)`; `select`/`orderBy` take predicate functions; `selectOnly`/join `where` take bare expressions.

---

4. OBSOLETE-FIELD REMOVAL SWEEP

Hypothesis: `items.print_barcode_label`, `items.is_otc`, `items.scale_barcode_alert` are one-way dead storage.

Completed audit (readers = 0 across lib/ and test/)
- No label/barcode-printing feature exists (no ESC/POS / sticker / printer code anywhere).
- No scale/weighing integration exists; `scaleBarcodeAlert` has zero consumers.
- `isOtc` was mapped into `PosCatalogItem` but never read. Restricted-item gating uses `requiresPrescription` / `isControlledDrug` (`pos_cart.dart`, `pos_workspace_controller.dart`); mixed RX+OTC invoices are modeled by a nullable `sales_invoices.prescription_id`, not the flag.
- Excel import/export, PDF receipts, purchases, reports, settings, backup/restore, and seed data do not reference any of the three fields.

Removal (done, non-destructive, no schema-version bump)
- Hand-edited: `lib/shared/database/tables/items.dart`; `ItemDraft` in `inventory_repository.dart`; `_applyPercent` in `bulk_use_cases.dart`; insert/update companions in `inventory_repository_impl.dart`; dead `isOtc` mapping in `pos_catalog_item.dart` + `pos_catalog_dao.dart`; item form UI state + switches and save wiring in `item_dialog.dart`; ARB keys + regenerated localizations; `PosCatalogItem` fixtures in `test/pos_domain_test.dart`.
- Regenerated: `lib/shared/database/app_database.g.dart` (drift), `app_localizations*.dart` (`gen-l10n`).

Migration posture
- Schema stays v10. Fresh databases no longer create the three columns. Pre-existing v10 stores keep inert orphan columns (Drift does not validate extra columns); a future maintenance window may `ALTER TABLE items DROP COLUMN` them. `backup_manifest.kCurrentSupportedSchemaVersion` and migration/backup/restore tests are unchanged.
- No committed drift schema dump exists for v10, so no snapshot regeneration was required.

Verification
- `flutter analyze` clean; `test/pos_domain_test.dart`, `item_dao_test.dart`, `inventory_test.dart`, `bulk_price_scope_test.dart`, `smart_search_test.dart`, `schema_audit_test.dart`, `database_lifecycle_test.dart`, `migration_test.dart` all green (`+103 All tests passed!`).

---

5. VERIFICATION SUMMARY

- `flutter analyze`: No issues found.
- Full test suite: green (see per-milestone counts above).
- Pre-push gate (analyze + full `flutter test`) passes; commit + push + GitHub Actions monitored.

---

6. FOLLOW-UPS

- Physical `DROP COLUMN` for the three obsolete `items` columns in a future schema bump (v11) if a destructive migration is ever entertained.
- Optional widget-level smoke test for `DashboardPage`.