# PHASE 12 — Audit Log, Settings & Administration Completion Report

## Summary

Phase 12 delivered three previously-placeholder administration modules plus the
hidden **Audit Log** viewer, all permission-gated and Arabic-first:

- **Application Settings** (`/settings`): Business Name, VAT rate and currency,
  persisted through the existing `app_settings` table. The business-name write
  reuses the same `pharmacy_name` key the POS documents and Z-report already read,
  so invoices pick up the new display name immediately. Save is gated on
  `settings.edit`, load on `settings.view`, and every successful save writes an
  `audit_config` audit row.
- **Audit Log** (`AppSection.audit`, `/audit`): a read-only, paginated viewer over
  the append-only `audit_logs` trail with search + action/actor/date filters, a
  detail dialog with JSON before/after snapshots, and a permission-aware column of
  canonical action/entity labels.
- **Administration hub** (`/users`): the existing Users page now sits next to two
  new tabs — **Roles** (create/edit Arabic labels, assign permissions, delete
  custom roles) and **Permissions** (read-only catalog grouped by module).

All reads are gated (`roles.view` / `settings.view` / `audit.view`), all writes are
gated (`roles.edit` / `settings.edit`), and every RBAC/settings write is audited.
Bootstrap safety is enforced in the use-case layer: the admin role can never lose
`kAdminRoleMinimumPermissions`, system roles always keep `roles.view`, and system
roles / roles assigned to users cannot be deleted.

- Analyzer: `flutter analyze` → **No issues found**.
- Tests: **463 passed** (Phase 11 baseline 435 + **28 new**).
- Schema version: **8 (unchanged** — everything reuses the Phase 4/6 tables:
  `audit_logs`, `app_settings`, `roles`, `role_permissions`, `permissions`; no
  migration, no new seeds).

## Semantics

- **Settings keys are additive**: `businessName` = `'pharmacy_name'` (the exact
  literal the POS documents already read), `taxRateBasisPoints` (whole basis
  points, 100 bp = 1%, stored as text) and `currencyCode` (default `SAR`).
  Absent keys fall back to `AppConfig.appName`, `0` and `SAR` respectively, so the
  page renders coherent defaults before the first save.
- **Tax rate is integer-only**: `Percent(basisPoints)` with validation 0..10 000
  (0%..100%) and 2-decimal input parsing in the page; no float money math.
- **RBAC minimums live in the use case, not the UI**: `SetRolePermissionsUseCase`
  silently re-adds `kAdminRoleMinimumPermissions` for `role_admin` and `roles.view`
  for any system role; the UI can never strip them, even by accident.
- **Delete guard**: system roles are undeletable; a role with ≥1 active user is
  undeletable (`InvalidOperationException` → Arabic snackbar messaging).
- **Audit trail stays append-only**: the viewer writes nothing; only domain writes
  (settings save, role create/update/delete, permission bulk-replace) append rows.

## Changes

### Settings (`lib/features/settings/`)
- `lib/core/constants/settings_keys.dart` — stable key names + defaults.
- `lib/shared/database/settings_dao.dart` (extended) — `getString`, `getInt`,
  `setString`, `setInt`, transactional `setAll` (`InsertMode.insertOrReplace`,
  records `updatedBy`/`atMillis`), `getAll`.
- `domain/entities/app_settings_entity.dart` — `AppSettings` (+`copyWith`) and
  `AppSettingsDraft`; `domain/entities/currency_options.dart` — 14 supported
  currency codes with Arabic names.
- `domain/repositories/settings_repository.dart` +
  `data/settings_repository_impl.dart` — read-through defaults, upsert write.
- `domain/usecases/settings_use_cases.dart` — `GetAppSettingsUseCase`
  (`settings.view`) and `SaveAppSettingsUseCase` (`settings.edit`, validation,
  `audit_config` audit row; audit failures swallowed so the save never breaks).
- `application/settings_controller.dart` — `SettingsController`/`SettingsViewState`.
- `presentation/pages/settings_page.dart` — form (name, tax, currency dropdown);
  `settings.edit` shows the save action, `settings.view`-only renders read-only.

### Audit log (`lib/features/audit/`)
- `domain/entities/audit_entry.dart` — `AuditEntry`, `AuditFilters` (search, date
  range `[from, to)`, `userId`, `action`) and `AuditActorOption`.
- `data/audit_dao.dart` — `listAudit` (COUNT + LEFT JOIN `users`, newest-first,
  LIMIT/OFFSET), `distinctActions`, `distinctActors`.
