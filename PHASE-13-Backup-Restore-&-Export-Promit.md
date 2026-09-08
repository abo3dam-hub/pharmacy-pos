PHASE 13 — BACKUP, RESTORE & EXPORT

Strict Implementation Prompt + Scope/Handoff Audit + Controlled Enhancements

Role

You are an Expert Flutter Desktop Architect, Offline-First SQLite Engineer, Financial Integrity Engineer, and QA Engineer.

You are continuing the existing Pharmacy Management & POS project.

You MUST work from the existing repository and existing implementation.

You MUST NOT redesign or rebuild completed phases.

---

1. CURRENT AUTHORITATIVE BASELINE

Current production baseline:

- Phase 10.1 — Financial Integrity Hardening: COMPLETE
- Phase 11 — Reports: COMPLETE
- Phase 12 — Audit, Settings & Administration: COMPLETE
- Current commit:
  "fa521fbf35dea1a5add5cd3bf1abf4f7ccea1b51"
- Database schema:
  "v8"
- Phase 11 tests:
  "435"
- Phase 12 tests:
  "463"
- "flutter analyze" was clean.

Authoritative architecture document:

"PROJECT-ARCHITECTURE-PLAN.md"

It is the Single Source of Truth.

---

2. MANDATORY PRE-IMPLEMENTATION SCOPE & HANDOFF AUDIT

Before changing ANY code:

Read and inspect:

1. "PROJECT-ARCHITECTURE-PLAN.md"
2. "PHASE10.1-FINANCIAL-INTEGRITY-HARDENING-REPORT.md"
3. "PHASE11-COMPLETION-REPORT.md"
4. "PHASE12-COMPLETION-REPORT.md"
5. Current database schema/migrations
6. Existing file-storage implementation
7. Existing expense receipt storage
8. Existing permissions/RBAC
9. Existing AuditService
10. Existing SettingsService/DAO
11. Existing PDF/Excel export infrastructure
12. Existing backup-related code, if any

Then produce an internal classification:

IMPLEMENTED

Things that already exist and MUST be reused.

CURRENT PHASE

Things belonging to Phase 13.

CONTROLLED ENHANCEMENT

Only the explicitly approved enhancements in this prompt.

LATER PHASE

Do not implement.

OUT OF ROADMAP

Do not implement.

STOP if the current code contradicts the architecture in a way that could cause data loss.

---

3. OFFICIAL PHASE 13 SCOPE

Phase 13 is:

Backup / Restore & Export

Implement:

1. Database backup
2. Database restore
3. Backup validation
4. Restore validation
5. Migration/schema compatibility validation
6. Backup/export UI
7. Appropriate RBAC
8. Audit logging
9. Safe restore workflow
10. Complete backup of database-associated files
11. Tests
12. Completion report

---

4. NON-NEGOTIABLE ARCHITECTURE RULES

DO NOT:

- create a second database
- create a second financial engine
- modify FinancialPostingService
- modify accounting semantics
- modify Phase 11 reports
- modify Phase 12 administration semantics
- redesign the schema without necessity
- delete the production database directly
- bypass migrations
- silently downgrade schema
- restore an incompatible database
- bypass RBAC
- bypass audit
- use floating-point money
- introduce new color/theme systems
- hardcode Arabic/English strings
- use Arabic-Indic digits

Arabic-first RTL remains mandatory.

All displayed numbers MUST use Western/Latin digits:

"0 1 2 3 4 5 6 7 8 9"

---

5. CONTROLLED ENHANCEMENT A — COMPLETE SELF-CONTAINED BACKUP

A normal SQLite-only copy is NOT sufficient.

Phase 9 stores expense receipt files outside SQLite.

Therefore a backup MUST include:

- SQLite database
- "expense_receipts/"
- required metadata

The backup must be self-contained.

Do not store only absolute filesystem paths.

Restore must recreate the associated receipt files.

If other application-owned persistent files are discovered during the audit, classify them and include only files that are required for database integrity/historical functionality.

Do NOT blindly archive cache/temp files.

---

