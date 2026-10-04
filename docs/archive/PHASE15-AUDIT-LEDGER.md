# Phase 15 — Master Audit Ledger

Working ledger for the Phase 15 final engineering audit (`PHASE-15-PROMIT.md` §5–§6).
Status of every historical requirement, debt, deferred item, handoff and known
concern from Phase 1 through Phase 14, verified against **current code** (not
stale reports).

Legend — Classification: **Complete** (verify only) · **Resolve Now** (fix)
· **Controlled Enhancement** (implement, low risk) · **Later** (document,
needs business/architecture decision) · **Out of Scope** (leave documented).

---

## Phase 1 — Foundation & DB

| Item | Historical Status | Current Code Status | Classification | Action |
|---|---|---|---|---|
| SQLite/drift schema, money as integer micros, basis-point percentages | Complete | Verified in `app_database.dart`, `money.dart`; all monetary values remain integer smallest-units (§8.1) | Complete | Verify only |
| `FinancialPostingService` single posting engine | Complete | Single engine — no second posting path in sales/purchases/returns/payments/expenses/cashbox (§9) | Complete | Verify only (covered by double-posting + GL reconciliation suites) |
| Schema version 1→8 forward-only migrations | Complete | v8; `_migrate` chain v1→v8 in `app_database.dart`; file-backed upgrade test `migration_test.dart` | Complete | Verify only |

## Phase 2 — RBAC / Auth

| Item | Historical Status | Current Code Status | Classification | Action |
|---|---|---|---|---|
| Roles/permissions RBAC, admin/pharmacist/cashier/viewer | Complete | Seeded in `seed_data.dart`; enforced in `PermissionService` + every page/controller gate | Complete | Verify only |
| In-memory session (relogin on restart) | Known debt ("Phase 2") | Still in-memory; intentional for a local desktop POS (login per launch) | Later | Document — by-design local-app behavior; not a defect |
| Legacy DB `role_viewer` migration/seeding | Known debt | Only fresh-install seeding existed; `beforeOpen` lacked idempotent healing | **Resolve Now** | **Fixed** — added `ensureViewerSeeded` (idempotent INSERT OR IGNORE), wired into `beforeOpen` (Phase 15 §13); regression test added |
| Anonymous-login audit username behavior | Known debt | `audit_logs.userId` is NOT NULL; unknown usernames are intentionally not audited (documented in `injection.dart`). Wrong-password/inactive on a known user IS audited | Later | Document — auditing unknown usernames would require a nullable `userId` schema change (v9) → Phase 16 business decision |
| Bcrypt password hashing | Complete | Verifying in `login.dart`/`UserDao` | Complete | Verify only |
| Audit immutability | Complete | `AuditService` append-only; no silent mutation path | Complete | Verify only |

## Phase 3 — Inventory

| Item | Historical Status | Current Code Status | Classification | Action |
|---|---|---|---|---|
| Inventory CRUD, batch/on-hand, stock adjust, bulk category, audit trail, Excel import/export | Complete | Implemented; `inventory_test.dart`, `item_dao_test.dart` pass | Complete | Verify only |
| Viewer denied inventory create | Complete | Permission gate verified via controller + page tests | Complete | Verify only |

## Phase 4 — Purchases / Suppliers / Expenses (basic)

| Item | Historical Status | Current Code Status | Classification | Action |
|---|---|---|---|---|
| Purchase invoices, expense invoices, stock movement via `StockService` | Complete | Purchases/expenses flow tests pass | Complete | Verify only |

## Phase 5 — Customers / Prescriptions

| Item | Historical Status | Current Code Status | Classification | Action |
|---|---|---|---|---|
| Customer ledger, prescription create/link, sales-side prescription linkage | Complete | Implemented; customer statement + prescription tests pass | Complete | Verify only |
| Stale per-customer quick-action removal | Complete | Removed in Phase 5 | Complete | Verify only |

## Phase 5.1 — Review / locks

| Item | Historical Status | Current Code Status | Classification | Action |
|---|---|---|---|---|
| Partial-sale design superseded by Phase 6 explicit pharmacist model | Complete | Phase 6 design lock implemented | Complete | Verify only (Phase 11 below) |

## Phase 6 — Partial Sales / Prices / Reports basics

| Item | Historical Status | Current Code Status | Classification | Action |
|---|---|---|---|---|
| Explicit pharmacist-controlled partial-sale model (`partialSaleEnabled`, `sellablePartUnitId`, `partsPerFullProduct`, `sellablePartBaseQuantity`) | Complete | Verified in schema + `partial_sale_test.dart` (full price = 1000 share, partial = 10% default markup) | Complete | Verify only |
| Partial base = full / parts; markup = `×(10000+bp)/10000` | Complete | Verified | Complete | Verify only |
| Inventory conversion via `sellablePartBaseQuantity`, not conflated with decomposition | Complete | Verified via tests | Complete | Verify only |
| Historical invoices preserve actual price/quantity | Complete | Verified | Complete | Verify only |

