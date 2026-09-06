# PHASE 7.5 – Financial Lifecycle Foundation — Completion Report

- **Base commit:** `f64ac5c40bbaf4a940d013d004228162dcf7bf6d`
- **Final commit:** `13b5a90e816deaa5a795faac00698da0965b909e`
- **Tests:** `+304: All tests passed!` (was 286 before this phase; +18 new/updated)
- **Analyzer:** `flutter analyze` → **No issues found!** (0 issues)
- **Schema:** drift v5 (`CustomerDao` feeds widened, `customer_payments` table added, `acc_1200` inventory account seeded)

---

## 1. Summary

Phase 7.5 established the financial lifecycle foundation: an atomic double-entry
posting engine alongside atomic sales, returns, customer payments/refunds, invoice
voids, and expenses/cash adjustments; a single authoritative SQL-derived customer
balance; and an Arabic-first UI with a strict Latin-digit number policy. All of it
is exercised end-to-end by a new comprehensive test file (`financial_lifecycle_test.dart`)
and pinned by updated schema/contract/backup tests.

Everything runs under **drift transactions**: a sale, return, payment, refund, void,
or expense either fully commits (drawer row + balanced journal + account balances +
customer balance + stock + audit) or rolls back completely. This is verified by an
`_ExplodingFinancial` rollback test.

---

## 2. Architecture

### 2.1 Posting engine — `lib/domain/services/financial_posting_service.dart` (NEW)
Single source of truth for GL postings. Public API:
- `postSale(drawerNet, cash, card, revenue, cogs, inventory, invoiceId, …)` — the two-driver
  sale journal.
- `postReturn(outstandingArOffset, cashRefund, …)` — the return journal.
- `postVoidReversal(refType 'sale', refId invoiceId, …)` — mirrors the original sale entry
  with inverted sign so the voidable posted columns (`cashMicros/cardMicros/creditMicros`)
  reverse out.
- `recordExpense(category, description, amount, userId)` — category-backed GL (rent→5101,
  salaries→5102, else 5100) + drawer outflow (`CashboxTransactionType.expense`), RBAC
  `Perm.expensesCreate`.
- `adjustCash(amount, reason, userId)` — drawer adjustment journaled against **Capital** (acc_3000)
  (documented limitation), RBAC `Perm.cashboxOperate`.
- `recordCustomerPayment` / `recordCustomerRefund` — payment-side customer money
  (see 2.4).

Journals are always balanced; each driver is validated (non-negative cash/card,
`cash + card == paid`, `drawerNet == cash − change ≥ 0`).

### 2.2 Wiring — `sale_service.dart`, `return_service.dart`
- `recordSale` resolves the payment split per method (cash→`(paid,0)`, card→`(0,paid)`,
  mixed→`(cashReceived, cardReceived)`), blocks credit without a customer/hasAccount,
  enforces the credit-limit, persists `cash/card/credit/remainingMicros`, then inside the
  transaction runs `postSale` + `syncCustomerBalance` + audit.
- Credit contract: **no customer → `InvalidOperationException`** (preserves the pre-existing
  "unpaid completed sale is rejected" test); `hasAccount=false` → `ValidationException`;
  credit-limit breach → `ValidationException`. POS UI remains cash/card/mixed only (credit is
  engine-level; Phase 8 deferral).
- `recordSaleReturn` rejects voided invoices, books AR-offset + cash refund with
  `_advanceInvoiceStatus`, and syncs the balance.
- New `voidInvoice` (only when `saleStatus == completed` **and** no returned lines; requires
  `Perm.salesVoid` + non-empty reason + `AuditAction.voidOrder`): reverses stock
  (`sale_void` movement), prescription dispensing, financials (`postVoidReversal`),
  and syncs the customer balance.

### 2.3 Customer balance — `lib/data/daos/customer_dao.dart`
A single derived feed (`_balanceFeedSnippet`) used by the cached `balance_micros` column
(`syncBalance`) and by statement offsets. Signature:

```
balance = opening
  + SUM( MAX(0, remainingMicros − returns-for-invoice) )  for completed/partial/fully returned invoices
  − SUM(customer_payments.amount)                          // positive payment ↓, negative refund ↑
```

Returns first offset outstanding AR (`remainingMicros` minus completed returns on that
invoice, clamped ≥ 0); any remainder is a real cash refund and has no balance effect.
Overpaid invoices net to zero (change returned at checkout). This keeps the invoice + return
+ payment lifecycles consistent with the double-entry books.

Statement `statementPage`/`startBalanceMicros`/`statementTotals` were widened to include
customer payments and full-returned invoices, with the same `(date, doc_type)` ordering.

### 2.4 Payment semantics — `customer_payment_service.dart` (NEW)
`customer_payments.amount_micros` is **credit-normal**:
- positive = money received from the customer (reduces balance; a debit from the drawer).
- negative = money returned to the customer (increases balance; a credit back to the drawer).
- `cashMicros + cardMicros == |amountMicros|`.
- `recordCustomerRefund` is guarded: a refund on no credit balance throws
  `InvalidOperationException` (no money is owed back).

### 2.5 POS — domain/data/presentation
- `pos_invoice.dart`: `PosInvoiceView` + `cashMicros/cardMicros/creditMicros/voidedBy/voidedAt`,
  `isReturnable` includes `partially_returned`, new `isVoidable`.
- `sales_repository.dart`: `voidInvoice` + split-carrying `checkout`.
- `pos_workspace_controller.dart`: computes the per-method split, new `voidInvoice`.
- `pos_workspace_page.dart`: "إلغاء الفاتورة" button when `isVoidable` and `Perm.salesVoid`.

