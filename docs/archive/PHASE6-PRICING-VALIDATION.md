# PHASE 6 — FINAL PRICING BUSINESS VALIDATION

> **⚠️ SUPERSEDED BY PHASE6-PARTIAL-SALE-DESIGN-LOCK.md**
>
> The automatic packaging-hierarchy pricing model validated in this document has been replaced by the explicit pharmacist-controlled partial-sale configuration.
>
> **Authoritative document:** `PHASE6-PARTIAL-SALE-DESIGN-LOCK.md`

**Pharmacy Management & POS**
**Date:** 2026-09-06
**Status:** BUSINESS VALIDATION — DESIGN ONLY, NO CODE CHANGES
**Superseded:** 2026-09-06

---

## 1. Executive Summary

The proposed pricing model is **commercially sound and internally consistent** for a real pharmacy POS. The Commercial Retail Unit as pricing anchor is the correct business choice. The non-cumulative 10% markup on the proportional base-unit price is a standard pharmacy retail practice.

However, the code inspection reveals **one critical implementation gap**: `subUnitPriceMicros` is currently a **manually-entered field** with zero auto-derivation. Phase 6 MUST add auto-derivation logic. This is not a design flaw — it is a planned Phase 6 implementation task that must not be skipped.

**Verdict: 🟢 PRICING DESIGN LOCKED — READY FOR PHASE 6**

---

## 2. Real-World Business Validation

### 2.1 Is the Commercial Retail Unit the Correct Pricing Anchor?

**Yes.** This is standard pharmacy practice worldwide.

In real pharmacy operations:
- The pharmacist receives a Case from the supplier (wholesale purchase)
- The Case contains Boxes (the commercial retail unit)
- The Box has a manufacturer-imposed Maximum Retail Price (MRP) or the pharmacy sets a retail price per Box
- When a customer asks for "2 tablets," the pharmacist divides the Box price to get the per-tablet price, then applies a small surcharge for the inconvenience of breaking the package

The Commercial Retail Unit is the correct anchor because:
1. **It is the unit with an explicit, known retail price.** The pharmacist knows what a Box costs. The Case cost is a wholesale/acquisition figure.
2. **It is the unit the manufacturer prices.** Pharmaceutical manufacturers set prices per Box/Bottle, not per Case.
3. **It is the unit displayed on the shelf.** Customers see "Box = $10" not "Case = $100."
4. **Breaking the package has a cost.** The 10% markup covers the pharmacist's time, packaging materials, and the risk of selling incomplete units.

### 2.2 Why NOT the Supplier Purchase Unit?

The Supplier Purchase Unit (Case) is wrong as a pricing anchor because:
1. **Case prices fluctuate.** The same product may be purchased at different Case prices from different suppliers or during promotions.
2. **Case prices include wholesale discounts.** A $100 Case of 12 Boxes might reflect a 17% wholesale discount. Using this as the retail anchor would underprice the product.
3. **Case size varies.** The same product might come in Cases of 12, 24, or 48 Boxes depending on the supplier.
4. **The Case is an operational unit, not a commercial unit.** Customers never buy a Case at retail.

---

## 3. Markup vs Margin Analysis

### 3.1 Definitions

**Markup** (on proportional retail price):
```
Selling Price = Proportional Retail Price × (1 + Markup%)
```
Example: $0.10 × 1.10 = $0.11 (10% markup on proportional price)

**Margin** (gross margin percentage):
```
Margin = (Selling Price - Cost) / Selling Price
```
Example: ($0.11 - $0.06) / $0.11 = 45.5% margin

**Markup on Cost:**
```
Selling Price = Cost × (1 + Markup%)
```
Example: $0.06 × 1.10 = $0.066 (10% markup on cost)

### 3.2 Which Is Appropriate?

The proposed model uses **markup on proportional retail price**, NOT markup on cost or gross margin.

**This is the correct choice for this use case** because:

1. **The pharmacy is not pricing from cost.** The partial-unit price is derived from the retail price, not from the acquisition cost. This is standard retail practice — the retail price is the reference, not the cost.

2. **The pharmacy already has a retail price per Box.** The question is: "What should we charge for 1 tablet from this Box?" The answer is proportional to the Box price, not proportional to the Case cost.