## Phase 6/7 Gap Closure

| Item | Historical Status | Current Code Status | Classification | Action |
|---|---|---|---|---|
| `lost_sales` table created only on fresh install; not in upgrade path | Known debt | `_migrate` v6 heals missing `lost_sales` (`app_database.dart`); migration test covers it | Complete | Verify only |
| Lost-sale capture, close, POS integration | Complete | Implemented; `lost_sale_test.dart` | Complete | Verify only |

## Phase 7 — POS Workspace / Sales Engine

| Item | Historical Status | Current Code Status | Classification | Action |
|---|---|---|---|---|
| POS tabs, search, cart, checkout, receipt, invoice persistence, barcode buffer, FEFO | Complete | `pos_workspace_page_test.dart`, `pos_integration_test.dart`, `sale_service_test.dart` pass | Complete | Verify only |
| **Space / Enter Quick Actions** (§21) | Deferred to Phase 15 (§17.1) | No global handlers; search field owns Enter | Controlled Enhancement | **Implemented** — contextual Enter quick-add: unique search result added directly; scanner priority preserved (`feed` reports emission); multi-result list untouched; tests added |

## Phase 7.5 — Financial Lifecycle

| Item | Historical Status | Current Code Status | Classification | Action |
|---|---|---|---|---|
| Payment split cash/card/credit, void flow, customer payments ledger | Complete | Verified in schema v5+ and `financial_lifecycle_test.dart` | Complete | Verify only |
| Customer payment number uniqueness | Debt → resolved | `customer_payments.payment_number` has `.unique()` constraint (§12) | Complete | Verify only |

## Phase 8 — Purchases/Returns/Reconciliation

| Item | Historical Status | Current Code Status | Classification | Action |
|---|---|---|---|---|
| Purchase returns, batch recovery, GL reconciliation | Complete | Implemented; `purchase_return` + `cashbox_gl_reconciliation_test.dart` | Complete | Verify only |
| `4002 Purchase Returns` semantics | Debt (unused account) | Account seeded v8 but accounting semantics unchanged; account exists as a liability per approved model | Later | Document — leave unused account; do not alter semantics |

## Phase 9 — Expenses / RBAC extension / Migration v7

| Item | Historical Status | Current Code Status | Classification | Action |
|---|---|---|---|---|
| Expense categories + payment method + expense numbers; RBAC for expenses | Complete | Verified (`migration_test.dart` v7 checks); `expense_*` suites pass | Complete | Verify only |
| Printable expense numbering `EXP-` back-fill | Complete | Verified | Complete | Verify only |

## Phase 10 — Accounting / Reversal / Periods

| Item | Historical Status | Current Code Status | Classification | Action |
|---|---|---|---|---|
| Journal reversals, accounting period close, system accounts | Complete | Verified v8 + `accounting_period_test.dart` | Complete | Verify only |
| Sales/purchase/customer-payment/return number uniqueness | Debt → resolved | DB `.unique()` on all four business-number columns | Complete | Verify only |

## Phase 10.1 — Financial Integrity Hardening

| Item | Historical Status | Current Code Status | Classification | Action |
|---|---|---|---|---|
| Double-posting protection (duplicate submit guard) | Complete | `double_posting_hardening_test.dart` passes | Complete | Verify only |
| No DB-level unique index on business numbers | Known debt | **Resolved earlier** — `.unique()` constraints now exist on `sales_invoices.invoice_number`, `customer_payments.payment_number`, `purchase_invoices.invoice_number`, `returns.return_number` | Complete | Verify only |
| 4002 dead/over-seeded purchase returns | Known debt | Account exists, semantics untouched | Later | Document |

## Phase 11 — Reporting + Arabic shaping workaround

| Item | Historical Status | Current Code Status | Classification | Action |
|---|---|---|---|---|
| Trial balance, income statement, balance sheet, sales/purchases/inventory/lost-sales/customer/supplier statements | Complete | `reports_dao_test.dart` includes accounting invariants (debits=credits, A=L+E, income↔retained earnings) | Complete | Verify only |
| Reports never mutate journals | Complete | Verify only (reports are read-only DAO projections) | Complete | Verify only |
| Arabic bidi shaping workaround retained | Complete | `pdf_arabic.dart` shaping documented; reports render Arabic | Complete | Verify only — regression covered by `reports_*` suites |

## Phase 12 — Admin/Settings/RBAC consolidation

