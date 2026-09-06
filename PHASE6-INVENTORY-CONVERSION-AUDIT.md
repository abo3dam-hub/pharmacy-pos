# FINAL INVENTORY CONVERSION VALIDATION

> **RESOLVED — CORRECTION DOCUMENTED IN PHASE6-PARTIAL-SALE-DESIGN-LOCK.md**
>
> The inventory conversion gap identified in this audit has been resolved by adding `sellablePartBaseQuantity` to the Phase 6 design. The authoritative document is now `PHASE6-PARTIAL-SALE-DESIGN-LOCK.md`.

**Phase 6 — Partial Sale**
**Date:** 2026-09-06
**Scope:** Inventory/unit-conversion audit ONLY
**Status:** Gap identified, correction documented, design updated

---

## 1. Executive Verdict

**🟡 YELLOW → 🟢 RESOLVED — CORRECTION DOCUMENTED**

The pricing design is correct and locked. The inventory conversion gap was identified: the current architecture cannot convert an intermediate sellable unit (e.g., Strip) to base units (e.g., Tablets). The correction has been documented: add `sellablePartBaseQuantity` to the `items` table. The full design update is in `PHASE6-PARTIAL-SALE-DESIGN-LOCK.md` §4.1, §10.

---

## 2. Actual Unit Model Found in Repository

### 2.1 Database Schema

**`item_units` table** (`item_units.dart`):

| Column | Type | Default | Notes |
|---|---|---|---|
| `itemId` | TEXT FK → Items | — | |
| `baseUnitId` | TEXT FK → Units | — | e.g., `unit_tablet` |
| `largeUnitId` | TEXT FK → Units | — | e.g., `unit_box` |
| `unitsPerLarge` | INTEGER | 1 | CHECK ≥ 1 |

**Constraint**: `UNIQUE(itemId, baseUnitId, largeUnitId)` — one row per item.

**Critical observation**: This table stores exactly **two tiers** per item — a base unit and a large unit. There is no column for a third intermediate unit (e.g., Strip).

### 2.2 Seeded Units

| ID | Arabic | English |
|---|---|---|
| `unit_strip` | شريط | Strip |
| `unit_box` | علبة | Box |
| `unit_tablet` | قرص | Tablet |

### 2.3 What Is NOT Stored

The `item_units` table does NOT store:
- How many Tablets are in a Strip
- How many Strips are in a Box (separately from Box→Tablet)
- Any arbitrary unit-to-unit conversion

---

## 3. Actual Conversion Logic Found

### 3.1 `UnitDao.conversionToBase()` — `unit_dao.dart:31-39`

```dart
Future<int?> conversionToBase(String itemId, String unitId) async {
  final row = await (_db.select(_db.itemUnits)
        ..where((u) => u.itemId.equals(itemId)))
      .getSingleOrNull();
  if (row == null) return null;
  if (row.baseUnitId == unitId) return 1;           // base → 1
  if (row.largeUnitId == unitId) return row.unitsPerLarge;  // large → unitsPerLarge
  return null;  // ANY OTHER UNIT → null
}
```

**Proven behavior**:
- `conversionToBase(panadol, unit_tablet)` → `1` ✅
- `conversionToBase(panadol, unit_box)` → `100` ✅ (if `unitsPerLarge = 100`)
- `conversionToBase(panadol, unit_strip)` → `null` ❌

**This is the gap.** Strip is neither the base unit nor the large unit. The method returns `null`.

### 3.2 `BaseUnitConverter` — `base_unit_converter.dart`

```dart
int toBaseUnits({required int boxes, required int strips, required int unitsPerLarge}) {
  return boxes * unitsPerLarge + strips;
}

BaseUnitBreakdown splitToUnits({required int baseUnits, required int unitsPerLarge}) {
  return BaseUnitBreakdown(
    boxes: baseUnits ~/ unitsPerLarge,
    strips: baseUnits % unitsPerLarge,
    boxSize: unitsPerLarge,
  );
}
```

**Proven behavior**: This is a **two-tier** converter. It handles:
- Box → base (via `boxes * unitsPerLarge`)
- Remainder → strips (via `strips`)
- Base → Box + Strips (via `splitToUnits`)

It does NOT handle an arbitrary third tier. The "strips" in this converter are the **remainder** after extracting boxes, not a separately-defined intermediate unit.

### 3.3 `Quantity` — `quantity.dart`

