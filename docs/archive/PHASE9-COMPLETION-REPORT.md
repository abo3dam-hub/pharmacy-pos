# Phase 9 — Expenses Management (المصروفات) — Completion Report

**Phase:** 9 — Expenses (المصروفات)
**Baseline commit:** `d1b5e4a6f235d8347ece749f603f11dac8130fca`
**Branch:** Feature work on the Phase 9 scope only.
**Final status:** **PASS**

---

## 1. Objective

Deliver a complete Expenses module: a categorized expense journal with printable
reference numbers (`EXP-00001`), payment-method breakdown (cash/card), scanned
receipt attachment/preview, DB-side paging and filtering, a guarded cancel
(reverse) workflow that books the GL + drawer back out atomically, and a
system/immutable category master — all built exclusively on the existing
financial engine, with one forward-only schema migration (v6 → v7).

## 2. Scope & constraints honoured

- **Phase 9 only.** No chart-of-accounts UI, journal UI, trial balance, income
  statement, balance sheet, period close, general analytics, customer-payment
  UI, drawer import/export or per-user shift targets — all remain Phase 10/11.
- **Money stays in integer micro-units** (scale 4) end-to-end; no
  `double`/`float` in any new code.
- **Financial engine reused, never rewritten**: recording and cancelling an
  expense go through `FinancialPostingService` (`recordExpenseByCode` /
  `cancelExpense`), so the journal balance, cashbox running balance and audit
  trail semantics are identical to automatic sale/return/payment entries.
- **Arabic-first / RTL UI**; all amounts render in Latin digits
  (`Money.formatArabicDigits`).
- **No `rawInsert` on transactional tables by the feature** — the DAO is
  read-only (`SELECT`); every write funnels through the engine or the master
  inserts (expense_categories).

## 3. Baseline verification

Before feature work: 354 tests passing, `flutter analyze` = 0 issues, schema v6,
clean working tree at `d1b5e4a`.

## 4. Schema (v6 → v7) — precise and forward-only

- **New `expense_categories` table** (§4.20): `id`, `code` (unique, stable),
  `name`, `nameEn` (nullable), `accountCode`, `isActive`, `isSystem`,
  `createdAt`, `updatedAt`, with `idx_expense_categories_code`.
- **`expenses` gains** `paymentMethod` (TEXT, default `'cash'`) and
  `expenseNumber` (TEXT, default `''`). The existing `category` TEXT column now
  stores the stable category **code** (values match the legacy
  `ExpenseCategory` enum names, so every historical row keeps its meaning).
- Migration back-fills `EXP-` + printf('%05d', rowid) for pre-existing rows,
  seeds the category master and idempotently ensures the expense RBAC
  permissions + role grants (`ensureExpensePermissions`).
- `seedDefaults` seeds the 8 system categories (rent→5101, salaries→5102, all
  others→5100) on fresh DBs, so testing databases carry the same master rows.

## 5. Financial engine (`FinancialPostingService`)

- **`recordExpenseByCode`** — full transaction: validates amount > 0 + a
  non-void category, books the expense row (with `EXP-nnnnn` numbering via
  `MAX(rowid)+1`, rowids are safe because expenses are never deleted), writes a
  `CashboxTransactionType.expense` row (negative cash) when the payment is cash,
  posts GL Dr expense-acct / Cr cash (or Cr bank for card), and audits
  (`AuditAction.expense`, entity `expense`).
- **`recordExpense`** (legacy enum API) delegates to the new primitive so the
  existing `financial_lifecycle_test.dart` contract is untouched.
- **`cancelExpense`** (requires `expenses.void`, non-empty reason, exactly-once
  `is_voided` guard): cash → CashboxRow `type=expense` **positive**, journal
  Dr Cash / Cr expense; card → Dr Bank / Cr expense; audit `void`.
- **Category-master fallback**: if a master row is missing (unseeded / pre-v7
  DBs) the engine falls back to the legacy mapping (rent→5101, salaries→5102,
  else 5100) so upgraded databases and unseeded test DBs stay correct.

## 6. Permission model (§16)