| Item | Historical Status | Current Code Status | Classification | Action |
|---|---|---|---|---|
| `SettingsRepositoryImpl.getSettings` repeated aggregate reads | Known debt | Trivial multi-table reads; caching adds stale-state risk with no measurable cost | Later | Document — do not optimize blindly (§14) |
| Hard-coded minimum-admin-permission logic | Known debt | `kAdminRoleMinimumPermissions` (bootstrap safety: the first admin must be able to reseed); verified it covers backup/restore/export/accounting codes | Later | Document — intentional bootstrap safeguard, correctly maintained |
| Role name / Arabic label synchronization | Known debt | `updateRole` only updates `nameAr`; `name` (stable code) stays as created | Later | Document — `name` is a stable code, not intended to mirror label; touching it would risk role-reference integrity |
| Audit pagination/count efficiency | Known debt | COUNT + page query per page load; no measured scaling problem | Later | Document — no speculative optimization |

## Phase 13 — Backup / Restore / Export

| Item | Historical Status | Current Code Status | Classification | Action |
|---|---|---|---|---|
| Online backup (WAL/SHM), manifest, SHA-256, receipts, verification, failure cleanup | Complete | `backup_service_test.dart`, `backup_archive_test.dart`, `backup_rbac_test.dart` pass | Complete | Verify only |
| Restore: preview, validation, schema compatibility, emergency backup, atomic replace, rollback, restart, audit | Complete | `restore_service_test.dart` (incl. corrupt/tampered/future-schema/zip-slip/rollback) | Complete | Verify only |
| Export: CSV BOM/CRLF/escaping/paging/blobs/manifest/read-only/Arabic | Complete | `data_export_test.dart` | Complete | Verify only |
| RBAC backup/restore/export permission seeds (fresh + upgraded + restored) | Complete | `ensureBackupPermissions` runs in `beforeOpen` | Complete | Verify only |

## Phase 14 — Polish/hardening + Keyboard shortcuts

| Item | Historical Status | Current Code Status | Classification | Action |
|---|---|---|---|---|
| Settings-backed, rebindable keyboard shortcuts (F1/F2/F5/F12/Alt+S) via `PosShortcutManager` | Complete | Implemented; `shortcut_manager_test.dart` | Complete | Verify only |
| Warning/error token WCAG AA contrast | Deferred to Phase 15 (§18) | `warning #B7791F` failed (≈3.4–3.6:1), `error #B45550` failed on canvas/container | **Resolve Now** | **Fixed** — `warning → #7F5714`, `error → #A9323A`; ≥4.5:1 on every light surface + containers + inverse text; AA contrast regression test added |
| RTL icon system (`AppDirectionalIcons`) | Complete | `app_rtl_icons_test.dart` | Complete | Verify only |

---

## Cross-cutting checks (current code)

| Concern | Status | Evidence |
|---|---|---|
| Financial invariants | PASS | debits=credits, A=L+E, income↔retained earnings suites pass |
| No duplicate posting paths | PASS | single `FinancialPostingService`; `double_posting_hardening_test.dart` |
| Document-number uniqueness | PASS | DB-level `.unique()` on invoice/payment/return numbers |
| Backup/restore destructive paths isolated | PASS | file-backed temp dirs; restored archives verified |
| RBAC > UI-only authorization | PASS | service/usecase-level gates (`PermissionService` checked in services) |
| Audit integrity | PASS | append-only; login success/failure/logout audited |
| L10n parity | PASS | ar/en ARB **1001/1001** keys, 0 missing either way |
| Hardcoded Arabic | P3 debt | ~741 lines / 73 files outside seed data + l10n (domain exception messages + ~40 presentation strings) — Arabic-first by design; English locale inherits Arabic text in these paths (documented in completion report §Localization) |
| RTL | PASS | `design_system_test.dart` Arabic-RTL + English-LTR render semantics |
| Accessibility | PASS (AA) | contrast regression added; rail destinations expose semantics; icon-only controls use tooltips |
| Performance | PASS | batch `_buildInvoiceViews` path; `sales_invoice_search_perf_test.dart` N+1 guard; no speculative optimization |
| Concurrency/retry | PASS | transactional services; double-submit guarded; retry tests |
| Soft delete/historical integrity | PASS | item deactivation, void/return flows preserve history (suites pass) |
| CI pipeline | Valid | `.github/workflows/ci.yml` — gen-l10n + analyze + test (ubuntu); `build-windows` on `v*` tags |
| Windows build | Not run here | Linux host; CI `build-windows` executes on tags (environment-dependent, documented) |

## Segment A/B/C/D/E classification summary

- **A — Already implemented:** the large majority (see tables above).
- **B — Outstanding, resolved this phase:** viewer-role legacy seeding; warning/error AA contrast.
- **C — Controlled Enhancement implemented:** Enter quick-add (unique search result) on the POS search field.
- **D — Requires future decision (documented):** anonymous-login audit (nullable `userId` schema change).
- **E — Outside useful scope (documented):** 4002 semantics change, role-name re-sync, settings/audit caching.