```dart
Quantity.fromBoxesAndFractions({boxes, fractions, unitsPerLarge})
  : baseUnits = boxes * unitsPerLarge + fractions;
```

Same two-tier model. `fractions` is the remainder, not an independently-defined unit.

### 3.4 `SaleService` — `sale_service.dart`

```dart
class SaleLineRequest {
  final int quantityBase;  // ALREADY in base units
  final String unitTypeId;  // stored as metadata only
}
```

The sale service receives **pre-converted** base units. It never calls `conversionToBase()` or `BaseUnitConverter`. The `unitTypeId` is written to the invoice line as a label — it is never used for conversion.

### 3.5 `StockService` — `stock_service.dart`

Works entirely in base units. No conversion logic.

---

## 4. Panadol / Strip Scenario Trace

### 4.1 Configuration

```
Product: Panadol
  item_units:
    baseUnitId = unit_tablet
    largeUnitId = unit_box
    unitsPerLarge = 100

  Partial-sale config (Phase 6):
    partialSaleEnabled = true
    sellablePartUnitId = unit_strip
    partsPerFullProduct = 10
```

### 4.2 Required Conversion

```
Sell 3 Strips → Must deduct 30 Tablets from stock
```

### 4.3 Actual Code Path

| Step | Code | Result |
|---|---|---|
| 1. User enters "3 Strips" | POS UI | quantity = 3, unit = Strip |
| 2. Convert to base units | `UnitDao.conversionToBase(panadol, unit_strip)` | **`null`** |
| 3. If null, what happens? | No fallback in the codebase | **UNDEFINED** |
| 4. `SaleLineRequest` constructed with | `quantityBase = ?` | **CANNOT BE CONSTRUCTED** |
| 5. `StockService.allocateFefo(db, panadol, ?)` | Needs integer | **WOULD FAIL** |

**The conversion fails at step 2.** There is no code path that can convert Strip → Tablets for this product.

### 4.4 Why It Fails

The `item_units` row for Panadol stores:
- `baseUnitId = unit_tablet`
- `largeUnitId = unit_box`
- `unitsPerLarge = 100`

When `conversionToBase(panadol, unit_strip)` is called:
- `unit_strip != unit_tablet` → not base
- `unit_strip != unit_box` → not large
- Returns `null`

The fact that 1 Strip = 10 Tablets is **not stored anywhere in the database** for this product.

---

## 5. Can Strip → Tablet Be Converted?

**NO** — not with the current architecture.

The system has no mechanism to determine that `1 Strip = 10 Tablets` for Panadol. The `item_units` table only stores `1 Box = 100 Tablets`. The intermediate `Strip → Tablet` relationship is not represented.

---

## 6. Evidence From Actual Code

| File | Line | Evidence |
|---|---|---|
| `unit_dao.dart` | 36 | `if (row.baseUnitId == unitId) return 1;` — only base unit |
| `unit_dao.dart` | 37 | `if (row.largeUnitId == unitId) return row.unitsPerLarge;` — only large unit |
| `unit_dao.dart` | 38 | `return null;` — **any other unit returns null** |
| `base_unit_converter.dart` | 25 | `boxes * unitsPerLarge + strips` — two-tier only |
| `sale_service.dart` | 17 | `final int quantityBase;` — expects pre-converted base units |
| `stock_service.dart` | 36 | `int quantityBase` — expects base units |

**There is no code anywhere in the repository that converts an arbitrary intermediate unit to base units.**

---

## 7. Stock Deduction Validation

### 7.1 Current Behavior (Without Partial Sale)

When selling 1 Box of Panadol:
1. UI calls `conversionToBase(panadol, unit_box)` → `100`
2. `SaleLineRequest(quantityBase: 100, unitTypeId: unit_box)`
3. `StockService.allocateFefo(db, panadol, 100)` → deducts 100 Tablets ✅

This works because Box is the `largeUnitId`.

### 7.2 Phase 6 Behavior (With Partial Sale)

When selling 3 Strips of Panadol:
1. UI calls `conversionToBase(panadol, unit_strip)` → **`null`** ❌
2. Cannot construct `SaleLineRequest` with correct `quantityBase`
3. Stock deduction fails or uses wrong quantity

**Stock deduction is UNSAFE for intermediate sellable units.**

---

## 8. Prescription Impact

### 8.1 Scenario

```
Prescription: 3 Strips of Panadol
Required stock deduction: 30 Tablets
```

