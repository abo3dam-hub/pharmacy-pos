# PHASE 10.1 — FINANCIAL INTEGRITY HARDENING
## Controlled Enhancement / Pre-Phase-11 Gate

**Repository:** `abo3dam-hub/pharmacy-pos`  
**Baseline:** Phase 10 commit `5452b26`  
**Baseline report:** `PHASE10-COMPLETION-REPORT.md`  
**Target report:** `PHASE10.1-FINANCIAL-INTEGRITY-HARDENING-REPORT.md`

---

## 1. ROLE

You are the senior Flutter/Dart software architect and accounting-system engineer responsible for hardening the existing Pharmacy POS financial subsystem.

This is **NOT a new roadmap phase**.

This is a controlled corrective enhancement after Phase 10 and before Phase 11.

Your job is to inspect the existing implementation, prove the current behavior, fix only the integrity issues defined below, preserve all completed work, and leave the repository ready for the Phase 11 Scope/Handoff Audit.

---

# 2. ABSOLUTE RULES

1. **Do not invent a new roadmap.**
2. **Do not start Phase 11.**
3. **Do not implement Trial Balance, Income Statement, Balance Sheet, general Reports, or other Phase 11 UI.**
4. **Do not rebuild existing financial functionality.**
5. `FinancialPostingService` remains the single authoritative financial posting engine.
6. Do not introduce a second accounting/posting engine.
7. Do not duplicate existing journal postings.
8. Preserve existing Phase 10 functionality unless a change is required by the integrity fixes below.
9. Follow the project's architecture and existing feature structure.
10. Domain business rules must remain outside presentation.
11. Money remains integer smallest-unit values. Never use floating point for financial values.
12. Percentages remain basis points where applicable.
13. Arabic remains the primary professional UI language, RTL by default, English secondary.
14. All displayed numbers MUST use Western/Latin digits:
    `0 1 2 3 4 5 6 7 8 9`
15. Database migrations are forward-only and must preserve existing user data.
16. Never solve a migration problem by deleting/resetting the database.
17. Every financial mutation must remain transactional.
18. Every sensitive mutation must preserve RBAC and audit requirements.
19. Do not silently change business meaning. If an ambiguity is discovered, STOP and document it instead of guessing.

---

# 3. MANDATORY PRE-IMPLEMENTATION AUDIT

Before changing code, inspect:

- `PROJECT-ARCHITECTURE-PLAN.md`
- `PHASE10-COMPLETION-REPORT.md`
- `PHASE9-COMPLETION-REPORT.md`
- Phase 8 completion report
- Phase 7.5 completion report
- relevant Phase 6/7 gap-closure report
- current database schema
- current `FinancialPostingService`
- `CashboxService`
- `AccountingPeriodService`
- journal tables/DAO
- customer payment implementation
- purchase accounting implementation
- account seed data
- accounting permissions
- existing financial lifecycle tests
- migration/backup tests

Create a written internal classification:

| Item | Status |
|---|---|
| Financial Posting Service | implemented |
| Journal immutability | implemented |
| Customer payment | implemented |
| Customer refund | inspect/harden |
| Double-posting protection | inspect/harden |
| Period close | implemented but verify enforcement |
| Cashbox ↔ GL | implemented but verify semantics |
| Purchase accounting | implemented |
| Chart of Accounts | implemented |
| Phase 11 reports | later phase — DO NOT IMPLEMENT |

Do not modify scope based on assumptions.

---

# 4. HARDENING ITEM A — CUSTOMER PAYMENT / REFUND POSTING

## Objective

Ensure customer payments and customer refunds can both be posted correctly without being falsely rejected by duplicate-reference protection.

Inspect the current `refType + refId` duplicate-posting mechanism.

### Requirements

A normal customer payment must produce exactly one original financial event.

A refund/reversal of a customer payment must be represented as a distinct financial event while retaining an explicit relationship to the original payment.

Do NOT disable duplicate protection.

Do NOT simply remove the duplicate check.

Preferred design:

- original payment reference remains unique
- refund gets a distinct reference/event type
- refund links back to the original payment
- reversal semantics remain explicit

The implementation must be idempotent.

### Mandatory tests

1. Customer payment posts once.
2. Repeating the same payment operation is rejected/idempotently ignored according to existing project convention.
3. Customer refund posts successfully against an existing payment.
4. Same refund cannot be posted twice.
5. Refund cannot exceed the refundable amount according to existing business rules.
6. Original payment remains traceable from refund.
7. Journal debit/credit totals remain balanced.
8. Cashbox and GL remain synchronized where cash is involved.
9. Audit records exist for payment and refund.

---

# 5. HARDENING ITEM B — PERIOD-CLOSE ENFORCEMENT

## Objective

