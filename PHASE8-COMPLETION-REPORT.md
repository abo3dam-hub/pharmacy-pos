# Phase 8 — Cash Box Dashboard & POS Credit Sales — Completion Report

**Phase:** 8 — Cash Box (الصندوق) + Credit-Sale Acceptance in the POS
**Baseline commit:** `4cc274d7aa3615b49787e491ebfc20906d9ea923`
**Branch:** Feature work on the Phase 8 scope only.
**Final status:** **PASS**

---

## 1. Objective

Deliver the Cash Box (drawer) dashboard and workflow — open/close sessions,
manual deposits/withdrawals, authorized adjustments, live reconciliation and a
paged, DB-side-filtered ledger history — plus credit-sale acceptance inside the
POS workspace, built exclusively on the existing financial engine
(`FinancialPostingService`, `SaleService`, `CustomerPaymentService`) with no
schema changes, no database reset and no new accounting modules.

## 2. Scope & constraints honoured

- **Phase 8 only.** No Expenses module, no general reporting UI, no new
  accounting screens.
- **Zero schema changes**: DB stays at v6; `cashbox_transactions` was already
  present and untouched in shape.
- **Money stays in integer micro-units** (scale 4) end-to-end; no
  `double`/`float` anywhere in the new code.
- **Arabic-first / RTL UI**; **all numeric amounts and timestamps render in
  Latin digits** (0-9) via `Money.formatArabicDigits()` which never emits
  Arabic-Indic digit set.
