# Product Management UX Fixes — v1.1.0 Fix Report

**Release:** `v1.1.0` (was v1.0.1)
**Scope:** The Product Management UX review round (Phase "v1.1 Product Management
UX fixes"). Every item below corresponds to one requested fix from the review
list and includes what changed, where, and how it is verified.

Regression baseline: `flutter analyze lib test` → **0 issues**;
`flutter test` → **532/532 pass** (including the two new regression suites).

---

## 1. Scrollable sidebar — every section (incl. Settings) stays reachable

**Requested fix:** On short screens the sidebar overflowed and sections
(notably **Settings**) fell out of reach.

**Change:** `NavigationRail` in `lib/core/widgets/app_shell.dart` is now
`scrollable: true`, so the destination list scrolls instead of overflowing.

**Files:** `lib/core/widgets/app_shell.dart`.

**Verify:** `test/item_form_ux_test.dart` — *"desktop rail is scrollable;
settings stays reachable"* (500px-tall viewport, Settings tapped after
scrolling).

## 2. Search-as-you-type selection in product master lists

**Requested fix:** Product master dropdowns (category, sub-category,
manufacturer, therapeutic group) offered long flat lists with no way to
search.

**Change:** New reusable `SearchableDropdownField<T>` widget — a text field
that filters options as you type. Used by every product master selector plus
the unit and packaging selectors.

**Files:** `lib/core/widgets/searchable_dropdown_field.dart` (new).

**Verify:** Widget tests select master rows through the typeahead
(`test/item_form_ux_test.dart`); the widget is exercised on every open state
and auto-suggest path.

## 3. Inline creation of master records, auto-selected after saving

**Requested fix:** When a master record (category, sub-category, manufacturer,
therapeutic group, supplier, unit) did not exist, the user had to leave the
product form, open the master-data page, create it, and come back.

**Change:** Each dropdown carries an **inline "+" action** that opens a small
create form directly in the product dialog. On success the new row is
auto-selected in the dropdown.

**Files:** `lib/features/inventory/presentation/widgets/item_dialog.dart`,
`items_tab.dart` (`_createMasterData`, `_createSupplier`).

**Verify:** `test/item_form_ux_test.dart` — *"inline category creation
auto-selects the created row"*.

## 4. Sub-category list filtered by the chosen category

**Requested fix:** Sub-categories were shown regardless of the parent
category.

**Change:** After a category is picked, the sub-category dropdown only lists
that category's sub-categories (empty category → empty, clearly filtered
list).

**Files:** `lib/features/inventory/presentation/widgets/item_dialog.dart`.

**Verify:** `test/item_form_ux_test.dart` — *"subcategory dropdown is filtered
by the chosen category"* (picks "أدوية" then expects "مضادات حيوية", absent
from the other category).

## 5. Items ↔ suppliers many-to-many (removed the single-supplier model)

**Requested fix:** An item had at most one supplier; pharmacies need several
(primary, wholesaler, manufacturer rep).

**Change:** New `item_suppliers` link table and schema **v9**:
`id` (text PK), `itemId` FK → Items, `supplierId` FK → Suppliers, composite
unique `{itemId, supplierId}`. The repository saves supplier links in the
*same transaction* as the item (create and update), dedupes, and replaces the
link set. Bulk/Excel item import preserves existing links.

**Files:** `lib/shared/database/tables/item_suppliers.dart` (new),
`lib/data/daos/item_supplier_dao.dart` (new: `forItem`, `supplierIdsForItem`,
`setForItem`), `lib/shared/database/app_database.dart` (v9 + `from < 9`
migration), `inventory_repository_impl.dart`, `inventory_repository.dart`
(`ItemDraft.supplierIds`).

**Verify:** `test/item_save_regression_test.dart` — suppliers persist,
dedupe, update, and survive bulk shelf edits; `test/migration_test.dart`
mirrors the v9 link table.

## 6. Supplier selection as chips in the product form

**Requested fix:** Choosing multiple suppliers had no in-form affordance.

**Change:** The suppliers section renders a filter **chips row**; tapping a
chip toggles the supplier on/off before saving.

**Files:** `lib/features/inventory/presentation/widgets/item_dialog.dart`.

**Verify:** `test/item_form_ux_test.dart` — *"supplier chips toggle a
many-to-many selection in the draft"* (two suppliers → both → untoggle one →
one).

## 7. Packaging (commercial unit) dropdown introduced and auto-suggested

**Requested fix:** The "commercial unit" was vague; the product mockup shows a
packaging/large unit with a clear label and the base unit pre-filling it.

**Change:** A dedicated packaging dropdown (`شكل التعبئة (الوحدة التجارية)`).
Selecting the base unit **auto-suggests it as the packaging unit** (editable,
not locked).

**Files:** `lib/features/inventory/presentation/widgets/item_dialog.dart`,
ARB key `itemPackagingUnit`.

