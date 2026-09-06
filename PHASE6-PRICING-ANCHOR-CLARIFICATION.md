# PHASE 6 — FINAL PRICING ANCHOR CLARIFICATION

**Pharmacy Management & POS**
**Date:** 2026-09-06
**Status:** DESIGN CLARIFICATION ONLY — NO CODE CHANGES

---

## 1. Architecture Inspection Results

### 1.1 What Exists Today

| Concept | Representation | Table/Column |
|---|---|---|
| **Base Unit** | 1 strip/tablet/ml/fraction | `item_units.baseUnitId` |
| **Large Unit** | 1 box/carton/bottle (the package sold at retail) | `item_units.largeUnitId` |
| **Conversion factor** | Base units per Large Unit | `item_units.unitsPerLarge` |
| **Retail selling price** | Price per Large Unit | `items.sellingPriceMicros` |
| **Sub-unit selling price** | Price per Base Unit (manually set) | `items.subUnitPriceMicros` |
| **Acquisition cost** | Cost per base unit (from purchase) | `batches.unitCostMicros` |
| **Purchase unit type** | Stored on purchase line for record only | `purchase_invoice_items.unitTypeId` |

### 1.2 What Does NOT Exist

| Missing Concept | Impact |
|---|---|
| **Purchase Unit as explicit tier** | The system has no `purchaseUnitId` or `unitsPerPurchaseUnit` column. The UI converts purchase quantities to base units before storage. |
| **Commercial Retail Unit as explicit tier** | The system has no `commercialRetailUnitId` column. The `largeUnitId` in `item_units` serves this role implicitly. |
| **Multi-level conversion chain** | `item_units` stores ONE conversion (large → base). It cannot store Case → Box → Strip → Tablet as separate tiers. |

---

## 2. Three-Tier Unit Model Analysis

### 2.1 The Three Concepts

```
Supplier Purchase Unit (Case/Carton/Wholesale Box)
        ↓  [UI-layer conversion, NOT stored in schema]
Commercial Retail Unit (Box/Bottle/Pack)
        ↓  [item_units.unitsPerLarge — stored in schema]
Base Unit (Tablet/Strip/ml/Gram)
```

### 2.2 Can the Current Schema Represent All Three?

**Yes — with one constraint.**

The schema CAN represent all three tiers, provided:

1. `item_units.unitsPerLarge` stores the conversion from **Commercial Retail Unit → Base Unit** (not from Purchase Unit)
2. The UI handles the **Purchase Unit → Commercial Retail Unit** conversion at data-entry time
3. `items.sellingPriceMicros` is always the price per **Commercial Retail Unit** (not per Purchase Unit)

### 2.3 Why This Works

**Purchase flow:**
- User enters: "Received 2 Cases, each Case = 12 Boxes"
- UI converts: 2 Cases × 12 Boxes/Case × `unitsPerLarge` = total base units
- System stores: `batches.quantityBase` = total base units, `batches.unitCostMicros` = cost per base unit
- The Case → Box conversion is done by the UI using a simple multiplier (hardcoded or user-entered at purchase time)

**Retail pricing flow:**
- `items.sellingPriceMicros` = price per Box (= Commercial Retail Unit)
- `item_units.unitsPerLarge` = Boxes → Base Units conversion
- Partial-unit price = `sellingPriceMicros ÷ unitsPerLarge × (1 + markup)`

**The Purchase Unit price never enters the retail pricing calculation.**

---

## 3. Schema Sufficiency Verification

### 3.1 Product A: Case → Box → Strip → Tablet

```
Item: Panadol
  item_units:
    baseUnitId = unit_tablet
    largeUnitId = unit_box
    unitsPerLarge = 100  (1 Box = 10 Strips × 10 Tablets = 100 Tablets)

  items:
    sellingPriceMicros = 1000000  ($10.00 per Box)
    subUnitPriceMicros = 110      ($0.11 per Tablet, auto-derived)

  Purchase: 1 Case = 12 Boxes
    UI converts: 12 × 100 = 1200 base units
    batch.quantityBase = 1200
    batch.unitCostMicros = cost per Tablet from supplier

  Partial-unit sale: 7 Tablets
    BaseUnitPrice = 1000000 ÷ 100 = 10000 micros ($1.00 per Strip... 
```

