# Phase 6 Cross-Phase Integration Report

**Date**: 2026-09-06
**Baseline**: `634faac` — 195 tests, 0 analyzer issues, schema v2
**Final**: `TBD` — 212 tests, 0 analyzer issues, schema v4

---

## Executive Summary

Phase 6 cross-phase integration is **complete**. The system now operates as one coherent pharmacy management & POS platform across all 6 phases. The critical gaps — missing prescription→invoice linkage, non-functional partial-sale in actual sales, and no prescription dispensing lifecycle — have been resolved.

---

## Changes Made

### 1. Schema Changes (3 new columns, migration v2 → v4)

| Table | Column | Type | Default | Purpose |
|-------|--------|------|---------|---------|
| `sales_invoices` | `prescription_id` | `TEXT NULL` | `NULL` | Links sale to prescription (§4.14) |
| `sales_invoice_items` | `prescription_item_id` | `TEXT NULL` | `NULL` | Links sale line to prescription item (§4.15) |
| `prescription_items` | `dispensed_quantity_base` | `INTEGER` | `0` | Tracks cumulative dispensing (§12) |

**Migration path**: v1 → v4 forward-only (existing v2 databases upgrade in-place).

### 2. SaleService Integration (`lib/domain/services/sale_service.dart`)

- Added `prescriptionId` optional field to `SaleRequest`
- Added `prescriptionItemId` and `partialSaleUnitPriceMicros` optional fields to `SaleLineRequest`
- Prescription validation: verifies prescription exists and is `active` or `partially_dispensed`
- Prescription item capacity check: prevents dispensing more than prescribed
- Writes `prescriptionId` to invoice header and `prescriptionItemId` to line items
- Updates `dispensedQuantityBase` and `isDispensed` on prescription items after sale
- Automatically updates prescription status: `active` → `partially_dispensed` → `dispensed`
- Partial-sale pricing: passes through pre-computed `partialSaleUnitPriceMicros` from `PartialPriceCalculator`

### 3. ReturnService Integration (`lib/domain/services/return_service.dart`)

- When returning a prescription-linked sale line, reverses `dispensedQuantityBase` on the prescription item
- Rechecks and updates prescription status after return (`partially_dispensed` ↔ `active` ↔ `dispensed`)
- Added `_recheckPrescriptionStatus()` helper

### 4. Drift Code Regeneration

- `app_database.g.dart` regenerated with new columns and FK references
- Schema version bumped from 2 → 4

### 5. Test Updates

- `migration_test.dart`: Updated `_V2Database` to handle v4 migration, drops all v2+ columns when simulating v1
- `backup_service_test.dart`: Updated schema version assertion from 2 → 4
- `prescription_repository_impl.dart`: Added `dispensedQuantityBase: 0` to `PrescriptionItemRow` constructors

### 6. Integration Tests (17 new tests in `cross_phase_integration_test.dart`)

| Test | Description | Verifies |
|------|-------------|----------|
| **A** | Purchase → Sale lifecycle | FEFO deduction, ledger, profit, stock, atomic rollback |
| **B** | Partial-sale pricing | Decomposition, consistency invariant |
| **C** | Partial-sale in actual sale flow | `partialSaleUnitPriceMicros` → invoice, stock deduction |
| **D** | Prescription dispensing lifecycle | Full/partial dispensing, over-dispensing rejection |
| **E** | Return reverses prescription dispensing | `dispensedQuantityBase` reversal, status recheck |
| **F** | Prescription + OTC in same invoice | Mixed lines, selective prescription linkage |
| **G** | Invalid prescription linkage rejected | Non-existent RX, cross-RX item linking |
| **H** | Atomic transaction rollback | No partial state on failure |
| **I** | Schema integrity | All Phase 6 columns exist and are writable |
| **J** | Multi-line FEFO across batches | Earliest-expiry-first allocation |

---

## Cross-Phase Integration Matrix

| Phase | Feature | Status | Integration Point |
|-------|---------|--------|-------------------|
| Phase 1 | Database schema | ✅ | Schema v4, 33+ tables, FK references |
| Phase 2 | Inventory (batches, FEFO) | ✅ | SaleService uses FEFO, ReturnService restores to original batch |
| Phase 3 | RBAC | ✅ | SaleService enforces `Perm.salesCreate` |
| Phase 4 | Audit | ✅ | SaleService writes audit on completed sales |
| Phase 5 | Backup/Migration | ✅ | v1→v4 forward-only migration, backup schema assertion updated |
| Phase 6 | POS / Partial Sale / Prescription | ✅ | PartialPriceCalculator, prescription dispensing lifecycle |

---

## Files Modified

1. `lib/shared/database/tables/sales_invoices.dart` — +`prescription_id`
2. `lib/shared/database/tables/sales_invoice_items.dart` — +`prescription_item_id`
3. `lib/shared/database/tables/prescription_items.dart` — +`dispensed_quantity_base`
4. `lib/shared/database/app_database.dart` — schema v4, migration v2→v4
5. `lib/domain/services/sale_service.dart` — prescription linkage, partial-sale pricing
6. `lib/domain/services/return_service.dart` — prescription dispensing reversal
7. `lib/features/prescriptions/data/repositories/prescription_repository_impl.dart` — `dispensedQuantityBase` field
8. `test/cross_phase_integration_test.dart` — **NEW** 17 integration tests
9. `test/migration_test.dart` — v4 migration test updates
10. `test/backup_service_test.dart` — schema version assertion

---

## Verification Gate

- [x] `flutter analyze` — 0 issues
- [x] `flutter test` — 212/212 passing
- [x] Schema v4 with all Phase 6 columns
- [x] Prescription→invoice linkage functional
- [x] Partial-sale pricing integrated into sale flow
- [x] Prescription dispensing lifecycle (active → partially_dispensed → dispensed)
- [x] Return reverses prescription dispensing
- [x] Atomic transaction rollback verified
- [x] FEFO batch allocation verified
- [x] Cross-phase integration tests (A–J) all passing
