# Changelog

All notable changes to **نظام الصيدلية (Pharmacy Management & POS) — `pharmacy-pos`**.

Version format follows SemVer (`MAJOR.MINOR.PATCH+build`).

---

## [Unreleased]

### Fixed
- **CI #132 fix — guardrail allowlist line drift** (2026-10-05): the previous
  commit's POS pay-sheet edit shifted the allowlisted packaging-structure
  label in `pos_workspace_page.dart` from line 794 to 795; the allowlist entry
  was not updated, so the whole-package display guardrail failed CI run #132
  (758 passed, 1 failed). Entry corrected to `:795`; guardrail green again.
- **CI green again + permission-gated UI shows disabled with reason**
  (2026-10-05, Ali):
  * Fixed 2 test failures that broke CI runs #130/#131: (1) the
    whole-package display guardrail's line-based allowlist broke when the
    purchase-form refactor shifted lines — allowlist updated; (2) the
    double-pay `_submitting` spinner kept animating behind the receipt
    dialog (it awaited the dialog), timing out `pumpAndSettle` — the
    spinner now stops right after checkout, before the receipt shows.
  * New `PermissionGate` widget (`lib/core/widgets/permission_gate.dart`):
    permission-restricted controls now render **disabled with a tooltip
    naming the missing permission** instead of hiding entirely (Ali's
    request). State still gates visibility (e.g. void stays hidden for
    returned invoices). Applied to the invoice detail page (void icon,
    return-all button, per-line return) and the POS return sheet's void
    button; new `permissionRequired` l10n key (AR/EN).
- **Stale-UI audit — comprehensive pass** (2026-10-05, requested by Ali
  after the void-icon bug):
  * **Void icon never appeared (real bug):** `_load()` in the invoice detail
    page assigned `_invoice` after `await` without `setState` — the body
    rebuilt via FutureBuilder but the AppBar never did, so the delete icon
    was never drawn even for eligible invoices. Now wrapped in `setState`;
    covered by new widget regression test
    `test/invoice_detail_void_icon_test.dart` (verified to fail without the
    fix).
  * **Stale expanded-row details in sales history:** `_detailCache` was never
    invalidated — re-expanding an invoice after returning from its detail
    page showed pre-return data. The cache entry is now dropped on return
    from the detail page.
  * **Stale session permissions (A1):** `reloadCurrentUser()` existed but
    was dead code — editing role permissions or a user's role kept the old
    permission set until re-login. Roles and users pages now refresh the
    auth session after a successful save.
  * **Fragile load patterns hardened (B1–B3):** purchase edit form, price
    history, and receipt-template card assigned state fields across awaits
    without `setState`, surviving only via a trailing setState. All three
    now build locals first and publish via a single setState; the receipt
    card also loads from `initState` instead of `build()`.
  * Audit covered all 73 state classes, all AppBar actions, dialog→list
    refresh flows, navigation patterns, and permission-gated UI. Remaining
    note for discussion: permission-gated controls hide entirely rather
    than showing disabled-with-reason.
- **Ali's Windows test round — 4 issues** (2026-10-05):
  * Return dialog now works in the line's sell unit (box/strip): a part-sale
    line previously hit `returnable ~/ unitsPerLarge == 0` and silently did
    nothing — a regression from the packages-only change. The dialog names
    the unit (e.g. "الكمية المرتجعة (شريط)").
  * Return action column moved to the first (rightmost in RTL) position in
    the invoice lines table — always visible without horizontal scrolling;
    plus a new visible "إرجاع الكل" button that returns every remaining line
    in one confirmed operation (full-invoice returns).
  * Stock balances/movement log show mixed packages (`28/2`) via new
    `formatMixedQuantity` — never raw base units after a part sale. Applied
    to the movement log delta + balance, batch quantities, and the
    `compoundStockText` fallback for items without part configuration.
  * Double-tap on "pay" recorded two invoices: added a `_submitting` guard
    with loading indicator on the payment sheet and a `_checkoutInProgress`
    re-entrancy guard in `PosWorkspaceController.checkout`.
