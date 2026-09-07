Pharmacy POS — Phase 12 Complete Implementation Prompt

ROLE

You are an expert Flutter Windows Desktop Developer, Software Architect, Database Engineer, and QA Engineer.

You are continuing an existing production-oriented Pharmacy Management & POS System.

Repository:

"https://github.com/abo3dam-hub/pharmacy-pos"

You are NOT starting a new project.

Your first responsibility is to understand and preserve the existing architecture, roadmap, completed work, business rules, financial integrity, and previous phase handoffs.

---

1. NON-NEGOTIABLE PROJECT GOVERNANCE

The authoritative architectural source of truth is:

"PROJECT-ARCHITECTURE-PLAN.md"

The official roadmap MUST be preserved.

Do NOT invent new phases.

Do NOT reorder phases.

Do NOT rebuild functionality that previous phases already implemented.

Do NOT perform unrelated refactoring.

Do NOT introduce feature creep.

Before implementation, follow this exact sequence:

Scope Audit → Handoff Audit → Classification → Handoff Resolution → Controlled Enhancement → Pre-Implementation Audit → Implementation → Tests → Verification → Completion Report

The audit must be performed against the CURRENT codebase, not only historical reports.

---

2. COMPLETED PHASE BASELINE

Phases 1–11 are already completed and approved.

Important baseline:

- Phase 5: 155 tests, 0 analyzer issues.
- Phase 10: schema v8, 395 tests, analyze clean.
- Phase 10.1: 417 tests, analyze clean.
- Phase 11: Reports completed.
- Phase 11 commit:
  "9604a8ce7e0323494c991d5dbc16472128c79aab"
- Phase 11: 435 tests, "flutter analyze" clean.
- Phase 11 is APPROVED.
- Do NOT recreate or replace the Reports architecture.

Read the actual repository before making assumptions.

---

3. OFFICIAL PHASE 12 SCOPE

According to the official Architecture Plan, Phase 12 is:

Audit Log & Settings

A. Audit Log

- Audit Log Viewer
- Audit history browsing
- Useful filtering/search
- Audit event details
- User/action/entity/date information where available
- Permission-controlled access

B. Application Settings

At minimum:

- Business Name
- Tax configuration
- Currency configuration

Settings must be persistent and integrated correctly with the existing architecture.

C. User / Role / Permission Management

Implement management UI for:

- Users
- Roles
- Permissions

The existing RBAC/security architecture must be reused.

---

4. MANDATORY SCOPE AUDIT

Before implementation:

1. Read "PROJECT-ARCHITECTURE-PLAN.md".
2. Identify the exact official Phase 12 scope.
3. Inspect the current project structure.
4. Inspect existing services, repositories, DAOs, database schema, DI, routing, localization, and permissions.
5. Identify what already exists for:
   - Audit
   - RBAC
   - Users
   - Roles
   - Permissions
   - Settings
6. Determine what is genuinely missing.

Do NOT assume that something is missing merely because the Phase 12 specification asks for it.

If it already exists, reuse and extend it where necessary.

---

5. MANDATORY HANDOFF AUDIT — PHASE 1 THROUGH PHASE 11

This is a mandatory project-governance requirement.

You MUST review the handoffs from EVERY previous phase, Phase 1 through Phase 11.

Inspect:

- Completion reports
- Handoff sections
- Known Debts
- Deferred Items
- Limitations
- TODOs
- Follow-up recommendations
- Architectural warnings
- Explicit "later phase" items
- Technical debt mentioned in previous phases

Do not limit the review to Phase 10, Phase 10.1, and Phase 11.

The entire history from Phase 1 → Phase 11 must be considered.

---

6. HANDOFF LEDGER

Create an internal consolidated Handoff Ledger.

For every outstanding handoff/debt item, determine:

Origin Phase| Item| Historical Status| Current Code Status| Classification| Phase 12 Action

Every item must be classified into exactly one category:

✅ ALREADY RESOLVED

The issue was already fixed in a later phase or is already correctly implemented in the current codebase.

Action:

- Do nothing.
- Do NOT rebuild it.
- Do NOT duplicate it.

🟢 RESOLVE IN PHASE 12

The handoff logically belongs to Phase 12 and should be resolved as part of this phase.

Action:

MUST be implemented/fixed NOW.

🟡 VALID LATER-PHASE ITEM

The issue genuinely belongs to an official later phase.

Action:

- Do not implement it now.
- Record the target phase.
- Record why it legitimately belongs there.
- Make sure it is not forgotten.

⚪ OUT OF ROADMAP

The item is outside the official project roadmap.

Action:

- Do not implement it.

---

7. CRITICAL HANDOFF POLICY — DO NOT DEFER VALID DEBTS FOREVER

The Handoff Audit is NOT an archival exercise.

It MUST NOT become a mechanism for endlessly postponing technical debt.

A previous "Deferred" label is NOT automatically a reason to defer the item again.

If a previous Handoff is logically related to Phase 12 and can correctly be resolved within Phase 12:

RESOLVE IT NOW.

Do not simply write:

"Deferred to a future phase."

without proving that it actually belongs to that future phase.

---

8. NO HANDOFF DEBT LOOP

The following pattern is explicitly prohibited:

Phase N:
"Deferred"

Phase N+1:
"Still deferred"

Phase N+2:
"Still deferred"

Phase N+3:
"Still deferred"

If an item has reached the phase where it logically belongs:

Close it.

Only defer an item when there is a genuine architectural, dependency, roadmap, or business reason.

Convenience, effort, or "we can do it later" are NOT sufficient reasons.

---

9. CURRENT CODEBASE OVERRIDES STALE REPORTS

Previous completion reports are historical evidence.

They are NOT proof of the current state.

Therefore:

If a previous report says:

"Deferred"

but the current codebase shows it is already implemented:

→ classify as Already Resolved.

If a previous report says:

"Complete"

but the current codebase proves it is incomplete:

→ classify according to the actual current state.

If the incomplete item belongs to Phase 12:

→ resolve it now.

---

10. IMPORTANT KNOWN PREVIOUS ITEMS TO VERIFY

At minimum, verify the current status of previously identified items such as:

- Existing AuditService
- Existing audit recording
- RBAC enforcement
- Accounting permissions
- Accounting-period audit records
- Customer/payment audit behavior
- "4002 Purchase Returns"
- Document-number uniqueness limitations
- DB-level uniqueness limitations
- Reports-related technical debt
- PDF Arabic/bidi workaround
- Statement query reuse
- Any TODO/deferred items from earlier phases

Do NOT automatically bring these into Phase 12.

Verify their current status and classify them correctly.

If one is genuinely a Phase 12 responsibility, resolve it.

If it belongs to Phase 13/14/etc., preserve it with a justified target.

---

11. IMPORTANT EXISTING ARCHITECTURE — DO NOT REBUILD

Previous phases already established important infrastructure.

In particular, inspect and reuse:

- Existing AuditService
- Existing audit persistence
- Existing RBAC
- Existing permission system
- Existing authorization enforcement
- Existing FinancialPostingService
- Existing Clean Architecture boundaries
- Existing database/migration system
- Existing DI
- Existing routing/navigation
- Existing localization
- Existing design system/components

DO NOT create:

- A second AuditService
- A second RBAC system
- A second permission engine
- A parallel financial posting mechanism
- A duplicate settings architecture if one already exists

Extend existing infrastructure where necessary.

---

12. CONTROLLED ENHANCEMENT POLICY

Small enhancements are allowed ONLY when they are required to make Phase 12 complete and architecturally correct.

Allowed examples:

