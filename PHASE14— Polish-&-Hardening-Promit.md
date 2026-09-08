PHASE 14 — HARDENING GATE + SCOPE/HANDOFF AUDIT + CONTROLLED ENHANCEMENTS + IMPLEMENTATION

Role

You are an Expert Flutter Desktop Architect, Senior Software Engineer, Financial Systems Engineer, QA Engineer, and Production Hardening Specialist.

You are continuing an existing Pharmacy Management & POS system.

Repository:

"https://github.com/abo3dam-hub/pharmacy-pos"

Current commit:

"c5f0afb"

Current phase:

Phase 13 completed with 486 passing tests and 0 analyzer issues, but Phase 13 has NOT yet received final post-completion approval.

Your task is to:

1. Perform the mandatory Phase 13 Hardening Gate.
2. Fix any confirmed Phase 13 blockers/minor defects within controlled scope.
3. Re-run all required validation.
4. Only after Phase 13 passes, perform the Phase 14 Scope & Handoff Audit.
5. Classify every candidate item.
6. Implement only Phase 14 scope and explicitly approved Controlled Enhancements.
7. Do NOT invent roadmap items.
8. Do NOT redesign completed financial/accounting systems.
9. Produce the final Phase 14 completion report.

---

0. ABSOLUTE RULES

These rules are mandatory.

Rule 1 — Architecture is authoritative

Read:

"PROJECT-ARCHITECTURE-PLAN.md"

It is the single source of truth for architecture, roadmap, boundaries, and design constraints.

Do not override it based on assumptions.

---

Rule 2 — Read the history before modifying code

Before implementation, inspect:

- "PROJECT-ARCHITECTURE-PLAN.md"
- "PHASE12-COMPLETION-REPORT.md"
- "PHASE13-COMPLETION-REPORT.md"
- current commit "c5f0afb"
- relevant source code
- relevant tests

Understand the existing architecture before changing anything.

---

Rule 3 — No Phase 14 implementation before the Phase 13 gate passes

The Phase 13 hardening gate is a mandatory prerequisite.

If a Phase 13 blocker remains:

STOP.

Do not start Phase 14 feature implementation.

---

Rule 4 — No second financial posting engine

There must remain exactly one authoritative financial posting engine:

"FinancialPostingService"

Do not create another journal/posting/accounting engine.

All financial operations must continue using the existing financial architecture.

---

Rule 5 — No duplicate implementation

Do not rebuild existing:

- POS
- inventory
- purchasing
- customer balances
- prescriptions
- cashbox
- expenses
- accounting
- reports
- audit
- backup
- restore
- export

unless a specific controlled hardening fix requires modification.

Reuse existing services, repositories, DAOs, use cases, and infrastructure.

---

Rule 6 — No roadmap invention

Do not add:

- banking system
- multi-branch system
- cloud synchronization
- online accounts
- payment gateway
- CRM
- payroll
- new accounting architecture
- new report families
- unrelated UI redesign

unless explicitly required by the official Phase 14 scope.

---

PART A — PHASE 13 POST-COMPLETION HARDENING GATE

A1 — Audit the actual implementation

Do NOT trust the completion report alone.

Inspect the actual implementation of at least:

lib/domain/services/backup_archive_service.dart
lib/domain/services/restore_service.dart
lib/domain/services/data_export_service.dart
lib/domain/services/app_paths.dart

lib/features/backup/domain/usecases/backup_use_cases.dart
lib/features/backup/application/data_management_controller.dart
lib/features/backup/presentation/pages/data_management_page.dart

lib/shared/database/app_database.dart
lib/shared/database/seed_data.dart

lib/core/constants/permission_codes.dart
lib/core/di/injection.dart
lib/core/di/providers.dart
lib/core/router/app_router.dart

test/backup_archive_test.dart
test/restore_service_test.dart
test/data_export_test.dart
test/backup_rbac_test.dart

Also inspect any additional files directly involved in database lifecycle and application shutdown.

---

A2 — CRITICAL RESTORE LIFECYCLE AUDIT

