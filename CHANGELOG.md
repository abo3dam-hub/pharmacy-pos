# Changelog

All notable changes to **نظام الصيدلية (Pharmacy Management & POS) — `pharmacy-pos`**.

Version format follows SemVer (`MAJOR.MINOR.PATCH+build`).

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
`PHASE*n*-COMPLETION-REPORT.md` and `PROJECT-ARCHITECTURE-PLAN.md`,
culminating in `PHASE16-COMPLETION-REPORT.md`.