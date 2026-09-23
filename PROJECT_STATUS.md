# Pharmacy POS — Project Status Report

Current date: 2026-09-13 · Branch: `main` · Remote: `abo3dam-hub/pharmacy-pos`

> Report for guiding subsequent development. Reflects the state after the
> Phase 18.4 sales-management cycle (routing overhaul, permanent sales history,
> invoice detail returns/voids, exact-COGS regression). Earlier cycles:
> [`POST-18.3-AUDIT-HARDEN-COMPLETION-REPORT.md`](./POST-18.3-AUDIT-HARDEN-COMPLETION-REPORT.md).

---

## 1. Snapshot

| Item | Value |
| --- | --- |
| Framework | Flutter (stable), Arabic-first RTL UI |
| Persistence | SQLite via Drift (code-gen `app_database.g.dart`) |
| L10n | `flutter gen-l10n` — `app_ar.arb` / `app_en.arb` |
| Tests | 87 test files · **640 tests pass** · `flutter analyze` clean |
| CI | GitHub Actions: `analyze-test`, `perf-file-db`, `build-windows`, `build-android` |
| Last CI | Run `34665548031` (commit `a7243c6`) — **all 4 jobs success**; `ba5d1c6` pushed, CI re-running |

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
| `ba5d1c6` | **feat(harden)**: audit-and-harden cycle — pricing v13, COGS reconciliation, financial dashboard |
| `632ee7e` | **fix(import)**: EN-name tie-breaker closes re-import gap on real 11.3k file + commit `test1.xlsx` |
| `20ef12c` | docs: status report — real-file acceptance green, EN tie-breaker notes |
| `37abc4a`/`14f90a8`/`81e7651` | **feat(ux/errors/i18n)**: chained save-and-continue (item→batch→invoice), reason-based failure messages, AR+EN item names |
| `(next)` | **feat(sales)**: Phase 18.4 — routing overhaul, permanent sales history, invoice detail returns/voids, exact-COGS + 19,601 regressions |
| `(next)` | **fix(cost-basis)**: package-vs-base-unit cost conversion at every entry point (item dialog, purchase form, batch dialog, Excel) + package-basis margin + POS sell-as-part option |

---

## 3e. Phase 18.4 — sales management & routing closure (complete)

Fixes the `//sale/z-report` / `//sale/invoice/<id>` routing bugs, adds a
**permanent Sales History** (سجل المبيعات) and an **actionable invoice detail**,
relabels the F5 hold shortcut, and locks the two-mode-pricing + COGS numbers
with regression tests. Full detail:
[`PHASE18.4-SALES-MANAGEMENT-ROUTING-ACCOUNTING-CLOSURE-COMPLETION-REPORT.md`](./PHASE18.4-SALES-MANAGEMENT-ROUTING-ACCOUNTING-CLOSURE-COMPLETION-REPORT.md).

- **Routing root cause:** call sites built `'/' + AppSection.sale.path` then
  appended the sub-route → `//sale/...`, which GoRouter failed to resolve
  (`no matching sublocation`). Resolved in `app_sections.dart` with canonical
  helpers `saleZReportPath()`, `salesHistoryPath()`, `saleInvoiceDetailPath(id)`
  used by BOTH the router and every call site; guarded by a route-path contract
  test (`test/route_paths_test.dart`).
- **Sales History:** `/sale/history` → `SalesHistoryPage` — search + status /
  payment / cashier / date-range filters, paginated `AppDataTable` (or cards on
  compact), each row opens the invoice detail and reloads on return (no timers).
- **Invoice detail:** status / payment / cashier chips, credit remaining, money
  and sale mode per line (package vs part, derived at build-time from persisted
  `unitBaseQuantity` vs `unitsPerLarge`), per-line return dialogs
  (`Perm.salesReturnCreate`/`Perm.returnProducts`) and a void action
  (`Perm.salesVoid`), each reloading the view after the mutation. Sale history
  icon added to the POS toolbar.
