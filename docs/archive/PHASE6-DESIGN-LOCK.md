# PRE-PHASE-6 FINAL DESIGN LOCK

> **⚠️ PARTIAL-SALE SECTIONS SUPERSEDED BY PHASE6-PARTIAL-SALE-DESIGN-LOCK.md**
>
> The partial-unit pricing model described in Sections 6–8 of this document has been replaced by the explicit pharmacist-controlled partial-sale configuration.
>
> **Authoritative document for partial-sale pricing:** `PHASE6-PARTIAL-SALE-DESIGN-LOCK.md`
>
> All other sections (prescription lifecycle, dispensing, linkage, historical pricing, rounding, accounting, returns, transaction atomicity, concurrency, test plan) remain valid.

**Pharmacy Management & POS**
**Date:** 2026-09-06
**Status:** DESIGN ONLY — NO CODE CHANGES
**Partial-sale sections superseded:** 2026-09-06

---

## Baseline

| Property | Value |
|---|---|
| Phases completed | 1–5 ✅ APPROVED |
| Tests | 155 passing |
| `flutter analyze` | 0 issues |
| Schema version | 1 |
| Tables | 32 |
| FKs | 53 |
| CHECK constraints | 16 |
| Pre-phase review | PHASE5.1-REVIEW-REPORT.md ✅ |

---

## SECTION 1 — PRESCRIPTION LIFECYCLE

### 1.1 Current State

**Enum** (`enums.dart:106`):
```dart
enum PrescriptionStatus { active, dispensed, expired, cancelled }
```

**Table columns** (`prescriptions.dart`):
- `status`: textEnum\<PrescriptionStatus\>() — NOT NULL
- `totalMicros`: INTEGER, default 0
- `issuedAt`: INTEGER (epoch millis)
- `expiryAt`: INTEGER, nullable

**Prescription item** (`prescription_items.dart`):
- `isDispensed`: BOOLEAN, default false — exists but **never written to true by any code path**

### 1.2 States Definition

| State | Meaning | Who triggers | Reversible? |
|---|---|---|---|
| `active` | Prescription issued, awaiting dispensing. All items `isDispensed = false`. | Created by pharmacist | Initial state |
| `partially_dispensed` | At least one item dispensed, at least one not. **MISSING FROM ENUM** | Sale completion | N/A — new state required |
| `dispensed` | All items dispensed. | Sale completion (all items) | No — medical record is final |
| `expired` | Past `expiryAt`. No further dispensing allowed. | System/cron or manual check | No — date fact |
| `cancelled` | Pharmacist voids the prescription. Items revert to un-dispensed. | Pharmacist with permission | **No** — cancellation is permanent (audit trail required) |

### 1.3 Required Change

**Add `partially_dispensed` to `PrescriptionStatus` enum.**

Without this state, the system has no way to represent "2 of 3 items dispensed." The current 4-state enum is insufficient.

Updated enum:
```
active → partially_dispensed → dispensed
active → expired
active → cancelled
partially_dispensed → expired
partially_dispensed → cancelled
```

### 1.4 Transition Rules

| From | To | Trigger | Guard |
|---|---|---|---|
| `active` | `partially_dispensed` | Sale completes with some (not all) items | At least 1 prescription item `isDispensed = true`, at least 1 `false` |
| `active` | `dispensed` | Sale completes with ALL items | All prescription items `isDispensed = true` |
| `partially_dispensed` | `dispensed` | Additional sale completes remaining items | All remaining items now `isDispensed = true` |
| `active` | `expired` | Manual or system check | `expiryAt < now` |
| `partially_dispensed` | `expired` | Manual or system check | `expiryAt < now` |
| `active` | `cancelled` | Pharmacist action | Audit log required |
| `partially_dispensed` | `cancelled` | Pharmacist action | Audit log required; dispensed quantities already consumed by sales — cancellation does NOT reverse sales |

### 1.5 Invalid Transitions

| From | To | Why invalid |
|---|---|---|
| `dispensed` | anything | Final state — medical record immutable |
| `expired` | anything | Date fact — cannot un-expire |
| `cancelled` | anything | Permanent — audit trail required |

### 1.6 Expiration Behavior

- `expiryAt` is set at prescription creation (nullable — non-expiring prescriptions allowed)
- Expiration check: `expiryAt != null && expiryAt < now`
- Expired prescriptions cannot be dispensed — `prepareForSale` must reject them
- Expiration does NOT affect historical invoices (financial records remain)
- The POS should check expiry before allowing "attach prescription to sale"

### 1.7 Cancellation Behavior

- Cancellation requires pharmacist-level permission
- Cancellation writes an audit entry with reason
- Cancellation does NOT reverse any completed sales — those are independent financial records
- Cancellation sets `status = cancelled` on the prescription header
- Prescription items remain in the database with their original `isDispensed` values
- A cancelled prescription cannot be reactivated

---

## SECTION 2 — PARTIAL DISPENSING

### 2.1 Data Model

**Existing columns on `prescription_items`**:
- `quantityBase` (INTEGER, NOT NULL, CHECK > 0) — prescribed quantity in base units
- `isDispensed` (BOOLEAN, default false) — all-or-nothing flag

**Problem**: `isDispensed` is a boolean. It cannot represent "3 of 10 dispensed."

