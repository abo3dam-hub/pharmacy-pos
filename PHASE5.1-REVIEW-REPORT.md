# Phase 5.1 Review Report — Pre-Phase-6 Architecture & Data Integrity Audit

**Date:** 2026-09-06
**Scope:** Customer Schema Consistency, Prescription→Sales Invoice Linkage, Partial-Unit Selling + 10% Configurable Markup
**Baseline:** Phases 1–5 approved, 155 tests passing, `flutter analyze` → 0 issues, schema version 1, 32 tables

---

## 1. Executive Summary

The codebase is well-structured clean architecture (32 tables, 53 FKs, 16 CHECK constraints, 60 indexes) with consistent layering across all phases. Two of the three focus areas have concrete findings that need attention before Phase 6 begins. The **prescription→sales invoice linkage** has a documented schema gap (`sales_invoices.prescription_id` is missing) and no dispense-status update mechanism. The **partial-unit selling** model has the data infrastructure (`ItemUnits`, `BaseUnitConverter`, `subUnitPriceMicros`) but lacks the configurable markup setting and the automatic sub-unit price derivation. The **customer schema** is clean and consistent across all layers.

---

## 2. Project Baseline

| Property | Value |
|---|---|
| Flutter/Dart SDK | ^3.13.2 |
| Database | drift ^2.28.0, sqlite3_flutter_libs, schema version **1** |
| Tables | 32 |
| Foreign keys | 53 (including 3 self-referential) |
| CHECK constraints | 16 |
| Indexes | 60 (non-PK, non-unique-inline) |
| Architecture | Clean arch: data/domain/application/presentation |
| State management | flutter_riverpod ^2.6.1 |
| DI | get_it ^8.0.0 |
| Navigation | go_router ^14.0.0 |
| Tests | **155 passing** |
| Analyzer | **0 issues** |
| Money model | Integer micro-units, scale 4, `Money` class with half-up rounding |

---

## 3. Customer Schema Consistency

**Status: 🟢 PASS**

### Evidence

**Database** (`tables/customers.dart`):
- PK: `id` (TEXT, NOT NULL, UUID-prefixed `cus_`)
- Required fields: `name`, `openingBalanceMicros`, `balanceMicros`, `creditLimitMicros`, `hasAccount`, `isActive`, `createdAt`, `updatedAt`
- Nullable fields: `phone`, `secondaryPhone`, `email`, `address`, `notes`, `dateOfBirth`, `gender`, `medicalHistory`, `taxVatNumber`
- Index: `idx_customers_name`
- No duplicate tables, no legacy fields

**DAO** (`data/daos/customer_dao.dart`):
- Balance is **derived** from the ledger via `_balanceFeedSnippet` (SQL snippet combining `opening_balance_micros + SUM(sales remaining) + SUM(sale returns)`)
- `syncBalance()` re-derives from ledger — never hand-edited
- Statement uses CTE with `UNION ALL` of completed sales invoices + sale returns, keyset pagination

**Repository** (`customer_repository_impl.dart`):
- `_customerExists()` correctly uses `where` clause (fixed in Phase 5)
- `update()` calls `syncBalance()` after opening-balance changes
- Statement prepends opening row on page 1, computes running balances in Dart

**Use cases** (`customers_use_cases.dart`):
- RBAC: `customers.view/create/edit` enforced in use-case layer
- Statement: double-gated by `customers.view` + `reports.view_sales`
- Audit: create/update/toggle-active/toggle-account all write audit rows
- Opening-balance change gets explicit `customer_balance` audit entry

**UI** (`customers_page.dart`, `customer_dialog.dart`, `customer_statement_page.dart`):
- Statement action gated by `_canView && c.hasAccount` in UI
- Dialog validates name required
- Statement shows debit/credit/balance columns with `Money.fromUnits().format()`

**Tests** (6 tests):
- create → master list → balance
- update/toggleActive/setAccount persistence
- viewer RBAC (denied create, allowed list)
- statement aggregation (opening + invoice + return → running balance)
- audit rows (4 entries)
- SQL-side search + pagination