- Missing settings table/storage
- Required migration
- Missing settings repository/DAO
- Missing service methods
- Missing audit query methods
- Missing audit filters
- Missing user/role repository methods
- Missing permission query methods
- Required DI registration
- Required router registration
- Required localization keys
- Required permission gates
- Tests required for Phase 12 behavior
- Small architectural fixes directly necessary for Phase 12

Do NOT use this as permission to redesign the application.

---

13. PHASE 12 — AUDIT LOG VIEWER

Implement a professional Arabic-first Audit Log Viewer.

It should allow authorized users to inspect audit activity.

At minimum support:

- Date/time
- User
- Action
- Entity/type
- Entity ID where available
- Relevant description/details
- Search/filter functionality
- Date range filtering
- User filtering where supported
- Action/entity filtering where supported
- Details view where useful

Use the existing audit infrastructure.

Do NOT create a separate audit recording mechanism.

The viewer must be read-only.

---

14. AUDIT SECURITY

Audit logs are sensitive administrative information.

The Audit Log Viewer MUST be permission controlled.

Reuse the existing permission/RBAC architecture.

Unauthorized users must not be able to access administrative audit information.

Do not bypass existing authorization checks merely because the viewer is an administrative screen.

---

15. PHASE 12 — APPLICATION SETTINGS

Implement the official Phase 12 application settings:

Business Name

Persistent application/business name.

Tax

Persistent tax configuration.

The implementation must respect the project's existing money/precision rules.

Do NOT introduce floating-point financial calculations where the existing financial architecture requires integer monetary units or basis points.

Currency

Persistent application currency configuration.

Use the existing currency/money architecture where available.

Do not duplicate currency models unnecessarily.

---

16. SETTINGS ARCHITECTURE

Settings must follow the existing Clean Architecture.

Expected flow where applicable:

UI
→ Controller/ViewModel
→ Use Case
→ Repository
→ DAO/Database

Do not bypass architecture by putting database logic directly inside widgets.

Settings must survive application restart.

If persistent settings storage does not exist, implement the minimum clean solution required by Phase 12.

If a settings mechanism already exists, reuse it.

---

17. USER MANAGEMENT UI

Implement professional administrative UI for user management.

At minimum:

- View users
- Add user
- Edit user
- Enable/disable user where supported by existing architecture
- Assign roles
- View relevant user information
- Enforce appropriate permissions

Respect existing authentication/security architecture.

Do not weaken security to make the UI easier to implement.

---

18. ROLE MANAGEMENT UI

Implement role management.

At minimum:

- View roles
- Create role where supported by architecture
- Edit role
- Assign permissions to roles
- View role permissions
- Prevent invalid/inconsistent role state

Reuse existing role/RBAC structures.

---

19. PERMISSION MANAGEMENT UI

Implement a clear professional permission-management interface.

Permissions should be grouped logically.

The UI should make it easy for an administrator to understand:

- What the permission controls
- Which permissions belong to which role
- Which role has which capabilities

Reuse the existing permission identifiers and enforcement mechanism.

Do NOT invent a parallel permission naming system.

---

20. RBAC INTEGRITY

Do not merely build screens that appear to work.

Verify that permission changes actually affect authorization behavior.

Test scenarios such as:

- Authorized administrator can access Audit Log.
- Unauthorized user cannot access Audit Log.
- Authorized administrator can manage users/roles/permissions.
- Unauthorized user cannot perform administrative operations.
- Role permission changes are respected by existing protected features.

Do not bypass authorization in UI, services, or repositories.

---

21. AUDITABILITY OF ADMINISTRATIVE ACTIONS

Where the existing audit architecture supports it, administrative operations introduced by Phase 12 should be properly auditable.

Examples:

- User creation/update
- Role changes
- Permission changes
- Important settings changes

Reuse the existing AuditService.

Do NOT create a second logging pipeline.

If an existing audit convention already exists, follow it consistently.

---

22. ARABIC-FIRST UI / UX

The application is Arabic-first.

All Phase 12 UI must use professional Arabic terminology.

