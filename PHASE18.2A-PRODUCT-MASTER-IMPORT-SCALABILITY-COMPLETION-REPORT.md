# Phase 18.2A — Product Master Contract Closure & Scalable Import Engine — Completion Report

**Status:** ✅ COMPLETED in one guided execution session.
**Baseline commit:** `c1bcf3b` (Phase 18.1 final state on `main`, all suites green).
**Phase 18.2A commit on `main`:** `3491c49` (see §7).
**Scope governor:** run the full test suite, document the solution, then stop. **The Syrian medicine database import was NOT started** — Phase 18.2A only removes the last contract and scaling obstacles so that import can run idempotently; the import itself remains a separately-scoped follow-up.

---

## 1. Summary

Phase 18/18.1 delivered a trade-name-only product contract and a lossless blank-preserve Excel importer. Phase 18.2A closes the remaining product-master contract gaps and makes the Excel import/export engine **safe to run against the ~14 000-row Syrian medicine database**:

- **Product master contract closed:** only the trade name is required; every other master field is optional. Create/edit with a trade name alone succeeds; parts/packaging unit relations stay optional and a **blank edit never erases an existing relation**; prices/cost are never an import condition; each active ingredient stays **paired with its strength** (الكامل System: `name:strength` `;`-separated list).
- **Excel lossless round-trip preserved:** trade/EN/scientific names, active-ingredient + strength pairs, equivalent, indications, category, manufacturer, pharmaceutical form, dose, size and the optional operational/financial fields survive export→import, and **blank = preserve on update**.
- **Deterministic, never-guessing matching:** 1) exact barcode (primary/secondary index) → authoritative; an unmatched barcode creates a brand-new row; 2) composite identity (normalized trade name + active-ingredient/strength pairs + pharmaceutical form + dose + manufacturer) with strict equality on every provided discriminator; 3) **more than one candidate → conflict/ambiguous** (row reported, skipped); no global fuzzy matching; no source ids become barcodes; `package_shape`/size/units are **not** part of the identity. Duplicate trade names across doses/forms/manufacturers resolve correctly.
- **Scalability:** the full catalog is loaded **once per operation** and indexed in memory (barcode → item, normalized trade name → candidates, plus bulk relational ingredient/indication/unit projections). There are **no `pageSize: 10000` calls and no per-row catalog scan** in the export/import pipeline (`_findByScanned` and `_matchingItem` removed). The row loop yields to the event loop every 256 rows, writes remain transactional per row, and the grid builder was bulk-ified.
- **Edit error messaging:** unchanged from Phase 18.1 — the product edit that collides with an existing barcode surfaces the real translated root cause («البيانات موجودة مسبقًا») via the regression test, not a generic save error.

**Verification:** `flutter analyze` **clean (0 issues)**; full test suite **581/581 green** (Phase 18.1 baseline 575 + 6 new Phase 18.2A scalability tests); the Phase 18.1 Excel contract A–G tests stay green.

---

## 2. What was closed (root causes → fixes → verification)

