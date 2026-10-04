# Ali's four fixes — completion report (2026-10-04)

Ali's four notes from the visual-refresh round, investigated and fixed in one
pass. Related: `DASHBOARD-VISUAL-REFRESH-REPORT-2026-10-04.md`,
`CHANGELOG.md` ([Unreleased] — 2026-10-04 entries).

---

## 1. Android navigation drawer did not close after tapping a section

**Symptom:** on Android (compact width < 600px), tapping a drawer destination
(Inventory, Sales, …) navigated but left the drawer open on top of the new
page.

**Root cause:** `lib/core/widgets/app_shell.dart` — `onDestinationSelected`
called `onSelect(...)` (navigation) but never dismissed the drawer, which is
a modal route. `NavigationDrawer` does not auto-close. Desktop was unaffected
(it uses `NavigationRail`).

**Fix:** pop the drawer route before navigating:

```dart
onDestinationSelected: (i) {
  Navigator.of(context).pop(); // dismiss the drawer (modal route)
  onSelect(AppSection.values[i]);
},
```

**Regression test:** `test/design_system_test.dart` — "tapping a drawer
destination closes the drawer": opens the drawer at 400px width, taps
Inventory, asserts the drawer is gone and the section changed.

---

## 2. List pages did not load their data on entry (startup race)

**Symptom:** sales history (and other lists) showed empty on entry; data
appeared only after touching the search field.

**Investigation result — it was NOT a missing initial load.** Every list page
already queries in `initState` via `Future.microtask`. The real bug is a
**startup race**: drift opens the database executor lazily
(`driftDatabase(name: 'pharmacy_pos')`), and the very first query can fire
before it is ready. The query throws, the page shows its empty state, and it
stays that way until a manual reload (the search field's debounced
`onChanged` re-fires `_load()`, by which time the DB is open — exactly the
reported symptom). Prior art: commit `e53cd4a` (2026-09-25) fixed the
identical symptom on the returns page with a single 800ms delayed retry —
but only that page got the fix.

**Fix (root, not per-page):** `main()` is now async and warms up the database
before the first frame — new `lib/core/database_warmup.dart`
(`warmUpDatabase`, bounded 3-attempt retry, never blocks startup; pages keep
their own error handling). One fix covers every list page — sales history,
returns, purchases, inventory, batches, suppliers, customers, expenses,
accounts, audit, prescriptions, reports, users — present and future. The
returns page keeps its local retry as belt-and-braces.

**Tests:** `test/database_warmup_test.dart` — warm-up opens the DB so the
first query succeeds; warm-up never throws even on a closed DB.

---

## 3. APK now installs as an update (no more uninstall-first)

**Symptom:** installing a newer APK over the older one (sideloaded) forced a
full uninstall first.

**Root causes — two independent blockers, both fixed:**

1. **Unstable signing key.** Release builds sign with the Gradle *debug*
   keystore (`android/app/build.gradle.kts`), and GitHub runners are
   ephemeral — every CI run generated a brand-new debug keystore, so
   consecutive APKs carried different certificates and Android rejected the
   install (`INSTALL_FAILED_UPDATE_INCOMPATIBLE`). **Fix:** generated one
   keystore once (30-year validity, standard debug credentials), stored it
   base64-encoded as the `ANDROID_KEYSTORE_B64` repo secret; CI decodes it to
   `~/.android/debug.keystore` before the build. Zero changes to
   `build.gradle.kts` needed. Keystore SHA-256 fingerprint:
   `11:6E:69:B3:D6:53:80:BE:84:F3:9F:18:BA:81:A0:AA:8D:54:62:FC:1D:3B:88:AA:43:72:E8:D6:4F:D4:B3:4F`
   (private key kept at `~/workspace/pharmacy-pos-keystore/`).
2. **Frozen `versionCode`.** `pubspec.yaml` was `1.1.0+1` through every
   release — every APK ever shipped had `versionCode = 1`, and Android only
   accepts an install as an update when the new `versionCode` is strictly
   greater. **Fix:** CI now builds with
   `--build-number=${{ github.run_number }}` (only ever increases per repo).

`applicationId` (`com.pharmacy.pharmacy_pos`) was verified fine — no change
needed.

**One unavoidable caveat for Ali:** the APK currently on his phone was
signed with a random key, so the *first* stable-key build still requires one
manual uninstall. Every build after that updates in place.

---

## 4. CI / test speed review (no safety reduction)

**Measured** (last green run `37206581583`, universal APK) — critical path
**~11.3 min**:

| Job | Time | Notes |
|---|---|---|
| `analyze-test` | 3.9 min | of which `flutter test` (738 tests) only **2.4 min** |
| `build-android` | 7.4 min | **bottleneck**: 6.0 min release APK build |
| `build-windows` | 4.8 min | parallel |
| `perf-file-db` | 1.8 min | parallel; ~70% redundant setup for one test file |

**Key finding:** the test suite is *not* the problem (2.4 min on CI), and all
old tests run on every push by design — that is the safety net. The felt wait
is the 6-minute APK build plus builds queueing behind tests.

**Changes** (`.github/workflows/ci.yml`):
- Gradle cache (`~/.gradle/caches` + `~/.gradle/wrapper`, keyed on
  `android/**/*.gradle*` + `pubspec.lock`) — biggest win, ~1–3 min off the
  APK build.
- `concurrency: cancel-in-progress` — a newer push cancels the stale run
  instead of queueing two full runs.
- Pub cache via `subosito/flutter-action` `cache: true` in all jobs.
- Flutter pinned to `3.44.2` in all jobs (was `stable` in three, `3.44.2` in
  one — same-run SDK inconsistency fixed).
- `timeout-minutes` on every job (20/15/20/25) — a hung test can no longer
  burn a runner for hours.

**Deliberately NOT done:** test sharding (2.4 min doesn't justify it),
skipping old tests on push (that *is* the safety net), running builds in
parallel with tests (wastes 6-min builds on broken commits).

**Realistic target:** critical path **~7–8 min** (was ~11.3), with zero test
coverage lost. The arm64-only build (commit `74c27e0`, §5) also trims the
APK build.

---

## 5. arm64-only build (already pushed 2026-10-04)

Per Ali's decision: CI builds `--target-platform android-arm64` only
(commit `74c27e0`). Expected APK ~45–50MB (was ~95MB universal); actual size
to be confirmed from the built artifact.

---

## Verification

- `flutter analyze`: **clean**
- `flutter test`: **741 tests pass** (738 + 2 warm-up + 1 drawer regression)
- CI: green run to be confirmed after push (all four jobs)

---

*Report written 2026-10-04. All changes pushed to `main`
(`abo3dam-hub/pharmacy-pos`).*
