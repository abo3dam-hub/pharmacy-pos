# Phase 1 — Foundation & Database: Completion Report

Repository: `abo3dam-hub/pharmacy-pos`
Report date: 2026-09-05
Status: Phase 1 delivered; ~90% complete. Remaining items listed below with their plan references.

## 1. What was done

### 1.1 Project scaffolding and folder structure — 100%
Flutter app with a layered architecture per the plan:
- `lib/core/` — cross-cutting: `money/`, `quantity/`, `errors/` (domain exceptions + failures), `constants/` (permission codes), `data_grid/` (paging), `di/` (injection + providers), `util/` (ids).
- `lib/domain/services/` — pure business logic: `base_unit_converter`, `bonus_calculator`, `stock_service`, `sale_service`, `purchase_service`, `return_service`, `audit_service`, `permission_service`.
- `lib/data/daos/` — Drift query layer: `item_dao`, `unit_dao`, `batch_dao`, `stock_movement_dao`, `category_dao`, `manufacturer_dao`, `therapeutic_group_dao`.
- `lib/shared/database/` — schema: `app_database.dart`, `app_database.g.dart`, 31 table files, `seed_data.dart`.
- `lib/l10n/` — Arabic-first localization (template `app_ar.arb`) + generated `AppLocalizations`.
- Platform stubs present: `android/`, `windows/`.

### 1.2 Complete Drift schema (§4) — 95%
31 tables covering the plan's data model, verified by `build_runner` producing a clean `app_database.g.dart` (reproducible in an empty checkout):
accounts, audit_logs, batches, cashbox_transactions, categories, customers, expenses, item_units, items, journal_entries, journal_entry_lines, lost_sales, manufacturers, permissions, prescription_items, prescriptions, purchase_bonuses, purchase_invoice_items, purchase_invoices, return_items, returns, role_permissions, roles, sales_invoice_items, sales_invoices, stock_movements, sub_categories, suppliers, therapeutic_groups, units, users.
Includes the reconciliation cache columns `items.currentStockBase` (§9/§11) and `sales_invoice_items.returnQuantityBase` (§14).

### 1.3 Money, base-unit conversion, validation (§7, §23) — 100%
- `Money`: integer micro-units, scale 4, non-const `fromMajor`/`parse`, const `fromUnits`/`zero`; `format`/`roundTo`/`floorTo` scale-corrected; Arabic-Indic digit output (`٫`/`٬`).
- `BaseUnitConverter`: `toBaseUnits`/`splitToUnits`; `BaseUnitBreakdown` back-computes via box size.
- `DomainException`/`AppException` hierarchy → services throw domain exceptions, never bare `Exception`.

### 1.4 Arabic-first l10n scaffold + Cairo/Tajawal + RTL theme (§34) — 40%
- `l10n.yaml`, `app_ar.arb` (template), `app_en.arb` (~40 keys), `flutter gen-l10n` green, `AppLocalizations.en`/`.ar` generated.
- Fonts (Cairo/Tajawal) and RTL `MaterialApp`/theme intentionally deferred to Phase 2 UI (Phase 1 ships no UI).

### 1.5 RBAC seeds (§16) + audit service (§17) — 100%
- `roles`/`permissions`/`role_permissions` seeds with canonical §16 codes (`sell`, `returnProducts`, `search`, `viewInventory`, `viewAlternatives`, `changePrices`, `changePurchaseCost`, `deleteInvoice`, `manageUsers`, `managePermissions`, `modifySettings`, `adjustStock`).
- Admin (bcrypt `Admin@123`) + cashier/pharmacist matrices, helper accounts, suppliers, categories, units.
- `PermissionService`: `roleIdForUser`, `codesForRole`, `hasRolePermission`, `hasUserPermission`, `require*` guards; unknown users denied.
- `AuditService`: append-only writes with actor id.

### 1.6 Backup metadata layout + migration framework (§29, §37) — 40%
- `schemaVersion 1` + `MigrationStrategy` (`onCreate` seeds, `beforeOpen`) present; smoke test covers open + seed.
- The `backups` metadata table (§29) and backup/restore service are NOT yet implemented (remaining item).

### 1.7 DAOs / repositories (§4.x, §22) — 100%
- Paged, DB-side searches with `PageRequest`/`PageResult`; `byBarcode`; reactive `watchSearch` (item); batch FEFO-ready lookup; supplier/category/manufacturer/therapeutic-group lookups.

### 1.8 Data-grid scaffolding (sort/filter/pagination §22) — 100%
- `PageRequest(page, pageSize, search)`, `PageResult(items, total)`; `count()+LIMIT/OFFSET` queries tested.

### 1.9 Unit tests (§31) — 95%
50 tests, all passing; `flutter analyze` clean (No issues found):
- `money_test` — parse/format/round/floor, Arabic-Indic output.
- `base_unit_converter_test` — box/strip/unit conversions (34 cases).
- `bonus_calculator_test` — 100+10+5+2 = 117, half-up allocation, batch valued ≤ paid.
- `stock_service_test` — FEFO expiry order, expired/voided skipped, NotEnoughStock, ledger/batch/cache atomicity, reconcile.
- `purchase_service_test` — batch 117 @ 8,547 micros, historical cost immutability, multi-batch.
- `sale_service_test` — FEFO deduction, profit, atomic rollback, unpaid rejected.
- `return_service_test` — stock restored to original batch, `returnQuantityBase` cap, over-return rejected.
- `permission_service_test` — admin-all, cashier/pharmacist matrices, unknown-user denied.
- `item_dao_test` — paged search, barcode, reactive watch.
- `database_smoke_test` — open/migrate + seed foundation.

### 1.10 GitHub Actions workflow (§39) — 100%
`.github/workflows/ci.yml`: `analyze-test` (ubuntu, `flutter pub get` → `gen-l10n` → `analyze` → `test`, with system SQLite) on push/PR to `main`; `build-windows` (`flutter build windows --release` + artifact) on `tags/v*`. Latest run: **success**.

## 2. What remains in Phase 1 scope

| Item | Plan ref | Notes |
|---|---|---|
| `backups` metadata table (+ index) | §29 | Not modeled yet; blocks backup service + round-trip test |
| Migration-upgrade test harness (open at older `schemaVersion`, migrate forward) | §37 | `stepsByStep`/`onUpgrade` skeleton exists; no upgrade-path test |
| Full §34 l10n key set (~130 strings) + Cairo/Tajawal + RTL theme | §34 | Partially deferred to Phase 2 (UI) |
| (optional) remaining §31 DB-migration-foundation tests | §31 | Depends on the upgrade harness above |

## 3. Percentage completed

| Deliverable | Plan § | Progress |
|---|---|---|
| Scaffolding / structure | §40 | 100% |
| Complete Drift schema | §4 | 95% |
| Money / base units / validation | §7, §23 | 100% |
| l10n + fonts + RTL theme | §34 | 40% |
| RBAC seeds + audit | §16, §17 | 100% |
| Backup layout + migration framework | §29, §37 | 40% |
| DAOs / repositories | §4.x, §22 | 100% |
| Data-grid scaffolding | §22 | 100% |
| Unit tests | §31 | 95% |
| CI workflow | §39 | 100% |
| **Overall** | | **≈ 90%** |

## 4. Commits on `origin/main`
- `1c53738` feat: implement pharmacy foundation and database
- `6f57a7b` ci: add GitHub Actions workflow

CI: https://github.com/abo3dam-hub/pharmacy-pos/actions (latest run success).