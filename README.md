# نظام الصيدلية — Pharmacy Management & POS

A professional **Arabic-first, offline-first Pharmacy Management & Point-of-Sale
(POS)** application built with Flutter. Primary production platform is
**Windows Desktop**; Android is supported for development/testing.

- **Version:** `1.1.0+1` (pubspec; `versionCode` on CI builds comes from
  the CI run number — see Android section below)
- **License / distribution:** self-contained portable Windows build
- **Full release notes:** [`CHANGELOG.md`](./CHANGELOG.md)
- **Architecture & database specification:** [`PROJECT-ARCHITECTURE-PLAN.md`](./PROJECT-ARCHITECTURE-PLAN.md)
- **Current project state:** [`PROJECT_STATUS.md`](./PROJECT_STATUS.md)

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

### End-to-end tests (on-device)

`integration_test/` drives the real app on a real device through the actual
UI (login → dashboard → POS sale → receipt), using a hermetic in-memory
database — it never touches the real database. Run on Windows or with an
Android device/emulator connected:

```sh
flutter test integration_test
```

Current coverage: app smoke (launch → login → dashboard → POS) and the full
POS sale flow (search → add → quantity → cash pay → receipt → DB assertions).

### Windows release build

Requires a Windows host with the Visual Studio C++ toolchain:

```sh
flutter build windows --release
# Output: build/windows/x64/runner/Release/
```

The repository's GitHub Actions workflow (`.github/workflows/ci.yml`) runs
`analyze-test`, `perf-file-db`, `build-windows`, and `build-android` on every
push to `main`, every PR, and every `v*` tag. A newer push cancels the stale
run (`concurrency: cancel-in-progress`). Flutter is pinned to `3.44.2` in all
jobs.

### Android release build (arm64-only)

```sh
flutter build apk --release --target-platform android-arm64
# Output: build/app/outputs/flutter-apk/app-release.apk (~45-50MB)
```

- **arm64 only** (per Ali's decision, 2026-10-04): the 32-bit armv7 slice is
  dropped; arm64 covers virtually all Android devices in use.
- **Signing:** the release build signs with the Gradle debug keystore, but CI
  restores a **stable** keystore (generated once, stored as the
  `ANDROID_KEYSTORE_B64` repo secret) before building — every CI APK carries
  the same certificate.
- **versionCode:** CI passes `--build-number=${{ github.run_number }}`, so it
  strictly increases with every build.
- **Installs as an update:** newer APKs install over older ones, no
  uninstall needed. Exception: the *first* stable-key build still requires
  one manual uninstall if the phone currently has an APK signed with an older
  random CI key.
- `applicationId`: `com.pharmacy.pharmacy_pos`.

## Distribution model

The release is distributed as the **portable self-contained Windows build**
(`Release/` folder: `pharmacy_pos.exe` + bundled native SQLite DLL, fonts,
assets and plugins). No installer is produced.

## Development seed

A development-only `admin` account with password `Admin@123` is seeded for
non-production builds; the production flow sets a real admin password at
first-run setup.