New codes: `expenses.view`, `expenses.create`, `expenses.edit`, `expenses.void`,
`expenses.categories.view`, `expenses.categories.manage` — seeded with Arabic
labels. Role grants: admin = all; pharmacist = all six; viewer =
`expenses.view` + `expenses.categories.view`. Router guard denies `/expenses`
without `expenses.view`.

## 7. Feature layer (`lib/features/expenses/`)

- **Entities** — `ExpenseListItem` (flattened joined row), `ExpensePaymentMethod`
  enum (cash/card).
- **Repository** — `ExpenseRepository` interface + `ExpenseRepositoryImpl` over
  the engine, `ReceiptStorage` and `ExpenseDao`. Writes: `record`, `updateEditable`
  (description/notes only — amount/category/payment/date immutable after
  posting), `cancel`, `attachReceipt`, `removeReceipt`, and category master CRUD
  (system rows immutable — rejected with `InvalidOperationException`).
- **Read DAO** — `ExpenseDao.listExpenses` (raw SQL, parameterised variables):
  paged LIMIT/OFFSET, DB-side filters (category / payment / status / date
  window) and search (description, number, notes, supplier) with joined
  category / operator / supplier names. Never loads the table into memory.
- **Services** — `ReceiptStorage` abstraction + `LocalReceiptStorage` (managed
  `expense_receipts/` under app documents; 5 MB ceiling; allowed image/PDF
  extensions).
- **Use cases** — RBAC-first with `PermissionService.requireRolePermission` on
  every call; audit rows for edit / receipt / category ops (the engine already
  audits create + cancel, so no double audit). Validation: amount > 0,
  description required, category active, code regex `^[a-z_][a-z0-9_]{1,31}$`,
  account code 4-digit ≥ 5100, duplicate-category rejection.
- **Controller** — `ExpenseController` / `ExpenseViewState` (initial/loading/
  ready/error), paged list, filter state, categories master, per-page
  non-voided totals header.

## 8. Presentation

- `pages/expenses_page.dart` — summary strip (count + page total), filter bar
  (search + category/payment/status dropdowns), responsive table/compact cards,
  pagination, per-row actions (receipt preview, attach receipt, edit, cancel),
  read-only hint for viewers. `isExpanded` on the filter dropdowns prevents RTL
  label overflow.
- `widgets/expense_dialogs.dart` — record (amount, description, category,
  supplier, cash/card `SegmentedButton`, date, notes, receipt picker), edit,
  cancel-with-mandatory-reason, category form (system-blocked read-only), and a
  full-screen receipt preview (`PdfPreview` for PDFs, `Image.file` otherwise).

## 9. Routing, sections & DI

- `AppSection.expenses` (`/expenses`, `Icons.receipt_long_outlined`) added
  between Accounts and Reports; `_sectionPage` → `ExpensesPage`; guard requires
  `expenses.view`.
- `_registerPhase9(db)` registers the engine singleton, `ReceiptStorage`,
  repository, all ten use cases and the controller; providers added for
  `expenseRepositoryProvider` and `expenseControllerProvider`.

## 10. Localization

New `navExpenses` + ~60 `expenses*` / `expense*` keys added to `app_ar.arb` and
`app_en.arb` (Arabic-first template); `flutter gen-l10n` regenerated the
localizations. `nullable-getter: false`, numbers stay Latin via `Money`.

## 11. Tests (36 new)

| File | Count | Covers |
| --- | --- | --- |
| `test/expense_service_test.dart` | 17 | seeds, cash record, amount/description/category/actor validation, edit, void-guard, category CRUD + validation + system-block, paging, viewer denial |
| `test/expense_integration_test.dart` | 4 | full record→edit→cancel lifecycle, attach/remove receipt, voided-immutability, cash/card both persisted |
| `test/expense_rbac_test.dart` | 7 | viewer read-only across all operations, missing-role rejection, admin full surface |
| `test/expense_audit_test.dart` | 6 | create/edit/void/attach audit rows, category create/toggle audits, system category cannot be deactivated |
| `test/expense_page_test.dart` | 3 | Arabic empty state, admin record button, viewer read-only hint + hidden actions |