| # | Finding (root cause) | Fix delivered | Verified by |
|---|----------------------|---------------|-------------|
| 1 | `_findByScanned`/`_matchingItem` ran `searchItems(PageRequest(pageSize: 10000))` for **every sheet row** and matched by trade-name prefix — after record 10 000 the catalog disappears and every remaining row becomes a duplicate create; it also fuzzy-matched on trade name. | Catalog loaded **once** per parse (`_ItemCatalog` in `inventory_excel_service.dart`): `allItems()` + bulk `activeIngredientRelationsForItems` / `indicationIdsForItems` / `itemUnitsForItems`; per-row matching is pure in-memory index lookup; `_findByScanned` deleted; unused `PageRequest` import dropped. | `test/inventory_import_scalability_test.dart` — call-counting `CountingRepo` wrapper: exactly **`2` `allItems()`** calls (1 export + 1 import) and **`0` `searchItems()`** for a 14 001-row round-trip. |
| 2 | Export also used `searchItems(pageSize: 10000)` — an export could silently truncate a catalog larger than 10 000 rows. | `ExportItemsUseCase` uses `repo.allItems()` (no page ceiling, ordered by trade name). | 14 001-row export produces a sheet with header + 14 001 rows (`maxRows == 14002`). |
| 3 | `InventoryViewBuilder.buildMany` issued N+1 lookup queries (category/manufacturer/units per row) → export of large catalogs was quadratic. | One pass: bulk `categories()`/`manufacturers()`/`units()` name maps + `itemUnitsForItems` + existing `activeIngredientRefsForItems`/`indicationNamesForItems`. | Export/import round-trip scale test (view builder used by `ExportItemsUseCase`). |
| 4 | Matching guessed/overmatched: barcode unmatched still fell back to trade name; identical trade names were "matched" arbitrarily; `package_shape` diff alone could pick one of several products. | Deterministic priority — **barcode exact first** (unmatched barcode = new row, no fallback), then **composite identity** with strict equality per provided discriminator; **>1 candidate → ambiguous conflict** (row skipped with «أكثر من منتج» issue); units/package excluded from identity. | Duplicate-name test (trade name + dose/form/manufacturer/strength resolve to exactly the right id; name-only with two candidates is ambiguous); package-shape test (identical composite + different size/units still ambiguous). |
| 5 | Same sheet could carry the same barcode/identity twice → duplicate items or confusing second-write. | In-file duplicate targeting rejected with «مكرر داخل الملف» (key = `b:<code>` / `i:<matched id>` / `c:<creation identity>`). | In-file duplicate test: 2 identical rows → 1 created, 1 «مكرر داخل الملف» issue, item count stays 1. |
| 6 | Re-importing an exported sheet after an edit could duplicate items (e.g. barcode erased by a partial edit). | The import path remains a clean barcode/composite **update**, and the contract test pins that a provided barcode is authoritative (intermediate partial `ItemDraft`s that intend to preserve a barcode keep it). | Re-import test: same sheet twice → first create 2, second update 2 / create 0 / count stays 2; financial blank-preserve test G re-pinned. |

---

## 3. Safe matching algorithm (canonical, Phase 18.2A)

For each sheet row, in order, **never guessing**:

1. **Barcode** (primary or secondary cell, non-blank) → exact lookup in the in-memory barcode index.
   - Found → that item is the target (update).
   - **Not found → a brand-new row** (unambiguous create). Source/database ids are never synthesised into barcode cells, and a mismatched barcode never fuzzy-matches a similar product.