### Findings

1. **No hard-delete** — customers are soft-deleted via `isActive`. No FK cascade risk. Historical records (sales, prescriptions, returns) remain intact.
2. **Minor**: `customers.phone` has no dedicated index. Search uses LIKE across `name|phone|email|taxVatNumber` — acceptable for expected data volume.

### Recommended Action

None required. Schema is clean and consistent.

---

## 4. Prescription → Sales Invoice Linkage

**Status: 🟡 WARNING**

### Evidence

**Prescriptions table** (`tables/prescriptions.dart`):
- `customerId` (TEXT, NOT NULL, FK → Customers.id)
- `totalMicros` (INTEGER, default 0)
- `status` (textEnum: `active|dispensed|expired|cancelled`)
- `prescriptionNumber` (TEXT, UNIQUE, `RX-<millis>`)
- No `prescription_id` on `SalesInvoices`

**SalesInvoices table** (`tables/sales_invoices.dart`):
- `customerId` (TEXT, nullable, FK → Customers.id) — walk-in cash sales allowed
- **No `prescription_id` column** — the documented gap from Phase 5

**PrescriptionItems table** (`tables/prescription_items.dart`):
- `isDispensed` (BOOLEAN, default false) — exists but **never set to true** by any code path

**PreparedSalePrescription** (`prescription_repository.dart`):
- In-memory snapshot with `prescription`, `customerName`, `items`
- `isReady` getter: `status == active && items.isNotEmpty`
- Phase 6 is expected to consume this and create a sale

**SaleService** (`domain/services/sale_service.dart`):
- `SaleRequest` has no `prescriptionId` field
- `recordSale()` creates `SalesInvoices` + `SalesInvoiceItems` — no prescription linkage
- After sale completes, prescription remains `active` (not `dispensed`)

### Scenario Analysis

| # | Scenario | Supported? | Evidence |
|---|---|---|---|
| 1 | Prescription exists, no sale | ✅ | Prescription stays `active` |
| 2 | Prescription → one sale | ⚠️ | Sale created but no FK link back; prescription not marked dispensed |
| 3 | Sale without prescription | ✅ | `SalesInvoices.customerId` is nullable |
| 4 | Sale contains prescription medicines | ✅ | Items are just `itemId` references |
| 5 | Prescription items not sold immediately | ✅ | `isDispensed` per-item exists (unused) |
| 6 | Prescription associated with invoice | ❌ | No FK, no association mechanism |
| 7 | Invoice cancelled | ✅ | Prescription stays `active` (independent) |
| 8 | Sale returned/refunded | ✅ | Returns restore stock; prescription unaffected |
| 9 | Prescription as medical record | ✅ | Independent table, never cascaded |
| 10 | Invoice as financial record | ✅ | Independent table |

### Findings

1. **BLOCKER-level gap**: `sales_invoices` has no `prescription_id` column. Phase 6 POS cannot link a sale back to its originating prescription without this column.
2. **Missing dispense update**: `prescription_items.isDispensed` exists but is never set to `true`. When a prescription is sold, items should be marked dispensed and the header status should move to `dispensed`.
3. **No FK cascade risk**: Medical history and financial history are logically separable — prescriptions and invoices are independent tables. A cancelled/voided invoice does not affect the prescription record. This is correct.
4. **`PreparedSalePrescription` is ephemeral**: The in-memory snapshot has no persistence. If the app crashes between "prepare" and "sale completion", the prepare state is lost. This is acceptable for a desktop POS (atomic UX flow).

### Recommended Action

**P1 — IMPORTANT** (can be implemented in Phase 6 alongside the POS):
1. Add `sales_invoices.prescription_id TEXT NULL REFERENCES prescriptions(id)` via forward-only migration (§29) in Phase 6.
2. After `SaleService.recordSale()`, if a `prescriptionId` was provided: update `prescriptions.status = dispensed` and set `prescription_items.isDispensed = true` for all items in the prescription.
3. Add `prescriptionId` to `SaleRequest` as an optional field.
4. This is a schema change — requires `schemaVersion` bump from 1 to 2.

