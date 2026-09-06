# STRICT FINAL PARTIAL-SALE DESIGN LOCK

**Pharmacy Management & POS**
**Date:** 2026-09-06
**Status:** DESIGN ONLY — NO CODE CHANGES

---

## 1. Executive Summary

The previous automatic packaging-hierarchy pricing model is **SUPERSEDED**. The new model is simpler, explicit, and pharmacist-controlled. Partial sale is an **optional, per-product configuration**. The pharmacist enables it, defines the smallest sellable part, the number of such parts in one complete product, the inventory conversion factor (how many base units one sellable part represents), and a product-specific markup percentage. The system does not infer any of these values.

The actual repository architecture supports this model with one addition: a new `sellablePartBaseQuantity` column on the `items` table is required to bridge the gap between sellable-part quantities and base-unit inventory quantities. Five new columns on the `items` table plus one new table (`app_settings`) are the minimum required schema changes. The existing `item_units` table remains for Box↔Tablet conversion and is NOT repurposed for partial-sale configuration.

**Verdict: 🟢 PRICING DESIGN LOCKED — INVENTORY CONVERSION EXPLICITLY DEFINED — READY FOR PHASE 6**

---

## 2. Previous Design — SUPERSEDED

> **SUPERSEDED BY FINAL EXPLICIT PARTIAL-SALE CONFIGURATION**

The previous design assumed:
- Automatic inference of "Commercial Retail Unit" from `item_units.largeUnitId`
- Automatic derivation of partial-unit price from `sellingPriceMicros ÷ unitsPerLarge × (1 + global markup)`
- A global default markup applied uniformly to all products
- The `subUnitPriceMicros` column auto-derived from the packaging hierarchy

This model is retired. It is replaced by the explicit pharmacist-controlled model defined below.

**Reason for retirement**: The automatic model conflates unit conversion (`item_units`) with retail pricing rules. Not every product with a `unitsPerLarge > 1` should support partial sales. Not every product should use the same markup. The pharmacist must have explicit control.

---

## 3. Final Business Model

### 3.1 Core Concepts

| Concept | Definition | Example |
|---|---|---|
| **Full Product** | The complete product/package sold at its configured retail price | Box = $10.00 |
| **Sellable Part** | The smallest portion the pharmacist permits the POS to sell separately | Strip, Sachet, Tablet, Ampoule |
| **Partial Sale** | A sale involving fewer Sellable Parts than one complete Full Product | 3 Strips from a Box of 10 |
| **Parts Per Full Product** | How many Sellable Parts constitute one Full Product (commercial decomposition) | 10 Strips per Box |
| **Sellable Part Base Quantity** | How many inventory base units one Sellable Part represents (inventory conversion) | 1 Strip = 10 Tablets |

### 3.2 Partial Sale Is Optional Per Product

Every product has a normal/full retail selling price. A product MAY optionally have partial sale enabled.

- **Partial sale disabled**: Product sold only as a complete unit/package.
- **Partial sale enabled**: Product can be sold as a complete unit OR as individual Sellable Parts.

### 3.3 The Pharmacist Controls Everything

The system MUST NOT automatically determine:
- Whether a product supports partial sales
- What the smallest sellable part is
- How many parts are in one full product
- How many base units one sellable part represents
- What markup to apply

The pharmacist explicitly configures all of these per product.

---

## 4. Product Configuration

### 4.1 Required Fields

When partial sale is enabled, the product configuration requires:

| Field | Type | Default | Validation | Purpose |
|---|---|---|---|---|
| `partialSaleEnabled` | BOOLEAN | false | — | Enables partial sale for this product |
| `sellablePartUnitId` | TEXT (FK → Units) | NULL | Required when `partialSaleEnabled = true` | The smallest sellable part |
| `partsPerFullProduct` | INTEGER | 1 | Must be > 1 when `partialSaleEnabled = true` | Commercial decomposition: how many sellable parts in one full product |
| `sellablePartBaseQuantity` | INTEGER | 1 | Must be ≥ 1 when `partialSaleEnabled = true` | Inventory conversion: how many base units in one sellable part |
| `partialSaleMarkupBasisPoints` | INTEGER | 1000 (10%) | 0–10000 (0%–100%) | Markup applied to partial-base price |

