# PHASE 13 — Backup, Restore & Export Completion Report

## Summary

Phase 13 delivers the previously-missing data safety layer: one-tap **backup** of
the entire PostgreSQL-free SQLite store into a self-contained, integrity-verified
archive; a **restore** that previews, validates, stages, activates and rolls back
safely; and a **read-only full-data export** to open CSV. All of it is exposed
through an Arabic-first `/settings/data` page, permission-gated, and exercised by
a dedicated test suite.

- **Backup** (`backup.archive`): a `manifest.json` + `database.sqlite` (snapshot
  taken via `VACUUM INTO` while the live app DB stays open) + every managed
  `files/expense_receipts/*` file, zipped with `archive` 3.6.1, then re-opened and
  SHA-256-verified before success is reported. A failed write never leaves a
  "successful" archive behind; every success also records ledger + audit rows.
- **Restore** (`backup.restore`): read-only **preview**; then a fully validated
  activate-with-rollback flow — extract+verify → format/schema compatibility
  checks (≥ v1, never a future schema, format 1) → stage + migrate via
  `AppDatabase.fromFilePath` → `PRAGMA integrity_check` → required-tables check →
  receipt reference reconciliation to the live receipts directory → pre-restore
  audit + **emergency backup** (`pre_restore_safety_*.zip`) → atomic file
  replacement (DB + `-wal`/`-shm` + receipts dir) → reopen + integrity + audit.
  On any activation failure the emergency backup is rolled back; if rollback
  itself cannot complete, the emergency path is preserved and surfaced.
- **Export** (`export.data`): every user table dumped to UTF-8 CSV (BOM so Excel
  renders Arabic), paged via DB-side `LIMIT/OFFSET` (5000/page), plus a machine
  readable `export_manifest.json`. The database is read-only: no insert, no audit
  rows. The test suite caught and verified a real bug fix here (see below).
- **RBAC**: `backup`, `backup.restore` and `export.data` are seeded on the admin
  role (idempotently, in `beforeOpen`) and enforced by three use cases against
  `PermissionService.requireRolePermission`; the UI page reflects the role's codes.

- Analyzer: `flutter analyze` → **No issues found**.
- Tests: **486 passed** (Phase 12 baseline 463 + **23 new** in 4 files).
- Schema version: **8 (unchanged)** — no migration. The new permissions are
  additive seeds applied on every database open, so restored archives from older
  builds receive them too.
- New dependency: `archive: ^3.6.1` (pure-Dart zip read/write).

## Semantics

- **Restore is a restart operation.** After a successful restore the in-memory
  connection would otherwise point at a replaced inode, so activation is the
  "replace the files" step and the UI asks the operator to restart; the app
  routes to `/login`. This is intentional, not a TODO: no in-process hot swap.
- **No downgrades, ever.** Archives with `schemaVersion > 8` are rejected before
  anything is touched; malformed, tampered or hostile archives throw
  `InvalidOperationException` with an Arabic reason. `manifest.json` size + SHA-256
  are checked against every embedded file, and unexpected archive entries (or
  `../` / absolute-path zip-slip names) are rejected.
- **Emergency archive is the rollback truth.** Before the activate step the live
  data is snapshotted; that snapshot both survives on disk and is the source for
  rollback. The restore test proves the file is preserved.
- **Export is pure read.** Rows are paged in SQLite, blob columns are hex-encoded,
  CSV cells are always quoted correctly, rows end each record with `\r\n`, and the
  source DB receives no writes (confirmed byte-identical CSV across two exports).
- **Receipt reconciliation, no posting.** After activation, `expenses.receipt_path`
  entries are re-pointed to the live receipts directory (basename-preserving);
  no financial values are recomputed or reposted — the archive bytes ARE the truth.

## Changes

### Domain services (`lib/domain/services/`)
- `app_paths.dart` — stable paths (`AppPaths.databasePath`, `receiptsDirectory`,
  `emergencyDirectory`, `defaultBackupsDirectory`).