---

## 5. Partial-Unit Selling

**Status: 🟡 WARNING**

### Evidence

**ItemUnits table** (`tables/item_units.dart`):
- `itemId` (FK → Items), `baseUnitId` (FK → Units), `largeUnitId` (FK → Units)
- `unitsPerLarge` (INTEGER, default 1, CHECK ≥ 1)
- Composite unique: `{itemId, baseUnitId, largeUnitId}`
- This is the conversion factor table (e.g., 1 box = 10 strips)

**Units table** (`tables/units.dart`):
- 3 seed units: `unit_strip` (شريط/Strip), `unit_box` (علبة/Box), `unit_tablet` (قرص/Tablet)

**Items table** (`tables/items.dart`):
- `sellingPriceMicros` — package/base selling price
- `subUnitPriceMicros` — **exists but default 0**, intended for sub-unit price
- `wholesalePriceMicros`, `halfWholesalePriceMicros`, `customPrice1Micros`, `customPrice2Micros`

**BaseUnitConverter** (`domain/services/base_unit_converter.dart`):
- `toBaseUnits(boxes, strips, unitsPerLarge)` → `boxes * unitsPerLarge + strips`
- `splitToUnits(baseUnits, unitsPerLarge)` → `BaseUnitBreakdown(boxes, strips, boxSize)`
- Pure conversion — no pricing logic

**SaleService** (`domain/services/sale_service.dart`):
- `SaleLineRequest.unitPriceMicros` — caller-provided price
- `SaleLineRequest.unitTypeId` — unit type at sell time
- **No partial-unit markup logic** — the service trusts the caller's price

**StockService** (`domain/services/stock_service.dart`):
- `allocateFefo(db, itemId, quantityBase)` — allocates by base units
- `applyMovement()` — all quantities are in base units
- Stock is tracked entirely in base units (integer)

### Conversion Chain

```
1 box = 10 strips (ItemUnits.unitsPerLarge)
1 strip = 1 tablet (if defined)

Selling 2 strips:
  BaseUnitConverter.toBaseUnits(boxes: 0, strips: 2, unitsPerLarge: 10) → 2 base units
  StockService.allocateFefo(db, itemId, 2) → deducts 2 from batch.quantityBase
```

**Integer-only**: All quantities are `int` (base units). No decimals. No floating-point risk.

### Findings

1. **No configurable markup setting**: The 10% default partial-unit markup is specified in the business rules but has **no database column, no settings table entry, and no configuration service**. The `AppConfig` class has only static constants (app name, version, locale).
2. **`subUnitPriceMicros` is not auto-derived**: When an item's `sellingPriceMicros` changes, `subUnitPriceMicros` is not automatically recalculated. It stays at its last-set value (default 0).
3. **No markup calculation in SaleService**: The POS caller must compute the partial-unit price manually. There is no centralized service that applies the 10% markup.
4. **Stock deduction is correct**: `StockService.allocateFefo` works entirely in base units. Selling 2 strips from a box of 10 correctly deducts 2 base units from the batch.
5. **Historical price preservation**: `SalesInvoiceItems.unitPriceMicros` is written at sale time. Changing the markup setting later does NOT affect historical invoices. This is correct.

### Recommended Action

**P1 — IMPORTANT** (should be implemented in Phase 6):
1. Add a `settings` table or extend `AppConfig` with a `partialUnitMarkupBasisPoints` column (default 1000 = 10%). This must be persisted in the database, not a static constant.
2. Add a `PartialUnitPriceCalculator` service that:
   - Takes `sellingPriceMicros`, `unitsPerLarge`, and `markupBasisPoints`
   - Returns `subUnitPriceMicros = (sellingPriceMicros / unitsPerLarge) * (10000 + markupBasisPoints) / 10000`
   - Uses `Money.timesRatio()` for integer-safe calculation
