# نظام الصيدلية — Pharmacy Management & POS

A professional **Arabic-first, offline-first Pharmacy Management & Point-of-Sale
(POS)** application built with Flutter. Primary production platform is
**Windows Desktop**; Android is supported for development/testing.

- **Version:** `1.0.0+1` (release tag `v1.0.0`)
- **License / distribution:** self-contained portable Windows build
- **Full release notes:** [`CHANGELOG.md`](./CHANGELOG.md)
- **Architecture & database specification:** [`PROJECT-ARCHITECTURE-PLAN.md`](./PROJECT-ARCHITECTURE-PLAN.md)

## Features

- Items / inventory, batches (FEFO), expiry tracking, stock movement ledger
- Purchases, receipts, bonus engine, purchase returns, supplier statements
- POS workspace: barcode scanning, cart, hold bills, cash/card/mixed/credit
  payments, partial-sale units, invoice returns & voiding, receipt printing,
  lost sales, smart alternatives
- Customers / prescriptions, credit accounts, customer statements
- Cash box, expenses, customer payments, accounting periods, financial close
- Double-entry accounting via a single `FinancialPostingService`, journals,
  trial balance, income statement, balance sheet, Z-report
- RBAC roles/permissions, user management, append-only audit log, rebindable
  keyboard shortcuts
- Online backup / validated restore / CSV export
- Arabic (RTL, primary) + English (LTR) localization with exact ARB parity

## Tech stack

Flutter (stable) · Riverpod · Drift/SQLite (offline-first) · Clean Architecture
(feature-based) · GoRouter · ARB localization (`flutter gen-l10n`)

## Building & testing

```sh
flutter pub get
flutter gen-l10n
flutter analyze
flutter test
```

### Windows release build

Requires a Windows host with the Visual Studio C++ toolchain:

```sh
flutter build windows --release
# Output: build/windows/x64/runner/Release/
```

The repository's GitHub Actions workflow (`.github/workflows/ci.yml`) runs
analyze + tests on Linux for every push/PR and produces the Windows release
build on `v*` tags (`build-windows` job), uploading the artifact
`pharmacy-pos-windows`.

## Distribution model

The release is distributed as the **portable self-contained Windows build**
(`Release/` folder: `pharmacy_pos.exe` + bundled native SQLite DLL, fonts,
assets and plugins). No installer is produced.

## Development seed

A development-only `admin` account with password `Admin@123` is seeded for
non-production builds; the production flow sets a real admin password at
first-run setup.