### 4.2 Full Retail Price

The Full Retail Price is `items.sellingPriceMicros`. This is the existing field. It is NOT changed by partial-sale configuration.

### 4.3 Stored vs Derived

| Value | Stored or Derived |
|---|---|
| Full Retail Price | **Stored** (`sellingPriceMicros`) |
| Partial Sale Enabled | **Stored** (new column) |
| Sellable Part | **Stored** (new column, FK → Units) |
| Parts Per Full Product | **Stored** (new column) |
| Sellable Part Base Quantity | **Stored** (new column) |
| Partial Markup | **Stored** (new column, product-specific) |
| Partial Base Price | **Derived**: `sellingPriceMicros ÷ partsPerFullProduct` |
| Partial Selling Price | **Derived**: `partialBasePrice × (10000 + markupBasisPoints) ÷ 10000` |
| Base Quantity for Stock | **Derived**: `sellablePartQuantity × sellablePartBaseQuantity` |

---

## 5. Full Retail Pricing

The Full Retail Price remains unchanged by partial-sale configuration.

```
Full Retail Price = items.sellingPriceMicros
```

When a customer buys a complete product (quantity ≥ partsPerFullProduct), the POS uses the Full Retail Price. No partial-sale markup is applied.

---

## 6. Partial Sale Pricing Formula

The ONLY approved formula:

```
Partial Base Price = Full Retail Price ÷ Parts Per Full Product

Partial Selling Price = Partial Base Price × (1 + Partial Markup %)
```

In integer micro-units:

```
partialBasePrice = Money.fromUnits(sellingPriceMicros).divideBy(partsPerFullProduct).units

partialSellingPrice = Money.fromUnits(partialBasePrice).timesRatio(10000 + markupBasisPoints, 10000).units
```

---

## 7. Markup Rules

### 7.1 Applied Exactly Once

The markup is applied exactly once to the Partial Base Price. There is no recursive, cumulative, or multi-level markup calculation.

### 7.2 Product-Specific

Each product has its own `partialSaleMarkupBasisPoints`. Different products may have different markups.

### 7.3 Configurable Default

The system may provide a global default markup (10% = 1000 bp). New products inherit this default. The pharmacist may override it per product.

### 7.4 NOT Universal or Mandatory

The 10% default is a business decision for this application. It is NOT:
- Legally required
- Universally standard
- Mandatory worldwide
- Universally accepted pharmacy practice

It is simply the default selected for this application.

---

## 8. Full vs Partial Quantity Handling

### 8.1 Quantity ≤ Parts Per Full Product

All parts sold at the Partial Selling Price.

```
Quantity = 5, Parts Per Full Product = 10
→ 5 × Partial Selling Price
```

### 8.2 Quantity = Parts Per Full Product

Complete product. Sold at Full Retail Price. No partial markup.

```
Quantity = 10, Parts Per Full Product = 10
→ 1 × Full Retail Price
```

### 8.3 Quantity > Parts Per Full Product

Decompose into complete products + remaining parts.

```
Quantity = 13, Parts Per Full Product = 10
→ 1 Full Product (at Full Retail Price) + 3 Parts (at Partial Selling Price)
```

### 8.4 Decomposition Algorithm

**Pricing decomposition:**
```
completeProducts = quantity ÷ partsPerFullProduct  (integer division)
remainingParts = quantity % partsPerFullProduct    (modulo)

total = (completeProducts × fullRetailPrice) + (remainingParts × partialSellingPrice)
```

**Inventory conversion:**
```
totalBaseQuantity = quantity × sellablePartBaseQuantity
```