### 2.2 Required Schema Change

Add to `prescription_items`:

```
dispensedQuantityBase  INTEGER  DEFAULT 0  CHECK (>= 0)
```

**Constraints**:
- `dispensedQuantityBase <= quantityBase` (enforced at application layer; CHECK constraint cannot reference another column in SQLite drift)
- When `dispensedQuantityBase == 0` → not dispensed
- When `dispensedQuantityBase == quantityBase` → fully dispensed
- When `0 < dispensedQuantityBase < quantityBase` → partially dispensed

**The existing `isDispensed` boolean becomes redundant.** It can be derived as `dispensedQuantityBase >= quantityBase`. Recommendation: keep it as a derived/cache column for backward compatibility and query performance, updated automatically when `dispensedQuantityBase` changes.

### 2.3 Dispensing Rules

1. Each sale against a prescription specifies which prescription items are being dispensed and in what quantity
2. `dispensedQuantityBase` is incremented by the sale quantity (in base units)
3. The sale quantity must not exceed `quantityBase - dispensedQuantityBase` (remaining quantity)
4. One prescription item CAN be dispensed across multiple invoices (e.g., prescribed 30 tablets, customer buys 10 today, 10 next week, 10 later)
5. One invoice CAN contain items from multiple prescriptions plus OTC items
6. The `prescriptionId` on `sales_invoices` links the invoice to the prescription that contributed items (if any)

### 2.4 Header Status Derivation

The prescription header `status` is derived from its items:

```
if all items: dispensedQuantityBase >= quantityBase → dispensed
else if any item: dispensedQuantityBase > 0 → partially_dispensed
else → active (or check expiry/cancellation)
```

This derivation happens at sale completion time within the same transaction.

### 2.5 Multiple Invoices Per Prescription

**Yes.** One prescription can produce multiple invoices:

```
Prescription: Amoxicillin × 30, Panadol × 20

Invoice #1 (today): Amoxicillin × 10
  → prescription_items[amoxicillin].dispensedQuantityBase = 10
  → prescription.status = partially_dispensed

Invoice #2 (next week): Amoxicillin × 10, Panadol × 20
  → prescription_items[amoxicillin].dispensedQuantityBase = 20
  → prescription_items[panadol].dispensedQuantityBase = 20
  → prescription.status = dispensed (all items fully dispensed)
```

---

## SECTION 3 — PRESCRIPTION → SALES INVOICE LINKAGE

### 3.1 Cardinality

```
Prescription  1 ──── *  SalesInvoice
SalesInvoice  1 ──── *  SalesInvoiceItem
PrescriptionItem  * ──── *  SalesInvoiceItem  (via dispensedQuantity tracking)
```

### 3.2 Answers

| Question | Answer |
|---|---|
| Can one prescription produce multiple invoices? | **Yes** — partial dispensing across visits |
| Can one invoice reference one prescription? | **Yes** — `sales_invoices.prescription_id` (nullable FK) |
| Can one invoice reference multiple prescriptions? | **No** — one `prescription_id` per invoice. If a customer has multiple prescriptions, create separate invoices or mix prescription + OTC items on one invoice with one prescription linked |
| Can one invoice contain prescription items + normal OTC items? | **Yes** — `prescription_id` is nullable. OTC items are just invoice lines not linked to any prescription item |
| Can one prescription item be dispensed across multiple invoices? | **Yes** — `dispensedQuantityBase` tracks cumulative dispensing |
| Can an invoice exist without a prescription? | **Yes** — `prescription_id` is nullable. Walk-in cash sales, OTC-only sales |
| Can a prescription exist without an invoice? | **Yes** — prescription created, customer hasn't purchased yet |

### 3.3 Design Decision: One Prescription Per Invoice

**Rationale**: Simplicity. A single invoice with one `prescription_id` FK is clean. If a customer has 3 prescriptions, the pharmacist creates 3 invoices (or combines items from multiple prescriptions into one invoice without linking to any specific prescription — the `prescription_id` stays null and individual lines track their dispensed quantities separately).

**Alternative rejected**: A junction table `invoice_prescription_links` — over-engineered for the pharmacy use case. One invoice = one prescription + optional OTC items is the common workflow.

### 3.4 Schema Change Required

Add to `sales_invoices`:
```
prescription_id  TEXT  NULL  REFERENCES prescriptions(id)
```

Add to `sales_invoice_items`:
```
prescription_item_id  TEXT  NULL  REFERENCES prescription_items(id)
```

This links each invoice line to the specific prescription item it dispenses, enabling `dispensedQuantityBase` tracking.

---

## SECTION 4 — MEDICAL VS FINANCIAL DATA

### 4.1 Separation Rules

| Rule | Implementation |
|---|---|
| Deleting/cancelling an invoice does NOT destroy the prescription | `sales_invoices.prescription_id` is a nullable FK with NO CASCADE. Prescription stands alone |
| Deleting/cancelling a prescription does NOT destroy historical invoices | Prescription cancellation sets `status = cancelled` on the prescription. Invoices have their own `saleStatus`. No FK from invoice to prescription triggers cascade |
| Historical invoice data remains immutable | `SalesInvoiceItemRow.unitPriceMicros`, `quantityBaseSigned`, `lineTotalMicros` are written at sale time and never updated |
| Medical history remains available | Prescription table and `prescription_items` are never deleted — soft lifecycle via `status` |
| Financial history remains auditable | `audit_logs` tracks all mutations. Invoice voiding writes audit with reason |

