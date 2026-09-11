# Phase 18.1 — Product Master Contract Corrections & Syrian DB Import Gate — Completion Report

**Status:** ✅ COMPLETED in one guided execution session.
**Baseline commit:** `681111a` (Phase 18.1 branch point; pushed to `main` as part of the `5fe6888` rebase). Current recommended `main` tip for this phase: the commit recorded at the end of this document.
**Scope governor:** run the full test suite first, document the solution, then stop. **The Syrian medicine database import was NOT started** — it is explicitly gated on this report's Definition of Done.

---

## 1. Summary

Phase 18 simplified the product contract (trade name required; units/parts/category optional), added relational active-ingredient/indication joins and a relational Smart Alternatives algorithm, and shipped a minimal-row Excel importer. Phase 18.1 closes the remaining inconsistencies so the product master is a single, well-defined contract that the **Syrian medicine database import (~14 000 rows) can be run against idempotently and losslessly**:

- The product **form** truly supports a **trade-name-only save**.
- Parts/packaging validations only fire when a **unit relation (base + large)** is actually configured; units are always saved as a consistent base+large relation.
- The **Excel import/export contract** is lossless and **blank = preserve on update** for every optional cell.
- Product **edits** (including duplicate-barcode edits) surface their **root-cause failure** instead of a generic save error.
- Smart Alternatives rank by tier → stock → **same manufacturer** → trade name, and the flat-token fallback only applies to legacy items without relational ingredients.
- Terminology inconsistency removed (`الوحدات الأساسية` filler → `الكمية`).

**Verification:** full test suite **575/575 green** (baseline 566 + 9 new), `flutter analyze` clean except the two pre-existing experimental `TableMigration` warnings.

---

## 2. Root-cause findings (what Phase 18.1 fixed)