**Example**: 13 Strips, partsPerFullProduct=10, sellablePartBaseQuantity=10:
```
Pricing: 1 Box ($10.00) + 3 Strips (3 × $1.10 = $3.30) = $13.30
Inventory: 13 × 10 = 130 Tablets deducted
```

---

## 9. Purchase Cost Separation

| Concept | Source | Used For |
|---|---|---|
| Purchase Cost | Supplier invoice | COGS, profit, inventory valuation |
| Full Retail Price | Pharmacist sets per product | Complete product sales |
| Partial Selling Price | Derived from Full Retail Price + markup | Partial sales |

The supplier's purchase cost must NOT be used as the Full Retail Price or as the basis for partial-sale pricing. These are independent concepts.

---

## 10. Inventory Interaction

### 10.1 Stock Quantities

All stock is tracked in base units (`batches.quantityBase`, `items.currentStockBase`). This is unchanged.

### 10.2 Sellable Part → Base Unit Conversion

**This is the critical inventory conversion.** The system MUST convert sellable-part quantities to base-unit quantities for stock deduction.

```
baseQuantity = sellablePartQuantity × sellablePartBaseQuantity
```

The `sellablePartBaseQuantity` field is the **explicit inventory conversion factor**. It is NOT derived from `item_units.unitsPerLarge` or any other field. The pharmacist configures it per product.

### 10.3 Stock Deduction for Partial Sales

When selling N Sellable Parts:
1. Convert: `baseQuantity = N × sellablePartBaseQuantity`
2. Deduct `baseQuantity` base units from stock via FEFO batch allocation
3. The `unitTypeId` on the invoice line records which unit was sold (metadata)
4. The `quantityBaseSigned` on the invoice line records the actual base units consumed

### 10.4 Inventory Conversion vs Commercial Decomposition

These are **two distinct concepts** that MUST NOT be conflated:

| Concept | Field | Question It Answers | Example |
|---|---|---|---|
| **Commercial decomposition** | `partsPerFullProduct` | How many sellable parts make one retail product? | 10 Strips = 1 Box |
| **Inventory conversion** | `sellablePartBaseQuantity` | How many base inventory units does one sellable part consume? | 1 Strip = 10 Tablets |

**These values MAY be equal in some products but MUST NOT be assumed identical.**

**Counterexample where they differ:**

```
Product: Syrup
  Full product = Bottle (200 ml)
  Sellable part = Dose (5 ml)
  Base unit = ml

  partsPerFullProduct = 40       (40 Doses = 1 Bottle)
  sellablePartBaseQuantity = 5   (1 Dose = 5 ml)
```

Here `partsPerFullProduct ≠ sellablePartBaseQuantity`. Using the wrong one would produce incorrect stock deductions.

### 10.5 Panadol Example — Complete Trace

```
Product: Panadol
  item_units: baseUnitId=tablet, largeUnitId=box, unitsPerLarge=100
  partialSale config:
    partialSaleEnabled = true
    sellablePartUnitId = strip
    partsPerFullProduct = 10
    sellablePartBaseQuantity = 10
    partialSaleMarkupBasisPoints = 1000

Selling 3 Strips:
  Pricing: 3 × $1.10 = $3.30
  Inventory: 3 × 10 = 30 Tablets deducted from stock via FEFO

Selling 13 Strips:
  Pricing: 1 Box ($10.00) + 3 Strips (3 × $1.10 = $3.30) = $13.30
  Inventory: 13 × 10 = 130 Tablets deducted from stock via FEFO
```

### 10.6 Unit Conversion Independence

The existing `item_units` table defines Box↔Tablet conversion for display and inventory purposes. This is independent of the partial-sale configuration. The `sellablePartBaseQuantity` may produce a different conversion factor than `item_units.unitsPerLarge`.

| System | Purpose | Fields |
|---|---|---|
| `item_units` | Display unit conversion (Box ↔ Tablet) | `baseUnitId`, `largeUnitId`, `unitsPerLarge` |
| Partial-sale config | Retail pricing + inventory for partial sales | `partialSaleEnabled`, `sellablePartUnitId`, `partsPerFullProduct`, `sellablePartBaseQuantity`, `partialSaleMarkupBasisPoints` |

