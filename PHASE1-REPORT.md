# Phase 1 — Foundation & Database: Completion Report (100%)

Repository: `abo3dam-hub/pharmacy-pos`
Report date: 2026-09-05
Status: **Phase 1 closed — every §4–§39 deliverable within scope is complete and verified.**
Verification: `flutter analyze` → No issues found; `flutter test` → **64/64 passing**; latest CI run success.

## 1. What was delivered

### 1.1 Project scaffolding and folder structure — 100% (§40)
Flutter app with a layered architecture:
- `lib/core/` — `config/` (app constants), `money/`, `quantity/`, `errors/` (domain exceptions), `constants/` (permission codes), `data_grid/` (paging), `di/`, `util/`.
- `lib/domain/services/` — pure business logic: `base_unit_converter`, `bonus_calculator`, `stock_service`, `sale_service`, `purchase_service`, `return_service`, `audit_service`, `permission_service`, **`backup_service`** (new).
- `lib/data/daos/` — Drift query layer (item, unit, batch, stock movement, category, manufacturer, therapeutic group).
- `lib/shared/database/` — `app_database.dart` (+ generated part), **32 table files**, `seed_data.dart`.
- `lib/l10n/` — Arabic-first localization (template `app_ar.arb`).
- Platform stubs: `android/`, `windows/`.

### 1.2 Complete Drift schema — 100% (§4)
32 tables cover the plan's data model (31 §4 tables + the §29 `backups` ledger):
`accounts, audit_logs, backups, batches, cashbox_transactions, categories, customers, expenses, item_units, items, journal_entries, journal_entry_lines, lost_sales, manufacturers, permissions, prescription_items, prescriptions, purchase_bonuses, purchase_invoice_items, purchase_invoices, return_items, returns, role_permissions, roles, sales_invoice_items, sales_invoices, stock_movements, sub_categories, suppliers, therapeutic_groups, units, users.`

Schema-alignment audit performed against §4 and finished at **100%**:
- Every field, uniqueness constraint and helper index from the plan is present (e.g. `batches(item_id, expiry_date)`, `stock_movements(item_id, created_at)`, audit `(entity_type, entity_id)`, sales invoice `(enabled, invoice_type, created_at)`).
- Reconciliation caches per §9/§11/§14: `items.currentStockBase`, `sales_invoice_items.returnQuantityBase`.
- **Physical column names match the plan literals** — the audit caught three spots where generated defaults diverged: journal/prescription `created_by` (was `created_by_id`), and the returns table (`returns`, was authored as `return_orders`). Corrected and pinned by a PRAGMA-based schema-audit test.
- All §4 enum columns persist the **canonical snake_case values** (`enums.dart` members are the stored literals; `enum_contract_test` locks this contract). Where the plan stores a literal that is not a legal Dart identifier — `InvoiceType.return_invoice` → `'return'`, `JournalReferenceType.return_invoice` → `'return'` — a custom `EnumValueConverter` maps member↔stored value (§4.14/§4.23), verified by round-trip tests.
- Non-nullability per plan enforced in the schema (movement/invoice users, return origin, audit actor+entity, categories, unit multiplicities, etc.).
- `returns` record both standalone return orders (§4.19) consistent with hybrid signed-line returns (§4.15).

### 1.3 Money, base-unit conversion, validation — 100% (§7, §23)
- `Money`: integer micro-units (scale 4), `fromMajor`/`fromUnits`/`parse`, scale-corrected `roundTo`/`floorTo`, Arabic-Indic digit formatting.
- `BaseUnitConverter`: `toBaseUnits`/`splitToUnits` + self-consistent `BaseUnitBreakdown`.
- Services throw `DomainException` subclasses; never bare `Exception`.

### 1.4 l10n + fonts + RTL app shell — 100% (§34)
- `l10n.yaml`, `app_ar.arb` (template) + `app_en.arb` — **87 keys each, parity verified**; `flutter gen-l10n` green.
- Cairo + Tajawal **bundled** under `assets/fonts/` and registered in `pubspec.yaml` (offline-first, no google_fonts runtime fetch).
- `lib/main.dart`: Arabic-first default locale (`ar`), `supportedLocales [ar, en]`, proper localization delegates, RTL-aware `NavigationRail` workspace shell with the §3 section map; `widget_test` renders and navigates it.