### 8.2 Current Behavior

The prescription stores `quantityBase` in base units (`prescription_items.quantityBase`). If the prescription is created with `quantityBase = 30` (correctly converted by the pharmacist at prescription creation time), the sale can proceed.

**However**: The prescription creation flow (`PrescriptionRepositoryImpl.create()`) uses `line.quantityBase` directly. The pharmacist must manually enter the base-unit quantity. There is no automatic Strip → Tablet conversion at prescription creation time.

### 8.3 Risk

If the pharmacist enters `quantityBase = 3` (thinking in Strips), the prescription will record 3 base units instead of 30. The subsequent sale will deduct 3 Tablets instead of 30.

**This is a data-entry risk, not a code bug.** The system trusts the caller to provide correct base-unit quantities.

---

## 9. Return Impact

### 9.1 Scenario

```
Original sale: 3 Strips (should be 30 Tablets deducted)
Return: 1 Strip (should restore 10 Tablets)
```

### 9.2 Current Behavior

`ReturnService.recordSaleReturn()` restores stock using the original batch information from `stock_movements`. It uses `quantityBase` from the original sale line.

**If the original sale correctly deducted 30 Tablets**, the return of 1 Strip must restore 10 Tablets. But the return service needs to know that 1 Strip = 10 Tablets to calculate the correct restoration quantity.

### 9.3 Risk

The return service reads the original `SalesInvoiceItemRow.quantityBaseSigned`. If the original sale recorded `quantityBaseSigned = 30` (correct), the return can restore the correct amount. But the return UI must know how to convert "1 Strip" to "10 Tablets" for the return quantity.

**Same conversion gap as the sale flow.**

---

## 10. Historical Transaction Impact

### 10.1 What Is Stored on Invoice Lines

| Column | Stored at sale time | Used for conversion? |
|---|---|---|
| `quantityBaseSigned` | ✅ Base units sold | This IS the converted quantity |
| `unitTypeId` | ✅ Strip/Box/Tablet label | Metadata only, not used for conversion |
| `unitPriceMicros` | ✅ Price per unit | Pricing only |
| `batchId` | ✅ Which batch consumed | Stock restoration |

### 10.2 Historical Safety

If the original sale correctly stores `quantityBaseSigned = 30` (for 3 Strips), historical data is safe. The return service can read this value and restore correctly.

**The risk is at write time, not read time.** If the wrong `quantityBaseSigned` is written (e.g., 3 instead of 30), the historical record is corrupted.

---

## 11. FEFO Impact

### 11.1 FEFO Allocation

`StockService.allocateFefo(db, itemId, quantityBase)` selects batches covering `quantityBase` base units using first-expiry-first-out.

### 11.2 Impact of Conversion Gap

If the conversion gap causes `quantityBase = 3` (should be 30), FEFO will:
- Allocate only 3 Tablets from batches
- Leave 27 Tablets undeducted
- Corrupt inventory counts

**FEFO is correct IF given the correct base-unit quantity.** The risk is in the conversion, not in FEFO itself.

---

## 12. Architectural Gap

### 12.1 The Gap

The system has no mechanism to convert an arbitrary sellable unit to base units when the sellable unit is **neither the base unit nor the large unit** defined in `item_units`.

### 12.2 Why It Matters for Phase 6

The Phase 6 partial-sale design requires:
- `sellablePartUnitId = unit_strip` (an intermediate unit)
- Conversion: `1 Strip = N Tablets` (where N is not stored)

The current `item_units` table only stores:
- `baseUnitId = unit_tablet`
- `largeUnitId = unit_box`
- `unitsPerLarge = 100` (Box → Tablet)

It does NOT store:
- `stripUnitId` or any reference to Strip
- `stripsPerBox` or `tabletsPerStrip`

### 12.3 The Two Concepts That Are Conflated

**A. Commercial decomposition** (1 Box = 10 Strips):
- Relevant to: partial-sale pricing, full-product decomposition
- Stored in: `partsPerFullProduct` (new Phase 6 column)

**B. Inventory conversion** (1 Strip = 10 Tablets):
- Relevant to: stock deduction, FEFO, returns, prescriptions
- **NOT stored anywhere**

In the Panadol example, these happen to produce the same number (10). But this equality is **not guaranteed**.

### 12.4 Counterexample Where They Differ