### 2.6 Number policy — `lib/core/money/money.dart`
- Fixed the pre-existing `format()` negative bug (Euclidean `%` vs truncating `~/` produced
  e.g. `-10.25 → -10.75`). Digits now come from `scaled.abs()`.
- `formatArabicDigits()` now equals `format()` — **Latin digits 0–9 + ASCII separators**.
  The Arabic-Indic glyph set (٠-٩) is never emitted for display (Arabic-first UI + RTL,
  Latin numbers), per §23. Input-side Arabic-Indic parse tolerance in
  `inventory_excel_service.dart` is untouched (input, not display).

### 2.7 Schema v5 — drift regenerated
- `sales_invoices`: + `cashMicros`, `cardMicros`, `creditMicros`, `voidedBy`, `voidedAt`.
- New table `customer_payments` (+ `enum_value_converter`).
- `app_database.dart` v5 + migration `from < 5`; `acc_1200` inventory account seeded
  (`insertOrIgnore` in migration and seed).
- Tests updated: `migration_test`, `schema_audit_test`, `enum_contract_test`
  (incl. `journalReferenceTypeValues.toSql`), `backup_service_test`,
  `database_smoke_test`, `pos_domain_test`, `pos_workspace_page_test`.

---

## 3. Files changed

**New**
- `lib/domain/services/financial_posting_service.dart`
- `lib/domain/services/customer_payment_service.dart`
- `lib/shared/database/tables/customer_payments.dart`
- `test/financial_lifecycle_test.dart` (17 tests)
- `test/number_format_test.dart`
- `PHASE7.5-COMPLETION-REPORT.md` (this file)

**Modified**
- `lib/core/money/money.dart`
- `lib/data/daos/customer_dao.dart`
- `lib/domain/services/sale_service.dart`
- `lib/domain/services/return_service.dart`
- `lib/features/sales/domain/entities/pos_invoice.dart`
- `lib/features/sales/domain/repositories/sales_repository.dart`
- `lib/features/sales/data/sales_repository_impl.dart`
- `lib/features/sales/presentation/controllers/pos_workspace_controller.dart`
- `lib/features/sales/presentation/pages/pos_workspace_page.dart`
- `lib/shared/database/app_database.dart` (+ regenerated `.g.dart`)
- `lib/shared/database/tables/sales_invoices.dart`
- `lib/shared/database/seed_data.dart`
- `lib/shared/models/enums.dart`
- `lib/shared/models/enum_value_converter.dart`
- Tests: `migration_test`, `schema_audit_test`, `enum_contract_test`, `backup_service_test`,
  `database_smoke_test`, `money_test`, `pos_domain_test`, `pos_workspace_page_test`

---

## 4. Tests (final: **304** passing)

Coverage highlights of `financial_lifecycle_test.dart`:
- Cash / card / mixed sales: drawer rows, balanced journals, running account balances
  (revenue/cash/COGS/inventory in credit-normal sign), per-method splits, change handling.
- Split validation (`cash + card == paid`, never negative).
- Credit sale rules (customer + has_account + credit limit) and remaining > 0.
- Full / partial returns, refund from drawer, status advance to `fully_returned` /
  `partially_returned`, voided-invoice rejection.
- Customer payments reduce balance + drawer; refund guarded by credit balance;
  refund on credit balance draws back out of the drawer.
- Void: RBAC (`Perm.salesVoid`), reason required, reverses stock + drawer + journal +
  flags invoice, rejects partially/fully returned invoices.
- recordExpense / adjustCash workflows + RBAC.
- Atomic rollback (`_ExplodingFinancial` postSale failure rolls the whole sale back).

---

## 5. Known debt & documented limitations
- `adjustCash` journals against **Capital (acc_3000)** — a stand-in until a dedicated
  cash-over/short account exists in the Chart of Accounts.
- Credit-limit is enforced at posting time but there is no proactive limit UI warning.
- Return/cash-refund interactions are covered at the service+DAO level; no dedicated
  accounting UI surfaced yet.
- The number-policy change intentionally stops emitting Arabic-Indic display digits; the
  Excel parse tolerance remains for input.

---

## 6. Deferred (Phase 8+)
- **Credit sales in the POS UI** (engine supports credit; UI stays cash/card/mixed).
- Cash box dashboard, accounting UI, Trial Balance / Income Statement / Balance Sheet.
- Chart of Accounts UI.
- Purchase accounting / full purchases GL.
- Backup redesign.
- Dedicated cash over/short account.

---

## 7. PASS / FAIL / DEFERRED matrix

| Requirement | Status |
|---|---|
| Atomic financial posting (cash/card/mixed/credit) | **PASS** |
| Returns (full/partial) + refunds | **PASS** |
| Customer payments / refunds with guard | **PASS** |
| Invoice void (RBAC + full reversal) | **PASS** |
| Expenses + cash adjustments (RBAC) | **PASS** |
| Single authoritative customer balance | **PASS** |
| Statement ledger incl. payments + full-returned | **PASS** |
| Schema v5 + migration + inventory account seed | **PASS** |
| Arabic-first UI + Latin-digits number policy | **PASS** |
| `flutter analyze` clean (0 issues) | **PASS** |
| `flutter test` all pass (304) | **PASS** |
| Credit in POS UI | **DEFERRED** (Phase 8) |
| Cash boxes / accounting dashboard | **DEFERRED** |
| Trial Balance / IS / BS | **DEFERRED** |
| Chart of Accounts UI | **DEFERRED** |
| Purchase accounting / backups redesign | **DEFERRED** |