Supporting updates: `schema_audit_test.dart` expects `expense_categories`;
`migration_test.dart` upgraded to v1→v7 (mirror of the full migration);
`backup_service_test.dart` pinned to schema version 7.

## 12. Acceptance matrix (24)

| # | Acceptance criterion | Status |
| --- | --- | --- |
| 1 | New expense is categorised, numbered (`EXP-nnnnn`), booked to GL + drawer atomically | PASS |
| 2 | Cash expenses flow out of the drawer; card expenses book bank (no drawer) | PASS |
| 3 | Amount must be > 0; description required | PASS |
| 4 | Category must exist and be active | PASS |
| 5 | Edit changes description/notes only — amount/category/payment/date immutable | PASS |
| 6 | Edits rejected on a voided expense | PASS |
| 7 | Cancel is exactly-once (`is_voided` guard) and requires a reason + `expenses.void` | PASS |
| 8 | Cancel reverses GL + drawer (cash → Cash/expense; card → Bank/expense) | PASS |
| 9 | `expenses.view` gates the route and the list | PASS |
| 10 | `expenses.create` gates recording; viewer denied | PASS |
| 11 | `expenses.edit` gates edit + receipt attach/remove | PASS |
| 12 | `expenses.void` gates cancel | PASS |
| 13 | `expenses.categories.view` / `.manage` gate the category screens | PASS |
| 14 | System categories are immutable (edit/disable rejected) | PASS |
| 15 | Category create validates code pattern, required name, 4-digit account ≥ 5100, duplicates | PASS |
| 16 | Receipt attach stores under managed storage with size/type ceilings; preview works | PASS |
| 17 | Receipt can be removed; voided expenses cannot take receipt changes | PASS |
| 18 | Audit rows for create/edit/void/receipt/category ops (engine + use cases, no double writes) | PASS |
| 19 | Paged journal (LIMIT/OFFSET), newest-first | PASS |
| 20 | DB-side filters: category / payment / status / search | PASS |
| 21 | Page header shows record count + per-page non-voided total (Latin digits) | PASS |
| 22 | Viewer sees read-only UI (no record/edit/void actions) | PASS |
| 23 | Arabic/RTL UI with Latin digits; l10n keys in both ARBs | PASS |
| 24 | `flutter analyze` 0 issues; full suite green (390/390) | PASS |

## 13. Migration & integrity

`migration_test` verifies v1→v7: mirror replicas the full upgrade path, expense
rows keep `category` (back-filled numbers, new columns), the category master and
expense permissions are present, and fresh installs are identical to upgraded
installs. Backup round-trips at version 7. No destructive rebuilds, no reseed of
user data.

## 14. Money / digits / RTL compliance

All amounts parsed via `Money.parse` and printed via `Money.formatArabicDigits`
(Latin digits). Widget test asserts the Arabic page renders without overflow
after the `isExpanded` fix.

## 15. Roadmap integrity statement

Phase 9 shipped **only** the expenses scope. Explicitly NOT started (Phase 10 +
Phase 11): Chart-of-Accounts UI, Journal UI, Trial Balance, Income Statement,
Balance Sheet, period close, general analytics, customer-payment UI, drawer
import/export, per-user shift targets. No such code exists in this diff.

## 16. Known limitations / documented debt (deferred, not blocking)

- **Receipt scans are file-system based** — an optional encrypted backup of the
  `expense_receipts/` directory is not implemented; a lost device loses scans
  (the DB keeps the path only).
- **No date-window picker on the page UI** — the DAO supports `fromMillis`/
  `toMillis`, but the filter bar exposes category/payment/status only.
- **Multi-branch / multi-store expense posting** remains out of scope until the
  (unstarted) multi-location phase.

## 17. Final status

**PASS** — Phase 9 implemented, localized, analyzed (0 issues) and fully tested
(390/390; 354 baseline + 36 new, zero regressions). Committed and pushed on the
feature branch; Phase 10/11 explicitly out of scope and not started.