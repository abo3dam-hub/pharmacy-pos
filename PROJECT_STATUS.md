# Pharmacy POS — Project Status Report

Current date: 2026-09-12 · Branch: `main` · Remote: `abo3dam-hub/pharmacy-pos`

> Report for guiding subsequent development. Reflects the state after the
> post-18.3 hardening/perf cycle (commits `c5a57d5` → `fa080fa`).

---

## 1. Snapshot

| Item | Value |
| --- | --- |
| Framework | Flutter (stable), Arabic-first RTL UI |
| Persistence | SQLite via Drift (code-gen `app_database.g.dart`) |
| L10n | `flutter gen-l10n` — `app_ar.arb` / `app_en.arb` |
| Tests | 82 test files · **603 tests pass** · `flutter analyze` clean |
| CI | GitHub Actions: `analyze-test`, `build-windows`, `build-android` |
| Last CI | Run `34663453629` (commit `fa080fa339…`) — **all 3 jobs success** |

Local env used by this workflow:

- Flutter SDK: `/teamspace/studios/this_studio/flutter`
- Repo: `/teamspace/studios/this_studio/projects/pharmacy-pos`
- `grep` only (no `rg`); tests require `ensureSqlite()` before sqlite3 use.

---

## 2. Feature map (`lib/`)

- `shared/` — cross-cutting: `database/` (AppDatabase + DAOs + `seed_data.dart`
  seeding via `db.batch`), design system widgets, l10n.
- `domain/` — `services/`: `permission_service.dart`, `audit_service.dart`,
  `stock_service.dart`.
- `features/` — `accounts, audit, auth, backup, customers, dashboard,
  expenses, inventory, prescriptions, purchases, reports, sales, settings,
  suppliers` (each with `data/` + `domain/` + `presentation/`).
- `features/inventory/` (the focus of recent work):
  - `domain/repositories/inventory_repository.dart` — contract + import types
    (`applyImport`, `ImportApplyEntry/Outcome/Result`, `ImportApplyAction`).
  - `data/repositories/inventory_repository_impl.dart` — Drift implementation.
  - `domain/usecases/excel_use_cases.dart` — `ImportItemsUseCase`,
    `ExportItemsUseCase`.
  - `domain/services/inventory_excel_service.dart` — xlsx parse/export,
    the 18-column header template.
  - `presentation/widgets/paged_master_table.dart` — `PagedMasterTable<T>`.
  - `presentation/.../master_data_tabs.dart`, `items_tab.dart`.

---

## 3. Commit trail (current hardening cycle)

| SHA | What |
| --- | --- |
| `c5a57d5` | **Phase 18.3**: import auto-creates master data; in-stock-first inventory view (origin of the reported issues) |
| `4d55ae5` | **fix(inventory)**: invoke in-file dedupe identity so imports keep every row (duplicate-collapse regression) |
| `e63b3bb` | **feat(inventory)**: safe delete + paginated master lists + scrollable grids |
| `fa080fa` | **perf(inventory)**: single-transaction import + batched audit, perf regressions |

---

## 4. The 4 post-18.3 issues → resolutions (complete)

All four tracked issues are fixed, tested, and committed.

### 4.1 Import collapses 22,212 rows → 17,052 (duplicate identity)
- **Cause:** the dedupe key used for "matches an existing product" collapsed
  distinct variants that shared a trade name (identical merchandise row).
- **Fix (`4d55ae5`):** the in-file duplicate detector restores the real identity
  (`tradeName`+`strength`), so every distinct row imports; re-import updates the
  same rows by barcode when present.
- **Tests:** `test/inventory_import_identity_regression_test.dart` (48-row
  trade-name-variant matrix: 48 created on first pass, 48 updated on re-import).

### 4.2 Master lists froze with large catalogues
- **Fix (`e63b3bb`):** `PagedMasterTable<T>` (page size 50, debounced search,
  pager + count snack, `AppDirectionalIcons`) drives all five master tabs;
  `items_tab.dart` and grids render scrollable, bounded lists.
- **Tests:** `test/paged_master_table_test.dart` — pagination, search reset,
  and a 5,000-entry case proving materialization stays ≤ page size.

### 4.3 Safe deletes for master data
- **Fix (`e63b3bb`):** delete flows for items + five master kinds (manufacturer,
  category, unit, active ingredient, indication) with relation checks
  (`item_units`, ledger history via `_itemHasHistory`…), confirm dialogs, audit
  writes, and `Perm.inventoryDelete` gating (admin-only).
- **Tests:** `test/inventory_delete_regression_test.dart` (10 tests).

### 4.4 Import performance / perceived hanging (this cycle)
- **Cause:** row loop opened a Drift transaction per row + one audit insert per
  row (+ per auto-created master row) → ~2×11k transactions, all awaited on the
  UI thread under the busy overlay.