---

## 11. Prescription Interaction

### 11.1 Prescription-Linked Partial Sales

A prescription may request a quantity of Sellable Parts. The system must convert this to base units for inventory:

```
Prescription: 3 Strips of Panadol
  dispensed sellable quantity = 3
  inventory base quantity = 3 × 10 = 30 Tablets
```

The resulting invoice line records:
- Actual quantity sold in base units (`quantityBaseSigned = 30`)
- Sellable part quantity for display/reference
- Actual unit price used (Partial Selling Price or Full Retail Price)
- Historical price (frozen at invoice creation)
- Prescription-item linkage (`prescription_item_id`)

### 11.2 No Re-Calculation

The partial-sale calculation is NOT repeated when reading an old invoice. The historical `unitPriceMicros` and `quantityBaseSigned` are immutable.

---

## 12. Returns

### 12.1 Historical Price

Returns use the original historical sale price, NOT the current price.

```
Original: 5 Strips × $1.10 = $5.50
Return: 2 Strips
Reversal: 2 × $1.10 = $2.20 (historical price, not today's price)
```

### 12.2 Inventory Restoration

Returns restore the correct historical base-unit quantity. The system must NOT depend on current product configuration to reinterpret an old transaction.

```
Original sale: 3 Strips → 30 Tablets deducted (using sellablePartBaseQuantity=10 at sale time)
Return: 1 Strip → 10 Tablets restored (using the same historical conversion)
```

The return reads `quantityBaseSigned` from the original invoice line (e.g., 30 for 3 Strips). To restore per sellable part: `quantityBaseSigned ÷ sellablePartQuantity` = base units per part. Alternatively, the invoice line can store the `sellablePartBaseQuantity` at sale time for guaranteed historical accuracy.

Returns restore stock to the original batch (via `StockService.applyMovement()` with `MovementType.sale_return`).

### 12.3 Prescription Reversal

If the return is from a prescription-linked sale, decrement `prescription_items.dispensedQuantityBase` by the returned base-unit quantity.

---

## 13. Historical Pricing

Once an invoice is finalized:
- `unitPriceMicros` — NEVER UPDATED
- `quantityBaseSigned` — NEVER UPDATED
- `lineTotalMicros` — NEVER UPDATED

Changing Full Retail Price, Parts Per Full Product, Sellable Part Base Quantity, or Partial Markup does NOT affect existing invoices.

**Historical transaction safety**: The invoice line retains `quantityBaseSigned` (the actual base units consumed). This value is the authoritative record of what was deducted from stock. Future changes to `sellablePartBaseQuantity` cannot corrupt historical inventory or return calculations because the base-unit quantity is already frozen on the invoice line.

---

## 14. Rounding

### 14.1 Sequence

```
Step 1: Full Retail Price (stored as sellingPriceMicros)
Step 2: Divide by Parts Per Full Product → Partial Base Price (rounded to micros)
Step 3: Apply markup → Partial Selling Price (rounded to micros)
Step 4: Multiply by quantity → Line Total (exact integer multiplication)
```

### 14.2 Money Operations

- `Money.divideBy()` — half-up rounding
- `Money.timesRatio()` — half-up rounding
- `Money * int` — exact (no rounding)

### 14.3 Deterministic

Given the same inputs, the formula always produces the same output. No floating-point. No intermediate precision loss.

---

## 15. Validation Rules

| Rule | Enforcement |
|---|---|
| `partsPerFullProduct > 1` when `partialSaleEnabled = true` | Application layer |
| `sellablePartUnitId` is NOT NULL when `partialSaleEnabled = true` | Application layer |
| `sellablePartBaseQuantity ≥ 1` when `partialSaleEnabled = true` | Application layer |
| `partialSaleMarkupBasisPoints` ∈ [0, 10000] | Application layer |
| `sellingPriceMicros > 0` for partial-sale products | Application layer |
| `partsPerFullProduct ≤ 0` rejected | Application layer |
| `sellablePartBaseQuantity ≤ 0` rejected | Application layer |
| When `partialSaleEnabled = false`: `sellablePartUnitId = NULL`, `sellablePartBaseQuantity = NULL` or default-safe inactive value | Application layer |