### 4.2 Foreign Key Behavior

- `sales_invoices.prescription_id` → `prescriptions.id`: **NO CASCADE** (restrict or no action). A prescription cannot be deleted if invoices reference it — but prescriptions are never hard-deleted anyway (they use soft status lifecycle)
- `sales_invoice_items.prescription_item_id` → `prescription_items.id`: **NO CASCADE**. Invoice items are permanent financial records

### 4.3 Immutability Guarantee

Once a `SalesInvoiceItemRow` is created:
- `unitPriceMicros` — never updated
- `quantityBaseSigned` — never updated
- `lineTotalMicros` — never updated
- `batchId` — never updated
- `unitTypeId` — never updated
- Only `returnQuantityBase` is incremented (by returns)

---

## SECTION 5 — PARTIAL-UNIT INVENTORY MODEL

### 5.1 Current Architecture

**Canonical inventory unit**: **Base unit** (integer).

All stock is tracked in base units:
- `batches.quantityBase` — batch stock in base units
- `items.currentStockBase` — item total stock in base units (cache, re-synced from ledger)
- `stock_movements.quantityBaseSigned` — movement delta in base units
- `stock_movements.quantityBaseAfter` — running balance in base units

**Conversion** (`item_units` table):
- 1 item has 1 `ItemUnitRow` mapping: `baseUnitId` + `largeUnitId` + `unitsPerLarge`
- Example: `unit_tablet` (base) + `unit_box` (large) + `unitsPerLarge = 100`
- This means 1 box = 100 base units (tablets)

**Seeded units**:
- `unit_strip` (شريط/Strip)
- `unit_box` (علبة/Box)
- `unit_tablet` (قرص/Tablet)

### 5.2 How Partial-Unit Sales Affect Inventory

Selling 3 tablets:
- `SaleLineRequest.quantityBase = 3`
- `StockService.allocateFefo(db, itemId, 3)` — allocates 3 base units from batches
- `StockService.applyMovement()` — writes `-3` to `stock_movements.quantityBaseSigned`
- `batches.quantityBase` decreased by 3
- `items.currentStockBase` decreased by 3

**Inventory deduction is ALWAYS in base units.** The unit type at sale time (`unitTypeId`) is for pricing and display only — it does not affect stock deduction.

### 5.3 Conversion Chain

```
Sale: 2 strips (unitTypeId = unit_strip)
  BaseUnitConverter.toBaseUnits(boxes: 0, strips: 2, unitsPerLarge: 10) = 2 base units
  StockService.allocateFefo(db, itemId, 2) → deducts 2 base units

Sale: 1 box (unitTypeId = unit_box)
  BaseUnitConverter.toBaseUnits(boxes: 1, strips: 0, unitsPerLarge: 10) = 10 base units
  StockService.allocateFefo(db, itemId, 10) → deducts 10 base units
```

### 5.4 Confirmation

The existing architecture correctly represents partial-unit inventory. No changes needed to the inventory model. The `BaseUnitConverter` and `StockService` already handle all conversions in base units.

---

## SECTION 6 — PARTIAL-UNIT PRICING

### 6.1 Locked Algorithm

```
Step 1: Identify the commercial/package unit
        → items.sellingPriceMicros = price per package

Step 2: Determine total base units in the package
        → item_units.unitsPerLarge = base units per package
        (e.g., 1 box = 10 strips, so unitsPerLarge = 10)

Step 3: Calculate base unit price
        → BaseUnitPrice = CommercialSellingPrice ÷ TotalBaseUnitsInPackage
        → Money.fromUnits(sellingPriceMicros).divideBy(unitsPerLarge)

Step 4: Apply configured markup ONCE
        → PartialUnitPrice = BaseUnitPrice × (10000 + markupBasisPoints) ÷ 10000
        → baseUnitPrice.timesRatio(10000 + markupBasisPoints, 10000)

Step 5: Line total
        → LineTotal = PartialUnitPrice × QuantitySold
        → partialUnitPrice * quantityBase
```

### 6.2 NON-CUMULATIVE GUARANTEE

The markup is applied **exactly once** at the base-unit level.

**Wrong (cumulative)**:
```
Box → Strip: price ÷ 10 × 1.10 = strip price
Strip → Tablet: strip price ÷ 10 × 1.10 = tablet price  ← FORBIDDEN
```

**Correct (non-cumulative)**:
```
Tablet price = Box price ÷ 100 × 1.10  ← single markup application
```

### 6.3 Implementation Location

The `PartialUnitPriceCalculator` service performs this calculation. It is called:
- When the POS builds a sale line with a sub-unit `unitTypeId`
- When `items.sellingPriceMicros` or `item_units.unitsPerLarge` changes
- When the markup setting changes (to re-derive `subUnitPriceMicros`)

### 6.4 When Unit Type Matches Package

If the sale `unitTypeId` matches the item's large unit (e.g., selling by the box), the partial-unit markup does NOT apply. The package price (`sellingPriceMicros`) is used directly.

The markup applies ONLY when the sale unit type is a sub-unit (smaller than the package).

### 6.5 Examples

