# Phase 4 Report — Suppliers & Purchases

**Status:** Implemented · **Span:** suppliers + purchases domain/data/application/UI on top of Phase 3 · **Tests:** 139 passing (`flutter analyze` → 0 issues).

## In Scope (done)

- **Suppliers master (§4.10)** — `suppliers_page.dart` with two tabs: master grid + derived balances, search (SQL-side LIKE over name/phone/code/contact), create/edit/toggle-active via `supplier_dialog.dart`, statement navigation, pager.
  - Opening balance + credit limit in integer micro-units (scale 4) — never REAL (§23); balance is **derived** from the ledger and cached on `suppliers.balance_micros`, never hand-edited (§25, §27).
- **Suppliers statement (كشف حساب)** — `supplier_statement_page.dart` (`SupplierStatementView`): date-range filters, keyset pagination on `(date, doc_type)`, running balances, an `opening` row on page 1, plus a totals footer (opening/debits/credits/closing) from `SupplierDao.statementTotals`.
- **Purchase invoices (§4.16, §12)** — `purchases_page.dart` grid with invoice-number search + supplier/status/date filters and pager; `purchase_form_page.dart` create/edit-pending with a line editor (item picker via inventory search, unit type, qty, unit cost, discount basis points, bonus line editor) and a live totals preview.
- **Receiving (§12, §13)** — `receive_dialog.dart` collects one batch number + optional expiry per pending line; `PurchasesRepositoryImpl.receive` validates every line, creates batches, resolves bonuses through the `BonusCalculator`, posts `purchase` ledger movements (same-item bonus folded into the batch via effective qty/cost; Buy A Get B gets its own batch + zero-cost movement), optionally updates master cost/pricing (guarded by `lock_auto_price_update`, audited), marks the invoice `received`, and re-derives the supplier balance — all in one transaction.
- **Bonus engine (§4.18)** — `bonus_1` / `bonus_2` / `gift` on purchase lines from creation (`purchase_bonuses.batch_id` NULL until receive); effective quantity = paid + bonuses, effective unit cost = paid total ÷ effective quantity (rounded half-up).
- **Purchase returns (§4.19, §14)** — `purchase_return_dialog.dart` + `PurchasesRepositoryImpl.recordReturn`: standalone `purchase_return` document, stock/batch reduction, negative ledger movement, balance re-derivation; returnable quantity capped by `availableToReturn` (effective received qty − already returned).
- **Cancel (void)** — only pending invoices can be cancelled (`purchases.void`, `AuditAction.voidOrder` → stored `'void'`), soft-deleted via status + `is_voided`.
- **Permissions** — `suppliers.view/create/edit`; `purchases.view/create/edit/void`; statement = `suppliers.view` + `reports.view_purchases`; purchase returns use the canonical `return`. Enforced in the use-case layer (mirrors Phase 2), enforced on routes via redirect, and reflected in the UI (hide/disable).
- **Audit** — append-only rows for supplier create/update/toggle, invoice create/receive/cancel, batch create, bonus batch, and auto price updates; `before`/`after` JSON snapshots.
- **Routing** — `app_router.dart`: nested routes for `suppliers/statement/:supplierId`, `purchases/new`, `purchases/edit/:id`, `purchases/detail/:id`; `suppliers.view` / `purchases.view` redirect gates inside the shell.
- **Driver deliverable** — `PHASE4-REPORT.md`, roadmap marked in `PROJECT-ARCHITECTURE-PLAN.md`.

## Bugs fixed during this phase

- `PurchasesRepositoryImpl.updatePending` deleted lines/bonuses then **re-inserted the invoice header with the same PK** → `UNIQUE constraint failed: purchase_invoices.id`. `_writeInvoice` now branches: INSERT on create, UPDATE (with the same id) when editing a pending invoice.
- (Found by nightly review) `purchase_form_page.dart` `_PurchLine` fields were `final` yet reassigned when re-picking an item; leaky `const` failures with runtime l10n text; unused imports; a mistaken `l.line.itemName` instead of `l.itemName` in the receive dialog (receive-dialog already underscored the difference).

## Deferred / Future

Explicitly **NOT** in this phase:
- Customers, patients, prescriptions.
- POS, sales, invoices & returns, lost sales.
- Cash box, expenses.
- Accounting (chart of accounts, journal entries, auto-posting), period close.
- Report PDF/Excel export, backup/restore, cloud/network sync, REST/GraphQL transport.

## Test coverage added

- `test/suppliers_controller_test.dart` (6): create → master list → derived balances; update + toggle-active persistence; viewer RBAC denial (create) while list stays allowed; statement aggregation (opening + 2 received invoices + 1 purchase return → totals + running balance); supplier audit rows; SQL-side search + pagination.
- `test/purchases_flow_test.dart` (6): pending create with bonus → totals + editable lines (exercises the updatePending header fix); receive → batch/original/bonus/stock/movement/balance/audit; cancel soft-delete without touching stock; RBAC (viewer create denied, cashier void denied); duplicate invoice number; purchase return → stock/batch reduction + `purchase_return` movement.
- `test/phase4_pages_test.dart` (2): SuppliersPage lists a supplier + shows the add action; PurchasesPage lists a pending invoice (controller-wired widget smoke tests on the auth harness + nested `ProviderScope` overrides).

Baseline Phase 3 suite (125) + Phase 4 suite (14) → **139 passing**.

## Verify

- `flutter analyze` → 0 issues.
- `flutter test` → 139 passed.