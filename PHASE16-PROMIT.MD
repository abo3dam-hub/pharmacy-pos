PHASE 16 — FINAL RELEASE & PRODUCTION LAUNCH

Role

You are an Expert Flutter Windows Desktop Engineer, Software Architect, QA Engineer, Release Engineer, and Code Auditor.

You are working on the existing Pharmacy Management & POS System repository:

"abo3dam-hub/pharmacy-pos"

This is the FINAL ROADMAP PHASE.

Your mission is NOT to rebuild the application or introduce uncontrolled new features.

Your mission is to:

1. Perform the final Scope/Handoff Audit.
2. Resolve the approved Phase 16 items.
3. Complete final localization.
4. Perform a REAL Windows build and verification.
5. Validate release readiness.
6. Apply only safe, explicitly controlled enhancements where justified.
7. Produce a professional production-ready release.
8. Leave the repository in a clean, documented, reproducible state.

---

1. NON-NEGOTIABLE PROJECT GOVERNANCE

"PROJECT-ARCHITECTURE-PLAN.md" is the authoritative Single Source of Truth.

Before changing ANY code:

Read completely:

- "PROJECT-ARCHITECTURE-PLAN.md"
- Phase 1 architecture / completion documents
- Phase 2 completion documents
- Phase 3 completion documents
- Phase 4 completion documents
- Phase 5 completion documents
- Phase 6 completion documents
- Phase 7 completion documents
- Phase 8 completion documents
- Phase 9 completion documents
- Phase 10 completion documents
- Phase 10.1 completion documents
- Phase 11 completion documents
- Phase 12 completion documents
- Phase 13 completion documents
- Phase 14 completion documents
- "PHASE15-AUDIT-LEDGER.md"
- "PHASE15-COMPLETION-REPORT.md"
- "PHASE-15-PROMIT.md"
- the current README and release/version documentation

Also inspect the CURRENT CODEBASE.

Do not trust historical reports over current code.

Current code overrides stale documentation.

---

2. REQUIRED FINAL SCOPE / HANDOFF AUDIT

Before implementation, construct a final audit table covering all relevant outstanding items from Phases 1–15.

Every item MUST be classified as exactly one of:

- IMPLEMENTED
- PHASE 16 — IMPLEMENT NOW
- LATER / FUTURE
- OUT OF ROADMAP
- INTENTIONALLY NOT CHANGED

Do NOT resurrect completed work.

Do NOT rebuild existing functionality.

Do NOT create duplicate services, repositories, widgets, accounting logic, localization systems, or architectural layers.

Historical "Deferred" status is NOT by itself sufficient justification for deferring an item again.

Inspect the current implementation first.

---

3. APPROVED PHASE 16 DECISIONS

The following decisions are already approved.

A. REAL WINDOWS BUILD — MUST DO

The application is a Windows Desktop application.

A real Windows build must be performed.

Do not claim Windows compatibility based only on Linux analysis.

The final release must include an actual:

"flutter build windows --release"

executed on a Windows environment, preferably through the existing GitHub Actions Windows runner.

Verify:

- dependency resolution
- Flutter analyze
- complete test suite
- Windows compilation
- release build
- generated executable/artifacts
- application startup where technically possible
- absence of obvious runtime startup failure
- artifact integrity
- correct version information where applicable

The existing CI Windows workflow must be inspected and improved only if necessary.

Do not weaken existing CI.

---

4. FULL USER-VISIBLE LOCALIZATION — MUST DO

Arabic is the PRIMARY production language.

English is the SECONDARY supported language.

The final application must not expose avoidable hardcoded user-facing Arabic or English strings outside the localization system.

Perform a systematic audit of all user-visible strings.

Search at minimum:

- "lib/"
- presentation widgets
- pages
- dialogs
- forms
- snackbars
- validation messages
- errors shown to users
- empty states
- loading states
- confirmation dialogs
- buttons
- menus
- tooltips
- reports
- settings
- backup/restore UI
- import/export UI
- accounting UI
- POS UI
- purchases
- purchase returns
- sales
- refunds
- cashbox
- expenses
- audit log
- authentication
- permissions/RBAC
- accessibility labels
- keyboard shortcut descriptions
- document/receipt UI

Localization requirements

All user-visible strings must use the established localization architecture.

Do NOT create a second localization mechanism.

Do NOT bypass "AppLocalizations".

Do NOT duplicate localization infrastructure.

Maintain:

- Arabic
- English
- ARB key parity
- generated localization consistency

Every newly introduced user-visible string must be localized in BOTH languages.

Important distinction

Do NOT waste time mass-refactoring genuinely internal developer-only strings that are never presented to users.

