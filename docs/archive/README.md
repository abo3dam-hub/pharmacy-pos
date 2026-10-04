# Archive — historical reports & prompts

This directory holds **point-in-time** documents: phase completion reports,
implementation prompts, old fix reports, and one-off analyses. They are
**frozen** — kept for history, never updated.

**Do not treat anything here as current.** The living, maintained documents
are at the repository root:

| Document | What it is |
|---|---|
| `../AGENTS.md` | **Agent instructions** — docs policy, push rule, env, load-bearing rules |
| `../README.md` | Project overview, setup, build & install instructions |
| `../CHANGELOG.md` | History of notable changes (updated with every change) |
| `../PROJECT_STATUS.md` | **The current state of the project** — start here |
| `../PROJECT-ARCHITECTURE-PLAN.md` | Authoritative architecture & database specification |
| `../design.md` | Design-system specification |
| `../ALI-FOUR-FIXES-REPORT-2026-10-04.md` | Latest fix round (drawer, list auto-load, APK signing, CI) |
| `../DASHBOARD-VISUAL-REFRESH-REPORT-2026-10-04.md` | Latest visual-refresh round |

Rule (per Ali, 2026-10-04): after every code change, update the root living
documents (`CHANGELOG.md`, `PROJECT_STATUS.md`, `README.md` when behavior or
build changes). Dated reports are written once, then frozen here.