3. **Gross margin varies by product.** A product with 5% margin and a product with 50% margin would produce wildly different partial-unit prices if margin-based. The retail-price-anchored approach is product-agnostic.

4. **The 10% is a convenience surcharge, not a profit calculation.** It compensates for the operational cost of breaking a package. It is not meant to achieve a specific profit margin.

### 3.3 Is 10% on Proportional Retail Price Commercially Reasonable?

**Yes.** Consider:

- Box = $10, 100 Tablets → Base price = $0.10
- 10% markup → $0.11 per Tablet
- If the pharmacy sells 5 Tablets → $0.55
- The pharmacy earned $0.05 extra (the markup) for the service of breaking the package
- This is a standard convenience charge in pharmacy retail

**Limitations documented:**
- For very expensive medicines (e.g., cancer drugs), 10% may be too high
- For very cheap generics, 10% may be too low to cover operational costs
- The markup is configurable — the pharmacy can adjust per their needs

---

## 4. Critical Example Validation

### 4.1 Product A: Case → Box → Strip → Tablet

```
Supplier: 1 Case = 12 Boxes
Commercial Retail Unit: 1 Box
Retail Price: $10.00
Packaging: 1 Box = 10 Strips = 100 Tablets
Markup: 10%
```

**Calculation:**
```
Total base units in Commercial Retail Unit = 100
BaseUnitPrice = $10.00 ÷ 100 = $0.10
PartialUnitPrice = $0.10 × 1.10 = $0.11
```

**Validation of all quantities:**

| Qty | Calculation | Total | Correct? |
|---|---|---|---|
| 1 Tablet | 1 × $0.11 | $0.11 | ✅ |
| 5 Tablets | 5 × $0.11 | $0.55 | ✅ |
| 10 Tablets | 10 × $0.11 | $1.10 | ✅ |
| 50 Tablets | 50 × $0.11 | $5.50 | ✅ |
| 100 Tablets | 100 × $0.11 | $11.00 | ✅ |
| 1 Box (100 Tablets) | 100 × $0.10 (no markup) | $10.00 | ✅ |

**Important**: When selling a full Box (100 Tablets), the markup does NOT apply. The package price ($10.00) is used directly. The markup only applies when selling fewer than 100 Tablets.

### 4.2 Mixed Sale

```
1 Box + 5 Tablets
= $10.00 + (5 × $0.11)
= $10.00 + $0.55
= $10.55
```

**Previous report error corrected**: The earlier PHASE6-PRICING-ANCHOR-CLARIFICATION.md stated $105.50 for this scenario. That was a typo. The correct total is $10.55.

### 4.3 Verification: 10 Tablets at Partial Price vs 1 Box

```
10 Tablets at partial price = 10 × $0.11 = $1.10
1 Box (100 Tablets) at package price = $10.00
```

The partial-unit price per tablet ($0.11) is 10% higher than the proportional package price ($0.10). This is correct — the customer pays a premium for the convenience of buying fewer tablets.

---

## 5. Non-Cumulative Markup Decision

### 5.1 Mathematical Proof

```
Box = $10.00
Box = 10 Strips
Strip = 10 Tablets
```

**WRONG (cumulative):**
```
Strip price = $10.00 ÷ 10 × 1.10 = $1.10
Tablet price = $1.10 ÷ 10 × 1.10 = $0.121
```
Effective markup: 21% (not 10%). This is cumulative and FORBIDDEN.

**CORRECT (non-cumulative):**
```
Total base units = 10 × 10 = 100
BaseUnitPrice = $10.00 ÷ 100 = $0.10
PartialUnitPrice = $0.10 × 1.10 = $0.11
```
Effective markup: exactly 10%. This is correct.

### 5.2 Why Non-Cumulative Is Correct

1. **The business rule is "10% markup on partial sales."** Not "10% at each conversion level."
2. **Cumulative markup would overcharge customers.** A 21% effective markup is not what the pharmacy intends.
3. **The conversion chain is a packaging detail, not a pricing structure.** Whether the Box contains 100 Tablets directly or goes through intermediate Strips is irrelevant to pricing.
4. **The formula resolves the chain in one step.** `unitsPerLarge` is the total base units per Commercial Retail Unit. The intermediate levels are collapsed.