---

## 16. Edge Cases

### 16.1 Parts Per Full Product = 1

Rejected. A partial-sale configuration with 1 part per full product means there is no smaller portion. The system must reject this configuration.

### 16.2 Partial Sale Disabled

The product is sold only as a complete unit. The POS must not offer partial-sale options for this product.

### 16.3 Products That Cannot Be Split

Sealed vials, blister packs that cannot be opened without destroying the product. The pharmacist disables partial sale for these products.

### 16.4 Different Products, Different Configurations

```
Product A: partialSale=true, part=strip, parts=10, markup=10%
Product B: partialSale=true, part=sachet, parts=8, markup=5%
Product C: partialSale=false
```

Each product is configured independently.

### 16.5 Quantity = 0

Rejected. Sale quantity must be positive.

### 16.6 Very Expensive Medicines

The 10% default may be too high. The pharmacist can override the markup per product.

---

## 17. Actual Repository Architecture Assessment

### 17.1 What Exists

| Component | Current State | Sufficient? |
|---|---|---|
| `items.sellingPriceMicros` | Stored, integer micro-units | ✅ Full Retail Price |
| `items.subUnitPriceMicros` | Stored, default 0, manually entered | ⚠️ Repurpose for partial price or keep manual |
| `item_units.unitsPerLarge` | Stored, integer, CHECK ≥ 1 | ⚠️ Unit conversion, NOT partial-sale config |
| `item_units.baseUnitId` | FK → Units | ✅ Base unit for inventory |
| `item_units.largeUnitId` | FK → Units | ✅ Large unit for inventory |
| `units` table | Registry of unit names | ✅ Reusable for sellable part |
| `BaseUnitConverter` | Converts between base/large | ✅ For stock deduction |
| `Money` class | Integer micro-units, scale 4 | ✅ `divideBy()`, `timesRatio()` |
| `SaleService` | Takes `unitPriceMicros` from caller | ✅ POS determines price |
| `StockService` | FEFO allocation in base units | ✅ Stock deduction |
| Settings table | **Does not exist** | ❌ Need `app_settings` for global default |

### 17.2 What Needs to Be Added

| Change | Table | Column | Type | Default |
|---|---|---|---|---|
| Add | `items` | `partialSaleEnabled` | BOOLEAN | false |
| Add | `items` | `sellablePartUnitId` | TEXT NULL | null |
| Add | `items` | `partsPerFullProduct` | INTEGER | 1 |
| Add | `items` | `sellablePartBaseQuantity` | INTEGER | 1 |
| Add | `items` | `partialSaleMarkupBasisPoints` | INTEGER | 1000 |
| Create | `app_settings` | — | TABLE | — |
| Bump | `schemaVersion` | — | — | 1 → 2 |

### 17.3 `subUnitPriceMicros` Decision

The existing `subUnitPriceMicros` column (currently manually entered) can be **repurposed** to store the auto-derived Partial Selling Price. When `partialSaleEnabled = true`, this field is auto-calculated from the formula. When `partialSaleEnabled = false`, it remains manually entered (or ignored).

**Alternative**: Keep `subUnitPriceMicros` as-is and compute the partial price at POS time without storing it. This is simpler but means the UI must compute it on every product lookup.

**Recommendation**: Auto-derive and store it. This is consistent with the existing pattern where `profitMarginBasisPoints` is auto-derived from cost and selling price.

### 17.4 `item_units` Independence

The `item_units` table remains for unit conversion (base ↔ large). It is NOT repurposed for partial-sale configuration. The two systems coexist:

| System | Purpose | Fields |
|---|---|---|
| `item_units` | Display unit conversion (Box ↔ Tablet) | `baseUnitId`, `largeUnitId`, `unitsPerLarge` |
| Partial-sale config | Retail pricing + inventory for partial sales | `partialSaleEnabled`, `sellablePartUnitId`, `partsPerFullProduct`, `sellablePartBaseQuantity`, `partialSaleMarkupBasisPoints` |

---

## 18. Required Phase 6 Changes

### 18.1 Database

1. Add 5 columns to `items` table (see §17.2)
2. Create `app_settings` table (for global default markup)
3. Bump `schemaVersion` from 1 to 2
4. Seed `app_settings` with default `partial_sale_markup_basis_points = 1000`

### 18.2 Domain

1. Create `PartialPriceCalculator` service:
   - `calculate(sellingPriceMicros, partsPerFullProduct, markupBasisPoints)` → `int partialSellingPriceMicros`
   - Uses `Money.divideBy()` and `Money.timesRatio()`
2. Create `SellablePartConverter` utility (or inline in POS logic):
   - `convertToBase(sellablePartQuantity, sellablePartBaseQuantity)` → `int baseQuantity`
   - Pure integer multiplication: `quantity × sellablePartBaseQuantity`
3. Extend `SaleService` to accept optional `partialSaleDecomposition`:
   - When quantity > partsPerFullProduct, decompose into full products + remaining parts
   - Full products priced at `sellingPriceMicros`
   - Remaining parts priced at `partialSellingPriceMicros`
   - Total base quantity = `quantity × sellablePartBaseQuantity`
4. Auto-derive `subUnitPriceMicros` when `partialSaleEnabled`, `sellingPriceMicros`, `partsPerFullProduct`, or `markupBasisPoints` changes

### 18.3 UI

1. Item dialog: add partial-sale configuration fields
2. POS: when selling partial quantities, decompose and calculate correctly
3. Product list: indicate partial-sale availability

### 18.4 Tests

All tests from §19 below.

---

## 19. Required Phase 6 Tests

### 19.1 Pricing Tests

| # | Test | Type |
|---|---|---|
| PS01 | Partial sale disabled → partial sale unavailable in POS | Unit |
| PS02 | Partial sale enabled → configured sellable part displayed | Unit |
| PS03 | Correct proportional partial price ($10 ÷ 10 × 1.10 = $1.10) | Unit |
| PS04 | Markup applied exactly once (not cumulative) | Unit |
| PS05 | Full product uses full retail price without markup | Unit |
| PS06 | Quantity < partsPerFullProduct → all parts at partial price | Unit |
| PS07 | Quantity = partsPerFullProduct → full product price | Unit |
| PS08 | Quantity > partsPerFullProduct → decompose (13 = 1 full + 3 parts) | Unit |
| PS09 | Different products have different part counts | Unit |
| PS10 | Different products have different markups | Unit |
| PS11 | Changing full retail price affects future sales only | Integration |
| PS12 | Changing partial markup affects future partial sales only | Integration |
| PS13 | Historical invoices remain unchanged after config changes | Integration |
| PS14 | Purchase cost remains independent of partial pricing | Unit |
| PS15 | Returns use historical sale price, not current price | Integration |
| PS16 | Prescription-linked partial sale works correctly | Integration |
| PS17 | Invalid part count (≤ 1) is rejected | Unit |
| PS18 | Rounding is deterministic (same inputs → same output) | Unit |
| PS19 | No cumulative markup across conversion levels | Unit |
| PS20 | Partial price not derived from supplier purchase price | Unit |

### 19.2 Inventory Conversion Tests

