# Phase 6 — Partial Sale Implementation Report

**Commit:** `d796d39` on `main`
**Baseline:** `12c0ae8` (155 tests, 0 analyzer issues)
**Result:** `d796d39` (195 tests, 0 analyzer issues)
**Date:** 2026-09-06

---

## 1. Database Layer

### 1.1 New Table: `app_settings`

**File:** `lib/shared/database/tables/app_settings.dart` (new, 16 lines)

Key-value store for global application settings. Stores the default partial-sale markup.

| Column | Type | Purpose |
|---|---|---|
| `key` | TEXT PK | Setting name (e.g., `partial_sale_markup_basis_points`) |
| `value` | TEXT | Setting value (e.g., `1000` = 10%) |
| `updatedAt` | INTEGER | Epoch millis |
| `updatedBy` | TEXT NULL | User who last changed it |

### 1.2 Modified Table: `items`

**File:** `lib/shared/database/tables/items.dart` (lines 68–92 added)

5 new nullable columns added after `currentStockBase`:

| Column | Type | When Disabled | When Enabled |
|---|---|---|---|
| `partialSaleEnabled` | BOOLEAN DEFAULT false | false | true |
| `sellablePartUnitId` | TEXT NULL FK→Units | NULL | NOT NULL |
| `partsPerFullProduct` | INTEGER NULL | NULL | NOT NULL (>1) |
| `sellablePartBaseQuantity` | INTEGER NULL | NULL | NOT NULL (≥1) |
| `partialSaleMarkupBasisPoints` | INTEGER NULL | NULL | NOT NULL (0–10000) |

### 1.3 Schema Migration

**File:** `lib/shared/database/app_database.dart`

- **Schema version:** `1` → `2`
- **Migration logic** (`_migrate` method):

```dart
if (from < 2) {
  // Phase 6: add 5 columns to items + create app_settings
  await m.addColumn(items, items.partialSaleEnabled);
  await m.addColumn(items, items.sellablePartUnitId);
  await m.addColumn(items, items.partsPerFullProduct);
  await m.addColumn(items, items.sellablePartBaseQuantity);
  await m.addColumn(items, items.partialSaleMarkupBasisPoints);
  await m.createTable(appSettings);
  // Seed default: 10% = 1000 bp
  await into(appSettings).insert(...);
}
if (from < 3) {
  await m.createTable(backups); // existing migration
}
```

- **Table list:** `AppSettings` added to `@DriftDatabase(tables: [...])`

### 1.4 Seed Data

**File:** `lib/shared/database/seed_data.dart` (lines 261–268 added)

On fresh database creation, seeds:

```dart
await db.into(db.appSettings).insert(
  AppSettingsCompanion.insert(
    key: 'partial_sale_markup_basis_points',
    value: '1000', // 10%
    updatedAt: now,
  ),
);
```

### 1.5 Enum Update

**File:** `lib/shared/models/enums.dart` (line 106)

```dart
// Before:
enum PrescriptionStatus { active, dispensed, expired, cancelled }

// After:
enum PrescriptionStatus { active, partially_dispensed, dispensed, expired, cancelled }
```

---

## 2. Domain Layer

### 2.1 New Service: `PartialPriceCalculator`

**File:** `lib/domain/services/partial_price_calculator.dart` (new, 203 lines)

Pure domain service with 3 public methods:

**`calculatePartialPrice()`** — Implements the locked pricing formula:

```dart
partialBasePrice = sellingPriceMicros ÷ partsPerFullProduct  // half-up
partialSellingPrice = partialBasePrice × (10000 + markupBasisPoints) ÷ 10000  // half-up
```

**`convertToBase()`** — Converts sellable-part quantity to base units:

```dart
baseQuantity = sellablePartQuantity × sellablePartBaseQuantity
```

**`decompose()`** — Splits a quantity into full products + remainder for pricing:

```dart
completeProducts = quantity ÷ partsPerFullProduct
remainingParts = quantity % partsPerFullProduct
totalPrice = (completeProducts × fullRetailPrice) + (remainingParts × partialSellingPrice)
totalBaseQuantity = quantity × sellablePartBaseQuantity
```

**`validate()`** — Validates partial-sale configuration:

- When disabled: all fields must be NULL
- When enabled: all fields mandatory, `partsPerFullProduct > 1`, `sellablePartBaseQuantity ≥ 1`, markup 0–10000
- **Consistency invariant:** `partsPerFullProduct × sellablePartBaseQuantity = unitsPerLarge` (when `unitsPerLarge` is provided)

Returns `PartialSaleDecomposition` data class with: `completeProducts`, `remainingParts`, `totalBaseQuantity`, `totalPriceMicros`.

---

## 3. Repository Layer

### 3.1 `ItemDraft` Extended

**File:** `lib/features/inventory/domain/repositories/inventory_repository.dart`

5 new fields added to `ItemDraft` constructor (defaults match disabled state):

```dart
final bool partialSaleEnabled;          // default: false
final String? sellablePartUnitId;       // default: null
final int? partsPerFullProduct;         // default: null
final int? sellablePartBaseQuantity;    // default: null
final int? partialSaleMarkupBasisPoints; // default: null
```

Updated in 3 places:

1. **Constructor** — new parameters with defaults
2. **`fromRow()` factory** — reads from `ItemRow`:

```dart
partialSaleEnabled: row.partialSaleEnabled,
sellablePartUnitId: row.sellablePartUnitId,
partsPerFullProduct: row.partsPerFullProduct,
sellablePartBaseQuantity: row.sellablePartBaseQuantity,
partialSaleMarkupBasisPoints: row.partialSaleMarkupBasisPoints,
```

3. **`copyWith()`** — includes partial-sale fields

### 3.2 Repository Implementation

**File:** `lib/features/inventory/data/repositories/inventory_repository_impl.dart`

Updated 2 methods:

- **`_toInsertCompanion()`** — adds `Value()` wrappers for all 5 fields
- **`_toUpdateCompanion()`** — adds `Value()` wrappers for all 5 fields

Both methods pass the partial-sale fields from `ItemDraft` to the Drift `ItemsCompanion`.

---

## 4. UI Layer

### 4.1 Item Dialog — Partial-Sale Configuration

**File:** `lib/features/inventory/presentation/widgets/item_dialog.dart`

**New state variables** (lines 88–93):

```dart
bool _partialSaleEnabled = false;
String? _sellablePartUnitId;
String _partsPerFullProduct = '';
String _sellablePartBaseQuantity = '';
String _partialSaleMarkupBasisPoints = '';
```

**Initialization** (`initState`, lines 109–128):

- Seeds `_partialSaleEnabled` from `_initial.partialSaleEnabled`
- Seeds `_sellablePartUnitId` from `_initial.sellablePartUnitId`
- Seeds text controllers for `partsPerFullProduct`, `sellablePartBaseQuantity`, `partialSaleMarkupBasisPoints`
- Markup converted from basis points to percentage for display (e.g., `1000` → `10`)

**New UI section** (after units section):

```dart
_section(l10n.partialSaleSection),
Wrap(
  children: [
    _switch('partialSaleEnabled', l10n.partialSaleEnabled, ...),
    if (_partialSaleEnabled) ...[
      _dropdown('sellablePartUnitId', l10n.partialSaleSellablePart, ...),
      _text('partsPerFullProduct', l10n.partialSalePartsPerFull, ...),
      _text('sellablePartBaseQuantity', l10n.partialSaleBaseQuantity, ...),
      _text('partialSaleMarkupBasisPoints', l10n.partialSaleMarkupPercent, ...),
    ],
  ],
)
```

- Toggle switch shows/hides configuration fields
- Dropdown for sellable part unit uses the same units list as base/large units
- Markup entered as percentage (e.g., `10`), converted to basis points on submit