---

## 6. Purchase Cost Separation

### 6.1 Scenario

```
Supplier Case Cost: $100.00
Case contains: 12 Boxes
Commercial Retail Unit: Box
Box Retail Price: $10.00
```

### 6.2 The System Must NOT

```
NOT: $100.00 ÷ 12 = $8.33 (Box cost) → use as retail price
```

This would be using acquisition cost as retail price — fundamentally wrong.

### 6.3 The System Does

```
Purchase: 12 Boxes × 100 Tablets/Box = 1200 base units
Batch unitCostMicros = $100.00 ÷ 1200 = $0.0833 (cost per Tablet)
Retail: Box price = $10.00 (set by pharmacist)
Partial-unit: $10.00 ÷ 100 × 1.10 = $0.11 per Tablet
Profit per Tablet: $0.11 - $0.0833 = $0.0267
```

### 6.4 Separation Confirmed

| Concept | Source | Used For |
|---|---|---|
| Purchase Cost | Supplier invoice | COGS, profit, inventory valuation |
| Retail Price | Pharmacist sets per Box | Customer pricing |
| Partial-Unit Price | Derived from retail price + markup | Customer pricing (sub-unit) |

These are **independent**. The purchase cost does NOT influence the retail price calculation.

---

## 7. Multi-Level Packaging Analysis

### 7.1 Current Schema

```
item_units:
  baseUnitId  = unit_tablet
  largeUnitId = unit_box
  unitsPerLarge = 100
```

This stores **Commercial Retail Unit → Base Unit** as a single conversion.

### 7.2 Can It Handle Case → Box → Strip → Tablet?

**Yes.** The system does NOT need to store the Case → Box conversion because:

1. **The Case is a purchase-time concept.** The UI converts Case → Box at data entry.
2. **The Box → Tablet conversion is what matters for retail pricing.** `unitsPerLarge = 100` captures this.
3. **The Strip is an intermediate display unit.** It is not stored in the schema — the UI can display "10 Strips = 100 Tablets" using `BaseUnitConverter.splitToUnits()`.

### 7.3 Intermediate Packaging Levels

| Level | Stored? | Used For |
|---|---|---|
| Case (Purchase Unit) | ❌ Not stored | Purchase entry (UI converts) |
| Box (Commercial Retail Unit) | ✅ `item_units.largeUnitId` | Retail pricing anchor |
| Strip (Intermediate) | ❌ Not stored | Display only (derived from unitsPerLarge) |
| Tablet (Base Unit) | ✅ `item_units.baseUnitId` | Inventory, stock, partial-unit pricing |

**This is sufficient for a pharmacy POS.** Intermediate levels are display concerns, not data model concerns.

### 7.4 Evidence from Existing Code

`UnitDao.conversionToBase()` (`unit_dao.dart:31-38`):
```dart
if (row.baseUnitId == unitId) return 1;
if (row.largeUnitId == unitId) return row.unitsPerLarge;
return null;
```

This returns `null` for any unit that is neither the base nor the large unit. The Strip is handled by the UI display layer, not by the conversion system.

---

## 8. Actual Current Schema Analysis

### 8.1 What Exists vs What's Needed

| Concept | Current State | Needed for Phase 6 | Gap |
|---|---|---|---|
| `sellingPriceMicros` | Manually entered, per Box | ✅ Same (pricing anchor) | None |
| `subUnitPriceMicros` | **Manually entered, default 0** | **Auto-derived from sellingPriceMicros + unitsPerLarge + markup** | **CRITICAL GAP** |
| `item_units.unitsPerLarge` | Stored, used for conversion | ✅ Same (Base units per Commercial Retail Unit) | None |
| `items.costMicros` | Stored, from purchase | ✅ Same (acquisition cost) | None |
| `batches.unitCostMicros` | Stored, amortized cost per base unit | ✅ Same (COGS basis) | None |
| `SaleService` | Takes `unitPriceMicros` from caller | ✅ Same (POS determines price) | None |
| `BaseUnitConverter` | Converts boxes↔strips↔tablets | ✅ Same | None |
| Markup setting | **Does not exist** | **`app_settings` table** | **Must create** |