This is the known Phase 13 blocker.

Verify the actual Windows restore lifecycle.

The current design requires:

live DB open
      ↓
close live DB connection
      ↓
delete stale WAL/SHM
      ↓
replace database
      ↓
replace managed receipt files
      ↓
open fresh DB connection
      ↓
integrity check
      ↓
return success
      ↓
restart application

The existing code exposes an "onBeforeReplace" mechanism.

Verify whether the actual production UI/controller path really closes the live database before replacement.

If it does not:

FIX IT.

The fix must be architecturally clean.

Preferred approach:

- make the restore workflow own the lifecycle responsibility, OR
- inject a reliable application database shutdown callback, OR
- use an explicit database lifecycle abstraction.

Do NOT simply hide the problem with:

try/catch

Do NOT assume Windows will allow replacement of an open SQLite file.

Do NOT create a second database as a workaround.

Do NOT silently continue if closing the live connection fails.

If the database cannot be closed safely:

ABORT RESTORE
DO NOT DELETE LIVE DATABASE
DO NOT DELETE RECEIPTS
DO NOT ACTIVATE STAGED DATA

The emergency backup must still remain available.

---

A3 — WAL / SHM SAFETY

Verify:

database.sqlite
database.sqlite-wal
database.sqlite-shm

handling.

Before activation:

- database connection must be closed
- stale WAL/SHM must be handled safely
- the restored DB must be opened cleanly
- no stale WAL/SHM from the previous database may corrupt or override restored data

Test this explicitly.

---

A4 — ROLLBACK LIFECYCLE

Verify rollback uses the same safe lifecycle.

Required:

activation fails
      ↓
close any newly opened connection
      ↓
restore emergency DB
      ↓
restore emergency receipts
      ↓
handle WAL/SHM
      ↓
reopen emergency DB
      ↓
PRAGMA integrity_check
      ↓
verify required tables
      ↓
verify core financial data

If rollback cannot safely complete:

- preserve emergency archive
- expose its exact path
- fail loudly
- never claim success

---

A5 — RECEIPT PATH RECONCILIATION AUDIT

Audit the current basename-based receipt reconciliation.

Determine whether the current filesystem layout guarantees unique receipt basenames.

If the current design is flat and uniqueness is guaranteed:

- document/retain it
- add a regression test if missing

If a real collision/path ambiguity exists:

- implement the smallest safe fix
- preserve backward compatibility
- do not redesign receipt storage unnecessarily

Do NOT change this merely for theoretical elegance.

---

A6 — RESTORE FINANCIAL INTEGRITY

Restore must never:

- recalculate sales
- recreate journals
- repost expenses
- recreate customer balances
- recreate cashbox movements
- alter historical financial values

Restored values must come from the archive itself.

Add/verify tests covering:

sales totals
returns
COGS
inventory
cash
customer balances
journal totals
cashbox totals
expenses

before and after restore.

---

A7 — BACKUP INTEGRITY

Verify:

- "VACUUM INTO"
- manifest
- SHA-256
- archive read-back verification
- receipts
- failure cleanup
- no partial successful archive

---

A8 — ARCHIVE SECURITY

Verify rejection of:

- malformed ZIP
- corrupted ZIP
- modified manifest
- checksum mismatch
- missing database
- missing required file
- unexpected archive entries
- "../"
- absolute paths
- future schema
- unsupported format

No archive may escape its staging directory.

---

A9 — EXPORT SECURITY AND CORRECTNESS

Verify that export:

- is read-only
- does not insert audit rows
- does not mutate business tables
- uses DB-side pagination
- produces valid CSV
- preserves Arabic UTF-8
- uses BOM
- quotes commas/quotes/newlines correctly
- handles NULL
- handles blobs safely
- produces deterministic output for the same DB state

Also inspect whether exporting all user tables unintentionally exposes authentication/security-sensitive data.

Do NOT automatically remove tables from export.

If sensitive data is included intentionally, document the security implication.

If credentials/secrets are unintentionally exportable, classify and fix the issue using the smallest safe approach.

---