6. CONTROLLED ENHANCEMENT B — BACKUP MANIFEST & INTEGRITY

Every backup package MUST contain a manifest.

Suggested format:

"manifest.json"

Include at minimum:

- backup format version
- application version
- schema version
- created timestamp
- database filename
- database byte size
- SHA-256 database checksum
- list of included managed files
- file sizes
- SHA-256 checksum per managed file

Do not use cryptographic secrets or passwords inside the manifest.

The manifest is for integrity and compatibility validation.

---

7. BACKUP FORMAT

Use the project's existing "archive" capability if appropriate.

Do NOT invent a custom binary format if an existing supported archive format is already available.

Recommended logical structure:

pharmacy-backup/
  manifest.json
  database.sqlite
  files/
    expense_receipts/
      ...

The exact implementation may differ if the existing project conventions require it.

The package must be portable and restorable.

---

8. BACKUP WORKFLOW

Backup must:

1. Verify current user has the required permission.
2. Resolve the live database path safely.
3. Create a consistent SQLite backup/copy using the safest existing project-compatible mechanism.
4. Include managed persistent files.
5. Generate checksums.
6. Generate manifest.
7. Create the archive.
8. Validate the generated archive before declaring success.
9. Write an audit entry.
10. Return a clear success/failure result.

Do not leave partially written backup files as successful backups.

Use temporary files/directories and rename/move only after successful completion.

---

9. CONTROLLED ENHANCEMENT C — SAFE RESTORE

Restore is destructive and MUST be treated as a sensitive operation.

Before restore:

1. Check RBAC.
2. Require explicit confirmation.
3. Validate archive structure.
4. Validate manifest.
5. Validate all checksums.
6. Validate backup format version.
7. Validate database schema version.
8. Determine whether migration is supported.
9. Reject incompatible or newer schema versions.
10. Create an emergency backup of the CURRENT database/files.
11. Only then proceed with restore.

Never destroy the current installation before the restore package has been fully validated.

---

10. RESTORE COMPATIBILITY RULES

Supported:

- current schema
- older schema versions only when the existing forward migration path can safely migrate them

Rejected:

- newer schema than the application supports
- corrupted database
- checksum mismatch
- malformed manifest
- missing required files
- unsupported backup format

Never downgrade the schema.

Never delete the DB merely because migration failed.

---

11. RESTORE SAFETY

The restore implementation MUST protect against:

- corrupt backup
- interrupted restore
- missing receipt files
- invalid SQLite database
- incompatible schema
- checksum mismatch
- partial extraction
- filesystem replacement failure

Preferred workflow:

Validate
   ↓
Create emergency backup
   ↓
Stage restore files
   ↓
Validate staged database
   ↓
Run supported migration if needed
   ↓
Validate schema
   ↓
Replace live data safely
   ↓
Restore managed files
   ↓
Reopen database
   ↓
Run integrity checks
   ↓
Audit restore

If final activation fails, preserve the emergency backup and fail safely.

Never report success if the restored database cannot be reopened and validated.

---

12. DATABASE VALIDATION

Before accepting a restored SQLite database:

Verify:

- database opens successfully
- expected schema version
- migrations can execute if required
- required tables exist
- required indexes exist where appropriate
- SQLite integrity check succeeds
- critical application tables are readable

At minimum consider:

PRAGMA integrity_check;

Do not invent unnecessary database constraints.

---

13. APPLICATION INTEGRITY VALIDATION AFTER RESTORE

After restoring:

Verify that the database still contains coherent:

- users/roles
- items
- batches
- stock movements
- suppliers
- purchases
- customers
- prescriptions
- sales
- returns
- expenses
- cashbox transactions
- journal entries
- audit logs
- settings

Financial data MUST NOT be recalculated or reposted during restore.

Restore is data restoration, NOT a financial posting operation.

---

14. FINANCIAL INTEGRITY RULE

The restore layer MUST NOT call:

- "postSale"
- "postReturn"
- "postPurchase"
- "postExpense"
- "postCustomerPayment"
- "postCustomerRefund"
- "postVoidReversal"