**Example 1**:
- Box price = 10.0000 (100000 micros)
- 1 box = 100 tablets (unitsPerLarge = 100)
- Markup = 10% (1000 bp)

```
BaseUnitPrice = 100000 ÷ 100 = 1000 micros ($0.10)
PartialUnitPrice = 1000 × (10000 + 1000) ÷ 10000 = 1000 × 11000 ÷ 10000 = 1100 micros ($0.11)
Line total for 3 tablets = 1100 × 3 = 3300 micros ($0.33)
```

**Example 2**:
- Strip price = 5.0000 (50000 micros)
- 1 strip = 10 tablets (unitsPerLarge = 10)
- Markup = 10%

```
BaseUnitPrice = 50000 ÷ 10 = 5000 micros ($0.50)
PartialUnitPrice = 5000 × 11000 ÷ 10000 = 5500 micros ($0.55)
Line total for 5 tablets = 5500 × 5 = 27500 micros ($2.75)
```

---

## SECTION 7 — CONFIGURABLE MARKUP

### 7.1 Storage

**New table**: `app_settings`

```dart
class AppSettings extends Table {
  TextColumn get key => text()();
  TextColumn get value => text()();
  TextColumn get updatedAt => integer()();
  TextColumn get updatedBy => text().nullable().references(Users, #id)();

  @override
  Set<Column> get primaryKey => {key};
}
```

**Default row**:
```
key: 'partial_unit_markup_basis_points'
value: '1000'
updatedAt: <seed time>
updatedBy: null
```

### 7.2 Data Type

- **Storage**: TEXT key → TEXT value (simple key-value store, flexible for future settings)
- **In-memory**: `int` (basis points, parsed from text)
- **Precision**: Integer basis points (100 bp = 1%). No fractional percentages
- **Valid range**: 0–10000 (0%–100%). Enforced at application layer

### 7.3 Default Value

`1000` basis points = **10%**

### 7.4 Permissions

- **View**: Any user with `inventory.view` or `settings.view` (new permission)
- **Edit**: Admin only (`admin` role) — changing markup affects all future sales pricing

### 7.5 UI Location

Admin Settings page (Phase 6 or later). For now, the value can be set via seed data and changed in the database directly. The settings table provides the infrastructure for future UI.

### 7.6 Global vs Product-Specific

**Global.** The markup is a pharmacy-wide policy, not per-product. All partial-unit sales use the same markup setting.

**Rationale**: Per-product markup would require an additional column on `items` and significantly more UI complexity. The business rule states "the pharmacy uses a default 10% partial-unit markup" — singular, global.

### 7.7 Special Authorization

Changing the markup requires admin role. The change is audited via `audit_logs` with action `price_change`.

---

## SECTION 8 — HISTORICAL PRICING

### 8.1 Guarantee

Once a `SalesInvoiceItemRow` is created, its `unitPriceMicros` is frozen. Changing the markup setting, item prices, or any configuration does NOT retroactively affect historical invoices.

### 8.2 How the Schema Preserves History

| Field | Written at sale time | Updated later? |
|---|---|---|
| `unitPriceMicros` | ✅ — the computed partial-unit price | **Never** |
| `quantityBaseSigned` | ✅ — base units sold | **Never** (only `returnQuantityBase` incremented) |
| `lineSubtotalMicros` | ✅ — `qty × unitPrice` | **Never** |
| `lineDiscountMicros` | ✅ — discount amount | **Never** |
| `lineTotalMicros` | ✅ — subtotal - discount + VAT | **Never** |
| `unitCostMicros` | ✅ — batch cost at sale time | **Never** |
| `costTotalMicros` | ✅ — `qty × unitCost` | **Never** |
| `profitMicros` | ✅ — `lineTotal - costTotal` | **Never** |
| `vatRateBasisPoints` | ✅ — tax rate at sale time | **Never** |
| `taxMicros` | ✅ — VAT amount | **Never** |
| `batchId` | ✅ — which batch was consumed | **Never** |
| `unitTypeId` | ✅ — box/strip/tablet at sale time | **Never** |

### 8.3 Scenario Verification

```
Today:    markup = 10%    → tablet price = $0.11    → invoice created
Tomorrow: markup = 15%    → tablet price = $0.115   → NEW invoices use this

Old invoice: unitPriceMicros = 1100  ← UNCHANGED ✓
New invoice: unitPriceMicros = 1150  ← uses new markup ✓
```

### 8.4 Pricing Basis

The `unitTypeId` on `SalesInvoiceItemRow` records which unit type was sold (box/strip/tablet). Combined with `unitPriceMicros`, this provides full pricing traceability:

- Sold by box: `unitPriceMicros = sellingPriceMicros` (package price, no markup)
- Sold by strip: `unitPriceMicros = subUnitPriceMicros` (base unit price × markup)
- Sold by tablet: `unitPriceMicros = subUnitPriceMicros` (base unit price × markup)

---

## SECTION 9 — ROUNDING & MONEY PRECISION

### 9.1 Current Money Implementation

**Storage**: Integer micro-units (scale 4). `1.0000` = 10000 units. No `REAL` columns.

