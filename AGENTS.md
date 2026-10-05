# AGENTS.md — pharmacy-pos

Instructions for any agent working in this repository. Follow them; they
encode Ali's standing decisions.

## Documentation policy (Ali, 2026-10-04)

**Living documents — the ONLY source of truth. Keep them updated with every
change:**

| Document | Update when |
|---|---|
| `README.md` | behavior or build/install changes |
| `CHANGELOG.md` | every notable change |
| `PROJECT_STATUS.md` | every change — it is the entry point for future agents |
| `PROJECT-ARCHITECTURE-PLAN.md` | architecture/database changes |
| `design.md` | design-system changes |

**Rules:**

1. After every code/docs change, update the living documents above so they
   reflect the actual current state. Reports must never lag behind the code.
2. `PROJECT_STATUS.md` is the single current-state doc — a future agent must
   be able to understand the exact project state from it alone. No
   contradictions between living documents are allowed.
3. Dated completion/fix reports are written **once**, then **frozen** in
   `docs/archive/` — never updated, never resurrected as current. Their key
   facts must also be merged into `CHANGELOG.md` / `PROJECT_STATUS.md`.
4. `docs/archive/` is history. Do not treat anything there as current, and do
   not create new root-level dated reports.
5. When in doubt, the living documents win over archived ones.

## Pushing

- Never use raw `git push` (no HTTPS credentials in this environment).
- Push with: `python3 ~/workspace/skills/github/bin/git_push.py --repo-dir ~/workspace/pharmacy-pos --owner abo3dam-hub --repo pharmacy-pos --ref main`
- Afterwards: `git fetch origin`, verify `git diff origin/main main` is empty,
  then `git reset --hard origin/main`.

## Environment

- Flutter SDK is at `~/workspace/.sdks/flutter` — export to `PATH` before any
  `flutter`/`dart` command. Pinned version: 3.44.2 (also pinned in CI).
- Tests need `ensureSqlite()` before sqlite3 use (see `test/helpers.dart`).
- `/tmp` is a 512M tmpfs: clean `/tmp/flutter_tools.*` before full test runs.

## Load-bearing rules

- Package↔base-unit cost conversion lives ONLY in
  `lib/core/units/package_cost.dart` (half-up) — never duplicate or
  approximate it elsewhere.
- CI (`.github/workflows/ci.yml`): 4 jobs (`analyze-test`, `perf-file-db`,
  `build-windows`, `build-android`). Android is **arm64-only**; release APKs
  are signed with a stable keystore restored from the `ANDROID_KEYSTORE_B64`
  repo secret; `versionCode` = `github.run_number` (must strictly increase).
- Full suite must stay green: `flutter analyze` clean, `flutter test` all
  passing — never reduce test coverage to save CI time.
- The whole-package guardrail test
  (`test/whole_package_display_guardrail_test.dart`) uses **line-based**
  allowlist entries for `purchase_form_page.dart` and `pos_workspace_page.dart`.
  Any edit to those files can shift the allowlisted lines and fail CI even when
  the code is correct — after touching them, run
  `flutter test test/whole_package_display_guardrail_test.dart` locally and
  fix the entry numbers before pushing (2026-10-05: missed entry broke CI #132).
- Never claim "CI green" in a commit message without checking the actual run —
  verify on GitHub Actions before declaring it (2026-10-05).