| # | Finding | Origin | Severity |
|---|---------|--------|----------|
| 1 | The product form unconditionally required a category and forced packaging/parts validation: a **trade-name-only save was impossible** even though that IS the documented contract. | Phase 17 | High (contract breach) |
| 2 | Parts validation auto-suggested/forced a parts count even when **no unit relation** was configured — meaningless without a base unit. | Phase 17 | High |
| 3 | Save could write a `units` relation whose base unit was a part unit while `parts == 0`, or write partial-sale config with no base unit → inconsistent unit rows. | Phase 17 | Medium |
| 4 | Clearing all relational active ingredients left a **stale flat `items.active_ingredients` summary** (the DB sync only rewrites the summary when the relational input *changes*, so a full clear kept the old text). | Phase 18 | Medium |
| 5 | Excel import preserved many fields on blank but **overwrote** financial columns (sell/wholesale/cost/half-wholesale/min/max) and didn't import VAT, has-expiry, EN/scientific/flat-ingredient, secondary barcode or the new `المكافئ / الشكل الصيدلاني / الجرعة / الحجم` columns; `updateItem → _toUpdateCompanion` additionally overwrote every non-sheet column (flags, custom prices, purchase-discount, instructions, license, notes, partial-sale config) → an export→import was **lossy**. | Phases 3/18 | High (Syrian-import readiness) |
| 6 | Financial **create-vs-update asymmetry**: raw-empty/whitespace cells became non-null → 0 and overwrote existing values even on an update. | Phase 18 | High |
| 7 | A product edit that collides with an existing barcode surfaced a **generic save error** — the duplicate branch was defensive/unreachable in practice, hiding the exact root cause the UI must explain. | Phases 17/18 | Medium |
| 8 | Smart Alternatives ran the **flat-token LIKE fallback for every item**, so a fully relational item could still be matched to junk flat tokens instead of only relational candidates. | Phase 18 | Medium |
| 9 | Ranking had no **same-manufacturer** tie-break (product geographies consistently stock the same vendor's variants). | Phase 18 | Low |
| 10 | Terminology rift: the prescrip qty field and partial-sale strings used «الوحدات الأساسية» (implies a base unit) while the unit relation is optional. | Phases 17/18 | Low |

---

## 3. Classification matrix (findings → fixes → verification)

| # | Fix delivered | Files | Verified by |
|---|---------------|-------|-------------|
| 1+2+3 | `_validate`: category/packaging/parts are optional; `parts <= 0` rejected **only when a part/base unit is configured**; partial-sale requires a base unit (`inventorySelectBaseUnit`); `_submit` no longer blocks trade-name-only saves on parts; `units` saved only when BOTH base and large units are set (base auto-suggested = large when only one chosen); `partsPerFullProduct` cleared when units are dropped. | `features/inventory/presentation/widgets/item_dialog.dart` | `item_form_ux_test.dart` rewritten: *trade-name-only saves; parts guidance targets only configured units* |
| 4 | On save, when the relational selection is cleared (and the initial had relational ingredient ids), the flat `activeIngredient` summary is set to null; DB `_syncIngredientSummary` left intact. | `item_dialog.dart` | round-trips in `inventory_excel_contract_test.dart` A |
| 5+6 | Import: financial fields now blank-preserve on update / zero on create (raw-empty and whitespace-only both collapse to null); VAT, min/max, has-expiry, EN/scientific/flat ingredient, secondary barcode and the 4 new pharmaceutical columns all blank-preserve; units relation built from sheet or preserved for existing; non-sheet columns preserved through `_toUpdateCompanion`; full-profile round-trip is lossless. Export: 4 new appended columns (23–26), `عدد الأجزاء` blank when no unit relation (was `?? 1`). | `features/inventory/domain/services/inventory_excel_service.dart` | new `test/inventory_excel_contract_test.dart` A–G |
| 7 | Root-cause regression test proving an edit that duplicates a barcode returns `DuplicateFailure` with «البيانات موجودة مسبقًا», releases the busy flag and leaks no phantom row; same-save mapping already routes it to the targeted UI message. | `inventory_repository.dart` (already-correct mapping), `test/inventory_controller_busy_regression_test.dart` | new product-edit regression test |
| 8 | `alternativeCandidates`: homogeneous relational clause when the requested item has relational ingredient ids; legacy flat LIKE fallback ran only when `ingredientIds` is empty. | `data/pos_catalog_dao.dart` | `smart_alternatives_repo_test.dart` rewritten + legacy-fallback test |
| 9 | `rank` order: tier → stock desc → same-manufacturer tie-break → trade name; `PosCatalogItem.manufacturerId` (nullable) populated from the row. | `pos_catalog_dao.dart`, `smart_alternatives_service.dart`, `pos_catalog_item.dart` | new same-manufacturer ranking test |
| 10 | `prescriptionQuantity` → «الكمية» / «Quantity» (`flutter gen-l10n` regenerated); 4 user-facing `PartialPriceCalculator` strings reworded off «الوحدات الأساسية». | `l10n/app_ar.arb`, `app_en.arb`, generated localizations, `domain/services/partial_price_calculator.dart` | `app_localizations_ar.dart` `prescriptionQuantity => 'الكمية'`; analyze clean |

Plus structural cleanup: dead `subCategoryId` removed from `ItemDraft.copyWith`; stale `MasterDataDraft` doc comment and `categories.dart` comment (sub_categories removed in Phase 18) corrected.

---

## 4. Excel import/export contract (canonical)

Sheet columns (positional; indexes preserved for backward compat):

| Idx | Header | Import semantics |
|-----|--------|------------------|
| 0 | الباركود الأساسي | match key (primary/secondary) |
| 1 | الباركود الثانوي | blank-preserve |
| 2 | الاسم التجاري | required; match key when barcode blank |
| 3 | الاسم التجاري (EN) | blank-preserve |
| 4 | الاسم العلمي | blank-preserve |
| 5 | المادة الفعالة (نصي) | blank-preserve |
| 6 | المادة الفعالة (روابط) | `Name:strength` `;`-separated; blank-preserve |
| 7 | التصنيف | name→categories |
| 8 | الشركة المصنعة | name→manufacturers |
| 9 | الاستطبابات | `;`-separated names; blank-preserve |
| 10 | مكان التخزين | blank-preserve |
| 11 | تاريخ الانتهاء (له صلاحية) | blank-preserve (bool) |
| 12 | الوحدة الأساسية | blank → preserve/absent on create |
| 13 | الوحدة الكبيرة | blank → preserve/absent on create; **must be present when base is set** (issue «الوحدات») |
| 14 | عدد الأجزاء | blank; base+large skipped when both absent |
| 15 | سعر البيع | blank-preserve (update) / 0 (create) |
| 16 | سعر الجملة | blank-preserve / 0 |
| 17 | سعر نصف الجملة | blank-preserve / 0 |
| 18 | الضريبة (‰) | blank-preserve |
| 19 | سعر التكلفة | blank-preserve / 0 |
| 20 | كمية الحد الأدنى | blank-preserve |
| 21 | كمية الحد الأقصى | blank-preserve |
| 22 | كمية المخزون | informational |
| 23 | المكافئ | blank-preserve |
| 24 | الشكل الصيدلاني | blank-preserve |
| 25 | الجرعة / العيار | blank-preserve |
| 26 | الحجم | blank-preserve |

Blanks normalize via `null`/empty/whitespace → preserve; **non-sheet fields** (flags, custom prices, purchase discount, usage instructions, general notes, license, partial-sale configuration) always preserve because `updateItem → _toUpdateCompanion` mirrors them from the existing row when the draft carries no change.

---

## 5. Tests

New / rewritten:

- `test/inventory_excel_contract_test.dart` (new, 7 tests A–G): A lossless full-profile round-trip (all financials, flags, partial-sale config, strengths, indications, units, new columns); B no-units item exports blank `عدد الأجزاء` and round-trips with `units == null`; C trade-name-only sheet row creates with defaults; D blank cells on update preserve existing values; E `Name:strength` `;`-separated relational ingredients; F partially-specified unit relation rejected with «الوحدات» issue; G financial optional — zero on create, preserve on update.
- `test/item_form_ux_test.dart` (rewritten case): trade-name-only save succeeds; parts guidance targets only configured units; parts relation saves with base=large unit.
- `test/smart_alternatives_repo_test.dart` (rewritten): relational-primary candidates; flat fallback only for legacy items; same-manufacturer ranking tie-break.
- `test/inventory_controller_busy_regression_test.dart` (new case): duplicate-barcode edit river `DuplicateFailure` with «البيانات موجودة مسبقًا», busy released, total unchanged.

**Full suite: 575/575 passed.** `flutter analyze`: clean except two pre-existing experimental `TableMigration` warnings.

---

## 6. Definition of Done — checklist

- [x] Trade-name-only product save works (form + Excel row + repo create path).
- [x] Parts/packaging validation fires only when a unit relation is configured; partial-sale requires a base unit.
- [x] `units` always saved as a consistent base+large relation; cleared fields propagate (units/pieces/part-price/active-ingredient summary).
- [x] Excel export has the 4 new pharmaceutical columns; blank parts when no units.
- [x] Excel import is blank-preserve for every optional column (financials, flags, barcodes, ingredients, indications, units) and lossless on full-profile round-trip (A–G tests green).
- [x] Financial create-vs-update asymmetry removed (raw-empty → null → preserve-on-update / 0-on-create).
- [x] Product-edit root-cause regression test green (DuplicateFailure + message + busy released).
- [x] Smart Alternatives relational-primary; flat fallback only for legacy; manufacturer tie-break ranking.
- [x] Terminology: `prescriptionQuantity` = الكمية; `PartialPriceCalculator` strings reworded.
- [x] Full suite green (575/575); analyze clean (2 known warnings).
- [x] `PROJECT-ARCHITECTURE-PLAN.md` updated (§5 Excel contract, §18 ranking, glossary, phase history).
- [x] Report written; branch pushed; commit SHA recorded; GitHub Actions CI verified.
- [ ] **NOT in scope — will not be started by this phase:** Syrian medicine database import (~14 000 rows). It proceeds only as a separately-scoped follow-up now that the gates above are met.

---

## 7. How to run

```bash
flutter pub get
flutter gen-l10n
dart run build_runner build --delete-conflicting-outputs   # if generated files change
flutter analyze
flutter test
```