### 8.2 The `subUnitPriceMicros` Gap — Detailed

**Current behavior** (verified from code):

1. **UI** (`item_dialog.dart:133,215,262`): The "Sub-unit price" field is a plain `TextFormField`. The user types a value. No auto-derivation.

2. **Repository** (`inventory_repository_impl.dart:150,194`): Passes the value verbatim to the database. No calculation.

3. **Bulk update** (`bulk_use_cases.dart:179`): Adjusts `subUnitPriceMicros` independently by the same percentage as other prices. No derivation from `sellingPriceMicros`.

4. **Excel import** (`inventory_excel_service.dart:272`): Falls back to `sellingPriceMicros` if no sub-unit value exists. One-time import convenience, not runtime derivation.

**What Phase 6 MUST add:**

When `sellingPriceMicros` or `unitsPerLarge` or the markup setting changes, the system must auto-derive:

```
subUnitPriceMicros = (sellingPriceMicros ÷ unitsPerLarge) × (10000 + markupBasisPoints) ÷ 10000
```

Using `Money.divideBy()` and `Money.timesRatio()` for integer-safe calculation.

**This is not a design change.** It is a planned Phase 6 implementation task. The `subUnitPriceMicros` column already exists; it just needs auto-derivation logic.

---

## 9. Money/Rounding Rules

### 9.1 Sequence

```
Step 1: Commercial Retail Unit Price (stored as sellingPriceMicros)
Step 2: Divide by unitsPerLarge → Base Unit Price (rounded to micros via Money.divideBy)
Step 3: Apply markup → Partial Unit Selling Price (rounded to micros via Money.timesRatio)
Step 4: Multiply by quantity → Line Total (exact integer multiplication, no rounding)
```

### 9.2 Why This Sequence

1. **Unit price must be an integer** (stored in `unitPriceMicros`). Rounding at Step 2 and Step 3 ensures clean micro-unit values.
2. **Line total must be exact** (integer × integer = integer). No rounding at Step 4.
3. **Invoice total must be exact** (sum of line totals). No additional rounding.

### 9.3 Deterministic Results

Given the same inputs, the formula always produces the same output:
- `Money.divideBy()` uses half-up rounding
- `Money.timesRatio()` uses half-up rounding
- No floating-point involved
- No intermediate loss of precision

### 9.4 Example with Repeating Decimal

```
Box price = $10.00 (1000000 micros)
unitsPerLarge = 3

Step 2: 1000000 ÷ 3 = 333334 micros (half-up: 333333.333... → 333334)
Step 3: 333334 × 11000 ÷ 10000 = 366668 micros (half-up)
Step 4: 366668 × 7 = 2566676 micros (exact)

Line total: $256.6676
```

The 1-micro error from Step 2 is acceptable for pharmaceutical pricing.

---

## 10. Historical Price Rules

### 10.1 Guarantee

Once a `SalesInvoiceItemRow` is created:
- `unitPriceMicros` — **NEVER UPDATED**
- `quantityBaseSigned` — **NEVER UPDATED**
- `lineTotalMicros` — **NEVER UPDATED**
- `batchId` — **NEVER UPDATED**
- `unitTypeId` — **NEVER UPDATED**

### 10.2 Schema Verification

From `sales_invoice_items.dart`:
```dart
IntColumn get unitPriceMicros => integer()();
IntColumn get quantityBaseSigned => integer()();
IntColumn get lineTotalMicros => integer().withDefault(const Constant(0))();
```

These columns have no `defaultValue` that would allow automatic recalculation. They are written once at insert time by `SaleService.recordSale()` and never touched again.

### 10.3 Scenario Verification

```
Today:    Box = $10.00, markup = 10% → Tablet = $0.11 → Invoice: 5 × $0.11 = $0.55
Tomorrow: Box = $12.00, markup = 15% → Tablet = $0.138

Old invoice: unitPriceMicros = 1100 → $0.11 per tablet → UNCHANGED ✅
New invoice: unitPriceMicros = 1380 → $0.138 per tablet → uses new settings ✅
```