**Key operations**:
- `Money.fromUnits(int)` — from micro-units
- `Money.parse(String)` — from decimal string, half-up rounding
- `Money.divideBy(int)` — integer division with half-up rounding
- `Money.timesRatio(int, int)` — multiply by ratio with half-up rounding
- `Money.roundTo(int)` — round to N decimal places
- `Money * int` — exact integer multiplication (no rounding needed)

### 9.2 Rounding Location

**Recommended**: `round unit price → multiply quantity`

```
partialUnitPrice = baseUnitPrice.timesRatio(11000, 10000)   // rounded to micros
lineTotal = partialUnitPrice * quantityBase                  // exact integer multiplication
```

**Why**: The unit price is stored in `unitPriceMicros` (must be integer micros). Rounding at the unit price level ensures:
1. Stored unit price is clean (no fractional micros)
2. Line total is exact (integer × integer = integer)
3. Invoice total is sum of exact line totals (no accumulated rounding error)

**Alternative rejected**: `multiply exact unit price → round line total` — this would require storing fractional micros (violates the Money contract) or rounding at the line level (which could cause sum-of-lines ≠ total).

### 9.3 Rounding Policy

- **Half-up** (standard commercial rounding) — already implemented in `_roundDiv`
- Unit price rounded to 4 decimal places (micros) — already the `Money.scale`
- Line total: no additional rounding (exact integer multiplication)
- Invoice total: sum of line totals (exact)

### 9.4 Repeating Decimals

Example: `10.0000 ÷ 3 = 3.3333...`

`Money.fromUnits(100000).divideBy(3)` = `_roundDiv(100000, 3)` = `(100000 + 1) ~/ 3` = `33334` = `$3.3334`

This is correct half-up rounding. The 1-micro error is acceptable for pharmaceutical pricing.

---

## SECTION 10 — ACCOUNTING

### 10.1 Trace: Partial-Unit Sale → Accounting

```
POS (partial unit sale)
  ↓
SalesInvoiceItem
  unitPriceMicros = partialUnitPrice (includes markup)
  quantityBaseSigned = base units sold
  lineTotalMicros = unitPrice × qty
  unitCostMicros = batch cost (unchanged by markup)
  profitMicros = lineTotal - costTotal
  ↓
SalesInvoice
  totalMicros = sum of line totals
  profitMicros = sum of line profits
  ↓
Revenue (Phase 10 journal)
  Credit: Sales Revenue = totalMicros
  ↓
Cost of Goods Sold (Phase 10 journal)
  Debit: COGS = totalCostMicros
  ↓
Gross Profit
  Profit = totalMicros - totalCostMicros
  (the markup is baked into totalMicros)
  ↓
Cash / Receivable
  Debit: Cash = paidMicros
  Debit: Accounts Receivable = remainingMicros
```

### 10.2 Markup Effect

| Aspect | Affected? | How |
|---|---|---|
| Revenue | **Yes** | Higher `unitPriceMicros` → higher `totalMicros` |
| Gross Profit | **Yes** | `profitMicros = lineTotal - costTotal` increases |
| Inventory Cost | **No** | `unitCostMicros` comes from batch purchase cost, NOT from selling price |
| Customer Balance | **Yes** | Higher total → higher credit if not fully paid |
| Daily Cash | **Yes** | Higher paid amount if cash sale |
| Financial Reports | **Yes** | Revenue and profit reflect the markup |

### 10.3 Critical Guarantee

**The markup is a selling-price adjustment, NOT an artificial change to inventory acquisition cost.**

- `batch.unitCostMicros` = what the pharmacy paid to the supplier (never changed by markup)
- `sales_invoice_items.unitCostMicros` = snapshot of batch cost at sale time (never changed by markup)
- `sales_invoice_items.profitMicros` = `(sellingPrice × qty) - (costPrice × qty)` — the markup increases the selling price side, not the cost side

---

## SECTION 11 — RETURNS / REFUNDS

### 11.1 Return Scenarios

| Scenario | Behavior |
|---|---|
| Return full package (1 box) | Restore `unitsPerLarge` base units to batch. Reverse `lineTotalMicros`. Update `prescription_items.dispensedQuantityBase` if prescription-linked |
| Return partial units (3 tablets) | Restore 3 base units to batch. Reverse `3 × unitPriceMicros`. Update `prescription_items.dispensedQuantityBase` -= 3 |
| Return items from prescription | Restore stock. Decrement `dispensedQuantityBase` on the prescription item. If all dispensed items returned, prescription reverts to `active` or `partially_dispensed` |
| Return only part of an invoice | `ReturnService.recordSaleReturn()` already handles this — creates `ReturnItems` with partial quantities |

### 11.2 Inventory Restoration

Returns restore stock to the **original batch** (identified via `stock_movements` where `refType = 'sale_line'` and `refId = originalInvoiceItemId`). This is already implemented in `ReturnService`.

### 11.3 Financial Reversal

- Return creates a `Returns` row with `totalMicros` = negative amount (money returned)
- Return creates `ReturnItems` with `quantityBaseSigned` = negative (restores stock)
- The original invoice's `returnQuantityBase` is incremented to prevent over-returning
- Customer balance is adjusted (if credit sale)

### 11.4 Prescription Dispensed Quantity Reversal