Closing an accounting period must actually protect the ledger.

The current `AccountingPeriodService` can close periods, but the financial posting path must enforce the closed-period rule centrally.

### Requirements

`FinancialPostingService` must not post an original journal entry into a closed accounting period.

The enforcement must be centralized in the financial posting layer, not merely in UI.

For every posting:

1. Resolve the accounting period using the entry date.
2. If the matching period is closed → reject the posting.
3. If no applicable period exists → follow the existing project policy. Do NOT invent automatic period creation.
4. Preserve transaction atomicity.

### Reversal policy

A reversal of an entry belonging to a closed period must NOT modify the closed historical entry.

The reversal must be recorded as a separate reversal event in an allowed open period, with an explicit link to the original entry.

If the current architecture cannot support this safely, STOP and report the blocker rather than implementing a shortcut.

### Mandatory tests

- posting inside open period → PASS
- posting inside closed period → rejected
- sale posting inside closed period → rejected
- purchase posting inside closed period → rejected
- expense posting inside closed period → rejected
- customer payment inside closed period → rejected
- reversal of closed-period entry follows explicit reversal policy
- no partial journal/cashbox/business transaction remains after rejection
- audit behavior is correct

---

# 6. HARDENING ITEM C — CASHBOX DEPOSIT / WITHDRAWAL SEMANTICS

This item requires an explicit business-rule decision based on the existing application meaning.

Current implementation uses Cash Over/Short (`1099`) as the offset for manual cashbox deposits and withdrawals.

Before changing anything, inspect:

- Phase 8 requirements
- Phase 10 completion report
- Cashbox UI labels
- domain/service semantics
- existing tests
- chart of accounts
- whether bank/safe accounts exist and are intended for transfers

### Rule

If "deposit/withdrawal" means **cash entering/leaving the physical drawer without representing a transfer to/from a known bank/safe account**, Cash Over/Short may remain appropriate.

If it means **actual transfer between Cash Drawer and Bank/Safe**, then the correct accounting must be a transfer between the corresponding asset accounts, e.g.:

Deposit to bank:
- Dr Bank
- Cr Cash

Withdrawal from bank to drawer:
- Dr Cash
- Cr Bank

Do not invent a new account or UI workflow unless existing architecture clearly requires it.

### Required outcome

Document the verified business meaning in the completion report.

If semantics are already correct:
- preserve implementation
- add/strengthen tests

If semantics are incorrect:
- fix the accounting classification
- preserve the existing user workflow
- add regression tests

Do not change terminology casually.

---

# 7. HARDENING ITEM D — PURCHASE RETURNS ACCOUNT CLASSIFICATION

Inspect account `4002` (`Purchase Returns`) and determine whether:

- it is actually used by the current posting engine, or
- it is unused/dead configuration.

Current purchase-return posting appears to reverse inventory directly:

- Dr AP/Cash/Bank
- Cr Inventory

Do not introduce unnecessary postings.

If `4002` is unused and its current account type conflicts with the actual accounting model, make the smallest safe correction or document why it must remain.

Do not redesign purchase accounting.

Mandatory regression tests must prove purchase and purchase-return accounting remains balanced and non-duplicated.

---

# 8. HARDENING ITEM E — DOUBLE-POSTING / IDEMPOTENCY AUDIT

Inspect all current uses of:

- `refType`
- `refId`
- `isReversal`
- `reversalOfEntryId`

Specifically inspect generated IDs based on timestamps such as:

- `cash-adjust-$now`
- cashbox movement references
- payment/refund references
- expense references
- purchase references
- sale references

The objective is not merely "unique enough".

Verify that rapid repeated operations, retries, and same-millisecond calls cannot accidentally create duplicate financial events.

### Requirements

For every financial event:

- reference identity must be deterministic or safely unique
- retry behavior must be defined
- duplicate original posting must be prevented
- reversal must remain distinct from original
- database constraints should be used where appropriate

Do not weaken the existing duplicate protection.

Add tests for rapid repeated calls where practical.

---

# 9. ATOMICITY REQUIREMENT

Every corrected workflow must remain atomic.

Examples:

### Customer payment
Payment record + journal + customer balance + cashbox + audit

### Customer refund
Refund record + reversal journal + balance + cashbox + audit

### Expense
Expense + journal + cashbox + audit

### Purchase
Purchase + inventory + journal + cash/bank/AP + audit

### Cashbox manual movement
Cashbox ledger + journal + audit

### Closed period rejection

If posting is rejected because the period is closed:

**nothing financial may be partially persisted.**

---

# 10. ACCOUNTING INTEGRITY RULES

All journal entries must remain balanced:

`SUM(debits) = SUM(credits)`

No negative journal line values.