or any other financial posting operation.

Restoring historical journal rows is enough.

Never double-post restored transactions.

---

15. EXPENSE RECEIPT RESTORATION

This is a mandatory acceptance gate.

Given:

Expense → receipt path → filesystem file

A backup/restore round-trip MUST preserve the relationship.

Test:

1. Create an expense.
2. Attach a receipt.
3. Create backup.
4. Modify/delete the original receipt/database state in a controlled test environment.
5. Restore backup.
6. Verify:
   - expense still exists
   - receipt reference is valid
   - physical receipt file exists
   - receipt can be opened/previewed

---

16. CONTROLLED ENHANCEMENT D — RBAC + AUDIT

Inspect existing permission catalog first.

Do not create duplicate permissions.

If suitable permissions already exist, reuse them.

If missing, add only the minimum required permissions.

Suggested logical permissions:

- backup.view
- backup.create
- backup.restore
- export.data

Use the project's actual naming conventions if different.

Recommended policy:

Viewer

No backup/restore unless explicitly granted.

Pharmacist

View/create backup only if existing security model allows.

Admin

Full backup/restore/export.

Restore must require elevated permission.

Every successful and failed sensitive restore attempt should be auditable according to the existing AuditService semantics.

Audit should include:

- operation
- actor
- timestamp
- result
- target/source information
- failure reason where safe

Do not store secrets or sensitive archive contents in the audit record.

---

17. EXPORT

Phase 13 export must complement, not duplicate, Phase 11 report export.

Phase 11 already provides report PDF/Excel exports.

Do NOT rebuild those.

Phase 13 export should focus on appropriate application/data export such as:

- master data
- transactional data
- financial/accounting data where appropriate
- audit data where permitted

Before implementing export, inspect existing export capabilities and reuse them.

Export MUST be read-only.

Export MUST NOT mutate:

- inventory
- sales
- purchases
- expenses
- cashbox
- journal
- audit trail

---

18. EXPORT FORMAT

Prefer existing project-supported formats.

If CSV is added, use proper escaping and UTF-8.

If Excel is already supported, reuse existing infrastructure.

Arabic content must remain readable.

Numbers must remain Western digits.

Dates must be localized for display but underlying exported values must remain unambiguous.

---

19. UI

Create a professional Arabic-first Backup & Restore / Data Management screen.

Possible route:

/settings/data

or another route consistent with the current Settings/Admin architecture.

Do not introduce a duplicate navigation system.

UI should provide:

Backup

- Create Backup
- choose destination
- progress/state
- success confirmation
- backup metadata

Restore

- choose backup
- inspect metadata
- validation result
- explicit destructive confirmation
- restore progress
- final result

Export

- choose export type
- choose destination
- export progress
- result

Use existing responsive layout and shared widgets.

No new colors.

No page-specific theme.

No hardcoded strings.

---

20. LATIN DIGITS

This requirement is global.

All UI numbers MUST remain:

"0 1 2 3 4 5 6 7 8 9"

Including:

- backup versions
- schema versions
- file counts
- sizes
- dates
- export row counts
- progress percentages

---

21. MIGRATION SAFETY

Do not create a migration merely for Phase 13 unless the existing architecture makes it necessary.

Prefer schema version "8" unchanged if possible.

If a migration is genuinely required:

- forward-only
- explicit
- tested
- old installations remain readable
- no destructive migration
- backup before migration
- update schema tests

---

22. TESTING REQUIREMENTS

Add tests covering:

Backup

- backup creation
- manifest generation
- SHA-256 verification
- archive validation
- database integrity
- managed files inclusion

Restore

- valid restore
- invalid archive
- checksum mismatch
- corrupt SQLite
- incompatible schema
- older schema with valid migration
- newer schema rejection
- emergency backup creation
- receipt restoration
- failed restore safety

RBAC

- unauthorized backup
- unauthorized restore
- unauthorized export
- authorized admin flows

Audit

- backup audit
- restore audit
- failed restore audit where applicable
- export audit where required

Financial