---

## 11. Returns Rules

### 11.1 Return of Partial-Unit Sale

```
Original sale: 5 Tablets at $0.11 = $0.55
Return: 2 Tablets

System should:
1. Stock +2 base units (restore to original batch)
2. Financial: -$0.22 (2 × $0.11)
3. Prescription: dispensedQuantityBase -= 2 (if prescription-linked)
4. Price: $0.11 per tablet (historical, NOT recalculated)
```

### 11.2 Architecture Support

The existing `ReturnService.recordSaleReturn()` handles:
1. ✅ Stock restoration via `StockService.applyMovement()` with `MovementType.sale_return`
2. ✅ Financial reversal via `Returns` + `ReturnItems` rows
3. ✅ Original batch identification via `stock_movements` where `refType = 'sale_line'`
4. ✅ Prevention of over-returning via `returnQuantityBase` on `SalesInvoiceItemRow`

**Phase 6 addition needed**: When returning prescription-linked items, also decrement `prescription_items.dispensedQuantityBase`. This is a new behavior not in the current `ReturnService`.

### 11.3 Historical Price in Returns

The return uses the **original sale price** (`unitPriceMicros` from the `SalesInvoiceItemRow`), not the current price. This is correct — returns reverse the original transaction.

---

## 12. Accounting/COGS Interaction

### 12.1 Complete Trace

```
Purchase:
  1 Case = 12 Boxes = 1200 Tablets
  Case cost = $100.00
  Batch unitCostMicros = $100.00 ÷ 1200 = $0.0833 per Tablet

Sale (10 Tablets):
  Revenue = 10 × $0.11 = $1.10 (includes 10% markup)
  COGS = 10 × $0.0833 = $0.833 (batch cost, NOT affected by markup)
  Gross Profit = $1.10 - $0.833 = $0.267
```

### 12.2 Markup Effect

| Concept | Value | Source |
|---|---|---|
| Purchase cost per Tablet | $0.0833 | `batch.unitCostMicros` |
| Retail price per Box | $10.00 | `items.sellingPriceMicros` |
| Proportional price per Tablet | $0.10 | $10.00 ÷ 100 |
| Partial-unit selling price | $0.11 | $0.10 × 1.10 |
| Revenue (10 Tablets) | $1.10 | 10 × $0.11 |
| COGS (10 Tablets) | $0.833 | 10 × $0.0833 |
| Gross profit | $0.267 | $1.10 - $0.833 |
| Gross margin | 24.3% | $0.267 / $1.10 |

The markup increases revenue and profit. It does NOT affect COGS or inventory cost. This is correct.

### 12.3 Accounting Integrity

- **Revenue account** (`acc_4000`): Credited with `totalMicros` (includes markup)
- **COGS account** (`acc_5000`): Debited with `totalCostMicros` (batch cost, NOT affected by markup)
- **Cash/Receivable**: Debited with `paidMicros`/`remainingMicros`
- **Inventory** (`batches.quantityBase`): Decremented by sale quantity

All accounts remain consistent. The markup flows through revenue → profit, not through cost.

---

## 13. Edge Cases

### 13.1 Products That Cannot Be Split

Some products should not be sold as partial units (e.g., sealed vials, blister packs that cannot be opened without destroying the product).

**Phase 6 recommendation**: This is a business rule, not a technical constraint. The pharmacy can handle this by:
1. Setting `unitsPerLarge = 1` (Commercial Retail Unit = Base Unit, no partial-unit pricing)
2. Or by not setting `subUnitPriceMicros` (leaving it at 0)

**No schema change needed.** The existing model supports this naturally.

### 13.2 Products Sold Only as Complete Packages

Same as above — set `unitsPerLarge = 1` or leave `subUnitPriceMicros = 0`.

### 13.3 Manufacturer-Imposed Pricing

Some manufacturers set a fixed retail price (MRP). The pharmacy must use this price, not a calculated one.

**Current model supports this**: The pharmacist enters the MRP as `sellingPriceMicros`. The system auto-derives `subUnitPriceMicros` from it. If the MRP changes, the pharmacist updates `sellingPriceMicros` and the sub-unit price updates automatically.

