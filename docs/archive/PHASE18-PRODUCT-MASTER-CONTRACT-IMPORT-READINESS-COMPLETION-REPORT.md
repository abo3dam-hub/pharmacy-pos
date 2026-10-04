# Phase 18 — Product Master Contract & Import Readiness — Completion Report

**Status:** Delivered · **Schema version:** 12 · **Test suite:** 566 passing · **`flutter analyze`:** 0 errors (2 expected `experimental_member_use` warnings)

> Companion to `PROJECT-ARCHITECTURE-PLAN.md` (§4/§5 updated to reflect schema v12) and the
> `SYRIAN-DRUGS-2026-DATABASE-ANALYSIS.md` readiness study.

---

## 1. Goal

Make the product master ready for large catalogs (e.g. the ~5k‑row Syrian drug file) by removing
requirements that force manual per‑row grooming and replacing them with a minimal, import‑friendly
contract while keeping the rich relational metadata that was previously held in free‑text columns:

1. **Product contract:** only the **trade name** is required. `categoryId`, units, parts and
   partial-sale settings are fully optional.
2. **Dropped legacy classification:** `sub_categories` and `therapeutic_groups` tables are removed
   (schema v12). Classification is a single optional `items.category_id`.
3. **Relational active ingredients & indications** (with per‑ingredient strength) supplant the flat
   free-text summary at the data level, while the flat `activeIngredient` column is still
   auto-maintained for search/POS fallback.
4. **Smart Alternatives** become relational-first (shared ingredients) with a flat-token fallback.
5. **Excel import** reads minimal rows (trade name + barcode + `name:strength` ingredient cell) and
   matches existing products by barcode then trade name.
6. **Error messaging:** replace the generic «حدث خطأ أثناء حفظ البيانات» with targeted messages for
   duplicate values, invalid references and unexpected DB errors.

---

## 2. What changed

### 2.1 Domain / data / schema
- `items.categoryId` → nullable `TextColumn` (no FK enforced — this schema emits constraints via
  `unique()` only; FKs are absent by design).
- `sub_categories` and `therapeutic_groups` tables + `TherapeuticGroupDao` + `groups_use_cases.dart`
  deleted; DI (`injection.dart`, `providers.dart`) and restore-service wiring updated.
- `ItemDraft` contract: `categoryId`/`units`/parts fields all optional; trade name is the only hard
  requirement. `_applyUnits` no-ops on null units (verified by dedicated tests).
- `InventoryItemView` / `PosCatalogItem` carry `activeIngredients: List<ItemIngredientRef>` (id/name/
  strength) and `indicationNames`; `InventoryViewBuilder` guards the nullable category.
- `ItemActiveIngredientDao.forItemIds` / `ItemIndicationDao.forItemIds` batch loads for list views.

### 2.2 Product form / UX
- Searchable, multi-row **active-ingredient selector** with per-row strength field and remove action
  (l10n: `itemActiveIngredientsSearch`, `itemActiveIngredientsHint`, `itemActiveIngredientsRemove`).
- Trade-name-only saves are permitted everywhere (units/parts/category optional).

### 2.3 Smart Alternatives (relational)
- `PosCatalogDao.alternativeCandidates` = products sharing ≥1 active-ingredient relation, falling
  back to flat `activeIngredient` token LIKE when no relational data exists.
- `SmartAlternativesService.compositionTokens` normalizes joined names + strengths.

### 2.4 Excel import (v12 layout)
- 23-column headers; `'المواد الفعالة'` @ col 6 / `'الاستطبابات'` @ col 9; ingredient cell
  `name:strength` joined by `;`/`؛`.
- Minimal rows allowed (trade name + barcode + optional ingredient cell). Unknown master names /
  inactive items → issue row + skip.
- Match order: existing DB product id → scanned barcode → trade-name fallback → create if new.

### 2.5 Targeted save errors («حدث خطأ» fix)
Root cause: raw `SqliteException`s bubbled to master-data saves (`on Exception` → generic), and
`DatabaseFailure` messages were swallowed by the UI fallback. Fixes:
- `InventoryRepositoryImpl._guarded` now classifies constraints: `SQLITE_CONSTRAINT_UNIQUE`
  (2067) → `DuplicateException` «البيانات موجودة مسبقًا (ربما الاسم أو الباركود مستخدم بالفعل)»;
  `SQLITE_CONSTRAINT_FOREIGNKEY` (787) → `ValidationException` (defensive, unreachable in this
  schema); everything else → `DatabaseException` with its own message.
- All master-data saves (category/manufacturer/unit/ingredient/indication) are now wrapped in the
  same mapping — a duplicate name surfaces a targeted message instead of the generic one.
- `items_tab` and `master_data_tabs` render a non-empty `DatabaseFailure.message` instead of the
  generic `authSaveError`.
- `InventoryController` catches any non-`AppException` exception and returns a
  `DatabaseFailure('حدث خطأ غير متوقع أثناء الحفظ')` instead of leaking to the UI.

### 2.6 Schema / backup
- `kCurrentSupportedSchemaVersion` → 12 (backup/restore/lifecycle suite).
- v12 migration: `DROP INDEX IF EXISTS` stale category/group item indexes → `TableMigration(items)`
  (nullable categoryId) → `DROP TABLE IF EXISTS sub_categories / therapeutic_groups`. `beforeOpen`
  re-enables FKs. `TableMigration` is experimental → the 2 expected analyzer warnings.

---

## 3. Test coverage (566 passing)

- `migration_test.dart` — `_V1Database` mirror at v12; fresh + v1→v12 upgrades assert `user_version`,
  dropped tables, `categoryId` nullable, trade-name-only insert; `\"notnull\"` keyword quoting.
- `item_save_regression_test.dart` — **9 regression tests** including:
  - save 2: create WITHOUT units succeeds (Phase 18 contract),
  - save 5: duplicate barcode on create → `DuplicateException`,
  - save 8: duplicate barcode on **update** → `DuplicateException`,
  - save 9: duplicate master-data name (category) → `DuplicateException`, not a generic save error.
- `item_form_ux_test`, `inventory_controller_busy_regression_test`, `smart_alternatives_repo_test`,
  `pos_domain_test` updated to the new optional-field contract and relational candidates.
- Removed `TherapeuticGroupDao` references across 5 files; restored `stock_movement_dao` imports;
  `categoryId: const Value(...)` helper fixes across 8 test files.

## 4. Quality gates
- `flutter analyze` — clean; only the 2 expected `experimental_member_use` warnings.
- `flutter test` — **566 / 566 green** (64.3s).

## 5. Out of scope / unchanged
FEFO, ledger/stock, purchase/sales/returns/accounting, prescriptions, Phase 17 partial-sale pricing,
audit/permission/backup architecture, `ActiveIngredients`/`Indications` masters.

## 6. Follow-up (not started — per instructions, do NOT begin without a new directive)
- Syrian medicine database phase: seeding the ~5k-row catalog from `syrian_drugs_final_verified.csv`.