After backup/restore round-trip verify:

- journal count unchanged
- journal totals unchanged
- trial balance unchanged
- balance sheet unchanged
- customer balances unchanged
- supplier balances unchanged
- cashbox data unchanged
- stock data unchanged

CRITICAL:

Backup/restore tests MUST prove that no financial posting occurred.

---

23. FULL REGRESSION

Run:

flutter analyze
flutter test

Also verify:

- migration tests
- backup round-trip tests
- existing report tests
- financial integrity tests
- Phase 12 RBAC tests
- PDF/Excel tests

No regression is acceptable.

---

24. PERFORMANCE

Do not load the entire database into Dart memory just to create a backup.

Use filesystem/database-level operations wherever possible.

Exports must use DB-side filtering/paging where applicable.

Do not introduce full-table scans for UI listing.

---

25. SECURITY

Never:

- expose database paths unnecessarily
- log secrets
- log archive contents
- allow arbitrary filesystem traversal
- restore arbitrary files outside the application data area without validation
- overwrite arbitrary user files silently

Sanitize archive paths.

Reject:

../
absolute paths
drive-letter paths
unexpected path traversal

during extraction.

---

26. STOP CONDITIONS

STOP implementation and report the blocker if:

- current database path cannot be determined safely
- restore would require destructive schema downgrade
- receipt storage architecture is inconsistent
- existing permissions conflict with restore safety
- migration history is incomplete
- archive extraction cannot be made path-safe
- current DB cannot be backed up consistently
- implementation would require modifying FinancialPostingService
- implementation would require changing accounting semantics

Do NOT work around these silently.

---

27. ACCEPTANCE GATES

Phase 13 is COMPLETE only if ALL are true:

- [ ] Backup works on Windows.
- [ ] Backup includes SQLite.
- [ ] Backup includes required managed files.
- [ ] Expense receipts survive round-trip.
- [ ] Manifest generated.
- [ ] SHA-256 validation works.
- [ ] Backup archive self-validates.
- [ ] Restore validates before replacement.
- [ ] Emergency backup is created before destructive restore.
- [ ] Schema compatibility is checked.
- [ ] Forward migrations work where supported.
- [ ] Newer/incompatible backups are rejected.
- [ ] SQLite integrity check passes after restore.
- [ ] Financial data remains identical after round-trip.
- [ ] No financial posting occurs during restore.
- [ ] RBAC enforced.
- [ ] Sensitive operations audited.
- [ ] Archive path traversal blocked.
- [ ] Arabic-first RTL UI.
- [ ] English localization complete.
- [ ] All displayed numbers use Latin digits.
- [ ] No new colors/theme violations.
- [ ] No duplicate report export implementation.
- [ ] "flutter analyze" clean.
- [ ] Full "flutter test" passes.
- [ ] Migration tests pass.
- [ ] Completion report created.

---

28. REQUIRED COMPLETION REPORT

Create:

"PHASE13-COMPLETION-REPORT.md"

It MUST include:

1. Baseline commit
2. Final commit
3. Scope audit
4. Implemented features
5. Controlled enhancements
6. Database/schema version
7. Backup format
8. Manifest structure
9. Restore safety model
10. Receipt backup/restore behavior
11. RBAC
12. Audit behavior
13. Export behavior
14. Tests added
15. Full test count
16. "flutter analyze" result
17. Migration verification
18. Financial integrity verification
19. Known limitations
20. Deferred items
21. Phase 14 handoff

Do not claim PASS unless every acceptance gate is verified.

---

29. PHASE 14 HANDOFF

At completion, explicitly classify remaining items as:

- implemented
- Phase 14
- later phase
- out of roadmap

Do NOT invent new roadmap phases.

The official roadmap remains authoritative.

---

30. FINAL RULE

The objective is NOT merely:

"make backup work."

The objective is:

A production-safe, self-contained, verifiable offline backup/restore system that can recover the entire pharmacy application's operational, financial, audit, settings, and receipt data without double-posting, data loss, schema corruption, or security bypass.

Do not weaken this requirement.