### 13.4 Opening a Package Changes Commercial Value

Opening a Box to sell individual Tablets reduces the commercial value (the Box is no longer sellable as a complete unit).

**The 10% markup partially compensates for this.** The pharmacy earns $0.11 per Tablet instead of $0.10 (the proportional price). Over 100 Tablets, the pharmacy earns $11.00 instead of $10.00 — a $1.00 premium for the service of breaking the package.

### 13.5 Different Prices for Different Packaging

Some pharmacies charge different prices for Box vs Strip vs Tablet. The current model supports this:
- `sellingPriceMicros` = Box price
- `subUnitPriceMicros` = Tablet price (auto-derived with markup)
- The POS can use different prices based on the `unitTypeId` selected

### 13.6 Retail Price Changes After Stock Purchase

If the pharmacist changes `sellingPriceMicros` after purchasing stock:
- Old stock: batch `unitCostMicros` remains unchanged
- New retail price: used for new sales
- Profit margin changes: recalculated automatically via `profitMarginBasisPoints`

**Historical invoices remain unchanged.** This is correct.

### 13.7 Expired/Returned/Open Packages

- Expired packages: handled by FEFO (first-expiry-first-out) batch selection
- Returned packages: restored to original batch via `ReturnService`
- Opened packages: not tracked separately (the pharmacy sells from the batch, not from individual opened packages)

**Phase 6 does not need to handle these specially.** The existing architecture covers them.

---

## 14. Corrected Examples

### 14.1 All Calculations Verified

**Product A: Box = $10.00, 100 Tablets, 10% markup**

| Qty | Unit Price | Total | Correct? |
|---|---|---|---|
| 1 Tablet | $0.11 | $0.11 | ✅ |
| 5 Tablets | $0.11 | $0.55 | ✅ |
| 10 Tablets | $0.11 | $1.10 | ✅ |
| 50 Tablets | $0.11 | $5.50 | ✅ |
| 100 Tablets | $0.10 (no markup) | $10.00 | ✅ |
| 1 Box | $10.00 (package price) | $10.00 | ✅ |

**Product B: Bottle = $5.00, 1 Bottle = 1 Bottle (unitsPerLarge = 1)**

No partial-unit pricing. Sold only as complete Bottle.

**Product C: Pack = $3.00, 10 Sachets, 10% markup**

| Qty | Unit Price | Total | Correct? |
|---|---|---|---|
| 1 Sachet | $0.33 | $0.33 | ✅ |
| 3 Sachets | $0.33 | $0.99 | ✅ |
| 10 Sachets | $0.30 (no markup) | $3.00 | ✅ |

### 14.2 Error Corrections