Requirements:

- RTL
- Arabic-first labels
- Professional Arabic wording
- Consistent terminology
- Proper Arabic dialogs
- Proper Arabic validation/error messages
- Proper Arabic empty states
- Proper Arabic confirmation messages
- No unnecessary English labels in the Arabic UI

English localization must remain supported where the existing project supports it.

Do NOT use machine-like or awkward Arabic translations.

Maintain the existing visual language of the application.

Do not perform a general UI redesign unrelated to Phase 12.

---

23. DATABASE / MIGRATIONS

Before modifying the schema:

1. Inspect the current schema version.
2. Inspect existing migrations.
3. Determine whether Phase 12 actually requires schema changes.
4. Preserve backward compatibility.

The current known baseline is schema v8 unless the current repository proves otherwise.

If a migration is required:

- increment schema version correctly
- implement migration
- preserve existing data
- test migration behavior
- do not modify old migrations unnecessarily

Never destroy existing production data during migration.

---

24. CLEAN ARCHITECTURE

Maintain existing architecture.

Do not put business logic in widgets.

Do not bypass repositories unnecessarily.

Do not introduce unnecessary abstractions.

Follow existing project conventions for:

- entities
- repositories
- use cases
- data sources
- DAOs
- controllers
- providers/state management
- DI
- routing

First inspect how the existing project implements these concepts, then follow its established pattern.

---

25. TESTING REQUIREMENTS

You MUST add/modify tests for Phase 12 behavior.

At minimum cover:

Audit

- Audit records can be queried.
- Filters work.
- Date filtering works.
- Unauthorized access is blocked.

Settings

- Business name persists.
- Tax persists.
- Currency persists.
- Settings survive reload/restart where testable.
- Invalid values are rejected appropriately.

Users

- User management works.
- Role assignment works.
- Authorization is respected.

Roles

- Role creation/editing works where supported.
- Permission assignment works.

Permissions

- Permission changes affect authorization.
- Protected functionality remains protected.

Regression

All existing tests must continue passing.

---

26. FINANCIAL SAFETY

Phase 12 must NOT break the existing financial engine.

Do not modify financial posting behavior unless a verified Phase 12 requirement absolutely requires it.

"FinancialPostingService" remains the single financial posting engine.

Do not introduce:

- duplicate financial posting
- direct journal manipulation
- floating-point financial calculations
- unauthorized financial mutations

Reports must remain read-only.

---

27. REGRESSION PROTECTION

After implementation run:

- Full test suite
- "flutter analyze"
- Any relevant formatting checks
- Relevant integration tests where available

Verify:

- Phase 1–11 behavior remains intact.
- Accounting remains intact.
- Reports remain intact.
- POS behavior remains intact.
- Inventory behavior remains intact.
- Customer/supplier behavior remains intact.
- Existing RBAC remains intact.
- Existing audit recording remains intact.

Do not accept a Phase 12 implementation that introduces unexplained regressions.

---

28. MANDATORY PRE-IMPLEMENTATION AUDIT

Before modifying code, internally verify:

Architecture

- Current architecture understood.
- Phase 12 boundaries understood.

Scope

- Official Phase 12 scope identified.

Handoffs

- Phase 1–11 handoffs reviewed.
- Handoff Ledger completed.
- Current code verified.
- Phase 12-relevant handoffs identified.

Resolution

- Every Phase 12-relevant previous handoff is included in the implementation.
- No valid Phase 12 handoff is unnecessarily deferred again.
- Later-phase items are explicitly preserved.

Existing Infrastructure

- Existing AuditService identified.
- Existing RBAC identified.
- Existing permissions identified.
- Existing settings infrastructure identified.
- Existing database architecture identified.

Risks

- Schema/migration impact identified.
- Regression risks identified.

Then proceed directly to implementation.

DO NOT STOP AFTER THE AUDIT.

The audit is a gate before implementation, not the final deliverable.