- `domain/usecases/audit_use_cases.dart` — 3 read-only, `audit.view`-gated use
  cases.
- `application/audit_controller.dart` — paginated `AuditController`
  (`pageSize: 25`, page-count pager, filter state).
- `presentation/widgets/audit_labels.dart` — canonical stored code → localized
  label mapping (action + entity type, raw-code fallback for unknown values);
  `widgets/audit_detail_dialog.dart` — readonly row detail with before/after JSON;
  `presentation/pages/audit_log_page.dart` — filter bar (debounced search,
  date pickers, action/actor dropdowns with an `'__all__'` sentinel), data
  table for desktop/tablet + cards on compact, pager.

### Administration / RBAC (`lib/features/auth/`)
- `domain/entities/rbac.dart` — `RoleRecord`, `PermissionInfo`, `RoleDetail`,
  `RolesSnapshot`, `RoleSaveResult`.
- `data/daos/rbac_dao.dart` — `RbacDao` (list with permission+user counts,
  create with duplicate guard, update label, transactionally replace permissions,
  delete) + `PermissionGroups`/`permissionModule` for the grouped dialog.
- `domain/usecases/rbac_use_cases.dart` — 5 gated, audited use cases +
  `kAdminRoleMinimumPermissions`.
- `application/rbac_controller.dart` — `RbacController`/`RbacViewState`.
- `presentation/widgets/permission_dialog.dart` + `role_dialog.dart` — grouped
  multi-select permission picker (selectable in create/edit flows).
- `presentation/pages/roles_page.dart`, `permissions_page.dart`,
  `admin_hub_page.dart` (`AdminTab` users/roles/permissions, permission-filtered
  tabs, access-denied empty state). The existing Users page is untouched.

### Wiring, DI & localization
- `app_sections.dart` — `AppSection.audit` added (label `navAudit`).
- `app_router.dart` — `/users` → `AdminHubPage` (sub-routes `/users/roles`,
  `/users/permissions`), `/settings` → `SettingsPage`, `/audit` → `AuditLogPage`;
  redirect guards added for roles/settings/audit.
- `injection.dart` (`_registerPhase12(db)`) + `providers.dart` — settings, audit
  and Rbac controllers + DAOs registered.
- ~90 l10n keys added to `app_ar.arb` (template) and `app_en.arb` (incl. plural
  `rolesPermissionsCount`/`rolesUsersCount` and param `rolesPermissionsFor`/
  `rolesDeleteConfirm`); `flutter gen-l10n` regenerated all three
  `app_localizations*.dart` files.

### Tests added (28)
- `test/settings_test.dart` (9) — DAO upsert + read-through defaults; guest-role
  denial (nothing persists); audit row on save; validation (empty name, tax >100%,
  non-3-letter currency); admin page save-into-DB round-trip; view-only role sees a
  disabled form and no save button.
- `test/audit_log_test.dart` (5) — paging + newest-first ordering; action/actor/
  date/search filters against a seeded trail; `distinctActions`/`distinctActors`;
  permission guard; page renders and opens the detail dialog.
- `test/rbac_test.dart` (14) — DAO create-unique/rename/replace-permissions/delete;
  snapshot guard; audited role create; admin-minimum + system `roles.view`
  invariants enforced on empty sets; delete blocks (system role, used role) then
  succeeds and audits; Roles page lists/copies/permission-dialog flows; hub tabs +
  access-denied state.
- `test/auth_harness.dart` (extended) — `attachAuthTo` now also wires the settings,
  audit and Rbac controllers over the testing DB so the app-level router smoke test
  stays hermetic (no getIt leakage).

## Verification

- `flutter analyze` — clean.
- `flutter test` — **463 passed** (full suite), no failures.

## Remaining tech debt

- **`SettingsRepositoryImpl.getSettings` reads the whole default aggregate each
  call** (3 key lookups + one row for `updatedAt`); fine at single-page scale, but
  a `getSettings` cache would avoid repeated reads as the app grows.
- **RBAC admin-minimums are hard-coded** in `kAdminRoleMinimumPermissions` (list),
  not derived from a settings/flag; the seed only includes the Phase-12 permission
  codes, so CSVs importing new permission families should re-check this constant.
- **Role `name` for custom roles is copied from the Arabic label** at creation and
  never re-synced on rename; harmless today (lookups use `id`) but worth revisiting
  if role names ever become a stable user-facing code.
- **Audit filters execute a fresh full COUNT each page**; for very large trails the
  pager could cache the count per filter set.