# Pharmacy POS — Project Status Report

Current date: 2026-09-12 · Branch: `main` · Remote: `abo3dam-hub/pharmacy-pos`

> Report for guiding subsequent development. Reflects the state after the
> post-18.3 hardening/perf cycle (commits `c5a57d5` → `a7243c6`).

---

## 1. Snapshot

| Item | Value |
| --- | --- |
| Framework | Flutter (stable), Arabic-first RTL UI |
| Persistence | SQLite via Drift (code-gen `app_database.g.dart`) |
| L10n | `flutter gen-l10n` — `app_ar.arb` / `app_en.arb` |
| Tests | 83 test files · **610 tests pass** · `flutter analyze` clean |
| CI | GitHub Actions: `analyze-test`, `perf-file-db`, `build-windows`, `build-android` |
| Last CI | Run `34665548031` (commit `a7243c6`) — **all 4 jobs success** |

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
| `e5101bf` | **docs**: project status report for the post-18.3 hardening cycle |
| `a7243c6` | **perf(inventory)**: live import progress + cancel; single-tx bulk edits; CI file-DB perf guard |
| `632ee7e` | **fix(import)**: EN-name tie-breaker closes re-import gap on real 11.3k file + commit `test1.xlsx` |

---

## 3b. UX/perf workstream #2 (complete, commit `a7243c6`)

The follow-up to the report's "suggested next targets", implemented and CI-green:

- **Live import progress + cancellation** (top priority from the report):
  - `ImportItemsUseCase.call` accepts `onProgress(ImportProgress)` and
    `shouldCancel()`; `ImportStage { parsing, applying }` and `ImportProgress`
    (processed/total/fraction) are exposed from `excel_use_cases.dart`.
  - `InventoryExcelService.parseImport` and
    `InventoryRepository.applyImport` poll a cancel checkpoint every 64/256
    rows and stream progress; cancellation inside the transaction rolls the
    whole sheet back atomically (`ImportCancelledException` →
    `ImportCancelledFailure`, an informational notice, not an error).
  - `InventoryController` gained `importProgress` state + `cancelImport()`;
    `items_tab.dart` renders `ImportProgressView` (phase label, progress bar,
    X/Y counter, cancel button) inside the existing `LoadingOverlay`.
  - New l10n keys: `inventoryImportParsing/Applying/Progress/Cancel/Cancelled`.
- **Bulk edits now single-transaction + batched audit**:
  - New `BulkUpdateEntry` + `InventoryRepository.applyBulkUpdates` (one
    transaction, same cancel/progress semantics as `applyImport`).
  - `BulkUpdateItemsUseCase` resolves drafts, persists in one transaction and
    flushes per-row + `bulk_op` audit through `AuditService.writeMany` instead
    of one transaction/audit per item.
- **Restore receipt reconciliation** (`RestoreService._reconcileReceiptPaths`)
  now updates expense receipt paths inside one transaction.
- **CI `perf-file-db` job**: runs `PHARMACY_FILE_DB=1 flutter test
  test/inventory_perf_regression_test.dart`, so the 11.3k-row guardrail also
  covers real disk fsync (in-memory DB cannot reproduce it). The perf test
  switches to a temp file DB when that env var is set and widens its ceiling.
- **Tests added**: `test/inventory_import_progress_cancel_test.dart` (4 tests:
  progress stream, atomic rollback on cancel-during-apply, abort
  cancel-during-parse, controller cancel wiring) and
  `test/inventory_real_file_import_test.dart`.

### EN-name tie-breaker (commit after `a7243c6`)
When several candidates survive the composite item match *and* the row's only
remaining discriminator is the English trade name, `_resolveItem` now narrows
by `الاسم التجاري (EN)` (tie-break only — a row that already resolves
uniquely behaves exactly as before, and matching candidates are never
rejected). This resolved the last gap on the **real** catalogue:

- Before: `test1.xlsx` second pass `updated=11278` (`created=11283`, 5
  name-ambiguity guards: كلوتريمازول، مينوكسيديل، يونادول ×3 — rows without
  barcode or active ingredients whose AR name matched >1 product).
- After: `updated=11283 = created`, issues `16` on both passes (same in-file
  duplicates), ~16 s per pass. Products that share AR **and** EN name with no
  other discriminator still trip the guard (correct — cannot disambiguate).
- Two explicit regression tests added in
  `test/inventory_import_identity_regression_test.dart` (EN breaks the tie;
  same-EN twins stay guarded).

### Deliberately not changed
- **Items / users / audit lists already page from the DB**
  (`AppDataTable` + `PageRequest`, sizes 30/25) — they never materialise the
  whole table, so adopting `PagedMasterTable` there would be churn without a
  perf win. `PagedMasterTable` remains the in-memory-list solution (master
  tabs).

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

- 83 files under `test/`; shared helpers in `helpers.dart` (`ensureSqlite`,
  `newDatabase`, role constants `_adminRole = 'role_admin'`,
  `_pharmacistRole = 'role_pharmacist'`).
- Perf/count-heavy tests: `inventory_import_scalability_test.dart` exercises
  14,001-row catalog; `inventory_perf_regression_test.dart` exercises 11,300
  (in-memory by default; `PHARMACY_FILE_DB=1` switches to a temp file DB).
- Scale tests run on in-memory DB → keep budgets generous.
- Known parallel-run flake (pre-existing, not from this cycle): running
  `backup_archive_test.dart` together with the restore/cross-phase suites can
  trip its "no leaked `pharmacy_backup_*` staging dirs" assertion because temp
  staging dirs leak from concurrently-running restore tests; it passes alone
  and in the full-suite run.

---

## 7. Open items / pending decisions

1. **`test1.xlsx` now committed; real-file acceptance is green.** The file
   (sheet `products`, 11,299 data rows, 27 columns) replays end-to-end on
   every test run: first pass `created=11283, master=1860, issues=16`
   (all in-file duplicates), second pass `created=0, updated=11283`,
   ≈16 s/pass. No ambiguity guards remain (EN tie-breaker).
2. **Unanswered design question:** should the Excel service return **bytes only**
   (vs. writing repo-root `inventory.xlsx` during tests)? Tests currently build
   bytes in-memory (`excel.save()` without filename) — keep it that way.
3. **Audit snapshot parity:** old create-audit used full-row JSON
   (`itemAuditJson(createdRow)`); the batched path journals draft-based
   snapshots (`itemAuditJsonDraft`). Acceptable today; revisit if deeper audit
   forensics are wanted.
4. Real-device (Android/Windows) latency for the ~16 s import is not yet
   measured on disk; `perf-file-db` CI now gives a file-backed number on
   Ubuntu, but a Windows/Android run is still outstanding.
5. True isolate offload of the import (parse + Drift writes in a background
   isolate) is the remaining big item for "zero frame drops during 11k import";
   with progress + cancel + single-transaction already shipping, it is lower
   priority now.

---

## 8. Suggested next design targets

- Move the import's heavy work into a background isolate (Drift background
  executor) so even the batch insert never competes with the rasterizer — the
  last big frame-drop item; progress + cancel already ship as the UX layer.
- Extend the progress/cancel pattern beyond inventory if other screens get
  long bulk operations.
- Windows/Android latency measurement of the 11.3k import on a real device.

---

## 9. Commands (reproducibility)

```bash
# test / analyze (full)
flutter test
flutter analyze

# focused perf / import suites
flutter test test/inventory_perf_regression_test.dart \
             test/inventory_import_scalability_test.dart \
             test/inventory_import_identity_regression_test.dart \
             test/inventory_import_progress_cancel_test.dart

# file-backed perf guard (what CI job `perf-file-db` runs)
PHARMACY_FILE_DB=1 flutter test test/inventory_perf_regression_test.dart

# l10n regeneration after editing app_ar.arb / app_en.arb
flutter gen-l10n
```