- **Whole-package rule: radical pass + returns reflected everywhere**
  (2026-10-05, reported by Ali — 4th report on parts leaking into the UI).
  Root causes found and fixed:
  * POS search rows showed stock in base units (`متاح: 150` for 50 boxes);
    now `formatBaseQuantity`.
  * The invoice return dialog showed/accepted base units (`6` for 2 boxes);
    now it shows and accepts packages and converts to base units only for
    the domain command.
  * Dashboard cards ignored posted returns and counted base units:
    `todayTotalMicros` is now ledger net revenue, `todayProfitMicros` ledger
    gross profit (both net of sale returns), and `todayUnitsSold` is net
    whole packages sold (new `ZReportDao.netPackagesSold`, sale returns
    subtracted, divided by `units_per_large`).
  * Z-Report page/PDF and the sales report showed units in base units; both
    now show whole packages (`unitsSoldPackages` / package-converted SQL).
  * Purchase detail bonuses shown in base units; now packages.
  * Invoice-detail, sales-history and receipt fallbacks now use
    `formatBaseQuantity`; the POS return success note counts packages.
  * Removed the quantity column from the inventory movements summary: it
    aggregates across items with different package sizes, so it can never be
    expressed in whole packages.
  * New CI guardrail `test/whole_package_display_guardrail_test.dart` fails
    the build if any presentation file interpolates a raw `*Base` quantity
    without `formatBaseQuantity` — parts can no longer leak silently again.
- **Android signing is now truly stable — explicit signing config**
  (2026-10-05, reported by Ali) — both post-Oct-4 APKs carried *different*
  signatures even though the "stable keystore" restore step ran fine both
  times. Root cause, proven by extracting the signer certificates from both
  APKs (different SHA-256 fingerprints, both generated fresh at build time):
  newer AGP (9.1.0) silently ignores a merely placed
  `~/.android/debug.keystore` and generates a fresh key per build, so *every*
  update required an uninstall. Fix: `android/app/build.gradle.kts` now
  declares an explicit `ciStable` signing config naming the restored keystore
  file (falls back to default debug signing on local dev machines); the CI
  restore step now *fails the job* instead of silently falling back to an
  ephemeral key; and a new `tool/check_apk_signature.py` step verifies the
  built APK's signer certificate matches the keystore (fails the build
  otherwise). Note: one final uninstall is still needed once, to move off the
  randomly-signed builds — afterwards updates install in place.