Wait — this reveals an important detail. Let me recalculate.

```
  Partial-unit sale: 7 Tablets
    BaseUnitPrice = 1000000 ÷ 100 = 10000 micros ($1.00 per Tablet)
    PartialUnitPrice = 10000 × 11000 ÷ 10000 = 11000 micros ($1.10 per Tablet)
    LineTotal = 11000 × 7 = 77000 micros ($7.70)
```

**Correct.** The Case price is never used. The Box selling price is the anchor.

### 3.2 Product B: Case → Bottle (no intermediate)

```
Item: Syrup
  item_units:
    baseUnitId = unit_tablet  (or unit_ml)
    largeUnitId = unit_box    (reused as "Bottle" label)
    unitsPerLarge = 1

  items:
    sellingPriceMicros = 500000  ($5.00 per Bottle)

  Partial-unit sale: N/A (Bottle is both Commercial Retail Unit AND Base Unit)
```

When `unitsPerLarge = 1`, the Commercial Retail Unit IS the Base Unit. No partial-unit pricing applies — the item is sold only as a complete package.

### 3.3 Product C: Carton → Pack → Sachet

```
Item: Powder
  item_units:
    baseUnitId = unit_sachet
    largeUnitId = unit_pack
    unitsPerLarge = 10  (1 Pack = 10 Sachets)

  items:
    sellingPriceMicros = 300000  ($3.00 per Pack)

  Purchase: 1 Carton = 50 Packs
    UI converts: 50 × 10 = 500 base units

  Partial-unit sale: 3 Sachets
    BaseUnitPrice = 300000 ÷ 10 = 30000 micros ($3.00 per Sachet)
    PartialUnitPrice = 30000 × 11000 ÷ 10000 = 33000 micros ($3.30 per Sachet)
    LineTotal = 33000 × 3 = 99000 micros ($9.90)
```

**Correct.** Carton price never enters retail pricing.

---

## 4. The Limitation and Its Resolution

### 4.1 Limitation

The schema stores **two tiers** (Commercial Retail Unit → Base Unit) in `item_units`. It does NOT store the Purchase Unit → Commercial Retail Unit conversion.

**Impact**: When a user enters a purchase, the UI must know (or the user must enter) how many Commercial Retail Units are in one Purchase Unit. This information is not persisted in `item_units`.

### 4.2 Resolution

This is **NOT a schema deficiency** — it is a **design choice**:

1. **Purchase Unit → Commercial Retail Unit conversion is a UI concern.** The user enters "1 Case = 12 Boxes" at purchase time. The UI multiplies to get base units. The system stores the result.

2. **The schema does not need to persist Purchase Unit → Commercial Retail Unit** because:
   - This conversion is entered at purchase time (not needed for retail pricing)
   - The batch stores the total `quantityBase` (already converted)
   - The batch stores `unitCostMicros` per base unit (already calculated)

3. **If future requirements demand it**, a `purchase_units` table could store per-item purchase unit conversions. But this is NOT needed for Phase 6.

### 4.3 No Schema Change Required

The current schema is **sufficient** for Phase 6 pricing. The three-tier model works because:

| Tier | Stored Where | Used For |
|---|---|---|
| Purchase Unit | NOT stored (UI converts at entry) | Purchasing, supplier transactions |
| Commercial Retail Unit | `item_units.largeUnitId` + `items.sellingPriceMicros` | Retail pricing anchor |
| Base Unit | `item_units.baseUnitId` + `item_units.unitsPerLarge` | Inventory, partial-unit pricing |

---

## 5. Pricing Flow — Complete Trace

### 5.1 Setup (one-time per item)