3. When `sellingPriceMicros` is updated (via price change workflow), auto-recalculate `subUnitPriceMicros` using the current markup setting.
4. In Phase 6 POS, when a line's `unitTypeId` differs from the item's large unit, use `subUnitPriceMicros` instead of `sellingPriceMicros`.

---

## 6. Accounting Impact

**Status: 🟢 PASS (deferred)**

### Findings

- **Journal entries** (Phase 10): Schema exists (`JournalEntries`, `JournalEntryLines`) but no service writes to them yet.
- **SaleService** records `totalCostMicros` and `profitMicros` on the invoice — sufficient for Phase 10 journal posting.
- **VAT**: `SaleLineRequest.vatRateBasisPoints` is accepted and `taxMicros` computed per line. Invoice-level `vatTotalMicros` is accumulated.
- **Profit**: Computed per line as `(unitPrice * qty) - (unitCost * qty) - discount`. Stored on `SalesInvoiceItems.profitMicros`.
- **Partial-unit markup**: When implemented, the markup will flow into `unitPriceMicros` at sale time, so `profitMicros` will naturally reflect it.
- No inconsistencies found between POS totals and accounting totals (accounting not yet implemented).

---

## 7. Data Integrity

**Status: 🟢 PASS**

| Area | Status | Evidence |
|---|---|---|
| Primary keys | ✅ | All TEXT UUID-prefixed, consistent format |
| Foreign keys | ✅ | 53 FKs enforced, `PRAGMA foreign_keys = ON` |
| Unique constraints | ✅ | 21 constraints (inline + composite) |
| CHECK constraints | ✅ | 16 constraints (quantity ≥ 0, amount ≠ 0, etc.) |
| Indexes | ✅ | 60 indexes covering search/filter/join columns |
| Nullability | ✅ | Correct: required fields NOT NULL, optional nullable |
| Cascade behavior | ✅ | No accidental cascades — soft-delete pattern used |
| Transaction boundaries | ✅ | `SaleService.recordSale()`, `PrescriptionDao.insertWithItems()` use `db.transaction()` |
| Concurrent writes | ⚠️ | Desktop-only, WAL mode enabled. Low risk but no explicit locking |
| Database init | ✅ | `onCreate` seeds defaults, `onUpgrade` forward-only migration |

---

## 8. Test Coverage

**Current: 155 tests**

### Coverage Matrix

| Area | Covered | Tests |
|---|---|---|
| **Customer** create | ✅ | `customers_controller_test.dart` #1 |
| **Customer** update | ✅ | #2 |
| **Customer** lookup/list | ✅ | #1, #6 |
| **Customer** deactivation | ✅ | #2 |
| **Customer** account toggle | ✅ | #2 |
| **Customer** statement | ✅ | #4 |
| **Customer** RBAC | ✅ | #3 |
| **Customer** audit | ✅ | #5 |
| **Prescription** create | ✅ | `prescriptions_controller_test.dart` #1 |
| **Prescription** lookup | ✅ | #1, #3 |
| **Prescription** → customer relationship | ✅ | #1 (joined name), #2 (FK validation) |
| **Prescription** → sale/invoice | ❌ | No test — linkage doesn't exist yet |
| **Prescription** dispense | ❌ | No test — `isDispensed` never set |
| **Prescription** RBAC | ✅ | #5 |
| **Prescription** audit | ✅ | #6 |
| **Unit conversion** (BaseUnitConverter) | ❌ | No direct test |
| **FEFO allocation** (StockService) | ❌ | No direct test (indirect via purchases_flow_test) |
| **Partial-unit price** | ❌ | No test — markup not implemented |
| **Configurable markup** | ❌ | No test — setting doesn't exist |
| **Historical price preservation** | ❌ | No test |
| **Rounding** (Money) | ❌ | No direct test for `divideBy`, `timesRatio`, `roundTo` |

### Missing Tests (for Phase 6)