A10 — RBAC / AUDIT

Verify:

backup
backup.restore
export.data

permissions.

Verify:

- admin seeding
- idempotent seeding
- unauthorized role rejection
- null role rejection
- partial permission roles
- UI permission visibility
- audit behavior

---

A11 — PHASE 13 HARDENING TEST GATE

After any required fix:

Run:

flutter analyze
flutter test

Also run the relevant migration/restore/integration tests.

Minimum required:

- all existing tests
- all Phase 13 tests
- new regression tests

No analyzer issues.

No test regressions.

No hidden skipped tests.

---

A12 — PHASE 13 STOP CONDITION

If any of the following remains:

- unsafe live DB replacement
- unsafe rollback
- possible live-data destruction before validated emergency backup
- corrupt restore can activate
- financial corruption
- archive security bypass
- export mutates DB

STOP.

Do not start Phase 14.

---

PART B — PHASE 14 SCOPE & HANDOFF AUDIT

Only after Phase 13 passes.

Perform a formal audit using:

PROJECT-ARCHITECTURE-PLAN.md
PHASE12-COMPLETION-REPORT.md
PHASE13-COMPLETION-REPORT.md
all known deferred items
all known technical debt
all handoff notes
actual current source code

Create an internal classification table:

Item| Source| Classification| Action
Existing Phase 14 requirement| Architecture Plan| Phase 14| Implement
Required handoff from Phase 13| Prior phase| Phase 14| Implement
Small safety/integrity fix| Controlled Enhancement| Implement if justified| 
Future roadmap item| Later Phase| Defer| 
Out-of-roadmap| Not approved| Reject| 
Already implemented| Existing code| Reuse| 
Duplicate implementation| Existing architecture| Do not implement| 

Do not silently move later-phase work into Phase 14.

---

PART C — CONTROLLED ENHANCEMENT POLICY

Controlled Enhancements are allowed, but only under these rules.

An enhancement is allowed only if it is:

1. directly related to Phase 14,
2. required for production hardening,
3. a correctness/security/integrity improvement,
4. necessary to safely integrate existing functionality,
5. small and bounded,
6. does not create a new subsystem,
7. does not change the official roadmap,
8. does not duplicate existing architecture.

For every Controlled Enhancement record:

Enhancement:
Reason:
Why it belongs in Phase 14:
Affected files:
Risk:
Tests:

Do not use Controlled Enhancement as permission to invent features.

---

PART D — PHASE 14 IMPLEMENTATION

After the Scope/Handoff Audit, implement the official Phase 14 scope defined by:

"PROJECT-ARCHITECTURE-PLAN.md"

The implementation must preserve:

Architecture

Presentation
    ↓
Domain
    ↓
Data
    ↓
Database

Domain remains pure Dart.

No Flutter/UI dependency inside Domain.

---

FINANCIAL RULES

All money:

integer smallest currency units

Never:

double
float

Percentages:

basis points

All financial posting continues through:

FinancialPostingService

No duplicate posting.

No direct journal manipulation from UI.

---

DATABASE RULES

SQLite remains the single Source of Truth.

No:

- second database
- in-memory business database
- cloud database
- duplicated financial store

Use forward-only migrations.

Never delete the production database to solve a migration problem.

---

UI RULES

Arabic is the primary professional UI language.

RTL by default.

English remains supported.

All displayed numbers MUST use Western/Latin digits:

0 1 2 3 4 5 6 7 8 9

This applies to:

- prices
- quantities
- invoice numbers
- barcodes
- customer IDs
- prescription IDs
- dates
- reports
- pagination
- account numbers
- balances
- statistics

Do not introduce Arabic-Indic digits.

---

PERFORMANCE

Preserve:

- DB-side filtering
- DB-side pagination
- indexed barcode lookup
- no whole-database loading
- no unnecessary rebuilds
- no N+1 queries where avoidable

---

SECURITY

Preserve:

- RBAC in domain/use-case layer
- UI permission guards
- audit sensitive operations
- immutable financial history
- controlled destructive actions
- reason-required sensitive operations

---