- **Backup/restore on Android: storage permission** (2026-10-05, reported by
  Ali) — creating a backup into a user-chosen shared folder (e.g. Download)
  failed with "unexpected error": the manifest declared no storage
  permissions at all, and Android 11+ scoped storage blocks raw file I/O in
  shared folders. Added `READ/WRITE_EXTERNAL_STORAGE` (capped) and
  `MANAGE_EXTERNAL_STORAGE` to the manifest, and the data-management page now
  requests file access before backup/restore/export (system Settings flow on
  API 30+, runtime dialog below) with a clear Arabic explanation instead of a
  generic error when declined. New `permission_handler` + `device_info_plus`
  dependencies; new `lib/core/permissions/storage_permission.dart` helper.
  Follow-up (same day, from Ali's screenshots): the first version opened the
  generic app-info settings page, where the "All files access" toggle does
  not exist — it lives on a separate special-access page. Now
  `Permission.manageExternalStorage.request()` opens that exact page
  directly, and the rationale dialog tells the user precisely which toggle
  to enable.
- **Windows build fix** (2026-10-05) — `permission_handler_windows` 0.2.2
  still includes `<experimental/coroutine>`, which MSVC 14.51+ (VS 2026 on
  the windows-latest CI runners) rejects with hard error STL1011/C2338.
  Added Microsoft's documented interim opt-out
  (`_SILENCE_EXPERIMENTAL_COROUTINE_DEPRECATION_WARNINGS`) in
  `windows/CMakeLists.txt`, inherited by all plugin targets. All four CI
  jobs green again.
- **Whole-package rule enforced across every remaining view** (2026-10-05,
  reaffirmed by Ali: all user-facing quantities and costs are in whole
  commercial packages, never parts) — a full audit found and fixed the last
  spots still showing base units: dashboard (low-stock and near-expiry cards),
  expiry-alerts page, reorder-suggestions page (stock, daily rate, suggested
  qty), purchase invoice detail (line quantity + unit cost), prescription
  detail lines, return detail dialog lines, inventory report (rows, totals,
  and print/PDF export), POS product-detail dialog (stock + cost), the
  alternatives dialog (available stock), and the item dialog's min/max stock
  fields (now entered and seeded per package). Each view now carries
  `unitsPerLarge` and renders via `formatBaseQuantity` /
  `baseUnitCostToPackageCost`; storage stays per base unit (COGS basis).
- **Chained batch→purchase flow no longer double-posts stock** (2026-10-05,
  reported by Ali) — the batch dialog's "save and add invoice" now hands the
  batch details (number, expiry, bonus) to the purchase invoice instead of
  posting stock itself; the purchase receive is the single stock-posting
  event. Previously the same quantity was added twice (once as a stock
  adjustment, once as a purchase). The user's batch number/expiry are now
  reused at receive time instead of an AUTO number.
- **Batch ledger shows commercial-package quantities and costs** (2026-10-05,
  reported by Ali) — for items with packaging, the batches table and the stock
  movement log now display quantities per package (e.g. 50 boxes, sale of 2)
  and the unit cost per package (e.g. 180.00) instead of base units
  (150, 6, 60.00). Storage stays per base unit (COGS basis); only the display
  changed. New `formatBaseQuantity` helper in `lib/core/units/package_cost.dart`.
- **Movement log shows the human batch number** (2026-10-05) — the batch
  column previously showed the internal UUID; it now resolves to the batch
  number.
- **Returns page: invoices tab** (2026-10-05, requested by Ali) — the returns
  workspace now has two tabs: invoices (every sales invoice, auto-loaded in
  chronological order on entry — pick one to return from, no search needed)
  and the recorded returns list.
- **Sales history: quick return shortcut** (2026-10-05, requested by Ali) —
  every invoice card now has a "ترجيع" button that opens the invoice detail
  where per-line returns are posted.
- **Android navigation drawer auto-closes** (2026-10-04) — on compact/Android
  widths, tapping a drawer destination now dismisses the drawer before
  navigating (`lib/core/widgets/app_shell.dart`); previously the drawer stayed
  open on top of the new page. Regression test added to
  `test/design_system_test.dart` ("tapping a drawer destination closes the
  drawer").
- **All list pages load on entry — startup race fixed at the root**
  (2026-10-04) — the database executor opens lazily and the very first query
  could fire before it was ready, leaving lists (sales history, purchases,
  inventory, …) empty until the user manually reloaded (e.g. touching search).
  `main()` now warms up the database (`lib/core/database_warmup.dart`,
  bounded retry, never blocks startup) before the first frame — one fix for
  every list page, present and future. New tests:
  `test/database_warmup_test.dart`.
- **APK now installs as an update — no more uninstall-first** (2026-10-04) —
  two independent blockers fixed: (1) every CI run generated a fresh debug
  keystore on its ephemeral runner → signature mismatch
  (`INSTALL_FAILED_UPDATE_INCOMPATIBLE`); a stable keystore is generated
  once, stored as the `ANDROID_KEYSTORE_B64` repo secret, and restored by CI
  before the build; (2) `versionCode` was frozen at 1 for every APK ever
  shipped → CI now passes `--build-number=${{ github.run_number }}` so it
  strictly increases. Note: one final manual uninstall is unavoidable when
  moving from the old randomly-signed APK to the first stable-key build;
  every build after that updates in place. `applicationId` unchanged
  (`com.pharmacy.pharmacy_pos`).
- **Package-vs-base-unit cost basis** (2026-09-24) — costs are entered per
  commercial package but stored per base unit (the COGS basis). New single
  conversion point `lib/core/units/package_cost.dart` (half-up), applied in
  the item dialog, purchase form, manual batch dialog, and Excel import/
  export; stored margin now compares package cost vs package price; POS has
  a labeled "sell as part" button and a box/part toggle chip on cart lines.
  Ali's scenario: box cost 11,000 ÷ 3 parts → one part sells at 5,600 with
  COGS ≈ 3,666.6667, never 11,000. See
  `docs/archive/COST-BASIS-FIX-REPORT-2026-09-24.pdf` and PROJECT_STATUS §3f.

## [Unreleased]

### Changed
- **CI speed-ups, no safety reduction** (2026-10-04) — Gradle cache for
  `build-android` (~1–3 min off the 6-min release build),
  `concurrency: cancel-in-progress` (a newer push cancels the stale run
  instead of queueing behind it), pub cache via `subosito/flutter-action`,
  Flutter pinned to `3.44.2` in all four jobs (was `stable` in three,
  `3.44.2` in one), and `timeout-minutes` guards on every job. Deliberately
  NOT done: test sharding and skipping old tests — the full suite (~740
  tests) takes ~2.4 min on CI and is the regression safety net. Realistic
  critical path now ~7–8 min (was ~11.3).
- **Android builds are now arm64-only** (2026-10-04) — CI builds the release
  APK with `--target-platform android-arm64`, cutting the download roughly in
  half (~95MB → ~45-50MB). arm64 covers virtually all Android devices in use
  today; the 32-bit armv7 build is dropped.

### Added
- **Dashboard visual refresh** (2026-10-04) — colorful but calm dashboard:
  auto-playing hero carousel (4 live-data slides: today's sales, stock
  alerts, near-expiry, new sale) with dots indicator; the six KPI cards use
  a curated pastel palette (`lib/core/theme/dashboard_palette.dart`,
  dark-mode aware) and every card/slide/alert header is tappable, navigating
  to its related page (sales history, reports, inventory, POS). The layout
  stays responsive with no vertical scrolling (adaptive carousel height,
  6/3/2-column KPI reflow, compact one-row income strip). New ARB keys with
  exact AR/EN parity. Report:
  `DASHBOARD-VISUAL-REFRESH-REPORT-2026-10-04.md`.
- **Drug catalog conversion tool** (2026-09-24) — `tool/convert_zena_catalog.py`
  converts the Zena drug catalog CSV (22,292 items) into the app's Excel
  import format (`products` sheet, Arabic headers): barcode cleanup
  (multi-barcode cells → primary/secondary), active-ingredient parsing to
  `name:strength` relational pairs, manufacturer/indication auto-creation,
  pharma-form inference, and unit relations (part/box) only where the catalog
  declares more than one part per package so the importer derives per-part
  cost correctly. Report: `docs/archive/CATALOG-IMPORT-REPORT-2026-09-24.md`. Sale prices
  are intentionally left blank (the catalog carries none).

### Changed
- **Camera barcode scanning (Android)** (2026-09-24) — new
  `lib/core/scanning/` module built on `mobile_scanner`: a camera scan button
  (📷 icon) now appears in every place a barcode is expected — the item
  dialog barcode fields (quick + detailed entry), the POS search, the
  inventory search, and the purchase-invoice item search. On POS, a camera
  scan follows the same path as a hardware scan (search + quick-add on an
  unambiguous hit). The button hides itself automatically on desktop/web,
  where the existing HID scanner pipeline keeps working. Includes camera
  permission handling and 7 new tests.
- **Item entry: quick vs detailed** (2026-09-24) — the item dialog now opens
  in **إدخال سريع** (quick entry, the default), showing only the essential
  fields (barcode, trade name, category, manufacturer, commercial packaging,
  parts count, partial-sale setup, package cost, sale price, expiry toggle).
  The full detailed form is one toggle away and keeps every previous field —
  simplification without removing features.
- **Lightweight motion language** (2026-09-24) — new
  `lib/core/motion/app_motion.dart` (entrance, stagger, count-up, press
  feedback) applied to the dashboard (staggered KPI cards, animated
  counters), purchase-invoice rows, and the POS cart totals. Short,
  subtle animations; pricing, COGS, and accounting behaviour unchanged.
- Verification: `flutter analyze` clean, **649 tests pass**. See
  `docs/archive/UX-SIMPLIFICATION-REPORT-2026-09-24.pdf` and PROJECT_STATUS §3g.

---

## [1.1.0] — 2026-09-08 — Product Management UX fixes

Complete rework of the product (item) management experience plus the
schema/migration, regression-test, and error-mapping work to support it.
See `docs/archive/PRODUCT-MANAGEMENT-UX-FIX-REPORT.md` for the itemized 21-section report.

### New in this release

- **Scrollable sidebar** — the `NavigationRail` in `app_shell.dart` is now
  `scrollable: true`, so every section (including Settings) stays reachable on
  short screens instead of overflowing the viewport.
- **Many-to-many item ↔ suppliers** — new `item_suppliers` link table
  (schema v9). Supplier chips are picked inline in the product dialog; the
  repository persists/updates the links in the same transaction as the item,
  and bulk Excel imports preserve them.
- **Searchable master-data dropdowns** — new reusable
  `SearchableDropdownField` (typeahead + inline "+" creator). Category,
  sub-category, manufacturer, therapeutic group, and the unit/packaging
  selectors all filter as you type; picking a category filters sub-categories,
  and a created row is auto-selected.
- **Packaging unit auto-suggestion** — choosing the base unit pre-fills the
  commercial ("packaging") unit; the form also labels the packaging field
  clearly.
- **Form validation + targeted errors** — no more generic
  "حدث خطأ أثناء حفظ البيانات". Unit-relation completeness, units-per-large
  (≥1), and partial-sale parts/base checks each surface a specific message.
- **Partial-sale wiring** — enabling partial selling auto-fills the default
  10% markup (stored in basis points) and validates parts/base quantities.
- **Wired error mapping** — repository `_guarded` translates
  `SqliteException`/`ValidationException`/`UnauthorizedException` into
  `DuplicateException`/`ValidationException`/`DatabaseException`/permission
  failures so the UI shows precise feedback (e.g. duplicate barcode) instead of
  the catch-all.
- **BUG FIX (found by new tests):** the "units per large" input was not wired
  to the enforced value — entered values were ignored and the validation could
  never fire. The `TextFormField` now syncs via `onChanged`.

### Data / migration

- Schema **v8 → v9**: `item_suppliers` created (`id` PK, `itemId` → Items,
  `supplierId` → Suppliers, composite unique `{itemId, supplierId}`).
- `migration_test.dart` mirrors v9 (`from < 9` block); fresh/v1→v9 migrations
  verified; restore schema-tamper test updated for the new supported version.
- `kCurrentSupportedSchemaVersion` in `backup_manifest.dart` bumped to 9 —
  this was the root cause of stale backup/restore expectations.

### Localization

- 13 new ARB keys (ar/en, exact parity): packaging-unit, suppliers, add-new,
  inventory units/base/large/per-invalid guidance, partial-sale unit/parts/
  base/markup messages. `localization_parity_test.dart` enforces parity.

### Verification

- `flutter analyze lib test`: 0 issues.
- `flutter test`: **532/532 pass**, including:
  - `item_save_regression_test.dart` (duplicate barcode → `DuplicateException`,
    suppliers M2M persist/dedupe/update, bulk shelf-edit preserves suppliers).
  - `item_form_ux_test.dart` (7 widget tests: rail scrolling, targeted
    validation, form order, suppliers chips, inline category auto-select,
    filtered subcategory, partial-sale markup/validation).
- Release-tag `v1.1.0` triggers the Windows build on Flutter 3.44.2 (kept for
  the v1.0.1 black-screen workaround) via CI.

---

## [1.0.1] — 2026-09-08 — Windows black-screen fix

Fixes a Windows-only rendering issue in the v1.0.0 release: on machines whose
GPU caps Direct3D 11 at **feature level 9_3** (e.g. Intel `Ironlake`/HD
Graphics, WDDM 1.1, no Vulkan), the app opened a window that stayed completely
black while the process ran normally — no crash, no error output, no database
access. Verified reproductions against the exact v1.0.0 artifact on
`windows-latest` show the same build renders the login screen correctly on
feature-level 11 hardware, so the failure is hardware/toolchain-specific, not
an application defect.

### Root cause

- flutter/flutter#191978 — a **Flutter engine regression introduced in 3.47.0**
  (commit `c7926ac`, PR flutter/engine#190374). The Windows compositor
  (`shell/platform/windows/compositor_opengl.cc`) started passing **sized** GL
  internal formats (`GL_RGBA8`/`GL_BGRA8_EXT`) to `glTexImage2D` on the
  OpenGL ES 2.0 context the Windows embedder always creates. On D3D11
  feature-level 9_3 machines ANGLE falls back to its FL9_3 display, where a
  sized `TexImage2D` internal format is out of spec for ES 2.0; the backing
  store texture is never allocated, the framebuffer is incomplete, and
  `blitFramebuffer` copies nothing → **silent all-black window over a fully
  healthy app**. Both Impeller and Skia are affected; stock `flutter create`
  apps reproduce it; no app code is involved.
- Field-validated workaround from the issue: **build with Flutter 3.44.2**
  (the last release line before 3.47). End-user rebuilds with 3.44.2
  consistently fix the black screen on the affected hardware.

### Changes in this release

- Pin the Windows release toolchain to **Flutter 3.44.2** in
  `.github/workflows/ci.yml` (`build-windows`) and `.github/workflows/windows-smoke.yml`.
- Loosen the Dart SDK constraint to `'>=3.12.0 <4.0.0'` in `pubspec.yaml`
  (Flutter 3.44.x ships Dart 3.12) and align `pubspec.lock`.
- Version bump: `pubspec.yaml` `1.0.1+1`; updated `windows/runner/Runner.rc`
  fallback metadata.
- Removed the temporary Phase-16 startup checkpoint instrumentation from
  `lib/main.dart` after CI evidence (startup log `enter-main` → `setup-done` →
  `runApp-called` → `first-frame`) confirmed the Dart startup and first-frame
  paths complete on non-9_3 hardware.

### Verification

- `flutter analyze`: 0 issues; `flutter test`: **517/517 pass** (Flutter 3.47.2).
- CI `build-windows` on v1.0.1 tag, built with **Flutter 3.44.2**: success.
- Runtime smoke of the `pharmacy-pos-windows` v1.0.1 artifact on
  `windows-latest`: process stays alive, window `pharmacy_pos` found, login
  screen captured (rendered content, not black), no crash dumps, no Event Log
  errors, SQLite database untouched until login.
- Caveat: CI hardware reports feature level 11 (`Microsoft Hyper-V Video`), so
  the FL9_3 scenario itself cannot be recreated on our runners. The fix relies
  on the field-validated 3.44.2 toolchain from flutter/flutter#191978; when an
  upstream Flutter release containing the engine fix (`[Windows] Use GL_RGBA as
  backing store internal format`) ships, the pin can be lifted.

---

## [1.0.0] — 2026-09-08 — Final Production Release

The first formal production release (`v1.0.0`). Delivered by the Phase 1 → 16
roadmap; Phase 16 performed the final scope/handoff audit, completed the
localization sweep, verified a real Windows release build through CI, and
published the final release tag.

### Major completed capabilities

- **Items / Inventory** — full product master data (barcodes, categories,
  sub-categories, manufacturers, therapeutic groups, units, batch/expiry,
  FEFO selection, stock adjustment ledger, minimum/maximum stock).
- **Purchases & Suppliers** — purchase invoices, receipts, batches, cost
  history, the Bonus Engine (bonus 1/2, gift), purchase returns, supplier
  statements.
- **Sales / POS** — multi-tab POS workspace, barcode scanning buffer, cart,
  hold bills (F5), payment methods (cash/card/mixed/credit), partial
  (pharmacist-controlled) unit sales, prescriptions linkage, sale returns,
  invoice voiding, receipt printing, lost sales, smart alternatives.
- **Customers / Prescriptions** — customer ledger/accounts, credit workflow,
  prescriptions with eligible-item dispensing.
- **Financial & Accounting** — single `FinancialPostingService` posting
  engine, double-entry journals, double-posting protection, cash box
  (open/close/deposit/withdraw/adjust), expenses, customer payments,
  accounting-period close, Financial Close, Z-report.
- **Reports** — trial balance, income statement, balance sheet, sales,
  purchases, inventory, lost sales, customer statements, supplier statements,
  with Arabic PDF/Excel export and bidi-shaping.
- **Administration** — RBAC roles/permissions (admin, pharmacist, cashier,
  viewer), user management, settings, keyboard-shortcut rebinding,
  append-only audit log.
- **Backup / Restore / Export** — online SQLite backup (WAL/SHM-safe) with
  SHA-256 manifests and receipts, validated restore with safety backup,
  full CSV/Excel export.

### Phase 15 hardening (carried into release)

- Warning/error color tokens corrected to WCAG AA.
- Idempotent `viewer`-role healing for legacy/restored databases.
- Enter quick-add on a unique POS search result (scanner priority preserved).
- Database-level uniqueness on all business numbers
  (`invoice_number`, `payment_number`, `purchase_number`, `return_number`).

### Phase 16 release work

- **Localization completion:** audited every presentation page/widget for
  hardcoded user-visible Arabic strings; all remaining literals (POS page,
  audit-log date pickers) moved into the ARB catalog. Both `app_ar.arb` and
  `app_en.arb` are in exact key parity (1019/1019).
- **Localization parity regression test added** (`localization_parity_test.dart`)
  to keep the Arabic/English key parity invariant protected.
- **Real Windows release build** executed on a GitHub Actions `windows-latest`
  runner (`flutter build windows --release`) — see below. The first real run
  surfaced **four Windows-only bugs** that Linux CI could not exercise; all
  were fixed and the release-tag run is green:
  - `extractAndVerify` keyed staged files with the OS-normalized entry name,
    while manifest `relativePath` values are forward-slash — receipt-bearing
    backups/restores/previews failed on Windows ("manifest-listed file
    missing"). Keys now use the archive-internal name.
  - `_extractEntry` left the output handle open when a corrupt entry's
    deflate stream errored, leaking a Windows file lock that masked the real
    error on corrupt-archive restore. The output stream always closes now.
  - Staging/work cleanup in `createBackup`/`preview`/`restore`/rollback is
    best-effort so a locked leftover can never replace the primary outcome.
  - Intermittent failure in the accounting-period RBAC/audit tests (seen
    locally and on CI) was root-caused to `DateTime(epochMillis)` used as a
    year constructor argument, whose int64 clock wraps land either in or out
    of range depending on the wall clock — fixed to use epoch millis directly.
- **CI hardening:** the `build-windows` job now runs `flutter gen-l10n` before
  analyze/test/build so the release build always uses freshly generated
  localization.
- **Release tag `v1.0.0`** with artifact upload.

### Accounting / security guarantees

- All money is integer smallest units; percentages are basis points —
  no floating point anywhere.
- Single posting engine; debits = credits; double-posting protected.
- Append-only audit log; RBAC enforced at the service/use-case layer, not
  UI-only.
- Offline-first: local SQLite is the single source of truth.

### Backup / restore status

- Backup: live-safe, WAL/SHM handled, archived with manifest + SHA-256 +
  receipt, corruption/tamper/failure cleanup covered by tests.
- Restore: preview + validation + schema compatibility + atomic replacement +
  rollback + safety backup + restart flow covered by tests.
- Export: BOM/CRLF/escaping/paging/blobs/manifest/read-only over CSV.

### Localization & RTL

- Arabic is the primary production language (RTL); English is fully supported
  (LTR) through the same pipeline.
- ARB parity exact: 1019 keys in both languages, 0 missing either way.
- RTL-safe directional icons, Cairo/Tajawal typefaces, PDF bidi shaping.

### Known limitations

- Presentation controllers and domain services emit localized-as-Arabic
  `Failure` messages by design (Arabic-first architecture); in the English
  locale these transient error/snackbar strings and persisted business notes
  remain Arabic. Fully re-localizing this layer would require an
  architectural change (threading `AppLocalizations` through the
  StateNotifier/domain layer) deferred past the release gate.
- Login sessions are in-memory (login required per launch) — by design for a
  local desktop POS.
- Unknown-username login attempts are not separately audited (`audit_logs.user_id`
  is NOT NULL by schema contract).
- Account `4002 Purchase Returns` exists but is intentionally unused: purchase
  returns post through the established supplier-payable/inventory posting
  model. Activation was rejected to preserve accounting semantics.

### Intentionally unchanged

- Unknown-username audit breadth
- Role `name` (stable code) vs Arabic-label synchronization
- Settings/audit caching (no measured need)
- In-memory login session
- `4002` Purchase-Returns account semantics

### Windows release artifacts

- Workflow: `.github/workflows/ci.yml` → `build-windows` job.
- Artifact: `pharmacy-pos-windows` — the self-contained
  `build/windows/x64/runner/Release/` output (portable EXE + bundled native
  libraries/assets). No separate installer is produced; the release is
  distributed as the portable Windows build.
- Version metadata: `pubspec.yaml` `1.0.0+1` (Windows executable version
  `1.0.0.1` via `FLUTTER_VERSION`).

### Full phase history

The authoritative background for every earlier phase is in the repository's
`docs/archive/PHASE*-COMPLETION-REPORT.md` and `PROJECT-ARCHITECTURE-PLAN.md`,
culminating in `docs/archive/PHASE16-COMPLETION-REPORT.md`.