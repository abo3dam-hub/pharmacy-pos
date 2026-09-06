# Design System & UI Foundation — Preflight Report

Status: **Aligned** to the approved pharmacy identity.

Commit: `893a805` — `chore: align ui foundation with pharmacy design system` (pushed to `origin/main`).
Verification: `flutter analyze` → No issues found; `flutter test` → **76/76 passing** (64 Phase 1 + 12 new design-system).

---

## 1. Existing UI Foundation (audit)

Before this preflight the presentation layer was limited to an Arabic-first app shell and l10n pipeline delivered in phase 1:

- `lib/main.dart` — `PharmacyApp` + `HomeShell` + `AppSection` (replaced here by the central design system).
- `lib/l10n/` — Arabic-first catalog (`app_ar.arb` template + `app_en.arb`), 87 keys ar/en parity, generated getters. **Kept intact.**
- `assets/fonts/` — Cairo (`Cairo-Regular.ttf`) + Tajawal (`Tajawal-Regular.ttf`) bundled and registered in `pubspec.yaml`. **Kept intact.**
- No `lib/core/theme`, `lib/core/widgets`, `lib/core/router`, or `lib/features/` existed — the design system is created fresh under `lib/core/` with **no duplication**.

## 2. Changes made (Preflight-Only Design System Foundation)

All new files: `lib/core/theme/*`, `lib/core/widgets/*`, `lib/core/constants/app_sections.dart`, `test/design_system_test.dart`; edited `lib/main.dart` + `test/widget_test.dart`.

Phase 2 (Authentication & Users) was **not started**. No business functionality was added. Phase 1 domain/data/database logic was **untouched**.

## 3. Design system (single source of truth)

One centralized tree — no second theme/colors/widgets anywhere:

| File | Responsibility |
|---|---|
| `app_colors.dart` | `AppColors` token source (light + dark) |
| `app_dimensions.dart` | `AppSpacing` (4–32), `AppRadius` (6/8/12), `AppLayoutTokens`, `AppLayout`, `AppBreakpoints` |
| `app_text_styles.dart` | `AppTypography` ThemeExtension + `context.appTypography` |
| `app_theme.dart` | `AppTheme.light()/dark()` — full M3 component themes |
| `constants/app_sections.dart` | `AppSection` nav map (§3) |
| `widgets/*` | `AppShell`+`AppDrawer`, `showAppConfirmDialog`, `LoadingOverlay`, `SearchField`, `AmountField`, `AppDataTable`, `AppResponsiveLayout` |

## 4. Theme

Modern Clinical + Professional + Calm + Premium via `ColorScheme.fromSeed` plus **explicit token mapping** (`error`, `secondary`):

- **Primary:** calm medical green `0xFF00696D` (existing seed, preserved).
- **Accent:** muted purple `0xFF7B6A9E` (used sparingly).
- **Neutrals:** white / warm-gray (`canvas`, `surface`, `surfaceContainer`);
- **Text:** charcoal `textPrimary`, secondary `textSecondary`.
- **Semantic:** success green `0xFF2F855A`, warning amber `0xFFB47A1E`, error calm red `0xFFB3403A`, info calm blue `0xFF2F6FAD` + dark counterparts.
- Dark theme maps the same tokens (`darkCanvas` `0xFF141716`, `darkPrimary` variant, etc.).

No neon, no busy surfaces, no excessive glassmorphism/cards.

## 5. Typography

Cairo is the applied font (bundled, wired via `AppConfig.fontFamilyArabic`); Tajawal is the bundled fallback (`AppConfig.fontFamilyFallback`). Needed for `TabularFigures` ledger-style figures. Single named hierarchy in `AppTypography`:

`pageTitle 28`, `sectionTitle 22`, `body 16`, `bodySecondary 14`, `label 14`, `labelSmall 12`, `table 13` (+tabular), `tableHeader 12`, `numeric/numericStrong`, `price`, `quantity`, `invoiceNumber`.