```
1. Pharmacist creates item "Panadol"
2. Sets:
   - sellingPriceMicros = 1000000  (Box price = $10.00)
   - item_units:
     - baseUnitId = unit_tablet
     - largeUnitId = unit_box
     - unitsPerLarge = 100  (1 Box = 100 Tablets)
3. System auto-derives:
   - subUnitPriceMicros = calculatePartialUnitPrice(
       sellingPriceMicros: 1000000,
       unitsPerLarge: 100,
       markupBasisPoints: 1000
     )
   - = 1000000 ÷ 100 × 1.10
   - = 10000 × 1.10
   - = 11000 micros ($1.10 per Tablet)
```

### 5.2 Purchase (per transaction)

```
1. User enters: "1 Case of Panadol, 12 Boxes, cost $6.00 per Box"
2. UI calculates:
   - totalBoxes = 12
   - totalTablets = 12 × 100 = 1200 base units
   - totalCost = 12 × $6.00 = $72.00
   - costPerTablet = $72.00 ÷ 1200 = $0.06
3. System creates:
   - batch.quantityBase = 1200
   - batch.unitCostMicros = 60000 ($0.06 per Tablet)
```

### 5.3 Sale — Full Box

```
1. Customer buys 1 Box
2. SaleLineRequest:
   - quantityBase = 100
   - unitPriceMicros = sellingPriceMicros = 1000000 ($10.00)
   - unitTypeId = unit_box
3. LineTotal = 1000000 × 1 = 1000000 ($10.00)
```

### 5.4 Sale — Partial Units (7 Tablets)

```
1. Customer buys 7 Tablets
2. SaleLineRequest:
   - quantityBase = 7
   - unitPriceMicros = subUnitPriceMicros = 11000 ($1.10)
   - unitTypeId = unit_tablet
3. LineTotal = 11000 × 7 = 77000 ($7.70)
```

### 5.5 Sale — Mixed (1 Box + 5 Tablets)

```
Line 1: Box
  - quantityBase = 100
  - unitPriceMicros = 1000000 (package price, no markup)
  - unitTypeId = unit_box

Line 2: Tablets
  - quantityBase = 5
  - unitPriceMicros = 11000 (base unit price + markup)
  - unitTypeId = unit_tablet

Total = 1000000 + 55000 = 1055000 ($105.50)
```

---

## 6. Non-Cumulative Markup — Mathematical Proof

Given:
- Box = 10 Strips
- Strip = 10 Tablets
- Box price = $10.00
- Markup = 10%

**WRONG (cumulative):**
```
Strip price = $10.00 ÷ 10 × 1.10 = $1.10
Tablet price = $1.10 ÷ 10 × 1.10 = $0.121  ← WRONG
```

**CORRECT (non-cumulative):**
```
Total base units in Commercial Retail Unit = 10 × 10 = 100
BaseUnitPrice = $10.00 ÷ 100 = $0.10
PartialUnitPrice = $0.10 × 1.10 = $0.11  ← CORRECT
```

**The formula resolves the entire conversion chain in one step:**

```
BaseUnitPrice = CommercialRetailUnitPrice ÷ (unitsPerLarge)
```

Where `unitsPerLarge` is the total number of Base Units in one Commercial Retail Unit. For multi-level products, `unitsPerLarge` = product of all intermediate conversion factors.

---

## 7. Schema Verification Summary

### 7.1 Purchase Unit — How It Works

| Aspect | Status | Evidence |
|---|---|---|
| Purchase quantity entry | UI converts to base units | `PurchaseLineDraft.quantityBase` is pre-converted |
| Purchase cost | Stored per base unit on batch | `batches.unitCostMicros` |
| Purchase unit type | Stored on invoice line for record | `purchase_invoice_items.unitTypeId` (informational only) |
| Stock receipt | In base units | `batches.quantityBase` |

**The Purchase Unit is a UI-layer concept.** The system stores the result (base units + cost per base unit), not the conversion chain.

### 7.2 Commercial Retail Unit — How It Works