2. **No barcode** → normalized Arabic trade name (`SmartSearch.normalize`: alef-family/yeh/tā-marbuta folding, tashkeel stripping, lower-case) →
   - candidates = items whose normalized trade name is identical;
   - narrow to the candidates whose stored profile matches **every discriminator the row actually provides**, exactly:
     - active-ingredient **id + strength pairs** (each provided pair must exist with the same normalized strength on the candidate; the sheet's `Name:strength` entries are resolved to ids first),
     - pharmaceutical form (normalized equality),
     - dose/العيار (normalized equality),
     - manufacturer id (FK equality);
     - blank cells provide **no** discriminator (blank = preserve on update).
   - Result: **0 candidates → create** (unambiguous), **1 → update that item**, **>1 → conflict/ambiguous** (row reported «يطابق أكثر من منتج» and skipped).
3. `package_shape` / size volume, unit relations and any flat-string fields are **never** part of the identity.
4. Within the file, each targeting key (barcode / matched item id / creation identity) may appear **once**; repeats raise «مكرر داخل الملف».

Rationale recorded in the file doc comment of `lib/features/inventory/domain/services/inventory_excel_service.dart`.

---

## 4. Anti-slowness / anti-freeze method (the ~14 000-row proof)

- **One-shot catalog:** `_ItemCatalog.load(repo)` = 1× `allItems()` + 3 bulk relational projections, then in-memory indexes (barcode, normalized trade name). Every per-row lookup is a hash/array access — **zero extra DB round trips per row**.
- **No `pageSize` ceiling anywhere** in export (`allItems()`) or import (was `searchItems(pageSize: 10000)` ×2 call sites). Out-of-scope paged lookups elsewhere (customers/suppliers `100000`, search `20`) are untouched — they are bounded corrective pages, not bulk catalog loads.
- **Chunked, non-blocking:** the parse loop `await Future<void>.delayed(Duration.zero)` every 256 rows — cooperative yielding fixed rate, **no fragile wall-clock assertions** in tests.
- **Transactional writes:** each row is applied through the existing `createItem`/`updateItem` repository transactions (units + supplier junction + relational ingredients/indications in one DB transaction) and audited.
- **Bulk grid/export builder:** `InventoryViewBuilder.buildMany` resolves categories/manufacturers/units/ingredients/indications in one pass.
- **Proof (structural):** `CountingRepo` (test wrapper) overrides `allItems`/`searchItems`; the 14 001-row export→import does **exactly 2 `allItems()` calls and 0 `searchItems()` calls**, and `created == 0, updated == 14001, issues == []`. Under the Phase 18.1 implementation rows 10 001+ were unreachable (page-size ceiling) and would have become duplicate creates.

---

## 5. Tests

`test/inventory_import_scalability_test.dart` (new, 6 tests; `inventory_excel_contract_test.dart` A–G unchanged and green):

| Test | Proves |
|------|--------|
| 14 001-row export/import matches every row with one catalog load, no scans | matching stays correct **after record 10 000**; `allItemsCalls == 2`, `searchItemsCalls == 0`, `created == 0`, `updated == 14001`, item count still 14001; sheet `maxRows == 14002` |
| Duplicate trade names disambiguate via dose/form/manufacturer | name-only → ambiguous issue; full composite → exact id (not the sibling); single dose discriminator → exact id |
| package_shape / units are never part of the identity | identical composite with different size/unit relation stays ambiguous (never a guess) |
| Unknown barcode creates; no source id is ever synthesised | unmatched barcode → new row with the sheet barcode stored as-is; pre-existing products untouched |
| In-file duplicate rows target one item only | duplicate barcode in one sheet → 1 created + «مكرر داخل الملف» issue, count 1 |
| Re-importing the same sheet updates instead of duplicating | second import → `updated`, never `created`, item count stable |

Also re-pinned: Phase 18.1 contract test G (the intermediate in-app edit that intends to keep a barcode now carries it, so the update matches by the authoritative barcode), and the product-edit duplicate-barcode regression test (`inventory_controller_busy_regression_test.dart` + `item_form_ux_test.dart` + `smart_alternatives_repo_test.dart`) all still green.

**Full suite: 581/581 passed.** `flutter analyze`: **0 issues**.

---

## 6. Definition of Done — checklist

- [x] Trade-name-only product contract: create/edit with trade name alone succeeds; all other master fields optional.
- [x] Parts/packaging unit relations optional; a blank edit never erases an existing relation (repo already preserves `units` when the draft carries none; import resolves preserved units from the in-memory catalog).
- [x] Prices/cost never an import condition; optional cells blank-preserve on update / zero on create.
- [x] Each active ingredient stays paired with its strength (relational `name:strength` + preserve on blank).
- [x] Excel contract lossless (trade/EN/scientific, ingredients+strengths, المكافئ, indications, category, manufacturer, form, dose, size, operational/financial) — A–G suite green.
- [x] Safe matching: barcode-exact → composite-exact → ambiguous→conflict; no fuzzy/guessing; source ids never barcodes; `package_shape` excluded from identity; duplicate trade names across dose/form/manufacturer resolve correctly.
- [x] Scalability: no `pageSize: 10000`; one catalog load + index access per row; no per-row catalog scan; chunked/non-blocking; bulk `buildMany`.
- [x] 14 000+-row test: export/matching correct after record 10 000; no-scan proof (structural, call-counting); duplicate-name/ambiguous/dedupe/no-dup-import tests.
- [x] Edit-error root-cause regression green; no fragile time limits anywhere.
- [x] `flutter analyze` clean (0 issues); full suite green (581/581).
- [x] `PROJECT-ARCHITECTURE-PLAN.md` updated (§5 Excel contract matching & scalability, phase history).
- [x] Report written; commit pushed; commit SHA recorded below; GitHub Actions CI verified.
- [ ] **NOT in scope — will not be started:** the Syrian medicine database import itself continues as a separately-scoped follow-up phase.

---

## 7. Commits & CI

| Item | Value |
|------|-------|
| Baseline | `c1bcf3b` |
| Phase 18.2A commit on `main` | `3491c49` |
| CI (GitHub Actions `ci.yml`) | **success** — `analyze-test` (flutter analyze + full flutter test suite), `build-windows`, `build-android` all green (run `34596786540`) |

---

## 8. How to run

```bash
flutter pub get
flutter analyze
flutter test test/inventory_import_scalability_test.dart test/inventory_excel_contract_test.dart
flutter test                        # full suite
```