- **Fix (`fa080fa`):**
  - `applyImport` persists the whole sheet in **one** transaction; per-row
    `_guarded()` + `on DomainException` capture keeps `'الصف N: <msg>'` failure
    semantics — a single bad row never rolls back the file.
  - `AuditService.writeMany` (`AuditEntry` list → one `db.batch`) journals every
    item + auto-created master + bulk-op summary in a single insert batch.
  - `_insertItemInternal`/`_updateItemInternal` are transaction-free helpers so
    the outer transaction owns the writes; updates preserve item suppliers.
- **Measured (in-memory DB, 11,300 rows):** fresh import **16.1 s**, re-run
  update **15.4 s** (the unoptimized path was far worse on a file-backed DB).
- **Tests:** `test/inventory_perf_regression_test.dart` — 11,300 fresh creates +
  audit count `11,301`, then 11,300 updates, both under a 120 s guardrail;
  printed durations give the real numbers. Budgets are loose **on purpose**:
  memory-DB CI runs should not flake; the strong guarantee is structural
  bounded rendering + single-transaction import.

---

## 5. Ground rules / gotchas discovered (write down, don't relearn)

- **`item_units` has NO `unit_id` column** — schema is
  `id, item_id, base_unit_id, large_unit_id, units_per_large`. The delete
  in-use check must query `base_unit_id = ?1 OR large_unit_id = ?1`.
- **`AuditLogRow.action` is stored as a String** (e.g. `'delete'`), not the
  enum — assertions compare against `AuditAction.delete.name`.
- **Drift nested transactions are avoided** — helpers never open their own
  transactions; the caller owns `_db.transaction`.
- **`db.batch` is callback-based** in this Drift version
  (`await db.batch((b) { b.insert(...); })`, no explicit `batch.commit()`).
- **Widget-test finder gotcha:** `find.text(...)` can match both the search
  `TextField` text and table cells — scope via
  `find.descendant(of: find.byType(AppDataTable), matching: …)`.
- **Fake `InventoryController` constructions in tests must pass all positional
  ctor args** (incl. `DeleteItemUseCase`).
- **`_guarded` error contract:** SqliteException `2067` → `DuplicateException`,
  `787` → FK `ValidationException`, else `DatabaseException`.
- **Xlsx builder in tests:** header positions follow `InventoryExcelService.headers`;
  barcode = column 0, trade name = column 2 (writing a name into column 3 feeds
  the EN-name field and produces zero rows).
- `Perm.inventoryDelete` is seeded **admin-only**.

---

## 6. Test conventions

- 82 files under `test/`; shared helpers in `helpers.dart` (`ensureSqlite`,
  `newDatabase`, role constants `_adminRole = 'role_admin'`,
  `_pharmacistRole = 'role_pharmacist'`).
- Perf/count-heavy tests: `inventory_import_scalability_test.dart` exercises
  14,001-row catalog; `inventory_perf_regression_test.dart` exercises 11,300.
- Scale tests run on in-memory DB → keep budgets generous.

---

## 7. Open items / pending decisions

1. **Real 11,299-row file not re-testable end-to-end** locally (repo copy is a
   1-row sample). If the user re-shares the real file, replay it through
   `ImportItemsUseCase` and record `summary` counts + elapsed.
2. **Unanswered design question:** should the Excel service return **bytes only**
   (vs. writing repo-root `inventory.xlsx` during tests)? Tests currently build
   bytes in-memory (`excel.save()` without filename) — keep it that way.
3. **Audit snapshot parity:** old create-audit used full-row JSON
   (`itemAuditJson(createdRow)`); the batched path journals draft-based
   snapshots (`itemAuditJsonDraft`). Acceptable today; revisit if deeper audit
   forensics are wanted.
4. Real-device (Android/Windows) latency for the 16 s import is not yet
   measured on disk; file-backed DB will differ from the in-memory numbers.

---

## 8. Suggested next design targets

- Move the whole import (parse + apply + audit) off the UI thread into an
  isolate / workflow with progress rows so the 11k import never blocks the
  frame, replacing the busy overlay with a cancellable progress screen.
- Reuse the `applyImport` atomicity pattern in other bulk paths
  (expenses/purchases/backup restore) that still loop transactions.
- Extend `PagedMasterTable` to the remaining large lists (inventory items,
  users, audit log) for uniform UI guarantees.
- Consider a lazy/CI job that runs the 11,300-row import against a file-backed
  migration to catch disk-fsync regressions (not possible on in-memory CI).

---

## 9. Commands (reproducibility)

```bash
# test / analyze (full)
flutter test
flutter analyze

# focused perf / import suites
flutter test test/inventory_perf_regression_test.dart \
             test/inventory_import_scalability_test.dart \
             test/inventory_import_identity_regression_test.dart

# l10n regeneration after editing app_ar.arb / app_en.arb
flutter gen-l10n
```