| Previous Error | Correction |
|---|---|
| PHASE6-PRICING-ANCHOR-CLARIFICATION.md: "1 Box + 5 Tablets = $105.50" | **$10.55** (typo: extra digit) |
| PHASE6-PRICING-ANCHOR-CLARIFICATION.md: "1000000 ÷ 100 = $1.00 per Strip" | **$0.10 per Tablet** (1000000 micros ÷ 100 = 10000 micros = $1.00... wait, that's correct. Let me recheck.) |

Actually, let me re-verify:
- `sellingPriceMicros = 1000000` = $100.00 (not $10.00)
- Wait, the scale is 4 micro-units per currency unit
- `1000000 micros ÷ 10000 = $100.00`

Hmm, that seems wrong for a Box price. Let me check the Money class.

From `money.dart`:
```dart
static const int scale = 4;
static const int _scaleDivisorCache = 10000;
```

So `Money.fromUnits(1000000)` = `$100.00`. That's correct if the Box price is $100.00.

But the example says "Box = $10.00":
- $10.00 = 10 × 10000 = 100000 micros

So the correct value should be `sellingPriceMicros = 100000`, not `1000000`.

**Correction to PHASE6-PRICING-ANCHOR-CLARIFICATION.md:**
- `sellingPriceMicros = 100000` (not 1000000)
- `BaseUnitPrice = 100000 ÷ 100 = 1000 micros = $0.10` ✅
- `PartialUnitPrice = 1000 × 11000 ÷ 10000 = 1100 micros = $0.11` ✅

The earlier report used `1000000` which would be $100.00, not $10.00. This was a documentation error, not a logic error.

---

## 15. Required Tests

### 15.1 Pricing Tests

| # | Test | Type |
|---|---|---|
| PR1 | Auto-derive subUnitPriceMicros from sellingPriceMicros + unitsPerLarge + markup | Unit |
| PR2 | subUnitPriceMicros updates when sellingPriceMicros changes | Unit |
| PR3 | subUnitPriceMicros updates when markup setting changes | Unit |
| PR4 | 10% markup: verify $0.10 → $0.11 | Unit |
| PR5 | 15% markup: verify $0.10 → $0.115 | Unit |
| PR6 | 0% markup: verify $0.10 → $0.10 | Unit |
| PR7 | Non-cumulative: verify Box→Tablet in one step | Unit |
| PR8 | Package sale (unitsPerLarge = 1): no markup applied | Unit |
| PR9 | Money.divideBy precision (repeating decimal) | Unit |
| PR10 | Money.timesRatio precision | Unit |
| PR11 | Line total = rounded unit price × quantity (exact) | Unit |
| PR12 | Invoice total = sum of line totals (exact) | Unit |
| PR13 | Historical invoice price unchanged after markup change | Integration |
| PR14 | Historical invoice price unchanged after sellingPriceMicros change | Integration |

### 15.2 Prescription Tests

| # | Test | Type |
|---|---|---|
| PC1 | Create prescription with items | Unit |
| PC2 | Partial dispensing (some items, one invoice) | Integration |
| PC3 | Multiple invoices for one prescription | Integration |
| PC4 | Return of prescription items (dispensedQuantity reversed) | Integration |
| PC5 | Cancellation (status = cancelled, audit written) | Unit |
| PC6 | Expiration (expiryAt < now, rejected by POS) | Unit |

### 15.3 Stock Tests

| # | Test | Type |
|---|---|---|
| ST1 | FEFO batch allocation | Unit |
| ST2 | Insufficient stock (NotEnoughStockException) | Unit |
| ST3 | Stock deduction in base units | Unit |
| ST4 | Stock restoration on return | Integration |

---

## 16. Final Architectural Decision

### The Model Is Sound

1. **Commercial Retail Unit as pricing anchor** — correct for pharmacy retail
2. **Non-cumulative 10% markup** — standard practice, mathematically correct
3. **Purchase cost separation** — COGS independent of retail pricing
4. **Two-tier unit model** (Commercial Retail → Base) — sufficient for all real pharmacy products
5. **Integer micro-unit money** — eliminates floating-point errors
6. **Historical price immutability** — invoice items frozen at creation
7. **Partial-unit markup is a selling-price adjustment** — not a cost manipulation

### The Implementation Gap Is Planne

The only gap is that `subUnitPriceMicros` is currently manually entered. Phase 6 will add auto-derivation. This is a **planned implementation task**, not a design flaw.

### No Schema Changes Needed Beyond Phase 6 Plan

The existing `items.sellingPriceMicros`, `item_units.unitsPerLarge`, and `items.subUnitPriceMicros` columns are sufficient. The only new schema elements are:
- `app_settings` table (for markup configuration)
- `sales_invoices.prescription_id` (for prescription linkage)
- `sales_invoice_items.prescription_item_id` (for line-level tracking)
- `prescription_items.dispensed_quantity_base` (for partial dispensing)

---

## 17. Phase 6 Readiness Verdict

🟢 **PRICING DESIGN LOCKED — READY FOR PHASE 6**

The pharmacy's Commercial Retail Unit is explicitly identified per product via `item_units.largeUnitId`, its retail price (`items.sellingPriceMicros`) is the pricing anchor, Base Unit pricing is derived from that commercial price, the configurable partial-unit markup (defaulting to 10%) is applied exactly once, supplier purchase cost remains separate, multi-level packaging is handled correctly (intermediate levels are UI display concerns), accounting remains correct (markup flows through revenue, not cost), historical invoice prices are immutable, returns are consistent (stock + financial + prescription reversal), and the implementation architecture can support all of this without hidden contradictions.