Only stop if there is a genuine blocker that makes safe implementation impossible.

---

29. IMPLEMENTATION RULE

Implement Phase 12 completely.

Do not implement only the UI while leaving the underlying functionality fake or incomplete.

Do not create placeholder buttons that do nothing.

Do not create mock settings that disappear after restart.

Do not create fake permission management that does not affect RBAC.

Do not create an Audit Log screen disconnected from the actual audit database.

Every delivered feature must be wired through the real application architecture.

---

30. FINAL VERIFICATION

Before declaring Phase 12 complete, perform a final self-audit.

Verify:

Scope

- Every official Phase 12 requirement is implemented.

Handoffs

- Every Phase 12-relevant Handoff from Phase 1–11 has been resolved.
- No Phase 12-relevant debt was unnecessarily deferred.
- Legitimate later-phase items remain preserved.

Architecture

- No duplicate infrastructure was created.
- Existing AuditService is reused.
- Existing RBAC is reused.
- Existing permission system is reused.

Database

- Schema is valid.
- Migrations are safe.
- Existing data is preserved.

Security

- Administrative features are permission controlled.
- RBAC actually works.

Localization

- Arabic UI is professional and RTL.
- Existing English localization remains intact.

Testing

- New tests pass.
- Existing tests pass.
- "flutter analyze" is clean.

---

31. COMPLETION REPORT

Create:

"PHASE12-COMPLETION-REPORT.md"

The report MUST include:

1. Executive Summary

2. Scope Audit

What official Phase 12 required.

3. Handoff Audit

Explicitly state that Phase 1–11 were reviewed.

4. Consolidated Handoff Ledger

Use:

Origin Phase| Handoff / Debt| Historical Status| Current Status| Classification| Phase 12 Action| Final Status

5. Handoff Resolution Summary

Clearly identify:

- What was resolved in Phase 12.
- What was already resolved.
- What legitimately remains for later phases.
- Why each remaining item belongs to a later phase.

6. Implemented Features

Document:

- Audit Log
- Settings
- Users
- Roles
- Permissions
- Any legitimate controlled enhancements.

7. Architecture Changes

8. Database/Migration Changes

9. Security/RBAC Changes

10. Localization Changes

11. Tests

Report exact test count.

12. Verification

Report:

- "flutter analyze"
- tests
- relevant verification results

13. Remaining Technical Debt

Only genuine remaining debt.

Do not hide deferred items.

Do not relabel Phase 12 work as "future work" merely to avoid completing it.

14. Final Acceptance

Explicitly state whether Phase 12 passes all acceptance gates.

---

32. GIT REQUIREMENTS

After successful implementation and verification:

1. Review changed files.
2. Ensure no accidental files are committed.
3. Ensure generated/build artifacts are not committed.
4. Commit the Phase 12 implementation.

Use a clear commit message such as:

"feat: complete Phase 12 audit settings and administration"

Push the changes to the repository if repository permissions allow it.

---

33. FINAL RESPONSE

Your final response must be concise but informative.

Include:

- Phase 12 status
- What was implemented
- Handoffs resolved
- Any legitimate remaining handoffs
- Test count
- "flutter analyze" result
- Commit hash
- Completion report path/link

Do NOT claim success unless the implementation, tests, analysis, and verification actually succeeded.

FINAL GOVERNING PRINCIPLE

The goal is NOT merely to "complete Phase 12."

The goal is to move the project forward while preserving architectural integrity and preventing technical debt from being endlessly carried from phase to phase.

Therefore:

Review the past completely.

Resolve every previous Handoff that belongs to Phase 12.

Do not unnecessarily defer it again.

Preserve only genuinely later-phase work.

Reuse what is already implemented.

Implement the official Phase 12 scope completely.

Test everything.

Verify everything.

Document everything.

Then deliver Phase 12 as a clean, production-ready increment without disturbing the approved work from Phases 1–11.