**Submit logic** (`_submit`, lines 252–281):

```dart
partialSaleEnabled: _partialSaleEnabled,
sellablePartUnitId: _partialSaleEnabled ? _sellablePartUnitId : null,
partsPerFullProduct: _partialSaleEnabled ? int.tryParse(...) : null,
sellablePartBaseQuantity: _partialSaleEnabled ? int.tryParse(...) : null,
partialSaleMarkupBasisPoints: _partialSaleEnabled
    ? (() { /* parse percentage → basis points */ })()
    : null,
```

When disabled, all partial-sale fields are set to `null`.

### 4.2 Prescription Pages — Switch Statement Updates

**Files:**

- `lib/features/prescriptions/presentation/pages/prescription_detail_page.dart` (line 82)
- `lib/features/prescriptions/presentation/pages/prescriptions_page.dart` (line 97)

Both `_statusLabel()` methods updated to handle the new `partially_dispensed` status:

```dart
PrescriptionStatus.partially_dispensed =>
  l10n.prescriptionStatusPartiallyDispensed,
```

---

## 5. Localization

### 5.1 New L10n Keys

**Files:** `lib/l10n/app_en.arb`, `lib/l10n/app_ar.arb`

| Key | English | Arabic |
|---|---|---|
| `partialSaleSection` | Partial Sale Configuration | إعدادات البيع الجزئي |
| `partialSaleEnabled` | Allow Partial Selling | السماح بالبيع الجزئي |
| `partialSaleSellablePart` | Sellable Part Unit | وحدة البيع الجزئي |
| `partialSalePartsPerFull` | Parts Per Full Product | عدد الأجزاء في العبوة الكاملة |
| `partialSaleBaseQuantity` | Base Units Per Part | عدد الوحدات الأساسية في الجزء |
| `partialSaleMarkupPercent` | Markup % | نسبة الزيادة % |
| `prescriptionStatusPartiallyDispensed` | Partially Dispensed | صرف جزئي |

### 5.2 Generated Localizations

**Files:** `app_localizations.dart`, `app_localizations_en.dart`, `app_localizations_ar.dart`

All 7 new getters added to abstract class and both language implementations.

---

## 6. Tests

### 6.1 New Test File: `partial_sale_test.dart`

**File:** `test/partial_sale_test.dart` (new, 563 lines, 40 tests)

| Group | Tests | What It Verifies |
|---|---|---|
| **PS01** | 1 | Partial-sale fields are NULL when disabled |
| **PS02** | 1 | Valid configuration stores all 5 fields |
| **PS17** | 2 | `partsPerFullProduct ≤ 1` rejected |
| **PS27** | 1 | `sellablePartBaseQuantity = 0` rejected |
| **PS28** | 2 | NULL fields valid when disabled; non-null rejected |
| **PS31–PS33** | 3 | Consistency invariant: valid (10×10=100), invalid (10×8≠100), skip when no unitsPerLarge |
| **PS34** | 1 | Database stores NULL when disabled |
| **PS35** | 1 | Missing base quantity rejected when enabled |
| **PS03** | 1 | $10 ÷ 10 × 1.10 = $1.10 |
| **PS04** | 1 | Markup applied exactly once |
| **PS05** | 1 | Full product at full retail price |
| **PS06** | 1 | Quantity < parts → all at partial price |
| **PS07** | 1 | Quantity = parts → full product price |
| **PS08** | 1 | Quantity > parts → decompose (13 = 1+3) |
| **PS09** | 2 | Different products, different part counts |
| **PS10** | 2 | Different markups produce different prices |
| **PS18** | 1 | Deterministic rounding |
| **PS19** | 1 | No cumulative markup |
| **PS20** | 1 | Supplier cost independent of partial price |
| **PS21–PS24** | 4 | 1→10, 3→30, 10→100, 13→130 base units |
| **PS25** | 1 | Changing base qty doesn't change price |
| **PS26** | 1 | Changing parts count changes price |
| **PS29** | 1 | Syrup counterexample (40 parts, 5ml/dose) |
| **Edge cases** | 6 | Zero qty, negative qty, markup bounds (0%, 100%, >100%, <0%) |
| **Decomposition** | 2 | 25 strips = 2 boxes + 5 strips; 1 strip = 0+1 |

