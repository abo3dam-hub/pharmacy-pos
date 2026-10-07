# Pharmacy POS — Project Status (living document)

**Last updated:** 2026-10-05 · **Branch:** `main` · **Remote:** `abo3dam-hub/pharmacy-pos`
**HEAD:** `5883dad` — "CI fix: guardrail allowlist pos_workspace_page.dart 794 -> 795 (run #132)"

> This is the **single current-state document**. Any future agent starts here.
> Updated with every change (per Ali, 2026-10-04). Dated deep-dive reports are
> frozen under [`docs/archive/`](./docs/archive/) — do not treat them as current.

## Living documents (the fixed set)

| Document | Purpose | Updated |
|---|---|---|
| `README.md` | Overview, features, build & install instructions | on behavior/build change |
| `CHANGELOG.md` | Notable changes history | every change |
| `PROJECT_STATUS.md` | **This file — current state** | every change |
| `PROJECT-ARCHITECTURE-PLAN.md` | Authoritative architecture & database spec | on architecture change |
| `design.md` | Design-system spec (§33 responsive foundation etc.) | on design change |
| `ALI-FOUR-FIXES-REPORT-2026-10-04.md` | Latest fix round (today) | frozen |
| `DASHBOARD-VISUAL-REFRESH-REPORT-2026-10-04.md` | Latest visual round (today) | frozen |
| `docs/archive/` | All older reports, prompts, one-off analyses | never (frozen) |

## 1. Snapshot

| Item | Value |
|---|---|
| Framework | Flutter 3.44.2 (pinned in CI), Arabic-first RTL UI |
| Persistence | SQLite via Drift, **schema version 14** (code-gen `app_database.g.dart`) |
| L10n | `flutter gen-l10n` — `app_ar.arb` / `app_en.arb`, exact AR/EN parity |
| Tests | **110 files · 752 tests pass** · `flutter analyze` clean |
| CI | GitHub Actions: `analyze-test`, `perf-file-db`, `build-windows`, `build-android` (~7–8 min critical path) |
| Last CI | Run #133 (commit `5883dad`) — **all 4 jobs green** 2026-10-05 (run #132 failed: guardrail allowlist line drift, fixed) |
| Windows | Portable build via `build-windows` job (`pharmacy-pos-windows` artifact) |
| Android | **arm64-only** APK (`pharmacy-pos-android` artifact, ~45–50MB) |
| Android signing | Stable debug keystore, generated once 2026-10-04, stored as `ANDROID_KEYSTORE_B64` repo secret, restored by CI before build |
| Android versionCode | `= github.run_number` (strictly increasing); `versionName` = `1.1.0` (pubspec) |
| applicationId | `com.pharmacy.pharmacy_pos` (namespace matches) |
| Install behavior | New APKs install **as updates** over older ones. One-time exception: moving off a pre-2026-10-04 randomly-signed APK needs one manual uninstall |

Local dev env (this machine):

- Flutter SDK: `~/workspace/.sdks/flutter` (export to `PATH` before use)
- Repo: `~/workspace/pharmacy-pos`
- `grep` only (no `rg`); tests require `ensureSqlite()` before sqlite3 use
  (`test/helpers.dart`); `/tmp` is a 512M tmpfs — clean `/tmp/flutter_tools.*`
  before full runs

## 2. Recent changes (newest first; detail in CHANGELOG)

- **2026-10-07 — Camera barcode scan in POS + smart price decimals (Ali):**
  camera scan now uses the exact barcode lookup (was: stock-filtered general
  search that hid zero-stock items and silently dropped ambiguous hits);
  `Money.format()` strips trailing zeros (`300.00`→`"300"`, `300.50`→`"300.5"`)
  across all display sites (UI, PDFs, Excel).