| Aspect | Status | Evidence |
|---|---|---|
| Unit identity | `item_units.largeUnitId` | The "large unit" IS the Commercial Retail Unit |
| Selling price | `items.sellingPriceMicros` | Price per Large Unit (= per Commercial Retail Unit) |
| Conversion to base | `item_units.unitsPerLarge` | Base units per Commercial Retail Unit |
| Sub-unit price | `items.subUnitPriceMicros` | Auto-derived from selling price + markup |

**The Commercial Retail Unit IS the `largeUnit` in the existing schema.** No new columns needed.

### 7.3 Base Unit — How It Works

| Aspect | Status | Evidence |
|---|---|---|
| Unit identity | `item_units.baseUnitId` | Canonical smallest inventory unit |
| Stock tracking | `batches.quantityBase` | All stock in base units |
| Movement tracking | `stock_movements.quantityBaseSigned` | All deltas in base units |
| Partial-unit price | `items.subUnitPriceMicros` | Base unit price with markup |

**The Base Unit is the canonical inventory unit.** All quantities resolve to base units.

---

## 8. Final Design Lock Statement

> **The Commercial Retail Unit, not the Supplier Purchase Unit or wholesale Case, is the pricing anchor for partial-unit retail sales.**

> **The configured partial-unit markup, defaulting to 10%, is applied exactly once to the Base Unit equivalent price derived from the Commercial Retail Unit selling price. Markup is never cumulative across unit-conversion levels.**

---

## 9. Required Changes for Phase 6

### Schema Changes

| # | Change | Table | Column | Reason |
|---|---|---|---|---|
| 1 | Add `prescription_id` | `sales_invoices` | `prescription_id TEXT NULL` | Prescription → Sale linkage |
| 2 | Add `prescription_item_id` | `sales_invoice_items` | `prescription_item_id TEXT NULL` | Line-level prescription tracking |
| 3 | Add `dispensed_quantity_base` | `prescription_items` | `dispensed_quantity_base INTEGER DEFAULT 0` | Partial dispensing |
| 4 | Add `app_settings` table | — | key-value store | Configurable markup |
| 5 | Add `partially_dispensed` | `PrescriptionStatus` enum | — | Prescription lifecycle |

**No additional schema changes needed for the three-tier unit model.** The existing `item_units` + `items.sellingPriceMicros` + `items.subUnitPriceMicros` columns are sufficient.

### Domain Changes

| # | Change | Location |
|---|---|---|
| 1 | `PartialUnitPriceCalculator` service | `lib/domain/services/` |
| 2 | `PrescriptionDispensingService` | `lib/domain/services/` |
| 3 | `AppSettingsDao` | `lib/data/daos/` |
| 4 | `SaleService` extension for prescription linkage | `lib/domain/services/sale_service.dart` |
| 5 | Auto-derive `subUnitPriceMicros` on price change | `lib/features/inventory/` |

### No Changes Needed

| Component | Why |
|---|---|
| `BaseUnitConverter` | Already handles large ↔ base conversion |
| `StockService` | Already works in base units |
| `PurchaseService` | Already receives pre-converted base units |
| `BonusCalculator` | Already works in base units |
| `Money` class | Already has `divideBy()` and `timesRatio()` |
| `item_units` table | Already stores Commercial Retail Unit → Base Unit conversion |
| `items.sellingPriceMicros` | Already stores Commercial Retail Unit price |

---

## 10. Final Verdict

🟢 **PRICING DESIGN LOCKED — READY FOR PHASE 6**

The current schema is sufficient for the three-tier unit model. The Commercial Retail Unit is represented by `item_units.largeUnitId` + `items.sellingPriceMicros`. The Base Unit is represented by `item_units.baseUnitId` + `item_units.unitsPerLarge`. The Purchase Unit is a UI-layer concern that does not require schema persistence. The partial-unit markup formula is non-cumulative and uses the Commercial Retail Unit as its anchor. No schema changes are needed for the unit model beyond the prescription linkage and settings table already specified in PHASE6-DESIGN-LOCK.md.