1. `BaseUnitConverter.toBaseUnits` / `splitToUnits` unit tests
2. `StockService.allocateFefo` tests (multiple batches, expiry, insufficient stock)
3. `Money.divideBy`, `Money.timesRatio`, `Money.roundTo` precision tests
4. Partial-unit markup calculation tests
5. Prescribe→Sale→Dispense lifecycle integration test
6. Historical invoice price preservation test (change markup, verify old invoices unchanged)

---

## 9. Cross-Layer Consistency

### Customer: ✅ Consistent
- DB: `customers.id` (TEXT) → DAO: `byId(String id)` → Repo: `findById(String id)` → UseCase: `call(...)` → Controller: `load/add/update` → UI: displays `CustomerRow.name`
- Balance: DB `balance_micros` ← `CustomerDao._balanceFeedSnippet` ← SalesInvoices + Returns
- All layers use the same `CustomerDraft` for create/update
- All layers use `CustomerRow` (Drift-generated) consistently

### Prescription: ✅ Consistent
- DB: `prescriptions.customer_id` (NOT NULL FK) → DAO: `search()` joins customers → Repo: `create()` validates customer exists → UseCase: `_validate()` checks customerId non-empty
- `PrescriptionItemView.unitPriceMicros` reads from `items.sellingPriceMicros` — same field used by POS
- `PreparedSalePrescription` correctly packages the data Phase 6 needs
- All layers use `PrescriptionDraft` / `PrescriptionRow` consistently

### Partial-Unit: ⚠️ Inconsistent
- DB: `item_units.unitsPerLarge` exists, `items.subUnitPriceMicros` exists (default 0)
- Service: `BaseUnitConverter` handles conversion but has no pricing logic
- SaleService: `unitPriceMicros` is caller-provided — no validation against markup rules
- **Gap**: No layer enforces or calculates the 10% markup. The business rule exists only in the spec document.

---

## 10. Required Fixes Before Phase 6

### P0 — BLOCKER

None. The documented `prescription_id` gap is explicitly deferred to Phase 6 (schema migration planned).

### P1 — IMPORTANT

| # | Area | Fix | Effort | When |
|---|---|---|---|---|
| 1 | Prescription→Sale | Add `sales_invoices.prescription_id TEXT NULL` + `schemaVersion` bump to 2 | Small | Phase 6 start |
| 2 | Prescription→Sale | Add `prescriptionId` optional field to `SaleRequest`; update `prescriptions.status` to `dispensed` + `prescription_items.isDispensed = true` after sale | Medium | Phase 6 POS |
| 3 | Partial-unit | Add `partial_unit_markup_basis_points` to a settings table (default 1000 = 10%) | Small | Phase 6 start |
| 4 | Partial-unit | Create `PartialUnitPriceCalculator` service using `Money.timesRatio()` | Small | Phase 6 POS |
| 5 | Partial-unit | Auto-derive `subUnitPriceMicros` when `sellingPriceMicros` changes | Small | Phase 6 pricing |

### P2 — OPTIONAL

| # | Area | Fix | Effort | When |
|---|---|---|---|---|
| 6 | Test | Add `BaseUnitConverter` unit tests | Small | Anytime |
| 7 | Test | Add `Money.divideBy`/`timesRatio` precision tests | Small | Anytime |
| 8 | Test | Add FEFO allocation edge-case tests | Medium | Anytime |
| 9 | Customer | Add index on `customers.phone` for search perf | Tiny | If needed |

---

## 11. Phase 6 Readiness

**🟡 READY AFTER P1 FIXES**

The codebase is architecturally sound. The customer schema is clean. The prescription system is well-structured with correct separation of medical and financial records. The unit/stock model supports partial-unit selling at the data level.

Before Phase 6 POS implementation begins:
- Items 1-5 (P1) should be planned into the Phase 6 task list
- The schema migration (prescription_id + settings table) should be the first commit of Phase 6
- The partial-unit price calculator should be built before the cart/checkout flow

None of these are blockers for starting Phase 6 — they are implementation tasks that belong in Phase 6 itself. The architecture is ready to receive them.