### 1.5 RBAC seeds + audit — 100% (§16, §17)
- `roles`/`permissions`/`role_permissions` use the **canonical §16 codes as persisted values** (`name` = code, `nameAr` = Arabic label, `granted` flag, surrogate `id` per linkage).
- Admin (bcrypt `Admin@123`) + cashier/pharmacist matrices; helper accounts, suppliers, categories, units.
- `PermissionService` `require*` guards; unknown users denied.
- `AuditService` append-only with actor + entity ids and a stored action mapper (`auditActionToStored`) emitting the §4.27 literals (`create/update/delete/login/logout/void/restore/price_change/bulk_op/audit_config/backup/restore_backup`).

### 1.6 Backup metadata + migration framework — 100% (§29, §37)
- `backups` table: `file_path, file_name, created_at, app_version, schema_version, size_bytes, checksum_sha256, status, note` + `created_at`/`status` indexes.
- `BackupService`: `recordCompleted` (SHA-256 via `crypto`, audit `backup` entry, ledger), `history`/`latest`, and `verifyRestore` (re-opens the file copy through `AppDatabase.fromFilePath`, runs `PRAGMA integrity_check`, compares checksums — audit `restore_backup` trajectory).
- Forward-only `MigrationStrategy.onUpgrade` harness proven by a **migration test**: a v1 file DB without `backups` is reopened under a future v2 schema and the table is added in place with zero data loss; a second test proves close/reopen data persistence on a real on-disk file.

### 1.7 DAOs / repositories — 100% (§4.x, §22)
- Paged, DB-side searches (`PageRequest`/`PageResult`), `byBarcode`, reactive `watchSearch`, batch FEFO-ready lookup, master-data lookups. `UnitDao` base/large-unit relation with conversion.

### 1.8 Data-grid scaffolding — 100% (§22)
- `PageRequest(page, pageSize, search)`, `PageResult(items, total)`, `count()+LIMIT/OFFSET` tested.

### 1.9 Tests — 100% (§31)
**64 tests, all passing.** `flutter analyze` clean.
- **Domain:** `money_test`, `base_unit_converter_test`, `bonus_calculator_test` (100+10+5+2 → 117 half-up), `permission_service_test`.
- **Services:** `stock_service_test` (FEFO expiry order; expired/voided excluded; **non-expiring batches eligible and sorted last**; atomicity; reconcile), `purchase_service_test` (bonuses, historical cost immutability, multi-batch), `sale_service_test`, `return_service_test` (batch restore, `returnQuantityBase` cap).
- **Data:** `item_dao_test` (paged search, barcode, reactive watch), `database_smoke_test`.
- **New in this closure:** `schema_audit_test` (every §4 table exists; critical NOT NULL columns; required indexes; enum + `'return'` literal round-trips), `enum_contract_test`, `migration_test` (file reopen + forward-only upgrade), `backup_service_test` (ledger + checksum + restore + audit), updated `widget_test` (Arabic RTL shell).

### 1.10 GitHub Actions workflow — 100% (§39)
- `analyze-test` (ubuntu, system SQLite, `pub get → gen-l10n → analyze → test`) on push/PR to `main`.
- `build-windows` (release + artifact) on `tags/v*`.
Checkout stays clean in CI because the Drift generated part and l10n outputs are committed; fonts are committed assets.

## 2. Remaining Phase-1 scope
**None.** Every plan deliverable in Phase 1 scope is implemented and verified.

## 3. Percentage completed

| Deliverable | Plan § | Progress |
|---|---|---|
| Scaffolding / structure | §40 | 100% |
| Complete Drift schema (32 tables) | §4 | 100% |
| Money / base units / validation | §7, §23 | 100% |
| l10n + fonts + RTL shell | §34 | 100% |
| RBAC seeds + audit | §16, §17 | 100% |
| Backup + migration framework | §29, §37 | 100% |
| DAOs / repositories | §4.x, §22 | 100% |
| Data-grid scaffolding | §22 | 100% |
| Unit tests (64 passing) | §31 | 100% |
| CI workflow | §39 | 100% |
| **Overall** | | **100%** |

## 4. Commits on `origin/main`
- `faabecd` docs: add initial project architecture plan
- `643caf5` docs: reconcile architecture plan with pharmacy specification
- `edac298` docs: finalize pharmacy architecture and database specification
- `1c53738` feat: implement pharmacy foundation and database
- `6f57a7b` ci: add GitHub Actions workflow
- `2aa74a2` docs: add Phase 1 completion report
- *(next)* feat: complete pharmacy phase 1 foundation

CI: https://github.com/abo3dam-hub/pharmacy-pos/actions (analyze-test green; build-windows on tags).