All screens read styles from `context.appTypography` — no ad-hoc `TextStyle`s.

## 6. RTL / LTR

- Arabic-first default `locale: ar` (RTL); `supportedLocales [ar, en]`; delegates configured.
- Directionality is locale-driven; all components use direction-agnostic icons/layout — verified RTL (Arabic default) and LTR (English override through an optional `locale` param on `PharmacyApp`, test-only).
- Type set on `MaterialApp` (`AppTheme.light()`, `darkTheme`) so every descendant inherits the design system.

## 7. Responsive foundation (§33)

`AppBreakpoints`/`AppLayout`:
- **Desktop ≥ 900px** — persistent `NavigationRail` + content (Windows Desktop priority).
- **Tablet 600–899px** — collapsed rail.
- **Compact < 600px** — `NavigationDrawer` via hamburger.

Shared `AppResponsiveLayout` selects per-layout children; `AppShell` routes all modules through the same frame. Verified by widget tests for desktop (rail) and compact (drawer) widths.

## 8. Shared widgets (reusable by later phases)

- `AppShell` + `AppDrawer` — navigation + content frame with `AppBar` and `_SectionPlaceholder` (no business logic).
- `showAppConfirmDialog` — themed confirm, destructive variant uses `colorScheme.error`.
- `LoadingOverlay` — calm blocking progress layer + optional label.
- `SearchField` — debounced search with clear button.
- `AmountField` — RTL-aware, money-shaped digits only (matches `Money` scale, max 4 decimals).
- `AppDataTable` — themed `DataTable` (single rows), empty state, `DataTableTheme` styling.
- `AppResponsiveLayout` — layout-breakpoint compositor.

## 9. Tests

`test/design_system_test.dart` (new) — palette/typography/token wiring, dark variant, spacing/breakpoints, RTL default + English LTR, responsive navigation, and shared-widget smoke tests (confirm dialog, loading overlay, search clear, `AppDataTable` empty/'rows', `AmountField` sanitization). `test/widget_test.dart` updated to the desktop-aware shell.

## 10. Flutter analyze

`flutter analyze` → **No issues found.**

## 11. Git

- `git status` clean of unintended files before commit.
- Commit: `893a805 chore: align ui foundation with pharmacy design system`.
- Pushed: `0b0e331..893a805 main -> main`.

---

## Gate checklist

- ✅ No second architecture / theme / colors / widget tree (single source under `lib/core`).
- ✅ Phase 1 intact (64 tests green, untouched domain/data/database).
- ✅ Phase 2 (Authentication & Users) **not started**.
- ✅ Design system ready for later phases (theme/colors/typography/shared widgets/responsive).
- ✅ `flutter analyze` No issues; `flutter test` 76/76.
- ✅ Commit `893a805` + push `origin/main`.
- ✅ Stopped; awaiting the separate Phase 2 prompt.

---

## 12. Addendum — Phase 2 (Authentication & Users) shipped on this foundation

The auth/user module (Phase 2) was built **on top of** the funds above without duplicating or restyling them:

- `LoginPage`, `AccessDeniedPage`, `UsersPage` and the user dialogs consume only `AppColors` / `AppSpacing` / `AppRadius` / `AppTypography` / `AppTheme` tokens (no new literals) and reuse `AppShell`, `AppResponsiveLayout`, `AppDataTable`, `SearchField`, `LoadingOverlay`, `showAppConfirmDialog`.
- `AppShell` gained optional `selectedSection` / `child` / `onSectionSelected` / `appBarActions` (backward-compatible; the design-system tests still pass).
- `AppDataTable` now scrolls horizontally when columns exceed the viewport (wide users grid).
- Phase 2 added `AppSection.users`, GoRouter routes and `NavigationRail`/drawer entry reuse the same `AppSection` label + icon SSOT.

This foundation remains the single source of truth; the PLAN §0 contract now names the exact SSOT files and immutability rules.