- **Smart Alternatives:** out-of-stock candidates are no longer excluded —
  they rank *behind* in-stock ones (tail position) instead of vanishing;
  unrelated + inactive items still drop. `_addAlternative` now surfaces the
  real reason (`e.failure.message`) instead of ErrorService text.
- **Exact-COGS regression** (`test/cogs_mixed_part_regression_test.dart`):
  box (3 base units @ 14,000) + 1 part (@ 5,600) = **196,000,000 micros**
  (exactly 19,600 units, never 19,601); COGS = **146,666,668** (4 × the
  per-base cost 36,666,667 = 11,000 ÷ 3 half-up), profit 49,333,332 —
  reconciled across invoice chain, GL account 5000, and the Income Statement,
  asserting `isNot(44,000,000×10)` for the historic box-cost-per-unit bug.
  Plus a `19,601` guard test in `partial_sale_test.dart` (pricing level).
- **F5 / labels:** `posHoldBill`= تعليق الفاتورة (F5); held-bill label
  سلة محفوظة → فاتورة محفوظة; 20 new AR+EN l10n keys; `gen-l10n` clean.

---

## 3f. Package-vs-base cost-basis fix (complete)

Ali's report: selling one part posted COGS = the whole box cost (11,000
instead of ≈3,666.667), and the partial-sale option wasn't where he wanted
it. Root cause: costs are **entered per commercial package** (the
pharmacist's unit) but **stored per base unit** (the COGS basis), and several
entry points stored the package figure without converting. Design rule Ali
set: partial selling stays an *option* during sale and in stock — never the
base unit of measure anywhere.

- **New helper** `lib/core/units/package_cost.dart`:
  `packageCostToBaseUnitCost` (half-up division) /
  `baseUnitCostToPackageCost` (exact multiplication) — one conversion point
  for every entry path.
- **Item dialog** (`item_dialog.dart`): `unitsPerLarge` field now seeds the
  stored value (was always `1` on edit); the cost field is labeled with the
  commercial-package name and seeds/displays the package cost, converting to
  per-base on save.
- **Purchase form** (`purchase_form_page.dart`): per-line package/base
  `SegmentedButton` (default package when `unitsPerLarge > 1`); stored values
  stay canonical base-unit; edit/prefill show package entry when the base
  quantity divides evenly.
- **Manual batch dialog** (`batch_dialog.dart` + `batches_page.dart`):
  same package/base toggle; quantity × and cost ÷ on submit in package mode.
- **Excel** (`inventory_excel_service.dart`): import converts the sheet's
  package cost to per-base (blank still preserves); export writes the
  package-scale cost back.
- **Margin** (`inventory_repository_impl.dart`,
  `purchases_repository_impl.dart`): stored `profitMarginBasisPoints` now
  compares package-scale cost vs package price (was 281% on a 27.27% item).
- **POS** (`pos_workspace_page.dart`, `pos_workspace_controller.dart`):
  labeled "sell as part" button (actual part name) in search results for
  partial-sale-configured items; visible box/part toggle chip on cart lines
  (touch alternative to F2); box and part stay separate lines via `cartKey`
  (`item.id::unitMode`); defensive guard in `addToCart` rejects part mode for
  non-configured items; unit labels use real unit names.
- **Tests**: `test/package_cost_basis_regression_test.dart` — helper
  unit tests (11,000 ÷ 3 → 3,666.6667), Excel import/export cost basis,
  package-basis margin (2727 bp), and Ali's end-to-end scenario (one part @
  5,600 → COGS 3,666.6667, never 11,000).
- **Verification (2026-09-24):** `flutter analyze` clean on the whole project;
  full suite **648 tests pass** (640 existing + 8 new), including the
  pre-existing COGS, Excel-contract, partial-sale, POS-integration and
  purchase suites.

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

## 3c. UX workstream #3: save-and-continue, error clarity, bilingual names (complete)