No mutation of an existing posted journal entry.

Corrections use reversal entries.

Original entries remain immutable.

Every reversal must identify the original entry.

No duplicate original event may exist for the same business event.

---

# 11. RBAC AND AUDIT

Preserve all existing permissions.

Do not bypass permission checks while moving logic.

Verify permissions for:

- customer payments/refunds
- accounting posting where applicable
- cashbox operations
- period closing
- purchase returns
- expenses

Sensitive operations must retain audit records with meaningful context/reason.

Do not introduce a permission escalation.

---

# 12. DATABASE / MIGRATION POLICY

First determine whether schema changes are actually required.

Prefer **no schema migration** if existing schema can safely support the hardening.

If a migration is required:

- increment schema version exactly once
- write forward-only migration
- preserve all existing data
- update migration tests
- update backup/restore tests
- test upgrade from earlier supported schema versions
- test fresh database creation

Never drop user data.

---

# 13. TESTING REQUIREMENTS

Before declaring completion:

### Mandatory commands

```bash
flutter analyze
flutter test
```

Also run the most relevant focused suites for:

- financial lifecycle
- customer payments/refunds
- journal posting
- cashbox
- accounting periods
- purchases
- expenses
- migrations
- backup/restore

### Required regression target

Existing tests must remain green.

No reduction in test coverage to hide failures.

If tests fail, fix the implementation rather than weakening assertions.

---

# 14. COMPLETION REPORT

Create:

`PHASE10.1-FINANCIAL-INTEGRITY-HARDENING-REPORT.md`

The report MUST contain:

1. Baseline commit
2. Final commit
3. Scope/Handoff Audit
4. Findings before implementation
5. Exact fixes
6. Customer payment/refund behavior
7. Period-close enforcement
8. Cashbox deposit/withdrawal semantic decision
9. Purchase-return account decision
10. Double-posting/idempotency findings
11. Atomicity verification
12. RBAC/audit verification
13. Database migration details, or explicitly state no migration was required
14. Test results
15. `flutter analyze` result
16. Acceptance matrix
17. Remaining technical debt
18. Explicit statement that Phase 11 was NOT implemented
19. Phase 11 handoff notes
20. Final PASS/FAIL decision

---

# 15. ACCEPTANCE GATES

Phase 10.1 is PASS only if all are true:

- [ ] No second financial posting engine exists.
- [ ] Existing Phase 10 functionality remains intact.
- [ ] Customer payment/refund lifecycle is correct and idempotent.
- [ ] Duplicate original postings are prevented.
- [ ] Refund events are distinguishable from original payments.
- [ ] Closed accounting periods actually block original postings.
- [ ] Closed-period reversal behavior is explicit and safe.
- [ ] Cashbox deposit/withdrawal accounting semantics are verified.
- [ ] Purchase accounting remains correct.
- [ ] Purchase returns remain correct.
- [ ] No double posting.
- [ ] No partial transactions.
- [ ] Journal entries remain balanced.
- [ ] Posted entries remain immutable.
- [ ] RBAC remains enforced.
- [ ] Audit remains complete.
- [ ] Latin digits remain enforced in UI.
- [ ] Arabic RTL / English LTR remains intact.
- [ ] Existing migrations remain valid.
- [ ] Backup/restore remains valid.
- [ ] All tests pass.
- [ ] `flutter analyze` has zero issues.
- [ ] Completion report exists.
- [ ] Phase 11 has NOT been implemented.

---

# 16. STOP CONDITIONS

STOP implementation and report the blocker if:

- a business meaning cannot be determined from existing architecture/reports/tests
- a fix would require changing the official roadmap
- a fix would require redesigning completed phases
- a closed-period reversal cannot be implemented without unsafe historical mutation
- a migration risks existing user data
- a proposed fix would create a second posting engine
- an existing financial event's intended accounting treatment is genuinely ambiguous

Do not guess.

---

# 17. FINAL HANDOFF

When all acceptance gates pass:

1. Commit the implementation.
2. Create `PHASE10.1-FINANCIAL-INTEGRITY-HARDENING-REPORT.md`.
3. Do not begin Phase 11.
4. State the exact final commit hash.
5. State test count.
6. State analyzer result.
7. State schema version.
8. State any remaining technical debt.
9. Provide explicit Phase 11 handoff notes.

The repository must be left in a clean, production-ready state for the next mandatory Scope/Handoff Audit.

---

## FINAL PRINCIPLE

**Harden, do not redesign.**

Phase 10 is already implemented.

This task exists only to close verified financial-integrity gaps before Phase 11.

Preserve what works.
Fix what is proven unsafe.
Do not invent scope.
Do not double-post.
Do not mutate history.
Do not bypass accounting controls.
Do not start Phase 11.