```
Product: Syrup
  Full product = Bottle (1 Bottle = 200ml)
  Sellable part = Dose (1 Dose = 5ml)
  partsPerFullProduct = 40 (200ml ÷ 5ml = 40 Doses)

  item_units:
    baseUnitId = unit_ml
    largeUnitId = unit_bottle
    unitsPerLarge = 200
```

Here:
- `partsPerFullProduct = 40` (commercial decomposition)
- `1 Dose = 5ml` (inventory conversion)

These are **different numbers**. `partsPerFullProduct` does NOT tell us that 1 Dose = 5ml. It tells us that 1 Bottle = 40 Doses.

To convert 3 Doses to base units (ml), we need: `3 × 5 = 15ml`. But `partsPerFullProduct = 40` would give us `3 × 40 = 120ml` — **wrong**.

---

## 13. Minimum Recommended Correction — IMPLEMENTED IN DESIGN

> **This correction has been documented in `PHASE6-PARTIAL-SALE-DESIGN-LOCK.md` §4.1, §10.2.**

### 13.1 `sellablePartBaseQuantity` (APPROVED)

Add one column to `items`:

```
sellablePartBaseQuantity INTEGER DEFAULT 1
```

**Meaning**: 1 sellable part = N base units.

**Example**:
- Panadol: `sellablePartBaseQuantity = 10` (1 Strip = 10 Tablets)
- Syrup: `sellablePartBaseQuantity = 5` (1 Dose = 5ml)

**Usage in Phase 6**:
```
quantityBase = sellablePartQuantity × sellablePartBaseQuantity
```

**Validation**: Must be ≥ 1 when `partialSaleEnabled = true`. Must be NULL or default when `partialSaleEnabled = false`.

### 13.2 Why This Is Minimal

- One column, one integer
- No new tables
- No changes to `item_units` or `BaseUnitConverter`
- No changes to `UnitDao.conversionToBase()`
- The POS UI reads this column and multiplies: `quantity × sellablePartBaseQuantity = quantityBase`
- Existing two-tier conversion (Box↔Tablet) is unaffected

### 13.3 Why NOT Use `partsPerFullProduct`

`partsPerFullProduct` describes commercial decomposition (how many sellable parts in one full product). It does NOT describe inventory conversion (how many base units in one sellable part).

**Equal in simple cases**:
```
Box = 10 Strips, Strip = 10 Tablets
→ partsPerFullProduct = 10, sellablePartBaseQuantity = 10
```

**Different in multi-level cases**:
```
Case = 12 Boxes, Box = 10 Strips, Strip = 10 Tablets
→ partsPerFullProduct = 10 (Box → Strip), NOT 120 (Case → Tablet)
→ sellablePartBaseQuantity = 10 (Strip → Tablet)
```

**Different in non-uniform cases**:
```
Bottle = 200ml, Dose = 5ml
→ partsPerFullProduct = 40 (Bottle → Dose)
→ sellablePartBaseQuantity = 5 (Dose → ml)
```

---

## 14. What Must NOT Be Changed

| Component | Reason |
|---|---|
| Partial-sale pricing formula | LOCKED |
| `partialSaleEnabled` | LOCKED |
| `sellablePartUnitId` | LOCKED |
| `partsPerFullProduct` | LOCKED |
| `partialSaleMarkupBasisPoints` | LOCKED |
| Full retail price model | LOCKED |
| Historical invoice immutability | LOCKED |
| Prescription lifecycle | LOCKED |
| `item_units` table | Unaffected — remains for Box↔Tablet conversion |
| `BaseUnitConverter` | Unaffected — remains for Box↔Tablet display |
| `UnitDao.conversionToBase()` | Unaffected — remains for Box↔Tablet lookup |
| `SaleService` | Unaffected — still receives pre-converted base units |
| `StockService` | Unaffected — still works in base units |

---

## 15. Final Phase 6 Readiness Verdict

**PRICING DESIGN: LOCKED / UNCHANGED** ✅

**INVENTORY CONVERSION: 🟢 RESOLVED — `sellablePartBaseQuantity` ADDED TO DESIGN**

**PHASE 6: READY FOR IMPLEMENTATION**

The inventory conversion gap has been resolved. The minimum correction (`sellablePartBaseQuantity` column on `items`) has been documented in `PHASE6-PARTIAL-SALE-DESIGN-LOCK.md`. Phase 6 can proceed with this correction included in the schema changes.