- **Financial engine reused, never rewritten**: every cash movement goes through
  `FinancialPostingService.postCashboxRow` (or the engine's `adjustCash`), so
  running balances and journal/audit semantics are identical to automatic
  sale/return/payment entries.

## 3. Baseline verification

Before feature work: 326 tests passing, `flutter analyze` = 0 issues, schema v6,
clean working tree at `4cc274d`.

## 4. New domain layer (accounts feature)

- `features/accounts/domain/entities/cashbox_session.dart`
  - `CashboxStatus { notOpened, open, closed }`, `CashboxDirection`,
    `CashboxHistoryEntry`.
  - Immutable `CashboxSession` with per-type signed ledger sums, `netMoves`,
    `expectedClosingMicros`, gross `inflowsMicros`/`outflowsMicros`,
    `runningBalanceMicros`, `hasDifference`, and a `CashboxSession.notOpened()`
    factory for the “no session yet” snapshot.
- `features/accounts/domain/repositories/cashbox_repository.dart` — the
  contract consumed by the page/controller (no Drift types leak past here).

## 5. Data layer

`features/accounts/data/cashbox_dao.dart` (read side only):
- `currentSession()` derives the drawer session from the ledger newest-to-oldest
  (latest `open`; latest `close` after it; per-type `SUM` over the session
  window via a `GROUP BY` custom query).
- `history(...)` — paged (`LIMIT/OFFSET`), newest-first, optional DB-side type /
  window filters, operator names joined from `users`. Placeholders are bound in
  statement order (WHERE args precede LIMIT/OFFSET).

`features/accounts/data/cashbox_repository_impl.dart` — thin adapter over the
service + DAO.

## 6. Cash Box service (`domain/services/cashbox_service.dart`)

Owns every mutation and its RBAC + audit, inside one transaction each:

- **open** — `cashbox.operate`; float must be **> 0** (schema `CHECK
  amount_micros != 0` makes a zero float structurally impossible); rejected
  only when a session is already open (reopen after close = new shift is
  allowed); inserts the seed row directly (running = previous cash sum + float)
- **close** — `cashbox.operate`; requires an open session, `declaredClose ≥ 0`
  and a non-empty reason; writes a **declaration snapshot**
  (`amountMicros = remainingMicros = declaredClose`) that never joins
  `netMoves`; records `expected`/`difference` in the audit trail
- **deposit / withdraw** — positive amount + mandatory reason + open session;
  withdrawals are stored **negative** in the ledger
- **adjustCash** — reuses the engine’s `adjustCash` (± amounts) after the
  open-session guard; the engine owns its own transaction/RBAC/audit
- **RBAC** — every mutation calls
  `requireUserPermission(db, userId, Perm.cashboxOperate)` (admin/pharmacist
  only; cashier = `cashbox.view` → denied)
- **Audit** — immutable `audit_logs` row (`entityType = 'cashbox'`) per
  operation with operation-specific payloads

## 7. Controller

`features/accounts/application/cashbox_controller.dart` — `CashboxViewState`
(initial/loading/ready/error), `load`/`reload`/`setTypeFilter`/`loadMore` and
the four mutations; maps `AppException` → `Failure` for the page.

## 8. Presentation

- `pages/cashbox_page.dart` — action bar (Open vs Close/Deposit/Withdraw/Adjust
  driven by session state + `cashbox.operate`), session card (status, opened/
  closed by/at, running + expected balances, surplus/shortage banner), drawer
  movements card (inflows / outflows / net moves), paged ledger table with
  type filter, and a read-only hint for viewers.
- `widgets/cashbox_dialogs.dart` — open (float ± note), close (declared cash
  + mandatory reason, expected shown), deposit/withdraw (amount + reason),
  adjust (signed amount + reason) using `Money.parse` validation.

## 9. Routing & permissions

`app_router.dart` — `/accounts` redirect requires `Perm.cashboxView`;
`_sectionPage` maps the Accounts section to `CashboxPage`. `app_sections.dart`
already shipped the section entry (Phase 6/7); the POS section maps to
`PosWorkspacePage` as before.

## 10. DI wiring (`injection.dart` / `providers.dart`)

- `_registerPhase8(db)` added after `_registerPhase7(db)` — registers
  `CashboxService`, `CashboxRepository` (`CashboxRepositoryImpl`),
  `CashboxController`.
- Phase 7’s `PosCatalogDao` registration **restored** (was accidentally dropped
  in a prior refactor of the same file).
- Providers: `cashboxServiceProvider`, `cashboxRepositoryProvider`,
  `cashboxControllerProvider`.

## 11. POS credit-sale acceptance

- `PosPaymentMethod.credit` added; `PaymentCalculator` credit branch computes
  `paid = cash + card`, `remaining = total − paid`, requires a **positive
  remaining** (a fully-covered credit is invalid — it’s a cash sale then).
- `PosCustomer.creditLimitMicros` (0 = unlimited) + `availableCreditMicros`.
- Controller guard: credit checkout requires a selected customer; the payment
  split forwards the down-payment cash/card components and the remainder opens
  the A/R account (`PaymentMethod.credit` in the engine via `_engineMethod`).
- Sheet UI: 4th segment + down-payment fields + outstanding/balance/limit block
  and a “credit requires a customer” error; submit gating updated.

## 12. Localization

New `cashbox*` (32) and `posCredit*` (8) keys added to `app_ar.arb` and
`app_en.arb`; `flutter gen-l10n` regenerated the localizations classes.

## 13. Tests (28 new)

| File | Count | Covers |
| --- | --- | --- |
| `test/cashbox_service_test.dart` | 17 | open/close/deposit/withdraw/adjust lifecycle, zero/negative rejections, reopen-after-close, double-close, RBAC denial, audit trail |
| `test/cashbox_integration_test.dart` | 3 | full shift reconciles with Z-Report, paged/history filtering (post placeholder-order fix), shortage + reopen survive |
| `test/cashbox_page_test.dart` | 2 | admin opens a fresh drawer (widget flow), cashier sees read-only state |
| `test/pos_domain_test.dart` (+6) | 6 | payment-calculator credit branches; credit checkout requires customer; down-payment split forwarded |

**Result:** `flutter analyze` = 0 issues; `flutter test` = **354/354 passing**
baseline 326 → 354 (+28), zero regressions.

## 14. Acceptance matrix (24)

| # | Acceptance criterion | Status |
| --- | --- | --- |
| 1 | Open drawer with opening float creates an `open` ledger row and session | PASS |
| 2 | Opening while already open is rejected; reopen after close starts a new shift | PASS |
| 3 | Negative (and zero) opening floats are rejected | PASS |
| 4 | Close persists a declaration snapshot (amount = counted cash), never a net move | PASS |
| 5 | Close requires an open session | PASS |
| 6 | Close requires a non-empty reason | PASS |
| 7 | Reconciliation: `expected = opening + netMoves`, `difference = declared − expected` (shared with Z-Report) | PASS |
| 8 | Surplus/shortage surfaces in the session (`hasDifference`, signed `differenceMicros`) | PASS |
| 9 | Deposit adds to and withdraw subtracts from the drawer | PASS |
| 10 | Withdrawals stored negative; deposits positive | PASS |
| 11 | Deposit/withdraw require an open session, positive amount and a reason | PASS |
| 12 | Adjustments (±) route through the financial engine and require an open session | PASS |
| 13 | Every mutation requires `cashbox.operate`; cashier (view-only) is denied | PASS |
| 14 | Every mutation writes an immutable `audit_logs` entry (`entityType = 'cashbox'`) | PASS |
| 15 | Running balance continuity across open/close/reopen sessions | PASS |
| 16 | `open`/`close` rows excluded from `netMoves` (match Z-Report DAO) | PASS |
| 17 | Paged history (LIMIT/OFFSET), newest-first | PASS |
| 18 | History DB-side filtered by transaction type (and window) | PASS |
| 19 | Ledger sums agree with `ZReportDao.aggregate` for the same shift window | PASS |
| 20 | POS credit payment method computes remaining and blocks full coverage | PASS |
| 21 | Credit checkout requires a selected customer | PASS |
| 22 | Credit down payment split (cash/card) forwarded; remainder opens A/R via `PaymentMethod.credit` | PASS |
| 23 | Page renders Arabic/RTL with Latin digits; read-only hint for viewers | PASS |
| 24 | `flutter analyze` 0 issues; full suite green (354) | PASS |

## 15. Reconciliation contract verification

`test/cashbox_integration_test.dart` drives a full shift: open 500.00 → cash
sale +400.00 → credit sale (0 down, nothing to drawer) → deposit +150.00 →
expected 1050.00 → close @ 1050.00. `CashboxDao.currentSession()` and
`ZReportDao.aggregate()` agree on `opening`, `netMoves`, `expectedClosing`,
`declaredClose`, `lastRemaining` and `difference = 0` for the same window.

## 16. Money / digits / RTL compliance

All amounts parsed with `Money.parse` (micros, scale 4), printed with
`Money.format`/`formatArabicDigits` (Latin digits). Widget test asserts running,
expected, net-moves and ledger amounts render `500.00` with Western digits.

## 17. Database integrity

Schema v6 unchanged; no migration file added; no reseed. `customers` already
had `creditLimitMicros`; `cashbox_transactions` unchanged; the engine’s journal
and audit tables untouched. Existing `schema_audit_test`/`migration_test` still
pass.

## 18. Financial-integrity guardrails respected

- Cash movements occur only via the engine (running balance computed the same
  way) or the service’s snapshot inserts (open/close seeds + declarations).
- No double-posting: a credit sale with zero down contributes nothing to the
  drawer; the A/R opens in `customer_transactions` via the engine’s
  `recordSale`/`recordCustomerPayment` path.
- Adjustments reuse `FinancialPostingService.adjustCash` — one transaction, one
  journal entry, one audit trail.

## 19. Known limitations / documented debt (deferred, not blocking)

- **Customer-payment collection dialog in the POS is not built.** The account
  settlement workflows (`CustomerPaymentService`, the Z-Report
  `customer_paid` bucket, statements) exist and are reconciled by tests, but
  there is no `nextPaymentNumber` UI to collect a payment from the cashier
  screen in this phase. Manual deposits/receipts are covered by the drawer
  deposit action; collections remain bookable at the service layer only.
- Drawer **import/export, banking/transfer screens and per-user shift cash
  targets** were out of scope and remain Phase 9 topics.

## 20. Phase 9 handoff

Natural next phases can build on the untouched engine + this dashboard:
1. **Customer-payment UI** — the collect-payment dialog + `nextPaymentNumber`
   generator (works against the existing `recordCustomerPayment`).
2. **Expenses screen** — `CashboxTransactionType.expense` already sums into
   the drawer and Z-Report; a CRUD UI + category master is the only gap.
3. **General reporting** — revenue/expense P&L over `cashbox_transactions`
   windowed sums and the journal.

## 21. Final status

**PASS** — Phase 8 implemented, wired, localized, analyzed (0 issues) and fully
tested (354/354). Committed and pushed on the feature branch; Phase 9/10/11 are
explicitly out of scope and were not started.