Chained "save and continue" workflow across the Arabic pharmacy-entry screens,
plus clearer failure messages everywhere and AR+EN item-name display:

- **Chained item → batch → invoice workflow:**
  - Product window (both **add-new** and **edit**) gains a third button
    **"حفظ و اضافة الى المخزون"** (`itemSaveAndContinueBatch`); returning
    `ItemFormAction.saveContinue` it saves the item and routes to
    `/inventory/batches/{itemId}?add=1` (the new item's id on create, the
    edited item's id on edit), where
    `BatchesPage.autoOpenAddBatch` (read from the `add` query param) auto-opens
    the add-batch dialog.
  - Batch window gains **"حفظ و اضافة فاتورة"**
    (`batchSaveAndContinuePurchase`); on `BatchFormAction.saveAndAddPurchase`
    the saved batch carries `PurchasePrefill(itemId, batchNumber, quantityBase,
    unitCostMicros)` to `/purchases/new` (GoRouter `extra`), which pre-fills the
    first invoice line (item resolved via the repository, base unit name, the
    entered quantity + unit cost). Navigation checks `Perm.purchasesCreate`
    first.
- **Reason-based failure messages (was: generic/occasionally silent errors):**
  - The batch dialog previously closed on a missing expiry with an unexplained
    error. It now keeps the dialog open and shows an inline field error
    **"تاريخ الانتهاء مطلوب لمنتج بتاريخ صلاحية"** (`batchExpiryRequired`)
    under the expiry field (cleared on date pick); invalid cost now surfaces
    `batchCostInvalid` (was `authSaveError`).
  - New shared helper `lib/core/errors/failure_messages.dart`
    (`failureMessage(l10n, failure)` + `showFailureSnack(context, failure?)`)
    maps repository failures to user-facing reasons (`DatabaseFailure` keeps a
    non-empty message, `DuplicateFailure` surfaces `failure.message`,
    `UnauthorizedFailure` explains permissions, unknown → a stable generic).
  - Applied across **16 pages** that previously either swallowed failures or
    showed a generic message (inventory batches/master tabs/items tab,
    purchases form/detail/list, customers/customer statement, suppliers/supplier
    statement, users, roles, settings, prescriptions form/detail/list).
    `data_management_page.dart` already surfaced `failure.message` and was left
    as-is.
- **AR+EN item names displayed together:**
  - `InventoryItemView.displayName` → `'عربي (English)'`; top-level
    `itemDisplayName(ItemRow)` for row-level use (inventory_item.dart). Used in
    the items grid + cards, the batches page header, and the purchase item
    picker/search + invoice lines.
  - Follow-up sweep (committed after `6294101`): a single shared rule
    (`bilingualName` in `lib/core/util/bilingual_name.dart` — both names when
    available, English preferred when forced to pick one) now drives **every**
    item/product surface: POS catalog list + cart lines + alternatives /
    "similar by composition" panels, POS checkout Rx/stock/stock-validation
    messages, POS invoice line views + PDF receipts + returns list (resolved
    live from `items`, bilingual for historical records too), prescription
    form picker + stored lines + prescription detail, purchase/receive detail
    lines + bonuses, the dashboard low-stock and near-expiry widgets, and the
    inventory report. Row/card "confirm" dialogs keep the compact
    `primaryLabel` (customer-facing EN preferred) for full-width names.
- **Controller:** `InventoryController.lastCreatedItemId` (String?) set on
  successful `createItem` (reset each attempt) so the continue flow knows the
  new item id — `createItem` still returns `Failure?`, keeping
  `inventory_controller_busy_regression_test.dart` intact.
- **Tests:** `test/item_batch_purchase_flow_regression_test.dart` (5 tests) —
  item form offers the continue action on create **and** on edit, both
  returning `saveContinue`, and the button stays hidden when the continue
  action is not enabled; an expiry-tracked batch blocks inline and keeps the
  dialog open; the save-and-add-invoice button returns its action with the
  filled input (quantity + money units). Plus
  `test/bilingual_name_test.dart` (8 tests) locking the AR+EN display rule and
  its POS fallbacks, and updated POS/perf/prescription name assertions
  (`بانادول (Panadol)`). Full suite: **622 tests green**, `flutter analyze`
  clean.

---

## 3g. UX simplification: quick/detailed item entry + lightweight motion language (complete, commit `b0bd81f`)

Ali's direction: simplify without removing features — the app felt complex,
rigid, and plain; he wanted colour, motion, and life, especially in the
dashboard, but kept light and never garish.

- **Item dialog: progressive disclosure** — new toggle
  **إدخال سريع / إدخال مفصّل** (quick entry default). Quick mode shows only
  the essential fields: barcode + trade name, category + manufacturer,
  commercial packaging, parts count, partial-sale setup, package cost, sale
  price, and the expiry toggle. The detailed mode keeps **every** Phase 17
  field in its previous order — nothing was removed, the advanced fields are
  just hidden until needed. 2 new AR+EN l10n keys; `localization_parity_test`
  updated.
- **Lightweight motion language** — new `lib/core/motion/app_motion.dart`:
  `Entrance` (short fade+slide with optional delay), `Stagger` (cascading
  entry), `CountUp` (animated numeric counters), `PressScale` (subtle press
  feedback). All built on `TweenAnimationBuilder` — short, cheap animations,
  no heavy rive/lottie assets.
- **Dashboard**: staggered KPI card entrance, numbers count up from zero,
  icon badges with a calm colour gradient + soft shadow; financial-visibility
  permissions unchanged.
- **Purchase invoice**: newly added item rows enter with a light
  fade/slide; package/part, bonus, and all accounting behaviour untouched.
- **POS**: cart-lines total/count animates gently via `AnimatedSwitcher` on
  line-count changes; pricing, COGS, and selling rules unchanged.
- **Tests**: 1 new test locking the quick/detailed mode behaviour; 4 existing
  tests adjusted to open the detailed mode via a new `_openDetailedDialog`
  helper. Verification (2026-09-24): `flutter analyze` clean, **649 tests
  pass**.
- Report: `UX-SIMPLIFICATION-REPORT-2026-09-24.pdf`.

---

## 3h. Camera barcode scanning on Android (complete)

- New `lib/core/scanning/` module on top of `mobile_scanner` (^7.4.2):
  `BarcodeScanService` (platform gate + injectable `current` for tests),
  `BarcodeScannerPage` (full-screen viewfinder, torch/camera-switch, first
  decode auto-pops, friendly camera-permission-denied message),
  `ScanBarcodeButton` (renders nothing where camera scanning is unsupported).
- Scan button wired into every barcode entry point: item dialog barcode
  fields (quick + detailed), POS search (camera scan follows the hardware
  scan path: search + quick-add), inventory `SearchField` (new optional
  `onScan`), purchase-invoice item search dialog.
- Desktop/web unchanged: the button hides itself, the HID `BarcodeBuffer`
  pipeline keeps working.
- AndroidManifest gains the `CAMERA` permission; 4 new AR+EN l10n keys.
- **Tests**: `test/barcode_camera_scan_test.dart` (7 tests: unsupported
  platforms, fake-service delivery, cancel no-op, SearchField wiring).
- Verification (2026-09-24): `flutter analyze` clean, **656 tests pass**.

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

- 86 files under `test/`; shared helpers in `helpers.dart` (`ensureSqlite`,
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
6. **Phase 18.4 residual debt:** (a) sale-mode on history/detail lines is
   derived from the *current* `item_units.unitsPerLarge` at view-build time —
   if an item's package size changes (or the item is deleted) after a sale, the
   old line degrades to base-unit display; the sell-unit base quantity is
   already persisted (`salesInvoiceItems.unit_base_quantity`), so a stored
   `units_per_large` snapshot would remove the coupling. (b) the phone-URL
   routing fix shipped without a manual Windows/Android smoke; CI builds cover
   compilation only.

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