- **2026-10-05 — Stale-UI comprehensive audit (Ali's request):** fixed the
  real void-icon bug (`_invoice` assigned without `setState` — AppBar never
  rebuilt) + regression test; sales-history expanded-row cache invalidation;
  auth session permission refresh after role/user edits (was dead code);
  hardened fragile load patterns in purchase form, price history, receipt
  card. Full sweep: 73 state classes, all AppBars, dialog→list flows.
- **2026-10-05 — Android signing fixed for real + backup storage permission**:
  (1) proven via certificate fingerprints that both post-Oct-4 APKs were
  signed with *different* freshly-generated keys — AGP 9.1.0 ignores a merely
  placed `~/.android/debug.keystore`; fix is an explicit `ciStable`
  signingConfigs in `android/app/build.gradle.kts`, fail-hard restore step,
  and a CI fingerprint check (`tool/check_apk_signature.py`); one final
  uninstall needed, then in-place updates. (2) backup/restore/export on
  Android now request file access (`MANAGE_EXTERNAL_STORAGE` on API 30+,
  classic permission below) — previously no storage permission existed at
  all, so writing a backup to a shared folder failed with "unexpected
  error". New deps: `permission_handler`, `device_info_plus`; helper
  `lib/core/permissions/storage_permission.dart`.
- **2026-10-05 — Ali's Windows test round (4 issues)**: (1) return dialog is
  sell-unit aware (box/strip) — the packages-only version silently did nothing
  for part-sale lines; (2) return action column moved first (always visible,
  no scroll) + new "إرجاع الكل" button for full-invoice returns in one
  confirmed step; (3) stock balances/movement log show mixed `packages/parts`
  (`28/2`) via new `formatMixedQuantity` — applied to movement delta/balance,
  batch quantities, and the `compoundStockText` no-part-config fallback;
  (4) double-tap on pay created two invoices — `_submitting` flag + spinner on
  the sheet and `_checkoutInProgress` guard in the controller.
- **2026-10-05 — whole-package rule, radical pass** (Ali's 4th report — parts
  still leaked in POS search stock hints, the return dialog, and dashboard
  cards that also ignored posted returns): fixed all remaining display leaks
  (POS search rows, return dialog in/out in packages, invoice/history/receipt
  fallbacks, POS return note, purchase bonuses, Z-Report page/PDF, sales
  report) and made the dashboard return-aware — `todayTotalMicros` = ledger
  net revenue, `todayProfitMicros` = ledger gross profit, `todayUnitsSold` =
  net whole packages via new `ZReportDao.netPackagesSold` (sale returns
  subtracted). Removed the movements-summary quantity column (cross-item sums
  can't be packages). Added CI guardrail
  `test/whole_package_display_guardrail_test.dart` that fails the build on
  any raw `*Base` quantity interpolated in presentation code.
  `flutter analyze` clean, 754/754 tests pass.
- **2026-10-05 — whole-package rule audit** (Ali reaffirmed: every
  user-facing quantity/cost is in whole commercial packages, never parts):
  the last base-unit displays were found and fixed — dashboard low-stock and
  near-expiry cards, expiry alerts, reorder suggestions (stock/rate/suggested
  qty), purchase detail lines (qty + cost), prescription lines, return dialog
  lines, inventory report rows/totals/print-export, POS product dialog
  (stock + cost), alternatives dialog, and item-dialog min/max stock fields
  (now entered per package). Each view carries `unitsPerLarge` and renders
  via `formatBaseQuantity` / `baseUnitCostToPackageCost`; storage stays per
  base unit (COGS basis). `flutter analyze` clean, 751/751 tests pass.
- **2026-10-05 — Ali's device-feedback round**: (1) chained batch→purchase
  flow no longer double-posts stock — the purchase receive is the single
  posting event and reuses the user's batch number/expiry
  (`batches_page.dart`, `purchase_form_page.dart` `PurchasePrefill` +
  `ReceiveBatchOverride`, `purchases_controller.dart`); (2) batch ledger and
  movement log display quantities/costs per commercial package for packaged
  items (`formatBaseQuantity` in `lib/core/units/package_cost.dart`) and the
  movement log shows human batch numbers instead of UUIDs; (3) returns page
  gained an invoices tab (all sales invoices auto-loaded chronologically —
  no search needed); (4) sales history invoice cards gained a "ترجيع" quick
  return shortcut. Regression tests added (returns invoices tab, ترجيع
  button, package display, `createAndReceive` batch override).
- **2026-10-04 — Ali's four fixes** (`a129f1f`): (1) Android nav drawer
  auto-closes after tapping a destination (`app_shell.dart`); (2) all list
  pages load on entry — root fix for the startup race, `main()` now warms up
  the Drift database (`lib/core/database_warmup.dart`) before the first
  frame; (3) APK installs as update (stable keystore secret +
  `--build-number=${{ github.run_number }}`); (4) CI speed-ups (Gradle cache,
  `concurrency: cancel-in-progress`, pub cache, Flutter 3.44.2 pinned in all
  jobs, `timeout-minutes` guards) with zero test coverage lost.
- **2026-10-04 — arm64-only Android build** (`74c27e0`): CI builds
  `--target-platform android-arm64`; APK ~95MB → ~45–50MB.
- **2026-10-04 — dashboard visual refresh** (`9457b4d`): hero carousel (4
  live-data slides), colorful calm KPI cards, tappable alert headers,
  dark-mode aware pastel palette, no vertical scroll.
- **2026-09-25/26** — item-dialog redesign per Ali's spec (3-column work
  window, `ba3df61`); search-speed overhaul (uses `search_text`, 150ms
  debounce); alternatives black-screen fix (dialog closes itself); inventory
  infinite-loading fix (`039cb42`, page-size floor 25).
- **2026-09-24** — package-vs-base-unit cost-basis fix (single conversion
  point `lib/core/units/package_cost.dart`, half-up); UX simplification
  (quick/detailed item entry, motion language); camera barcode scanning
  (Android); catalog xlsx regenerated with the Dart `excel` package
  (`9e15747`).
- **2026-09-13** — Phase 18.4: sales routing overhaul, permanent sales
  history, invoice detail returns/voids, exact-COGS regression.

Historical detail for anything older lives frozen in `docs/archive/`.

## 3. Open items (need Ali on his device / decision)

1. **Inventory infinite-loading fix** — confirm no-hang + 25-item display on device.
2. **Alternatives black-screen fix** — confirm on device.
3. **Search-speed overhaul** — confirm on real device/database.
4. **Item-dialog redesign** (Ali's own spec) — confirm on device.
5. **Catalog import retry** — the fixed xlsx (22,292 medicines) is ready; Ali
   hasn't retried the import on his device yet (last failure ~row 4,600 on the
   old build).
6. **Real-device latency** of the ~11.3k-row import on Windows/Android disk
   (CI `perf-file-db` gives Ubuntu file-backed numbers only).
7. **Phase 18.4 residual:** sale-mode on history lines is derived at
   build-time from current `units_per_large`; a stored snapshot would remove
   the coupling (sell-unit base quantity is already persisted).

## 4. Ground rules / gotchas (don't relearn)

- **`item_units` has NO `unit_id` column** — schema is
  `id, item_id, base_unit_id, large_unit_id, units_per_large`.
- **`AuditLogRow.action` is stored as a String** (`AuditAction.delete.name`).
- **Drift nested transactions are avoided** — helpers never open their own
  transactions; the caller owns `_db.transaction`.
- **`db.batch` is callback-based** (`await db.batch((b) { b.insert(...); })`).
- **Widget-test finder gotcha:** `find.text(...)` can match both the search
  `TextField` and table cells — scope via `find.descendant(...)`.
- **Fake `InventoryController` in tests must pass all positional ctor args.**
- **`_guarded` error contract:** SqliteException `2067` → `DuplicateException`,
  `787` → FK `ValidationException`, else `DatabaseException`.
- **Xlsx builder in tests:** header positions follow
  `InventoryExcelService.headers`; barcode = column 0, trade name = column 2.
- `Perm.inventoryDelete` is seeded **admin-only**.
- **Cost/margin math is load-bearing:** package↔base-unit conversion lives
  ONLY in `lib/core/units/package_cost.dart` (half-up) — never duplicate it.
- **Push rule:** never raw `git push`; use
  `python3 ~/workspace/skills/github/bin/git_push.py --repo-dir ~/workspace/pharmacy-pos --owner abo3dam-hub --repo pharmacy-pos --ref main`,
  then `git fetch origin` + verify empty diff + `git reset --hard origin/main`.

## 5. Test conventions

- 106 files under `test/`; shared helpers in `test/helpers.dart`
  (`ensureSqlite`, `newDatabase`).
- Perf/count-heavy: `inventory_import_scalability_test.dart` (14,001 rows),
  `inventory_perf_regression_test.dart` (11,300 rows; `PHARMACY_FILE_DB=1`
  switches to a temp file DB — this is what CI `perf-file-db` runs).
- Scale tests run on in-memory DB → keep budgets generous.
- Known parallel-run flake (pre-existing): `backup_archive_test.dart` with the
  restore suites can trip its staging-dir assertion; passes alone and in the
  full suite.

## 6. Commands

```bash
export PATH="$HOME/workspace/.sdks/flutter/bin:$PATH"
flutter pub get && flutter gen-l10n
flutter analyze
flutter test                      # full suite (~8 min locally)
PHARMACY_FILE_DB=1 flutter test test/inventory_perf_regression_test.dart
```