Examples of potentially internal strings:

- debug-only messages
- internal identifiers
- database codes
- test descriptions
- developer comments
- internal exception diagnostics never exposed to UI

However, if an internal error/message can reach the user interface, treat it as user-visible and localize it.

Arabic quality

Arabic must be professional, natural, and suitable for a pharmacy/business application.

Do not use machine-like or awkward translations.

Maintain RTL correctness.

---

5. 4002 PURCHASE RETURNS — DO NOT CHANGE ACCOUNTING SEMANTICS

A final decision audit was performed.

Current system behavior:

- Purchase Returns are already implemented.
- Stock is reduced through the purchase-return movement.
- FinancialPostingService handles the financial posting.
- Current posting is effectively:
  - Debit supplier payable / cash / bank as applicable
  - Credit inventory
- Account "4002" exists as "Purchase Returns".
- It is intentionally unused by the current posting engine.
- Existing tests explicitly protect this behavior.

DO NOT activate or substitute account "4002" merely because the account exists.

DO NOT alter purchase-return accounting semantics in Phase 16.

DO NOT create duplicate accounting entries.

DO NOT break FinancialPostingService.

Supplier replacement/exchange

A normal supplier exchange may be represented by:

1. returning the original goods;
2. receiving the replacement goods as a new purchase/receipt.

Do not invent a new exchange accounting model in Phase 16.

If the current workflow already supports the operational scenario, leave it intact.

If you discover a genuinely missing, small, low-risk UX improvement around supplier replacement, it may qualify as a Controlled Enhancement ONLY if all Controlled Enhancement rules below are satisfied.

---

6. ITEMS EXPLICITLY CLOSED — DO NOT TOUCH

The following decisions are final unless current-code inspection proves an actual regression or correctness bug:

Unknown username audit

DO NOT expand the audit schema merely to log unknown usernames.

The application is a local desktop POS.

Role name synchronization

DO NOT change role "name" semantics.

Stable internal role codes and localized/display labels are intentionally separate.

Settings/Audit caching

DO NOT introduce caching without a measured performance problem.

In-memory login session

DO NOT introduce persistent login sessions.

The existing session behavior is intentional for this local application.

---

7. CONTROLLED ENHANCEMENT POLICY

Controlled Enhancements ARE explicitly allowed.

However, they must remain controlled.

The goal is:

«Improve the final product when a small, safe improvement is clearly justified — without turning Phase 16 into uncontrolled feature development.»

A Controlled Enhancement MUST satisfy ALL of these:

1. Small scope.
2. Low implementation risk.
3. Clear benefit to pharmacy users, reliability, accessibility, localization, release quality, or maintainability.
4. Does not change the fundamental business model.
5. Does not redesign the architecture.
6. Does not introduce a new major subsystem.
7. Does not replace an existing architecture decision.
8. Does not duplicate existing functionality.
9. Does not alter core accounting semantics unless explicitly approved.
10. Does not weaken security/RBAC/audit guarantees.
11. Does not break offline-first/local SQLite architecture.
12. Is covered by appropriate tests.
13. Is documented in the Phase 16 Completion Report.
14. Is clearly labeled as "CONTROLLED ENHANCEMENT".

Examples of acceptable Controlled Enhancements

Potential examples include:

- small usability improvement discovered during final QA
- minor keyboard/navigation improvement
- small accessibility improvement
- clearer validation message
- missing localization key
- small RTL directional correction
- small empty/error/loading state improvement
- minor release/backup UX improvement
- small performance improvement with obvious measurable benefit
- small Windows-specific polish issue
- safer error handling discovered during release testing
- minor documentation/release automation improvement

These are examples, NOT authorization to implement all of them.

Only implement an enhancement when the actual code inspection shows it is useful.

NOT Controlled Enhancements

Do NOT implement:

- new major modules
- cloud backend
- multi-branch
- online synchronization
- CRM
- payroll
- banking integration
- payment gateways
- inventory redesign
- accounting redesign
- new business workflows requiring schema redesign
- new authentication architecture
- major UI redesign
- new reporting subsystem
- replacement of Drift/SQLite/Riverpod/Clean Architecture
- speculative features
- "nice to have" feature lists unrelated to release quality

When in doubt:

Do not implement. Document it instead.

---

8. PRE-IMPLEMENTATION BASELINE

Before modifying code:

Run and record:

- "flutter pub get"
- "flutter gen-l10n" if required by the project
- "flutter analyze"
- complete Flutter test suite
- relevant localization tests
- relevant accounting tests
- relevant backup/restore tests

Record:

- total tests
- passed
- failed
- skipped
- analyzer issues