| # | Test | Type |
|---|---|---|
| PS21 | 1 Strip → sellablePartBaseQuantity × 1 base units | Unit |
| PS22 | 3 Strips → 3 × sellablePartBaseQuantity base units | Unit |
| PS23 | 10 Strips → 10 × sellablePartBaseQuantity base units | Unit |
| PS24 | 13 Strips → 13 × sellablePartBaseQuantity base units (decomposed pricing, unified inventory) | Unit |
| PS25 | Changing sellablePartBaseQuantity does NOT change partial-sale price | Unit |
| PS26 | Changing partsPerFullProduct DOES affect partial-sale price | Unit |
| PS27 | sellablePartBaseQuantity = 0 is rejected | Unit |
| PS28 | sellablePartBaseQuantity with partialSaleEnabled = false is ignored | Unit |
| PS29 | Counterexample: partsPerFullProduct ≠ sellablePartBaseQuantity produces correct results | Unit |
| PS30 | FEFO deducts exact base quantity (not sellable quantity) | Integration |

---

## 20. Migration/Schema Considerations

### 20.1 Forward-Only Migration

The schema change is forward-only (§29 convention). New columns are appended with defaults. Existing rows get:
- `partialSaleEnabled = false` (no partial sale for existing products)
- `sellablePartUnitId = null`
- `partsPerFullProduct = 1`
- `sellablePartBaseQuantity = 1`
- `partialSaleMarkupBasisPoints = 1000`

### 20.2 Backward Compatibility

Existing products are unaffected. Their `partialSaleEnabled = false` means the new fields are ignored. The POS continues to work as before for complete-product sales.

### 20.3 `subUnitPriceMicros` Migration

Existing values in `subUnitPriceMicros` are preserved. For products where `partialSaleEnabled = false`, the field remains as-is (manually entered or 0). For products where `partialSaleEnabled = true`, the field is auto-derived going forward.

---

## 21. Final Canonical Business Rule

> **Partial sale is an optional, explicitly configured product-level business rule. The pharmacist enables partial sale and defines the smallest sellable part, the number of such parts contained in one complete product, the number of inventory base units each sellable part represents, and the partial-sale markup. The complete product continues to use its normal retail price. Partial-unit pricing is calculated directly from that full retail price, divided by the configured number of sellable parts, with the configured markup applied exactly once. Inventory stock deduction uses the configured sellable-part-to-base-unit conversion factor. Supplier purchase packaging and purchase cost do not determine the partial retail price or the inventory conversion factor.**

---

## 22. Phase 6 Readiness Verdict

🟢 **PRICING DESIGN LOCKED — INVENTORY CONVERSION EXPLICITLY DEFINED — READY FOR PHASE 6**

### Verification Checklist

| # | Requirement | Status |
|---|---|---|
| 1 | New explicit pharmacist-controlled model documented | ✅ |
| 2 | Old automatic partial pricing clearly superseded | ✅ (§2) |
| 3 | Actual repository architecture inspected | ✅ (§17) |
| 4 | Full Retail Price clearly separated from partial-sale pricing | ✅ (§5) |
| 5 | Supplier purchase cost separate | ✅ (§9) |
| 6 | Partial markup applied exactly once | ✅ (§7.1) |
| 7 | Complete products never receive partial markup | ✅ (§8.2) |
| 8 | Quantities above one full product correctly decomposed | ✅ (§8.3) |
| 9 | Product-specific configuration addressed | ✅ (§4) |
| 10 | Historical prices immutable | ✅ (§13) |
| 11 | Returns addressed | ✅ (§12) |
| 12 | Prescription linkage addressed | ✅ (§11) |
| 13 | Inventory interaction addressed with explicit conversion factor | ✅ (§10) |
| 14 | Rounding addressed | ✅ (§14) |
| 15 | Invalid configurations addressed | ✅ (§15, §16) |
| 16 | Required tests documented (pricing + inventory conversion) | ✅ (§19) |
| 17 | All relevant reports consistent | ✅ |
| 18 | No unresolved business ambiguity | ✅ |
| 19 | `sellablePartBaseQuantity` explicitly defined | ✅ (§4.1, §10.2) |
| 20 | Commercial decomposition vs inventory conversion distinguished | ✅ (§10.4) |
| 21 | Counterexample documented | ✅ (§10.4) |
| 22 | FEFO flow explicitly traced | ✅ (§10.5) |
| 23 | Historical transaction safety ensured | ✅ (§13) |