**Verify:** `test/item_form_ux_test.dart` — membership test asserts the
packaging field shows the auto-suggested "شريط", then editing keeps the user's
value.

## 8. Form field order and labels match the mockup

**Requested fix:** The dialog order (name → barcode → master data → suppliers
→ units → cost/sell prices → partial-sale → stock → switches) and its labels
should match the reviewed mockup.

**Change:** Product dialog rebuilt in the reviewed order; labels clarified
(e.g. packaging label, units relation, cost/sell price section).

**Files:** `lib/features/inventory/presentation/widgets/item_dialog.dart`,
ARB keys `itemPackagingUnit`, `itemSuppliers`, `itemAddNew`.

**Verify:** `test/item_form_ux_test.dart` — *"form order and packaging label
match the product mockup"* (asserts section labels appear in order).

## 9. Stop the generic save error

**Requested fix:** Any failed save surfaced the catch-all
"حدث خطأ أثناء حفظ البيانات", hiding the real cause.

**Change:** Repository `_guarded` maps failures to typed exceptions —
`SqliteException` → `DuplicateException`/`DatabaseException`,
`ValidationException` stays typed, `UnauthorizedException` → permission
failure. The items tab shows a specific, localized message per type
(duplicate barcode, permission denied, etc.); `authSaveError` is now only the
final fallback.

**Files:** `lib/features/inventory/data/repositories/inventory_repository_impl.dart`,
`items_tab.dart` (`_showFailure`), `lib/core/errors/exceptions.dart`.

**Verify:** `test/item_save_regression_test.dart` — duplicate barcode raises
`DuplicateException` (not a generic failure).

## 10. Targeted validation messages for unit relations

**Requested fix:** Saving without units produced the generic error instead of
telling the user exactly what is missing.

**Change:** `_validate` reports each missing part specifically: base unit
needed, packaging unit needed, and unit relation required when units or
barcodes are present.

**Files:** `lib/features/inventory/presentation/widgets/item_dialog.dart`,
ARB keys `inventoryUnitsRequired`, `inventorySelectBaseUnit`,
`inventorySelectLargeUnit`.

**Verify:** `test/item_form_ux_test.dart` — membership test asserts the
"select base unit" guidance.

## 11. Units-per-large validation wired (bug found by the new tests)

**Requested fix (found in testing):** the units-per-large "invalid" message
could never appear because the input field was not wired — entered values were
ignored and the enforced value stayed at the seeded default.

**Change:** The units-per-large `TextFormField` now syncs its value into the
state via `onChanged`, so ≤ 0 is rejected with
`inventoryUnitsPerLargeInvalid` and the entered value is what persists.

**Files:** `lib/features/inventory/presentation/widgets/item_dialog.dart`,
ARB key `inventoryUnitsPerLargeInvalid`.

**Verify:** `test/item_form_ux_test.dart` — membership test enters `0` and
asserts the targeted message; `test/item_save_regression_test.dart` — entered
values persist.

## 12. Partial-sale section connected end-to-end

**Requested fix:** The partial-sale UI was cosmetic; the sellable-part unit,
parts count, and parts-base quantity did not drive the saved draft.

**Change:** The partial-sale group now selects the **sellable-part unit**,
**parts per full package**, and **base units per part**, and stores them on
the draft.

**Files:** `lib/features/inventory/presentation/widgets/item_dialog.dart`.

**Verify:** `test/item_save_regression_test.dart` — a null partial-sale
markup round-trips through edit; widget tests drive the group live.

## 13. Default 10% markup auto-filled when partial sales are enabled

**Requested fix:** Enabling partial selling should default the markup to the
business standard 10%.

**Change:** Flipping the partial-sale switch pre-fills the markup field with
`10` (persisted as integer basis points).

**Files:** `lib/features/inventory/presentation/widgets/item_dialog.dart`.

**Verify:** `test/item_form_ux_test.dart` — *"partial-sale switch auto-fills
the default markup and validates"* asserts `10` appears immediately.

## 14. Partial-sale targeted validation

**Requested fix:** Partial-sale save errors were opaque; parts/base mistakes
gave no direction.

**Change:** Specific messages: sellable-part unit required
(`partialSaleUnitRequired`), parts required (`partialSalePartsRequired`),
parts must be > 1 (`partialSalePartsInvalid`), base units required
(`partialSaleBaseRequired`), base units must be > 0 (`partialSaleBaseInvalid`),
markup must be ≥ 0 (`partialSaleMarkupInvalid`).

**Files:** `lib/features/inventory/presentation/widgets/item_dialog.dart`,
ARB keys `partialSaleUnitRequired`, `partialSalePartsRequired`,
`partialSalePartsInvalid`, `partialSaleBaseRequired`, `partialSaleBaseInvalid`,
`partialSaleMarkupInvalid`.