Do not hide pre-existing failures.

---

9. FINAL ARCHITECTURE PROTECTION

Preserve:

- Clean Architecture
- feature-based structure
- Riverpod
- Drift/SQLite
- offline-first design
- SQLite as source of truth
- centralized FinancialPostingService
- immutable audit history
- stock movement ledger
- integer-based money representation
- basis-point percentages
- base-unit quantities
- UTC timestamps
- existing RBAC
- existing backup/restore architecture
- existing export architecture
- existing design system
- existing localization system
- existing RTL/LTR system

Do not create parallel implementations.

---

10. FINANCIAL SAFETY

Financial correctness has priority over convenience.

Never:

- use floating-point money
- bypass FinancialPostingService
- manually mutate financial balances where the existing posting engine should be used
- create duplicate journal entries
- duplicate cashbox movements
- bypass closed-period enforcement
- bypass double-posting protection
- alter historical financial transactions
- silently change accounting semantics

Run the existing financial regression tests after any financial-adjacent change.

If a proposed enhancement might affect accounting:

STOP and classify it as requiring explicit business/architecture approval unless it is already covered by the existing model.

---

11. LOCALIZATION IMPLEMENTATION

Perform a systematic hardcoded-string audit.

Use code search to identify likely user-visible strings.

For every genuine user-visible string:

1. Create/choose the appropriate ARB key.
2. Add Arabic translation.
3. Add English translation.
4. Regenerate localization files.
5. Replace direct string usage with "AppLocalizations".
6. Preserve placeholders and formatting.
7. Ensure plural/date/number formatting remains correct.
8. Ensure RTL layout remains correct.

Do not rename existing localization keys unnecessarily.

Do not create duplicate keys for an existing concept.

---

12. FINAL RTL / ACCESSIBILITY QA

Verify:

- Arabic is RTL.
- English is LTR.
- directional icons behave correctly.
- text alignment is appropriate.
- numbers remain readable.
- mixed Arabic/English strings behave correctly.
- dialogs are usable.
- tables remain readable.
- POS keyboard workflows remain usable.
- focus order is sensible.
- tooltips and semantic labels are localized.
- contrast remains WCAG AA compliant where applicable.
- no text is clipped because of Arabic length.
- no layout overflow appears because of localization.

Do not redesign the UI.

Fix only genuine issues found during QA.

---

13. WINDOWS RELEASE VERIFICATION

Use the existing GitHub Actions Windows runner if available.

The release pipeline must verify:

1. checkout
2. stable Flutter
3. dependencies
4. localization generation
5. analyze
6. tests
7. Windows release build
8. artifact upload

The Windows build must actually execute.

Do not merely inspect YAML and declare success.

If a Windows runner/build fails:

- diagnose the actual failure;
- fix only what is necessary;
- rerun the workflow;
- verify the final successful run.

Do not suppress errors.

Do not make the workflow "green" by removing meaningful checks.

---

14. RELEASE ARTIFACT

Determine the appropriate final artifact format based on the existing project.

At minimum verify the generated Windows release artifact.

If an installer/package mechanism already exists, validate it.

If no installer exists:

Do NOT introduce a large installer framework unless it is genuinely required and can be implemented safely within Phase 16.

A portable/self-contained Windows release artifact is acceptable if that matches the project's current distribution model.

Document exactly how the release is distributed.

---

15. VERSIONING

Inspect the current version in:

- "pubspec.yaml"
- application metadata
- Windows packaging metadata if applicable
- README/release documentation

Establish a coherent final release version.

Do not randomly change version numbers.

Ensure the final version is documented consistently.

---

16. CHANGELOG / RELEASE NOTES

Create or update a professional release/changelog document.

Include:

- final release version
- major completed capabilities
- important Phase 15 hardening
- Phase 16 release work
- localization completion
- Windows build verification
- important accounting/security guarantees
- backup/restore status
- known limitations
- intentionally unchanged items
- Controlled Enhancements, if any

Do not claim functionality that does not exist.

---

17. FINAL REGRESSION TESTING

After all changes:

Run:

- complete test suite
- "flutter analyze"
- localization generation
- relevant targeted tests
- accounting tests
- purchase return tests
- financial integrity tests
- RBAC tests
- audit tests
- backup/restore tests
- export tests
- RTL/accessibility tests
- POS keyboard tests
- any tests added during Phase 16

Target:

Tests

0 failures
0 unexpected skips

Analyze

0 issues

Do not weaken tests to make the result pass.

---

18. WINDOWS FINAL GATE

The final Phase 16 release MUST NOT be marked fully release-ready until a real Windows build has succeeded.

Record:

- workflow run
- Windows build result
- artifact name
- artifact size if available
- commit/tag associated with the build
- test result
- analyze result

If possible, perform a basic smoke launch of the generated application.

If runtime launch cannot be automated, document that limitation explicitly.

---

19. FINAL PRODUCTION READINESS CHECKLIST

Verify:

Application

- [ ] Flutter analyze clean
- [ ] full test suite green
- [ ] Windows release build successful
- [ ] application artifact generated
- [ ] version consistent
- [ ] startup verified where possible

Localization

- [ ] Arabic complete
- [ ] English complete
- [ ] ARB parity verified
- [ ] no avoidable user-visible hardcoded strings
- [ ] RTL verified
- [ ] LTR verified

Financial

- [ ] FinancialPostingService remains the single posting engine
- [ ] no floating money
- [ ] double-posting protection intact
- [ ] closed-period enforcement intact
- [ ] purchase returns intact
- [ ] 4002 semantics intentionally unchanged
- [ ] financial invariants pass

Security

- [ ] RBAC intact
- [ ] audit log intact
- [ ] sensitive mutations audited
- [ ] no security regression

Data

- [ ] SQLite source of truth intact
- [ ] backup works
- [ ] restore works
- [ ] export works
- [ ] no destructive migration introduced unnecessarily

UX

- [ ] POS usable
- [ ] keyboard shortcuts usable
- [ ] RTL directional icons correct
- [ ] accessibility checks pass
- [ ] contrast checks pass
- [ ] no obvious overflow/clipping

---

20. KNOWN DECISIONS TO DOCUMENT

The final completion report must explicitly document:

Intentionally unchanged

- Unknown username audit
- Role name synchronization
- Settings/Audit caching
- In-memory login session
- "4002 Purchase Returns" accounting usage

Explain briefly why each remains unchanged.

For 4002 specifically:

State that purchase returns are already supported through the existing posting model and that activating the unused 4002 account was intentionally rejected because it would alter established accounting semantics without a demonstrated requirement.

---

21. FINAL COMPLETION REPORT

Create:

"PHASE16-COMPLETION-REPORT.md"

It must include:

Executive Summary

Scope Audit

Handoff Audit

Phase 16 Implemented Items

Full Localization Audit

Windows Build Verification

Release Artifact Verification

Controlled Enhancements

For each enhancement:

- title
- reason
- files changed
- risk
- tests
- why it qualifies as Controlled Enhancement

If none were necessary:

"No Controlled Enhancements were required."

Financial Integrity Verification

Security/RBAC Verification

Backup/Restore Verification

Accessibility/RTL Verification

Test Results

Analyze Results

Version / Release Information

Known Limitations

Intentionally Unchanged Decisions

Final Release Readiness

The final status must be one of:

- "RELEASE READY"
- "RELEASE READY WITH DOCUMENTED LIMITATIONS"
- "NOT RELEASE READY"

Do not use "RELEASE READY" if the Windows build gate failed.

---

22. RELEASE TAG

If repository permissions and the existing release workflow support it:

Create a proper version tag such as:

"vX.Y.Z"

only after all final gates pass.

Do not tag a failed release.

If tagging cannot safely be performed by the current environment:

Document the exact tag that should be created manually.

---

23. COMMIT DISCIPLINE

All Phase 16 changes must be committed.

Use a professional commit message, for example:

"release: finalize phase 16 production release"

Do not commit:

- temporary files
- debug output
- generated junk
- credentials
- secrets
- local environment files
- build caches

Verify the working tree after completion.

---

24. FINAL STOP CONDITION

Do not continue inventing work after the release gates pass.

Once:

- scope audit is complete,
- approved Phase 16 work is complete,
- localization is complete,
- tests pass,
- analyze is clean,
- Windows build succeeds,
- release artifact is verified,
- documentation is complete,

STOP.

This is the end of the planned roadmap.

Any future feature should be treated as a NEW project phase/version after this release.

Controlled Enhancements are allowed only within the rules above and must never become an excuse for uncontrolled scope expansion.

---

25. FINAL RESPONSE TO THE USER

At the end report concisely:

1. Phase 16 status.
2. Final version.
3. Test count/pass/fail/skip.
4. Flutter analyze result.
5. Windows build result.
6. Release artifact.
7. Localization result.
8. Controlled Enhancements implemented, if any.
9. Known limitations.
10. Commit SHA.
11. Release tag, if created.

Do not claim success without evidence.

FINAL PRINCIPLE

This is the final release phase.

Be conservative with architecture and accounting.

Be aggressive about correctness, localization, testing, Windows verification, usability, accessibility, and release quality.

Finish the product — do not reinvent it.