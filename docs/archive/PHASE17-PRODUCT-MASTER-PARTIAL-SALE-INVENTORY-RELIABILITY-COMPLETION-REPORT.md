PHASE 17 — PRODUCT MASTER REDESIGN + PARTIAL-SALE RELIABILITY: COMPLETION REPORT

Status: SHIPPED ✓

Branch: `main`
CI: `analyze-test` workflow — success ✓ (see workflow run for the landing commit)
Full details: see project audit notes (schema v11 upgrades below).

---

Shipped in this phase

1. Product-master form redesign (`item_dialog.dart`)
   - Sections in the mandated order: الباركود/الاسم → التصنيف والمعلومات الدوائية
     (category + manufacturer with inline create, الاستطبابات chips, scientific
     name + المكافئ, materials الفعالة with per-ingredient العيار, الموردون,
     الشكل الصيدلاني/الجرعة/الحجم) → التكلفة / السعر / الأجزاء →
     المخزون → إعدادات إضافية → تعليمات الاستخدام.
   - Forbidden legacy terms removed everywhere: الوحدة الأساسية / Base
     Quantity / وحدة البيع الجزئي / سعر الوحدة الفرعية / التصنيف الفرعي /
     المجموعات العلاجية / شريط-as-sellable-part. التعبئة التجارية → الأجزاء →
     عدد الأجزاء replaces the old unit-pair model in the form.
   - `MasterDataKind` pruned to {category, manufacturer, unit, activeIngredient,
     indication}; subcategories and therapeutic groups fully removed from the UI,
     Excel template and master-data tabs (`master_data_tabs.dart`, size
     regression fixed).

2. Partial-sale reliability (root cause of the edit "حدث خطأ" bug)
   - Money.parse grouped-separators validation fixed (strict format acceptance);
     the regression was `Money.fromUnits(...).format()` seeds (e.g. `10,000.00`)
     being handed back to `Money.parse` on edit. `test/money_test.dart` 14/14.
   - Markup default moved 10% → 20%: `partial_sale_markup_basis_points` seeds to
     2000 bp; v11 migration rewrites untouched '1000' → '2000' (deliberate values
     preserved).
   - New persistent `items.partial_sale_price_micros`: NULL = automatic
     (formula via `PartialPriceCalculator`), set = manual override (سعر بيع
     الجزء) that survives save/reload/restart, restored explicitly via a
     "استعادة الحساب التلقائي" action. Authoritative at the POS through
     `PosPricing.partialSellingPricePerPart`.

3. Schema v11 + forward migration
   - New columns: `item_active_ingredients.strength` (per-ingredient العيار),
     `items.partial_sale_price_micros`.
   - `kCurrentSupportedSchemaVersion => 11`; backfill + migration bump mirrored
     in `test/migration_test.dart` (v1 → v11 path), `backup_archive_test.dart`,
     `backup_service_test.dart`.
   - Defensive guards in `_migrate(… from < 11 …)`: stores that upgrade from
     < 10 create the junction tables from the *current* schema (strength already
     present), so the column adds are existence-guarded — the v1→v11 round-trip
     proves no duplicate-column failure and no data loss.

4. Business-term inventory display
   - `compoundStockText` (new `compound_stock_text.dart`): `9 علب / 2 ظرف`,
     crosses large-unit and parts counts with Arabic pluralization (علبة→علب,
     ظرف→ظروف, Box→Boxes, Sachet→Sachets); used by the items grid stock column.
   - Seed rename: `unit_strip` 'شريط' → 'ظرف' / 'Sachet' (fresh installs).

5. Excel round-trip aligned with the new model
   - 21-column template: removed التصنيف الفرعي / المجموعة العلاجية /
     سعر الصندوق; renamed الوحدة الأساسية → الأجزاء, الوحدة الكبيرة →
     التعبئة التجارية, كمية التعبئة → عدد الأجزاء. Import preserves legacy
     `subCategoryId` / `therapeuticGroupId` / `subUnitPriceMicros`.

6. Search coverage + layered ranking
   - `ItemDao` + `PosCatalogDao` now match `equivalentDrug`, and manufacturer
     names via `SmartSearchDao` (direct FK resolution).
   - Relevance-first ordering when searching by the default order: exact
     trade-name → prefix → contains → other fields (`test/smart_search_test.dart`
     extended).

Verification

- `flutter analyze`: No issues found.
- `flutter gen-l10n`: clean (ARB swept: removed 13 obsolete keys, re-valued
  parts/packaging labels, added 8 Phase 17 keys in ar/en).
- `flutter test`: 563 tests — All tests passed.
- Batch/expiry UX kept in place and verified: `nearExpiryDays = 90`,
  `batchStatusFor` chips on the batches page, dashboard near-expiry window
  (`test/dashboard_test.dart`), add-batch expiry picker.

Follow-ups

- Physical `DROP COLUMN` for the obsolete `items` columns and the removed
  master-data rows (subcategories, therapeutic groups) in a future destructive
  schema bump.
- Old-layout Excel files will not import into the new template (export
  regenerates the 21-column layout).