**Verify:** `test/item_form_ux_test.dart` — parts = 1 asserts
"عدد الأجزاء في العبوة الكاملة يجب أن يكون أكبر من 1".

## 15. Suppliers shown/edited from the items grid side

**Requested fix:** Item rows should indicate suppliers and let the user edit
them without leaving the list.

**Change:** The items tab loads supplier rows, opens the product dialog in
edit mode with pre-selected supplier chips, and saves the link set back.

**Files:** `lib/features/inventory/presentation/widgets/items_tab.dart`.

**Verify:** suppliers edit round-trip in `test/item_save_regression_test.dart`.

## 16. Bulk (shelf) item edit preserves supplier links

**Requested fix:** Updating many items at once must not drop their suppliers.

**Change:** The bulk shelf-edit path and Excel import keep existing links;
materialized rows carry `supplierIds` untouched.

**Files:** `inventory_repository_impl.dart`, `inventory_repository.dart`
(`fromRow`/`copyWith`), `bulk_use_cases.dart`, `excel_use_cases.dart`.

**Verify:** `test/item_save_regression_test.dart` — bulk shelf edit then
checks `item_suppliers` rows survive.

## 17. Localization parity for the new v1.1 messages

**Requested fix:** Every new message must exist in both Arabic and English.

**Change:** 13 ARB keys added (see items above) in `app_ar.arb` + `app_en.arb`;
`flutter gen-l10n` regenerated the localizations; parity remains enforced.

**Files:** `lib/l10n/app_ar.arb`, `app_en.arb`, generated
`app_localizations*.dart`.

**Verify:** `test/localization_parity_test.dart` — 13-key v1.1 parity test.

## 18. Schema v9 migration correctness

**Requested fix:** A restore or downgrade must be checked against the new
schema version consistently.

**Change:** `kCurrentSupportedSchemaVersion` in
`lib/features/backup/domain/entities/backup_manifest.dart` bumped **8 → 9**
(the stale constant was the root cause of failing restore expectations).
Test mirrors updated to schema 9.

**Files:** `backup_manifest.dart`, `test/backup_archive_test.dart`,
`test/backup_service_test.dart`, `test/restore_service_test.dart`,
`test/migration_test.dart`, `test/inventory_test.dart`.

**Verify:** full suite backup/restore/migration tests green
(restore tamper test now uses `999` to stay "future").

## 19. Permanent item-save regression suite

**Requested fix (for safety):** the original save/validation flows that were
broken in v1.0.x require permanent coverage.

**Change:** `test/item_save_regression_test.dart` replaces the throwaway repro
file: valid create, no-units validation, base == packaging, partial-sale
markup persistence, duplicate barcode `DuplicateException`, suppliers M2M
persist/dedupe/update, bulk shelf-edit supplier preservation.

**Files:** `test/item_save_regression_test.dart` (new), `test/_repro_save_test.dart`
(deleted).

**Verify:** 100% of the suite passes.

## 20. UX/widget regression suite

**Requested fix (for safety):** the UI behaviors in items 1–8 must not
silently regress.

**Change:** `test/item_form_ux_test.dart` (new) — 7 widget tests covering the
rail scroll, targeted validation, form order/labels, supplier chips, inline
category auto-select, filtered sub-category, and partial-sale markup +
validation, all through the real `showItemFormDialog` surface.

**Files:** `test/item_form_ux_test.dart` (new).

**Verify:** 7/7 pass.

## 21. Full-baseline verification and release

**Requested fix:** the release gate must re-run the whole baseline and ship a
real Windows artifact.

**Change:** `flutter analyze lib test` → 0 issues; **full `flutter test` →
532/532 pass**. Version bumped to `1.1.0+1` (`pubspec.yaml`, `CHANGELOG.md`,
Windows runner metadata); the `v1.1.0` tag triggers the CI Windows release
build on Flutter 3.44.2 (kept from the v1.0.1 black-screen workaround).

**Files:** `pubspec.yaml`, `CHANGELOG.md`, `.github/workflows/ci.yml`.

**Verify:** CI build + artifact smoke on `windows-latest`.

---

## Summary of shipped files

**New:** `lib/core/widgets/searchable_dropdown_field.dart`,
`lib/data/daos/item_supplier_dao.dart`,
`lib/shared/database/tables/item_suppliers.dart`,
`test/item_form_ux_test.dart`, `test/item_save_regression_test.dart`.

**Core edits:** `app_shell.dart`, `items_tab.dart`, `item_dialog.dart`,
`inventory_repository_impl.dart`, `inventory_repository.dart`,
`bulk_use_cases.dart`, `excel_use_cases.dart`, `app_database.dart` (+gen),
`backup_manifest.dart`, `exceptions.dart`, DI/providers, `app_ar/en.arb`
(+gen l10n).

**Schema:** database **v8 → v9** (`item_suppliers`, composite unique
`{itemId, supplierId}`), migration created in app code and mirrored in tests.