### 6.2 Updated Tests

**File:** `test/migration_test.dart` (rewritten, 137 lines)

- Updated `_V2Database` class to include Phase 6 migration (partial-sale columns + app_settings)
- Updated assertions: `schemaVersion` expects `2` instead of `1`
- Added assertions for new columns: `partialSaleEnabled`, `sellablePartUnitId`, etc.
- Added assertion for `app_settings` table existence
- Migration test properly simulates v1→v2 by dropping Phase 6 columns and setting `PRAGMA user_version = 1`

**File:** `test/backup_service_test.dart` (1 line)

- Line 88: `expect(verification.schemaVersion, 1)` → `expect(verification.schemaVersion, 2)`

---

## 7. What Was NOT Changed

| Component | Reason |
|---|---|
| `SaleService` | Already works with `quantityBase` (base units). Conversion happens in POS layer. |
| `StockService` | FEFO operates on base quantities. No changes needed. |
| `BaseUnitConverter` | Handles box↔strip. Partial-sale conversion is separate (via `sellablePartBaseQuantity`). |
| `ItemDao` | Existing `byId()`, `search()`, `insert()`, `update()` work with new columns automatically. |
| Accounting logic | No changes needed. |
| Customer schema | No changes needed. |
| Reporting architecture | No changes needed. |
| Authentication | No changes needed. |

---

## 8. File Inventory

| Action | File | Lines Changed |
|---|---|---|
| **Created** | `lib/shared/database/tables/app_settings.dart` | +16 |
| **Created** | `lib/domain/services/partial_price_calculator.dart` | +203 |
| **Created** | `test/partial_sale_test.dart` | +563 |
| **Modified** | `lib/shared/database/tables/items.dart` | +24 |
| **Modified** | `lib/shared/database/app_database.dart` | +22 |
| **Modified** | `lib/shared/database/seed_data.dart` | +9 |
| **Modified** | `lib/shared/models/enums.dart` | +1/-1 |
| **Modified** | `lib/features/inventory/domain/repositories/inventory_repository.dart` | +20 |
| **Modified** | `lib/features/inventory/data/repositories/inventory_repository_impl.dart` | +10 |
| **Modified** | `lib/features/inventory/presentation/widgets/item_dialog.dart` | +72 |
| **Modified** | `lib/features/prescriptions/presentation/pages/prescription_detail_page.dart` | +2 |
| **Modified** | `lib/features/prescriptions/presentation/pages/prescriptions_page.dart` | +2 |
| **Modified** | `lib/l10n/app_en.arb` | +9 |
| **Modified** | `lib/l10n/app_ar.arb` | +9 |
| **Modified** | `lib/l10n/app_localizations.dart` | +13 |
| **Modified** | `lib/l10n/app_localizations_en.dart` | +21 |
| **Modified** | `lib/l10n/app_localizations_ar.dart` | +21 |
| **Modified** | `lib/shared/database/app_database.g.dart` | +926 (regenerated) |
| **Modified** | `test/migration_test.dart` | +68/-26 |
| **Modified** | `test/backup_service_test.dart` | +1/-1 |
| **Total** | **20 files** | **+1988/-26** |

---

## 9. Quality Metrics

| Metric | Result |
|---|---|
| `flutter analyze` | **0 issues** |
| `flutter test` | **195/195 passing** (155 original + 40 new) |

---

## 10. Git

| Item | Value |
|---|---|
| Commit | `d796d39` |
| Branch | `main` |
| Push | ✅ Succeeded to `origin/main` |
| Files changed | 20 |
| Lines added | +1988 |
| Lines removed | -26 |