When returning items from a prescription-linked sale:
1. Find the `prescription_item_id` on the `SalesInvoiceItemRow`
2. Decrement `prescription_items.dispensedQuantityBase` by the returned quantity
3. Derive new prescription status:
   - If all items now `dispensedQuantityBase == 0` → `active`
   - If some items partially dispensed → `partially_dispensed`
   - If all items fully dispensed → `dispensed` (shouldn't happen after return, but handle gracefully)

### 11.5 Audit

Returns write audit entries with:
- `entityType: 'sales_return'`
- `entityId: return row id`
- `after: { original_invoice_id, total_micros, item_count }`

---

## SECTION 12 — TRANSACTION ATOMICITY

### 12.1 Operations That MUST Be Atomic

**Sale creation** (already implemented in `SaleService.recordSale()` via `db.transaction()`):

```
1. Create SalesInvoice header
2. For each line:
   a. FEFO batch allocation (StockService.allocateFefo)
   b. Create SalesInvoiceItem row
   c. Apply stock movement (StockService.applyMovement)
3. Update SalesInvoice totals
4. Update prescription dispensed quantities (NEW)
5. Derive prescription status (NEW)
6. Write audit entry
```

**All 6 steps happen in ONE transaction.** If any step fails, ALL roll back.

### 12.2 Failure Scenarios

| Failure | Rollback | Evidence |
|---|---|---|
| Invoice created but stock not deducted | Transaction rolls back — invoice not created | `db.transaction()` ensures atomicity |
| Stock deducted but invoice missing | Cannot happen — stock deduction is inside the transaction | `StockService.applyMovement()` called within `SaleService.recordSale()` transaction |
| Prescription marked dispensed but sale failed | Cannot happen — prescription update is inside the same transaction | Phase 6 must add prescription update INSIDE the existing transaction |
| Payment recorded but invoice failed | Cannot happen — payment is recorded as `paidMicros` on the invoice header | Payment is a field on the invoice, not a separate record |

### 12.3 Prescription Update Placement

The prescription `dispensedQuantityBase` update and status derivation MUST happen inside the same transaction as the sale. If the sale rolls back, the prescription must remain unchanged.

```
db.transaction(() async {
  // 1. Create invoice
  // 2. Create invoice items + stock movements
  // 3. Update prescription items (dispensedQuantityBase += saleQty)
  // 4. Derive prescription status
  // 5. Write audit
});
```

---

## SECTION 13 — CONCURRENCY & STOCK SAFETY

### 13.1 Current Protection

**FEFO allocation + stock deduction happen in a single transaction:**

1. `allocateFefo()` reads available batches (SELECT)
2. `applyMovement()` updates `batches.quantityBase` (UPDATE)
3. Both are inside `SaleService.recordSale()` transaction

**SQLite WAL mode** + **transaction isolation** prevents the "lost update" problem:
- Transaction A reads stock = 5, sells 4 → batch updated to 1
- Transaction B starts, reads stock = 1 → cannot sell 4 (NotEnoughStockException)

### 13.2 Desktop-Only Context

The app is desktop-only (single-user per database file). Concurrency is limited to:
- Multiple windows/tabs of the same app (unlikely for a single-pharmacy desktop POS)
- Backup/restore operations (handled separately)

**Current architecture is sufficient.** No additional locking mechanisms needed.

### 13.3 Edge Case: Simultaneous Sales

If two sales happen "simultaneously" (within the same SQLite busy timeout):
- SQLite serializes writes (WAL mode allows concurrent reads but serializes writes)
- First transaction commits, second sees updated stock and either succeeds or gets `NotEnoughStockException`

**No data corruption risk.** The existing architecture handles this correctly.

---

## SECTION 14 — TEST PLAN

### 14.1 Prescription Tests

| # | Test | Type |
|---|---|---|
| P1 | Create prescription with items | Unit |
| P2 | Prescription without sale (status = active) | Unit |
| P3 | Full dispensing (all items, one invoice) | Integration |
| P4 | Partial dispensing (some items, one invoice) | Integration |
| P5 | Multiple invoices for one prescription | Integration |
| P6 | Cancellation (status = cancelled, audit written) | Unit |
| P7 | Expiration (expiryAt < now, rejected by POS) | Unit |
| P8 | Return of prescription items (dispensedQuantity reversed) | Integration |
| P9 | Prepare for sale (active prescription) | Unit |
| P10 | Prepare for sale (expired prescription → rejected) | Unit |
| P11 | Prepare for sale (cancelled prescription → rejected) | Unit |
| P12 | Prescription item quantity constraints (dispensedQuantityBase <= quantityBase) | Unit |

### 14.2 Partial-Unit Tests

| # | Test | Type |
|---|---|---|
| U1 | Box sale (1 box = unitsPerLarge base units) | Unit |
| U2 | Strip sale (sub-unit sale) | Unit |
| U3 | Tablet sale (smallest sub-unit) | Unit |
| U4 | Multi-level conversion (box → strip → tablet) | Unit |
| U5 | Insufficient stock (NotEnoughStockException) | Unit |
| U6 | FEFO batch allocation across multiple batches | Unit |
| U7 | BaseUnitConverter.toBaseUnits | Unit |
| U8 | BaseUnitConverter.splitToUnits | Unit |

### 14.3 Pricing Tests

| # | Test | Type |
|---|---|---|
| R1 | 10% markup: verify base unit price × 1.10 | Unit |
| R2 | 15% markup: verify base unit price × 1.15 | Unit |
| R3 | 0% markup: verify base unit price × 1.00 | Unit |
| R4 | Markup applied exactly once (non-cumulative) | Unit |
| R5 | Package sale (no markup applied) | Unit |
| R6 | Changed markup does NOT affect historical invoices | Integration |
| R7 | Money.divideBy precision (repeating decimals) | Unit |
| R8 | Money.timesRatio precision | Unit |
| R9 | Line total = rounded unit price × quantity (exact) | Unit |
| R10 | Invoice total = sum of line totals (exact) | Unit |

### 14.4 Accounting Tests

| # | Test | Type |
|---|---|---|
| A1 | Revenue = totalMicros (includes markup) | Integration |
| A2 | COGS = totalCostMicros (batch cost, NOT selling price) | Integration |
| A3 | Profit = revenue - COGS | Integration |
| A4 | Cash payment (paidMicros = totalMicros) | Integration |
| A5 | Credit sale (paidMicros < totalMicros, remainingMicros > 0) | Integration |
| A6 | Return reverses revenue and restores stock | Integration |
| A7 | Return of prescription item reverses dispensedQuantity | Integration |

### 14.5 Settings Tests

| # | Test | Type |
|---|---|---|
| S1 | Read markup setting from app_settings | Unit |
| S2 | Update markup setting (admin only) | Unit |
| S3 | Markup change affects new sales, not old ones | Integration |

---

## SECTION 15 — DESIGN DECISIONS

### FINAL LOCKED BUSINESS RULES

#### 1. Prescription Lifecycle
- States: `active`, `partially_dispensed`, `dispensed`, `expired`, `cancelled`
- `partially_dispensed` is a NEW state required for partial dispensing
- Transitions are one-way (no re-activation from `dispensed`/`expired`/`cancelled`)
- Cancellation is permanent and audited

#### 2. Partial Dispensing
- `prescription_items.dispensedQuantityBase` tracks cumulative dispensing
- One prescription item CAN be dispensed across multiple invoices
- Header status is derived from items: all dispensed → `dispensed`, some → `partially_dispensed`, none → `active`

#### 3. Prescription ↔ Invoice Cardinality
- One prescription → many invoices (partial dispensing across visits)
- One invoice → at most one prescription (`prescription_id` nullable FK)
- One invoice can contain prescription items + OTC items
- One prescription item → many invoice items (across multiple sales)

#### 4. Partial-Unit Conversion
- All inventory in base units (integer)
- `item_units.unitsPerLarge` = conversion factor
- `BaseUnitConverter` handles box↔strip↔tablet conversion
- Stock deduction always in base units

#### 5. Base-Unit Definition
- 1 base unit = 1 strip/tablet/fractional unit
- Defined per item in `item_units`
- Stock tracked in base units (`batches.quantityBase`, `items.currentStockBase`)

#### 6. Partial-Unit Pricing
- `BaseUnitPrice = CommercialSellingPrice ÷ TotalBaseUnitsInPackage`
- `PartialUnitPrice = BaseUnitPrice × (10000 + markupBasisPoints) ÷ 10000`
- Applied ONLY when sale unit type is sub-unit (not package)
- Uses `Money.divideBy()` and `Money.timesRatio()` for integer-safe calculation

#### 7. NON-CUMULATIVE 10% MARKUP
- Markup applied exactly ONCE at the base-unit level
- NOT at each conversion level (box→strip, strip→tablet)
- Default: 1000 basis points (10%)
- Formula: `baseUnitPrice × 1.10`

#### 8. Markup Configuration
- Stored in `app_settings` table (key-value)
- Key: `partial_unit_markup_basis_points`
- Default: `1000` (10%)
- Global (not per-product)
- Admin-only edit with audit trail
- Valid range: 0–10000 (0%–100%)

#### 9. Rounding
- Half-up rounding (standard commercial)
- Unit price rounded to micros (4 decimal places) via `Money.timesRatio()`
- Line total = rounded unit price × quantity (exact integer multiplication)
- Invoice total = sum of line totals (exact)

#### 10. Historical Pricing
- `SalesInvoiceItemRow.unitPriceMicros` frozen at creation time
- Changing markup/item prices does NOT affect historical invoices
- `unitTypeId` records which unit was sold (pricing traceability)

#### 11. Returns
- Returns restore stock to original batch (FEFO)
- Returns reverse `dispensedQuantityBase` on prescription items
- Returns create `Returns` + `ReturnItems` rows (financial reversal)
- Original invoice's `returnQuantityBase` prevents over-returning

#### 12. Accounting
- Markup is a selling-price adjustment (NOT cost manipulation)
- Revenue includes markup; COGS uses batch cost
- Profit = revenue - COGS (markup increases profit)
- Journal entries (Phase 10) post from invoice totals

#### 13. Transaction Atomicity
- Sale creation is ONE atomic transaction
- Includes: invoice, items, stock, prescription updates, audit
- Any failure rolls back ALL changes
- Prescription update happens INSIDE the sale transaction

---

## SECTION 16 — IMPLEMENTATION CONTRACT

### MUST

1. **Schema**: Add `sales_invoices.prescription_id TEXT NULL REFERENCES prescriptions(id)` — schemaVersion bump to 2
2. **Schema**: Add `sales_invoice_items.prescription_item_id TEXT NULL REFERENCES prescription_items(id)`
3. **Schema**: Add `prescription_items.dispensedQuantityBase INTEGER DEFAULT 0`
4. **Schema**: Add `app_settings` table with seed row `partial_unit_markup_basis_points = 1000`
5. **Enum**: Add `partially_dispensed` to `PrescriptionStatus`
6. **Service**: Create `PartialUnitPriceCalculator` service with `calculate()` method
7. **Service**: Create `PrescriptionDispensingService` to update `dispensedQuantityBase` and derive status
8. **SaleService**: Accept optional `prescriptionId` in `SaleRequest`; update prescription after sale
9. **SaleService**: Accept optional `prescriptionItemId` + `dispensedQuantityBase` in `SaleLineRequest`
10. **Settings**: Create `AppSettingsDao` to read/write key-value settings
11. **PrescriptionStatus**: Update all existing `.equalsValue(PrescriptionStatus.active)` checks to also accept `partially_dispensed` where appropriate
12. **FEFO**: Use existing `StockService.allocateFefo()` — no changes needed
13. **Stock**: Use existing `StockService.applyMovement()` — no changes needed
14. **Money**: Use existing `Money.divideBy()` and `Money.timesRatio()` — no changes needed
15. **Tests**: Implement all tests from Section 14
16. **Audit**: All prescription status changes and markup setting changes write audit entries

### MUST NOT

1. **MUST NOT** modify `Money` class
2. **MUST NOT** modify `StockService` or `BaseUnitConverter`
3. **MUST NOT** add product-specific markup (global only)
4. **MUST NOT** apply markup cumulatively at each conversion level
5. **MUST NOT** allow re-activation of `dispensed`, `expired`, or `cancelled` prescriptions
6. **MUST NOT** allow deletion of prescriptions or invoices (soft lifecycle only)
7. **MUST NOT** store money in `REAL` columns
8. **MUST NOT** use floating-point for pricing calculations
9. **MUST NOT** update historical `SalesInvoiceItemRow.unitPriceMicros`
10. **MUST NOT** create invoice without stock deduction (atomic transaction)
11. **MUST NOT** mark prescription dispensed if sale fails (atomic transaction)
12. **MUST NOT** hard-code the markup percentage (use `app_settings`)
13. **MUST NOT** bypass RBAC checks in use-case layer

### DATABASE

| Change | Table | Column | Type | Default | FK |
|---|---|---|---|---|---|
| Add | `sales_invoices` | `prescription_id` | TEXT NULL | null | → `prescriptions(id)` |
| Add | `sales_invoice_items` | `prescription_item_id` | TEXT NULL | null | → `prescription_items(id)` |
| Add | `prescription_items` | `dispensed_quantity_base` | INTEGER | 0 | — |
| Add | `app_settings` | — | TABLE | — | — |
| Modify | `prescriptions` | `status` | textEnum | — | Add `partially_dispensed` value |
| Bump | `schemaVersion` | — | — | 1 → 2 | — |

### DOMAIN

| Responsibility | Location |
|---|---|
| Partial-unit price calculation | `PartialUnitPriceCalculator` (new service in `lib/domain/services/`) |
| Prescription dispensing update | `PrescriptionDispensingService` (new service in `lib/domain/services/`) |
| App settings read/write | `AppSettingsDao` (new DAO in `lib/data/daos/`) |
| Markup setting access | `AppSettingsRepository` (new in `lib/features/settings/`) |

### SERVICES

| Service | Responsibility |
|---|---|
| `SaleService` | Accept `prescriptionId`, `prescriptionItemId`, `dispensedQuantityBase` on lines. Call `PrescriptionDispensingService` inside transaction |
| `PartialUnitPriceCalculator` | `calculate(sellingPriceMicros, unitsPerLarge, markupBasisPoints, saleUnitTypeId, largeUnitId)` → returns `int unitPriceMicros` |
| `PrescriptionDispensingService` | `dispense(db, prescriptionItemId, quantityBase)` → updates `dispensedQuantityBase`, derives header status |
| `StockService` | **No changes** — existing FEFO + movement logic is sufficient |
| `ReturnService` | **Extend** to handle prescription item `dispensedQuantityBase` reversal on prescription-linked returns |

### UI

| Screen | Behavior |
|---|---|
| POS (Phase 6) | Attach prescription → load items → allow partial selection → compute partial-unit prices → complete sale |
| Prescription detail | Show `dispensedQuantityBase` / `quantityBase` per item |
| Admin settings | Read/write `partial_unit_markup_basis_points` (admin only) |
| Customer statement | No changes needed — financial data unaffected |

### TESTS

All tests from Section 14 must be implemented. Minimum acceptance threshold:
- All 155 existing tests continue to pass (no regression)
- All new tests pass
- `flutter analyze` → 0 issues

---

## FINAL VERDICT

🟢 **DESIGN LOCKED — READY FOR PHASE 6 IMPLEMENTATION**

All ambiguities resolved. The design is grounded in the actual codebase (32 tables, 155 tests, 53 FKs). Schema changes are minimal and forward-only. The partial-unit pricing model is non-cumulative and integer-safe. The prescription lifecycle supports partial dispensing. Transaction atomicity is preserved. Historical pricing is immutable.