- `backup_archive_service.dart` — `createBackup` (VACUUM INTO snapshot, zip
  layout, manifest, ledger + audit, read-back SHA-256 verification, no partial
  archive on failure) and `extractAndVerify` (`_sanitizeEntryPath` traversal
  guard, per-file checksum/size checks, unknown-entry rejection, archives that
  fail structurally are wrapped as `InvalidOperationException`).
- `restore_service.dart` — `preview` and `restore` with the full
  stage/validate/backup/replace/reopen/rollback workflow above.
- `data_export_service.dart` — `exportAll` (BOM'd CSV per table, paging,
  `export_manifest.json`, `ExportDataResult`).

### Backup feature (`lib/features/backup/`)
- `domain/entities/` — `backup_manifest.dart` (`kBackupFormatVersion = 1`,
  `kCurrentSupportedSchemaVersion => 8`, `BackupManifest`, `BackupArchiveLayout`),
  `backup_results.dart` (`BackupArchiveResult`, `RestoreResult`, `RestorePreview`),
  `data_export_result.dart`.
- `domain/usecases/backup_use_cases.dart` — `CreateBackupUseCase`,
  `PreviewRestoreUseCase`, `RestoreBackupUseCase`, `ExportDataUseCase`, each
  gated on its permission.
- `application/data_management_controller.dart` — Arabic loading/error/success
  state machine for the page.
- `presentation/pages/data_management_page.dart` — directory/folder/archive
  pickers (`file_picker` static API), progress, result dialogs, and the
  "restart required" → `/login` flow.

### Wiring
- `lib/core/constants/permission_codes.dart` — `Perm.exportData = 'export.data'`.
- `lib/shared/database/seed_data.dart` — seed entry; `kAdminRoleMinimumPermissions`
  extended with `backup`, `backup.restore`, `export.data`; idempotent
  `ensureBackupPermissions(db)`.
- `lib/shared/database/app_database.dart` — `beforeOpen` runs
  `ensureBackupPermissions` (no migration; schema stays 8).
- `lib/core/di/injection.dart` / `providers.dart` — `_registerPhase13`
  (`AppPaths`, archiver, `RestoreService`, `DataExportService`, four use cases,
  `DataManagementController`) + `dataManagementControllerProvider`.
- `lib/core/router/app_router.dart` — `/settings/data` route under settings guard.
- `lib/features/settings/presentation/pages/settings_page.dart` — navigation card
  to Data Management.
- `lib/l10n/app_ar.arb` / `app_en.arb` — ~30 `dataManagement*` keys, regenerated.

### Tests (`test/`)
- `backup_archive_test.dart` (8) — round-trip create/verify, layout + manifest
  fields + ledger checksum, receipt files, missing/corrupt/zip-slip/bad-checksum/
  unexpected-entry rejection, staging-dir cleanup.
- `restore_service_test.dart` (5) — full restore replaces live DB + files,
  financial invariants preserved (drawer, journal totals, revenue/cash/COGS/
  inventory balances, stock), receipt reconciliation, emergency backup preserved,
  `restore_backup` audit rows, preview valid, newer-schema rejection leaves live
  data untouched, corrupt/missing archive never reaches activation.
- `data_export_test.dart` (4) — BOM + header + row counts, manifest metadata,
  read-only guarantee (identical CSV across two exports), deep-dir creation.
- `backup_rbac_test.dart` (6) — admin seeded with all three codes, idempotent
  seeding across re-opens, unauthorized/`null` role rejection for all four use
  cases, admin success path, partial-rights (backup-only role) enforcement.

### Bug found & fixed by the new suite
- `_writeCsvRow` emitted `\r\n` after **every** column instead of once per record,
  producing a vertical "one column per line" CSV. Fixed so each record is a proper
  `value,value,…\r\n` line; the export tests now assert real CSV shape.
- Corrupt archives could escape as a raw `FormatException` from the zlib inflater;
  `extractAndVerify` now converts any non-`InvalidOperationException` failure
  during extraction into a single Arabic `InvalidOperationException`.

## Verification

- `flutter analyze` → No issues found.
- `flutter test` → All 486 tests passed (463 baseline + 23 new).
- Schema version unchanged at **8**; no migration, no `FinancialPostingService`
  changes, no second database, no duplication of the Phase 11 report exports.