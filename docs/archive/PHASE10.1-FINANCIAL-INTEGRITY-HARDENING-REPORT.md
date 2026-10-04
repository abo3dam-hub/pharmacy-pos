# PHASE 10.1 — Financial Integrity Hardening Report

## Summary

Phase 10.1 hardened the single financial posting engine (`FinancialPostingService`)
with explicit reversal semantics for customer refunds (Item A), a **central**
closed-accounting-period enforcement applied to every posting path (Item B),
RBAC + audit on accounting-period administration, an atomic double-posting guard
that runs **before** any side effect (Item E), and documented + regression-tested
semantics for cash over/short adjustments (Item C) and the unused `4002`
purchase-returns liability account (Item D).

- Analyzer: `flutter analyze` → **No issues found**.
- Tests: **417 passed** (baseline 390 + 27 new/updated in this phase).
- Schema version: **8 (unchanged** — no migration needed; drift unique-index
  alternative rejected, see Debt).
- Baseline commit (pre-work): `b34b166`; this phase commits on top of it.

## Audit classification (what the audit found)

| Item | Finding | Decision | Where |
| --- | --- | --- | --- |
| A | `postCustomerRefund` was an **undo-style** journal that nulled `reversalOfEntryId` and reversed `isReversal`, breaking traceability and the provenance guard | **FIX** — refunds are distinct events flagged `isReversal: true`, keep their own unique reference, and link via `reversalOfEntryId` to the most recent original payment journal | `postCustomerRefund`, `CustomerPaymentService._record` |
| B | Closed-period enforcement existed only for manual journals; sales/purchases/expenses/payments/refunds could post into a closed period | **FIX** — date-window check moved into `postJournalEntry`, so every posting path is protected centrally and atomically | `_enforcePeriodOpen` (new) |
| B+R | `AccountingPeriodService` had **no permission checks** and wrote no audit trail (RBAC gap) | **FIX** — `createPeriod`/`closePeriod` now require `accounting.post` and write audit rows | `accounting_period_service.dart` |
| C | Deposit/withdraw journal posts to Cash Over/Short `1099` — looked like a possible missing "bank/safe" account | **DOCUMENT AS CORRECT** — Phase 8 report scopes banking/transfer screens *out*; UI labels إيداع نقدي/سحب نقدي are drawer movements; bank is used only for card transactions; no safe account exists. Tests pin the semantics | `test/double_posting_hardening_test.dart` |
| D | `purchaseReturns` `4002` is seeded as a liability but never used; `postPurchaseReturn` reverses Inventory directly (Dr AP/Cash/Bank, Cr Inventory) | **DOCUMENT RETENTION** — dead configuration for existing installs; no migration to avoid data drift risk. Regression test proves no journal touches `4002` | `test/double_posting_hardening_test.dart` |
| E | Guard blocked only at journal-insert time → a rejected duplicate **leaked drawer rows** (e.g. `postCustomerPayment` wrote the cashbox row before the guard threw) | **FIX** — pre-check extracted to `_assertNoDuplicate` and run at the top of *every* public posting entry-point with pre-journal side effects | `financial_posting_service.dart` |
| E | `adjustCash` used `'cash-adjust-$now'` refId — back-to-back adjustments in the same millisecond collided | **FIX** — `'cash-adjust-${newId('adj')}'` | `adjustCash` |

## Changes

### `lib/domain/services/financial_posting_service.dart`
- `postCustomerRefund` posts `isReversal: true` with optional `reversalOfEntryId`,
  keeping its own `paymentId` reference; the customer-payment path resolves the
  most recent **non-reversal** payment journal and passes it onwards.
- `_enforcePeriodOpen` central closed-period rule:
  - day-granular window `entryDate >= startDate && entryDate < endDate + 1 day`
    (matches how the UI stores period bounds);
  - multiple matching periods → latest `startDate` wins; none match → project
    policy (post freely, no auto-create);
  - reversals are new entries dated "now", so their own (open) period governs;
    back-dating a reversal into a closed period is rejected before any insert.
- `_assertNoDuplicate` extracted from the inline guard; `postJournalEntry` calls it
  (defense in depth) AND `postSale`, `postReturn`, `postCustomerPayment`,
  `postCustomerRefund`, `postVoidReversal` call it up-front, before any drawer row
  is written, so a rejected event never leaks side effects. Manual /
  opening-balance journals stay exempt; the legitimate original+reversal pair is
  still allowed while a "*second* original" or "*second* reversal" for the same
  reference is refused.
- `adjustCash` reference changed to a per-invocation UUID.

### `lib/domain/services/customer_payment_service.dart`
- Refund branch (`_record`, `isRefund == true`) resolves the most recent original
  `customerPayment` (`amountMicros > 0`, newest first) and passes its journal
  entry id as `reversalOfEntryId`.

### `lib/domain/services/accounting_period_service.dart`
- Constructor now takes optional `PermissionService` / `AuditService`
  (`AccountingPeriodService()` registered in DI).
- `createPeriod` requires `userId`, validates `accounting.post` and `end > start`,
  trims the period name, and audits `create`.
- `closePeriod` requires `accounting.post` and audits `update` with before/after.

### UI / DI
- `injection.dart`, `accounting_controller.dart` (create passes `userId`),
  `periods_page.dart` (create dialog passes `authControllerProvider.user?.id`).

### Tests added (27)
- `test/customer_payment_integrity_test.dart` (9) — Item A + payment-side Item B:
  single original event, guard rejects repeated reference **atomically** (drawer
  unchanged), refund as linked reversal, duplicate-refund refused, refund credit
  limit, traceability, and closed-period atomic rejection for payment and refund.
- `test/accounting_period_enforcement_test.dart` (9) — Item B + RBAC/audit:
  open-period success (date admitted exactly), sale/purchase/expense closed-period
  atomic rejection, reversal of a closed-period entry lands in the open period
  linked, back-dated reversal into a closed period rejected, `accounting.post`
  required for create/close, create+close audited.
- `test/double_posting_hardening_test.dart` (6) — Items C/D/E: duplicate original
  refused, original+reversal allowed while duplicate reversal refused, manual/
  opening-balance exempt, rapid repeated `adjustCash` unique references, deposit/
  withdrawal = drawer vs Cash Over/Short with bank untouched and 2 distinct
  cashbox journals, purchase + purchase-return balanced, non-duplicated and never
  touching `4002`.
- Updated `test/accounting_period_test.dart` for the new constructor/create
  signature.

## Verification

- `flutter analyze` — clean.
- `flutter test` — **417 passed** (full suite), no failures.

## Remaining tech debt

- **No DB-level partial unique index** on `(ref_type, ref_id, is_reversal)`: a
  migration could fail on existing duplicates, so enforcement stays in the service
  layer (`_assertNoDuplicate`). Deferred pending a migration strategy.
- **`4002` Purchase Returns (liability)** remains seeded/dead on existing installs
  (no migration, no engine usage). Revisit when purchase-return GL accounts are
  formalised (Phase 11+ reporting).
- **No unique constraint on `customer_payments.payment_number`/`sales_invoices.invoice_number`**:
  uniqueness currently enforced by business checks + the posting guard, not the schema.
- **Banking/transfer screens** (`bank` is currently only used for card proceeds)
  remain out of scope per the Phase 8 report decision.