TESTING REQUIREMENTS

For every new feature/fix:

Unit tests

Test:

- business rules
- validation
- permissions
- edge cases

Integration tests

Test:

DB
→ repository
→ service
→ use case
→ persistence

Regression tests

Every bug fixed in this phase must receive a regression test.

UI tests

Only where meaningful and stable.

---

MANDATORY FULL VALIDATION

Before declaring Phase 14 complete:

flutter analyze
flutter test

Verify:

0 analyzer issues
0 failing tests
0 unexpected regressions

Verify database migrations from earliest supported schema through current schema.

Verify backup/restore round-trip.

Verify financial invariants.

Verify RBAC.

Verify Arabic/RTL.

Verify Latin-digit formatting.

Verify application startup.

---

FINANCIAL ACCEPTANCE GATES

Before completion, verify:

Assets = Liabilities + Equity

Trial Balance:

Total Debits = Total Credits

Cashbox ↔ GL reconciliation remains correct.

Customer balances remain correct.

Supplier balances remain correct.

Sales/returns/expenses do not create duplicate postings.

Void/reversal operations remain exactly-once.

Closed-period rules remain enforced.

---

GIT DISCIPLINE

Do not modify unrelated files.

Do not rewrite completed phases unnecessarily.

Use clear conventional commit messages.

The final commit must contain:

- Phase 13 hardening fixes, if required
- Phase 14 implementation
- Controlled Enhancements that were explicitly justified
- tests
- localization
- report

---

FINAL REPORT

Create:

"PHASE14-COMPLETION-REPORT.md"

The report MUST contain:

1. Executive Summary

2. Phase 13 Hardening Gate

Include:

- findings
- blocker(s)
- fixes
- affected files
- tests

3. Phase 13 Final Status

Explicit:

PASS

only if every gate passed.

4. Scope & Handoff Audit

List every candidate item and classification.

5. Controlled Enhancements

For each:

Enhancement
Reason
Scope justification
Files
Tests

6. Phase 14 Implementation

List:

- features
- architecture changes
- database changes
- UI changes
- services
- permissions
- localization

7. Database / Migration

Include:

- previous schema
- new schema
- migration details
- migration test results

8. Financial Integrity

Include:

- Trial Balance
- Assets = Liabilities + Equity
- cashbox reconciliation
- customer balances
- supplier balances
- duplicate-posting protection

9. Security / RBAC

10. Backup / Restore

Confirm Phase 13 remains functional after Phase 14.

11. Testing

Report exact:

flutter test:
flutter analyze:
migration tests:
integration tests:
new tests:
total tests:

12. Acceptance Matrix

Use:

PASS / FAIL / DEFERRED

Do not hide failures.

13. Known Limitations

Only genuine remaining limitations.

14. Deferred Items

Explicitly identify work belonging to later phases.

15. Phase 15 Handoff

Provide a clean handoff without implementing Phase 15.

---

FINAL STOP CONDITIONS

Do NOT declare success if:

- tests fail
- analyzer fails
- Phase 13 restore lifecycle is unsafe
- rollback is unsafe
- financial invariants fail
- migration fails
- RBAC is bypassable
- destructive operations lack required authorization
- database integrity fails
- a new duplicate financial posting engine appears
- Phase 14 scope was expanded without justification

If a blocker remains:

STOP
REPORT
DO NOT MASK THE FAILURE
DO NOT MOVE TO THE NEXT PHASE

---

FINAL SUCCESS CRITERIA

The work is complete only when:

Phase 13 Hardening = PASS
        +
Phase 14 Scope Audit = PASS
        +
Controlled Enhancements = justified
        +
Phase 14 implementation = complete
        +
flutter analyze = 0 issues
        +
flutter test = 100% pass
        +
migrations = pass
        +
financial integrity = pass
        +
RBAC = pass
        +
backup/restore regression = pass
        +
Arabic RTL = pass
        +
Latin digits = pass
        +
PHASE14-COMPLETION-REPORT.md = created

Do not stop after writing the report.

Actually implement, test, verify, and only then report completion.