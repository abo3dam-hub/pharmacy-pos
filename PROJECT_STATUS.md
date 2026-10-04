# Pharmacy POS — Project Status (living document)

**Last updated:** 2026-10-04 · **Branch:** `main` · **Remote:** `abo3dam-hub/pharmacy-pos`
**HEAD:** `a129f1f` — "Ali's four fixes: drawer auto-close, list auto-load race, stable APK signing, CI speed-ups"

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
| Tests | **106 files · 741 tests pass** · `flutter analyze` clean |
| CI | GitHub Actions: `analyze-test`, `perf-file-db`, `build-windows`, `build-android` (~7–8 min critical path) |
| Last CI | Run `37209412343` (commit `a129f1f`) — in progress at time of writing |
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
