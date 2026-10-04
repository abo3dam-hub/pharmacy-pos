# Phase 2 — Authentication & Users: Completion Report

Repository: `abo3dam-hub/pharmacy-pos`
Report date: 2026-09-06
Status: **Phase 2 closed — Authentication & Users delivered end-to-end (domain → data → application → presentation) and verified.**
Verification: `flutter analyze` → No issues found; `flutter test` → **117/117 passing** (80 pre-existing + 37 new Phase 2).

## 1. What was delivered

### 1.1 Domain layer — 100% (§16)
- `lib/features/auth/domain/entities/` — `User` and `AuthSession` (immutable value objects; session bundles user + permission set + signed-in-at).
- `lib/features/auth/domain/services/password_service.dart` — **bcrypt only**; plaintext passwords never stored or logged; `minLength` policy (6).
- `lib/features/auth/domain/services/permission_guard.dart` — `ensurePermission(Perm)` guard thrown inside use cases as `UnauthorizedException`.
- `lib/features/auth/domain/usecases/` — one use case per action: `login`, `logout`, `create_user`, `update_user`, `deactivate_user`, `reactivate_user`, `change_password`, `list_users` (DB-side search + pagination), `check_permission`, `get_current_user`. Business rules live here: duplicate usernames (case-insensitive) → `DuplicateException`, short password → `ValidationException`, self-deactivate → `InvalidOperationException`, missing user → `NotFoundException`, non-admin mutations → `UnauthorizedException`.
- `lib/features/auth/domain/repositories/auth_repository.dart` — repository contract.

### 1.2 Data layer — 100% (§4.26, §27)
- `lib/features/auth/data/daos/user_dao.dart` — Drift DAO: username lookup, `LIMIT/OFFSET` paged + SQL `LIKE` search, hash update.
- `lib/features/auth/data/repositories/auth_repository_impl.dart` — maps rows ↔ entities; drives `recordLogin`/audit persistence.
- **Viewer role seeded** (`role_viewer` / `مشاهد`, read-only) with a restricted permission matrix — `search`, `view_inventory`, `view_alternatives`, `inventoryView`, `stockView`, `salesView`, `purchasesView`, `suppliersView`, `customersView`, report views, `cashboxView`, `expensesView`. No mutating rights. Admin/Pharmacist/Cashier matrices retained.
- DB seeding auto-runs in `onCreate` (existing databases are not re-seeded — documented limitation).

### 1.3 Application layer — 100% (§17, §35)
- `lib/features/auth/application/auth_controller.dart` — `AuthController` `StateNotifier`: `login` (audits `login`/`login_failed` by note mapping), `logout` (audits `logout`), `isAuthenticated`, expose-permissions, and a reactive `stream` bridging GoRouter (§36). Session is in-memory only.
- `lib/features/auth/application/users_controller.dart` — `UsersViewController`: load list, create/update user, deactivate/reactivate, change password (auto-receives the acting admin id → **audit never lost**), `must` permission guard before every mutation; failures surface as typed failure states (no silent throws).
- DI: `lib/core/di/injection.dart` register the graph (UserDao → AuthRepository → per-action use cases → controllers); Riverpod providers in `lib/core/di/providers.dart`.
- **Audit mapping** (`injection.dart` note-based): logout → `AuditAction.logout`; login success → `login`; login failure → `login_failed` (new action literal surfaced in `lib/shared/models/enums.dart`; mirrors §17).

### 1.4 Presentation layer — 100% (§16, §36, §24)
- `lib/core/router/app_router.dart` — GoRouter v14, auth-aware `redirect` + `refreshListenable` (`_GoRouterListenable` bridging `AuthController.stream`): unauthenticated → `/login`; authenticated on `/login` → `/`; `/users` without `users.view` → `/access-denied`. Single `ShellRoute` hosts one route per `AppSection` inside `AppShell`. `_LogoutButton` in the shell app bar.
- `login_page.dart` — Arabic-first themed login (username/password), error states localised, bcrypt-verified.
- `users_page.dart` — admin Users module: desktop `AppDataTable` with search + pagination and row actions (edit/deactivate/reactivate/change password) for `admin`; **compact cards** (avatar + last-login, tap → actions) under `AppBreakpoints`; delete confirmed via `showAppConfirmDialog`.
- `user_dialog.dart` — create/edit dialog; role selector with 4 seeded roles (including viewer); inline password constraints.
- `access_denied_page.dart` — friendly 403 page.
- **Design-system compliance (§0):** pages consume only `AppColors`/`AppSpacing`/`AppRadius`/`AppTypography`/`AppTheme` tokens and reuse `AppShell`, `AppResponsiveLayout`, `AppDataTable`, `SearchField`, `LoadingOverlay`, `showAppConfirmDialog` — no new colors, fonts, or duplicated shared widgets; all strings via `AppLocalizations` (127-key ar ⇄ en parity, unaffected).
- Enabling/disabled pattern: non-admin actors never see user-management actions; the router additionally guards `/users`.

### 1.5 Tests — 100% (§31)
**117 tests, all passing; `flutter analyze` clean.** New in Phase 2:

| Suite | Coverage |
|---|---|
| `test/auth_use_cases_test.dart` | PasswordService, LoginUseCase (success/unknown/wrong-password/inactive + last-login refresh), Create/Update/Deactivate/Reactivate/ChangePassword/ListUsers — business rules, exceptions, pagination/search, RBAC guards |
| `test/auth_controller_test.dart` | AuthController flow + audit rows (`login`, `login_failed`, `logout`); UsersViewController guard + audit (`create`, `delete`, `restore`, `password_changed`); non-admin denied with no audit write |
| `test/users_page_test.dart` | Admin grid loads; create viewer via dialog; deactivate with confirm; change password; non-admin sees no actions; compact 390×844 cards |
| `test/auth_harness.dart` | Reusable test harness: seeded in-memory DB (`role_viewer`) + overridden Riverpod providers (`overrideWith`) |

Also updated (surviving suites): `design_system_test`, `widget_test` (shell signed-in flow), `database_smoke_test` (4 roles).

## 2. Limitations (documented)

- **Unknown-username login failures are not auditable** — `audit_logs.userId` is NOT NULL (FK); the code never writes a `null`-actor row. Known-username failures are audited as `login_failed`.
- **Session is in-memory** — app restart returns to `/login`; a durable session/persistence is a later-phase concern.
- **`role_viewer` is not auto-seeded into pre-existing databases** — seed runs in `onCreate` only; upgrading production DBs needs a migrate/seed step (future §29 work).

## 3. Percentage completed

| Deliverable | Plan § | Progress |
|---|---|---|
| Auth domain (entities, bcrypt, RBAC guard, use cases) | §16 | 100% |
| Auth data (UserDao, repository, viewer seed) | §4.26, §27 | 100% |
| Auth application (controllers, DI, audit mapping) | §17, §35 | 100% |
| Auth presentation (login, users, dialogs, access-denied) | §16, §24, §36 | 100% |
| GoRouter auth-aware navigation | §36 | 100% |
| Design-system compliance (§0 contract) | §0, §33 | 100% |
| Tests (37 new; 117 total passing) | §31 | 100% |
| **Overall** | | **100%** |

## 4. Commits on `origin/main`

- `872249a` docs: add design system preflight report
- `893a805` chore: align ui foundation with pharmacy design system
- *(next)* `feat: complete pharmacy phase 2 authentication and users`

CI: https://github.com/abo3dam-hub/pharmacy-pos/actions (analyze-test green on push).