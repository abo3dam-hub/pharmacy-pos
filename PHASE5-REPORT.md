# Phase 5 Report — Customers & Prescriptions

**Status:** Implemented · **Span:** customers + prescriptions domain/data/application/UI on top of Phase 4 · **Tests:** 155 passing (`flutter analyze` → 0 issues).

## In Scope (done)

- **Customers master (§4.11)** — `customers_page.dart` (tab 1 of the Customers section): search (SQL-side LIKE over name/phone/email/tax VAT), create/edit/toggle-active/toggle-account via `customer_dialog.dart` (name/phones/email/address/tax VAT, date-of-birth picker, gender dropdown, opening balance + credit limit money fields, has-account + active switches), balance column, account/active pills, pager.
  - `has_account` (credit) flag; opening balance + credit limit in integer micro-units (scale 4) — never REAL (§23); balance is **derived** from the sales ledger and cached on `customers.balance_micros`, never hand-edited (§25, §27).
- **Customer statement (كشف حساب العميل)** — `customer_statement_page.dart`: date-range filters, keyset pagination on `(date, doc_type)`, running balances, an `opening` row on page 1, plus a totals footer (opening/debits/credits/closing) from `CustomerDao.statementTotals`. Feeds: completed `sale_invoice` remaining (`total − paid`) as debit + `paid` as credit, and signed (negative) completed `sale_return` money as credit. Gated by `customers.view` + `reports.view_sales`.
- **Prescriptions (§4.12, §4.13)** — `prescriptions_page.dart` (`PrescriptionsList`, reusable inside the Customers section tab 2): SQL-side search across number/patient/doctor, optional customer scope, pager, status pills, opens detail. `prescription_form_page.dart`: customer dropdown (active customers), patient/age/gender/dob, doctor/clinic cards, issued/expiry pickers, item line editor (inventory picker via `inventoryRepositoryProvider.searchItems`, qty/dosage/frequency/duration/notes), live totals. `prescription_detail_page.dart`: header card, item lines with `lineTotalMicros`, total, status, and the "Prepare for sale" action.
  - Header + items are written in **one atomic transaction** (`PrescriptionDao.insertWithItems`) — no orphan prescriptions, no orphan items (§26, §27). `customer_id` is NOT NULL; every line validates the item exists. Unique `RX-<millis>` numbers, item ids `rxi_`. `totalMicros = Σ qty_base × items.selling_price_micros`. Create-only (`active`); no edit (item/price irrevocability).
- **Prescription → sale link (Phase 6 mechanism, no POS)** — `PreparePrescriptionForSaleUseCase` + `PreparedSalePrescription` snapshot: validates the prescription is `active` and carries ≥ 1 line, then hands the future POS a customer + item list (trade name, qty in base units, unit selling price) to attach to a sale. Gated by `prescriptions.view` + `customers.view`.
- **Permissions** — `customers.view/create/edit`; `prescriptions.view/create`; seeded `role_pharmacist` (full), `role_cashier` (customers view/create + prescriptions view), `role_viewer` (customers view only). Customer statement = `customers.view` + `reports.view_sales`. Enforced in the use-case layer (mirrors Phase 2/4), on routes via redirect, and reflected in the UI (hide/disable).
- **Audit** — append-only rows for customer create/update/toggle-active/toggle-account (+ explicit `customer_balance` row when the opening balance changes) and prescription create; `before`/`after` JSON snapshots.
- **Routing & l10n** — `app_router.dart`: `statement/:customerId`, `prescriptions/new` (`prescription-new`), `prescriptions/detail/:id` (`prescription-detail`), customers redirect guard; ~85 new Arabic-first keys in `app_*.arb` with metadata blocks; `flutter gen-l10n` regenerated.
- **Driver deliverable** — `PHASE5-REPORT.md`, roadmap marked in `PROJECT-ARCHITECTURE-PLAN.md`.

## Bugs fixed during this phase

- `PrescriptionDao.detail` originally joined `prescriptions × customers × items` with a full-table item scan; rewritten to a bounded header lookup + `IN` item-name/price lookup (`_itemMeta`), removing the accidental Cartesian scan.
- `PrescriptionDao.search` joined list leaking rows / ordering; switched to a proper `innerJoin` with per-column `OrderingTerm`s.
- enum compares used `.equals()` (String-only) on `textEnum` columns → `.equalsValue(PrescriptionStatus.active)` in `activeForCustomer`.
- **`_customerExists` missing its `where` clause** (returned an arbitrary customer instead of the one referenced) → now `(select..where((c) => c.id.equals(id))).getSingleOrNull()`. Caught by review; covered by the no-orphan-customer test.
- Various 3→4 level import paths and unused l10n/imports purged; `_lines` made `final`; removed a stale per-customer quick-action that bypassed the statement route.

## Documented schema gap (deferred to Phase 6)

- `sales_invoices` does **not** carry a `prescription_id` column yet (§4.14 / §4.21 reference a prescription link on the sale). This phase deliberately avoided a schema migration; the `PreparedSalePrescription` snapshot already profiles the exact payload (customer + items) Phase 6 needs. **Recommendation:** when Phase 6 builds the POS, add `sales_invoices.prescription_id TEXT NULL REFERENCES prescriptions(id)` via the forward-only migration mechanism (§29) alongside other planned Phase 6 schema work; `schemaVersion` stays 1 for now.

## Deferred / Future

Explicitly **NOT** in this phase:
- POS, sales, invoices & returns, lost sales (Phase 6/7).
- Dispensing/editing/cancelling prescriptions beyond `active`; expiry jobs.
- Cash box, expenses, accounting, reports, backup/export (Phases 8–13).

## Test coverage added

- `test/customers_controller_test.dart` (7): create → master list shows derived opening balance; update/toggle-active/toggle-account persistence; viewer RBAC denial (create) while list stays allowed; account ledger seeded with completed sales invoice + sale return → cached balance + statement opening/documents/running balances/totals; customer audit rows (create/update/toggle-active/toggle-account); SQL-side search + pagination.
- `test/prescriptions_controller_test.dart` (5): create → list joins the customer and computes `totalMicros`; no-orphan validation (missing customer/item rejected, nothing persisted); detail resolves item trade names + line totals; prepare-for-sale snapshot for `active` and rejection when dispensed; RBAC (viewer cannot list, cashier can view but cannot create); audit row.
- `test/phase5_customers_pages_test.dart` (4): CustomersPage lists customers + add action; prescriptions tab lists a prescription; customer dialog validates the required name; viewer role sees customers but no create action. (Controller-wired widget smoke tests on the auth harness + nested `ProviderScope` overrides.)

Baseline Phase 4 suite (139) + Phase 5 suite (16) → **155 passing**.

## Verify

- `flutter analyze` → 0 issues.
- `flutter test` → 155 passed.