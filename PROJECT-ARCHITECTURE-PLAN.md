# Pharmacy Management & POS System — Authoritative Architecture & Implementation Blueprint

> **Document status:** Authoritative implementation blueprint.
> This document is the single source of truth that reconciles the original Pharmacy Management & POS — Architecture & Database Foundation Specification with the technical implementation plan.
> All functional requirements from the original specification are preserved in full. Nothing is omitted, simplified, renamed, or weakened.

---

## Table of Contents

1. [Project Goals](#1-project-goals)
2. [Technology Stack](#2-technology-stack)
3. [Architecture](#3-architecture)
4. [Complete Database Schema](#4-complete-database-schema)
5. [Items / Product Model](#5-items--product-model)
6. [Batch Model](#6-batch-model)
7. [Units & Base Unit Quantity Model](#7-units--base-unit-quantity-model)
8. [Pricing Model](#8-pricing-model)
9. [Inventory Model](#9-inventory-model)
10. [Stock Movement Ledger](#10-stock-movement-ledger)
11. [Sales Model](#11-sales-model)
12. [Purchase Model](#12-purchase-model)
13. [Purchase Bonus Engine](#13-purchase-bonus-engine)
14. [Returns Model (Hybrid)](#14-returns-model-hybrid)
15. [Lost Sales Model](#15-lost-sales-model)
16. [Users, Roles & Permissions](#16-users-roles--permissions)
17. [Audit Logging](#17-audit-logging)
18. [Smart Alternatives Engine](#18-smart-alternatives-engine)
19. [POS Workspace](#19-pos-workspace)
20. [Barcode Scanner Architecture](#20-barcode-scanner-architecture)
21. [Keyboard Shortcuts](#21-keyboard-shortcuts)
22. [Data Grids & Bulk Actions](#22-data-grids--bulk-actions)
23. [Financial Precision Strategy](#23-financial-precision-strategy)
24. [Arabic-First UX & Localization Rules](#24-arabic-first-ux--localization-rules)
25. [Accounting Integration Foundation](#25-accounting-integration-foundation)
26. [Transactions](#26-transactions)
27. [Data Integrity](#27-data-integrity)
28. [Soft Deletion & Historical Integrity](#28-soft-deletion--historical-integrity)
29. [Migration Strategy](#29-migration-strategy)
30. [Performance Requirements](#30-performance-requirements)
31. [Testing Strategy](#31-testing-strategy)
32. [Security Considerations](#32-security-considerations)
33. [Responsive & Desktop / Android UI](#33-responsive--desktop--android-ui)
34. [Localization & RTL Engineering](#34-localization--rtl-engineering)
35. [State Management & DI](#35-state-management--di)
36. [Navigation](#36-navigation)
37. [Backup & Restore](#37-backup--restore)
38. [Git / GitHub Workflow](#38-git--github-workflow)
39. [Windows Build Strategy](#39-windows-build-strategy)
40. [Phase 1 Deliverables](#40-phase-1-deliverables)
41. [Future Implementation Roadmap](#41-future-implementation-roadmap)
42. [Requirements Coverage Checklist](#42-requirements-coverage-checklist)

---

## 1. Project Goals

Build a professional **Pharmacy Management & Point-of-Sale (POS) system** that is:

- **Arabic-first** professional application, with English as a secondary locale.
- **Windows Desktop** as the primary production platform; **Android** supported for development and testing.
- **Offline-first** with all data stored locally in a single SQLite database.
- **Feature-based, Clean Architecture** so business logic is platform-independent and the same codebase runs on Windows and Android.
- **Inventory, Purchases, Suppliers, Customers/Patients, Prescriptions, Invoices, Expenses, Cash Box, and a full double-entry Accounting system** with Trial Balance, Income Statement, Balance Sheet, and Account Statements.
- **Financially precise**, storing all monetary values as integer minor currency units to avoid floating-point errors.
- **Batch/expiry aware** (FEFO) with a dedicated batch model.
- **Fully auditable** via an immutable audit log and a complete stock movement ledger.
- **Extensible** for backup/restore, PDF/Excel export, advanced reports, and future synchronization.

---

## 2. Technology Stack

| Concern | Choice |
|---------|--------|
| Framework | Flutter (latest stable), Material 3 |
| Primary platform | Windows Desktop |
| Secondary platform | Android (development/testing) |
| State management | Riverpod (v2+, with code generation) |
| Database | Drift (formerly Moor) over SQLite |
| SQLite implementation | `drift` + `sqlite3_flutter_libs` (Windows) / `drift_sqflite` (Android) |
| Code generation | `build_runner` + `drift_dev` |
| Navigation | GoRouter (v14+) |
| Dependency injection | get_it + injectable |
| Localization | `flutter_localizations` + `intl` + ARB files, `flutter gen-l10n` |
| Financial types | Custom integer minor-units Money type (see §23) |
| Hashing | `bcrypt` |
| UUID | `uuid` |
| PDF | `pdf` + `printing` |
| Excel | `excel` package |
| Archiving | `archive` |
| File selection | `file_picker` |
| Directory access | `path_provider` |
| Testing | `test`, `mocktail`/`mockito`, `integration_test` |

---

## 3. Architecture

**Pattern:** Clean Architecture (layered) with Feature-Based Modular Structure, keeping a strict dependency rule.

```
┌─────────────────────────────────────────────────────┐
│                   Presentation                       │
│  (Pages, Widgets, Controllers/Notifiers, Theme,      │
│   Localization-aware UI, DataGrids, POS Workspace)   │
├─────────────────────────────────────────────────────┤
│                   Domain                             │
│  (Entities, Use Cases, Repository Interfaces —       │
│   pure Dart, zero framework dependencies)            │
├─────────────────────────────────────────────────────┤
│                   Data                               │
│  (Repository Implementations, DataSources,           │
│   Models/DTOs, Drift DAOs, File System, PDF/Excel)   │
├─────────────────────────────────────────────────────┤
│                   Database                           │
│  (Drift table definitions, migrations, DAOs)         │
├─────────────────────────────────────────────────────┤
│                Core / Shared                         │
│  (Utils, Constants, DI, Localization, Theme, Money,  │
│   Error Handling, Validators, Shortcuts, Scanner)    │
└─────────────────────────────────────────────────────┘
```

### Dependency Rule (authoritative)

- **Domain** depends on **nothing** framework-specific. All entities and use cases are pure Dart.
- **Data** depends on packages (Drift, file system) but never on Flutter widgets.
- **Database** is an implementation detail of the Data layer, reached exclusively through repositories / DAOs.
- **Presentation** depends on Flutter + Domain only.
- **Core/Shared** hosts cross-cutting concerns (Money, validation, error handling, localization, DI, keyboard shortcuts, barcode scanning protocol).
- Business rules live in Domain use cases and are **independent** of the UI.
- The data layer is replaceable/evolvable without rewriting the domain or presentation layers (e.g., future network sync can be added as an additional data source).

### Offline-First Strategy

- All data lives in local SQLite (Drift). No server is required for core functionality.
- No REST/GraphQL API in Phase 1; it may be added later as an *optional* synchronization layer *without* changing domain rules.
- All CRUD, POS, reports, and accounting operate fully offline.
- Backup/restore operates on local files (§37).

### Platform Independence

- The same domain + core code runs identically on Windows and Android.
- Platform-specific differences are confined to the Database connection bootstrap and file paths (via `path_provider`).

---

## 4. Complete Database Schema

> Every table is documented with: name, purpose, every field, data type, nullable/required, default, primary key, foreign keys, unique constraints, indexes, relationships, and business rules.
>
> **Monetary columns** are stored as `INTEGER` minor currency units (see §23). Amounts such as prices, costs, discounts, taxes, balances, totals are `INTEGER` (micro/pico units as designed in §23) unless the minor-unit integer is specified. To avoid any ambiguity, all financial columns below are marked `INTEGER` (money, minor units). Quantities are `INTEGER` (base units, per §7). Timestamps are INTEGER Unix epoch (milliseconds), stored UTC; display is localized.

### ER Overview

```
[roles]──<[role_permissions]>──[permissions]

[users] 1──<[sales] 1──<[sale_items] >──[items] 1──<[item_units] >──[units]
   │    1──<[purchases] 1──<[purchase_items] >──[items] <──[batches] 1
   │    1──<[returns] >
   │    1──<[cashbox_transactions]
   │    1──<[audit_log]
   │    1──<[stock_movements]

[suppliers] 1──<[purchases]
[customers]  1──<[sales]
[items] 1──<[batches]
[batches] 1──<[stock_movements]

[items]──<[smart_alternatives] (dynamically derived, no stored table)

[lost_sales]
[prescriptions] 1──<[prescription_items]
[journal_entries] 1──<[journal_entry_lines]
[accounts] (self-referencing parent)
```

---

### `units`
**Purpose:** Master list of sellable/buyable unit labels (Box, Strip, Tablet, Blister, Bottle, Ampoule, etc.) used to express item quantities and display quantities.

| Field | Type | Nullable | Default | Notes |
|--------|------|----------|---------|-------|
| id | TEXT | No | (UUID) | Primary Key |
| name_ar | TEXT | No | — | Arabic unit name (e.g., علبة) |
| name_en | TEXT | Yes | NULL | English unit name |
| is_sub_unit | INTEGER | No | 0 | 1 = sub-unit/Strip/Fraction; 0 = large unit/Box fractionable concept |
| created_at | INTEGER | No | now | epoch ms |

**Constraints / Rules:** `name_ar` UNIQUE. Used only as a dictionary; item-unit relationships are declared in `item_units`.

---

### `item_units`
**Purpose:** Declares the Base Unit and Large Unit relationship for an item (see §7).

| Field | Type | Nullable | Default | Notes |
|--------|------|----------|---------|-------|
| id | TEXT | No | UUID | Primary Key |
| item_id | TEXT | No | — | FK → `items.id` |
| base_unit_id | TEXT | No | — | FK → `units.id` (sub-unit / strip / fraction / tablet) |
| large_unit_id | TEXT | No | — | FK → `units.id` (box) |
| units_per_large | INTEGER | No | 1 | Number of base units per large unit (e.g., 10 strips per box) |

**Unique:** `(item_id, base_unit_id, large_unit_id)`. An item has exactly one canonical Base Unit plus one Large Unit pairing (see §7 for the `TotalBaseUnits` rule).

---

### `items` (Products / Medicine Master Data)
**Purpose:** The complete master-data record for an item / product. This is the authoritative Items model from the original specification (see §5 for the field-by-field rationale).

| Field | Data Type | Nullable | Default | Notes |
|-------|-----------|----------|---------|-------|
| id | TEXT | No | UUID | Primary Key |
| **Identification** |
| primary_barcode | TEXT | Yes | NULL | Primary Barcode; indexed; lookup-optimized |
| secondary_barcode | TEXT | Yes | NULL | Secondary Barcode (alternative/other package barcode) |
| trade_name_1 | TEXT | No | — | Trade Name 1 (الاسم التجاري) |
| trade_name_2 | TEXT | Yes | NULL | Trade Name 2 (name_en / secondary trade name) |
| scientific_name | TEXT | Yes | NULL | Scientific Name (الاسم العلمي) |
| active_ingredients | TEXT | Yes | NULL | Active Ingredients / Composition |
| equivalent_drug | TEXT | Yes | NULL | Equivalent Drug reference |
| manufacturer | TEXT | Yes | NULL | Manufacturer |
| main_category_id | TEXT | No | — | FK → `categories.id` (Main Category) |
| sub_category_id | TEXT | Yes | NULL | FK → `categories.id` (Sub-Category, self-referencing child) |
| therapeutic_group | TEXT | Yes | NULL | Therapeutic Group (المجموعة العلاجية) |
| **Pharmaceutical Specifications** |
| pharmaceutical_form | TEXT | Yes | NULL | Pharmaceutical Form (شكل صيدلاني) |
| dose_concentration | TEXT | Yes | NULL | Dose / Concentration |
| size_volume | TEXT | Yes | NULL | Size / Volume |
| shelf_location | TEXT | Yes | NULL | Shelf Location |
| **Flags** |
| has_expiry_date | INTEGER | No | 0 | Has Expiry Date flag |
| print_barcode_label | INTEGER | No | 0 | Print Barcode Label flag |
| is_otc | INTEGER | No | 0 | OTC / over-the-counter flag |
| is_controlled_drug | INTEGER | No | 0 | Controlled Drug flag |
| scale_barcode_alert | INTEGER | No | 0 | Scale Barcode Alert flag |
| lock_auto_price_update | INTEGER | No | 0 | Lock Automatic Price Update flag |
| requires_prescription | INTEGER | No | 0 | Requires prescription (computed selling rule) |
| is_active | INTEGER | No | 1 | Soft-delete / inactive flag (see §28) |
| **Pricing (master/default — see §8)** |
| purchase_cost | INTEGER | No | 0 | Purchase Cost (master default), money minor units |
| purchase_discount_pct | INTEGER | No | 0 | Purchase Discount % |
| retail_price | INTEGER | No | 0 | Public / Retail Price, money minor units |
| sub_unit_price | INTEGER | No | 0 | Sub-unit Price, money minor units |
| wholesale_price | INTEGER | No | 0 | Wholesale Price, money minor units |
| half_wholesale_price | INTEGER | No | 0 | Half-Wholesale Price, money minor units |
| custom_price_1 | INTEGER | No | 0 | Custom Price 1, money minor units |
| custom_price_2 | INTEGER | No | 0 | Custom Price 2, money minor units |
| vat_tax_pct | INTEGER | No | 0 | VAT / Tax %, basis points |
| profit_margin_pct | INTEGER | No | 0 | Calculated Profit Margin % (derived, see §8) |
| **Inventory / Stock** |
| current_stock_base | INTEGER | No | 0 | **Cached/derived** quantity in base units (see §10). NOT the source of truth. |
| minimum_stock_base | INTEGER | No | 0 | Reorder threshold in base units |
| **Timestamps** |
| created_at | INTEGER | No | now | epoch ms |
| updated_at | INTEGER | No | now | epoch ms |

**Indexes:** `primary_barcode` (unique where non-null), `secondary_barcode`, `trade_name_1`, `scientific_name`, `main_category_id`, `therapeutic_group`.

**Business rules:**
- A product's *master/default* pricing is stored here and is distinct from *batch/purchase-specific* cost (stored on `batches` and purchase lines). See §8.
- Historical invoices/batches preserve their own costs and are never mutated when pricing changes.
- Quantity fields (`current_stock_base`, `minimum_stock_base`) are stored in **base units** and derived from the Stock Movement Ledger (see §10).

---

### `categories`
**Purpose:** Hierarchical item categorization (main + sub categories).

| Field | Type | Nullable | Default | Notes |
|--------|------|----------|---------|-------|
| id | TEXT | No | UUID | Primary Key |
| name | TEXT | No | — | Category name (Arabic-first) |
| name_en | TEXT | Yes | NULL | English name |
| description | TEXT | Yes | NULL | |
| parent_id | TEXT | Yes | NULL | FK → `categories.id` (self-referencing; sub-category) |
| is_active | INTEGER | No | 1 | inactive = soft-delete |
| created_at | INTEGER | No | now | |

**Rules:** `name` UNIQUE per depth. Supports main (parent_id NULL) and sub categories (parent_id set) matching Main Category / Sub-Category on the item.

---

### `batches`
**Purpose:** The dedicated Batch/expiry/costing entity. Every distinct receipt of stock is tracked as one or more batches (see §6 for full rules).

| Field | Type | Nullable | Default | Notes |
|--------|------|----------|---------|-------|
| id | TEXT | No | UUID | Primary Key |
| item_id | TEXT | No | — | FK → `items.id` |
| batch_number | TEXT | No | — | Batch / lot number |
| expiry_date | INTEGER | Yes | NULL | Expiry date epoch ms; NULL when item `has_expiry_date` = 0 |
| remaining_qty_base | INTEGER | No | 0 | Remaining quantity in base units (§7) |
| purchase_cost | INTEGER | No | 0 | Batch-level purchase cost (money minor units) |
| purchase_date | INTEGER | No | — | Date purchased, epoch ms |
| supplier_id | TEXT | Yes | NULL | FK → `suppliers.id` |
| bonus_qty_base | INTEGER | No | 0 | Bonus quantity where applicable, base units |
| created_at | INTEGER | No | now | |
| updated_at | INTEGER | No | now | |

**Indexes:** `(item_id, expiry_date)` for FEFO; `batch_number`; `supplier_id`.

**Business rules:**
- An item may have many batches. **The item carries no single expiry date** — expiry is per batch.
- FEFO selection: for normal sale, select batches sorted by `expiry_date` ascending (earliest expiry first), consuming `remaining_qty_base`.
- **Expired batches** (`expiry_date < today`) are NEVER automatically selected for normal sale.
- Non-expiring products: `has_expiry_date`=0 ⇒ `expiry_date`=NULL and FEFO ignores expiry (uses FIFO by purchase date).
- Batch-level costing / inventory / returns are all tracked against `batches`.
- When a new purchase arrives with a different cost, the item's *master* `purchase_cost` is NOT overwritten automatically (respects `lock_auto_price_update`; see §8).

---

### `stock_movements` (Stock Movement Ledger)
**Purpose:** The complete, auditable, append-only ledger of every stock change. This is the **source of truth** for inventory; `items.current_stock_base` is a derived cache (see §10).

| Field | Type | Nullable | Default | Notes |
|--------|------|----------|---------|-------|
| id | TEXT | No | UUID | Primary Key |
| item_id | TEXT | No | — | FK → `items.id` |
| batch_id | TEXT | Yes | NULL | FK → `batches.id`; NULL when not batch-bound |
| quantity_base | INTEGER | No | 0 | Quantity change in base units (positive/negative) |
| movement_type | TEXT | No | — | See movement types below |
| reference_type | TEXT | Yes | NULL | e.g., 'sale','purchase','return','adjustment' |
| reference_id | TEXT | Yes | NULL | id of the referencing document |
| unit_cost | INTEGER | No | 0 | Unit cost at movement time, money minor units |
| user_id | TEXT | No | — | FK → `users.id` (who caused the change) |
| note | TEXT | Yes | NULL | Free-text note / reason |
| created_at | INTEGER | No | now | |

**Movement types (authoritative):**
- `opening_balance`
- `purchase`
- `sale`
- `sale_return`
- `purchase_return`
- `stock_adjustment`
- `damaged`
- `expired`
- `transfer`
- `manual_correction`

**Indexes:** `(item_id, created_at)`, `(batch_id)`, `(reference_type, reference_id)`, `movement_type`.

**Business rules:**
- Every stock-changing operation MUST create one or more ledger rows **inside the same transaction** as the parent operation (§26).
- `items.current_stock_base` is a **derived/cached** value recomputed from the ledger sum — it is explicitly NOT the sole source of truth.
- `quantity_base` is authoritative in base units; display quantities are derived (§7).
- Ledger rows are immutable (append-only) — see §28.

---

### `suppliers`
**Purpose:** Supplier master data.

| Field | Type | Nullable | Default | Notes |
|--------|------|----------|---------|-------|
| id | TEXT | No | UUID | Primary Key |
| name | TEXT | No | — | Supplier name (Arabic-first) |
| contact_person | TEXT | Yes | NULL | |
| phone | TEXT | Yes | NULL | |
| email | TEXT | Yes | NULL | |
| address | TEXT | Yes | NULL | |
| tax_number | TEXT | Yes | NULL | |
| balance | INTEGER | No | 0 | Running balance, money minor units (derived from ledger/accounting) |
| is_active | INTEGER | No | 1 | inactive = soft-delete |
| created_at | INTEGER | No | now | |
| updated_at | INTEGER | No | now | |

**Rules:** Supplier balances are derived from the accounting/purchases ledger; never edited manually.

---

### `customers`
**Purpose:** Customer / Patient master data.

| Field | Type | Nullable | Default | Notes |
|--------|------|----------|---------|-------|
| id | TEXT | No | UUID | Primary Key |
| name | TEXT | No | — | Customer name |
| phone | TEXT | Yes | NULL | |
| email | TEXT | Yes | NULL | |
| date_of_birth | INTEGER | Yes | NULL | epoch ms |
| gender | TEXT | Yes | NULL | |
| address | TEXT | Yes | NULL | |
| medical_history | TEXT | Yes | NULL | |
| balance | INTEGER | No | 0 | Running balance, money minor units (derived) |
| is_active | INTEGER | No | 1 | |
| created_at | INTEGER | No | now | |
| updated_at | INTEGER | No | now | |

---

### `prescriptions`
**Purpose:** Prescription master (Arabic: وصفة).

| Field | Type | Nullable | Default | Notes |
|--------|------|----------|---------|-------|
| id | TEXT | No | UUID | Primary Key |
| customer_id | TEXT | No | — | FK → `customers.id` |
| doctor_name | TEXT | Yes | NULL | |
| notes | TEXT | Yes | NULL | |
| image_path | TEXT | Yes | NULL | scanned image |
| created_by | TEXT | No | — | FK → `users.id` |
| created_at | INTEGER | No | now | |

### `prescription_items`

| Field | Type | Nullable | Default | Notes |
|--------|------|----------|---------|-------|
| id | TEXT | No | UUID | Primary Key |
| prescription_id | TEXT | No | — | FK → `prescriptions.id` |
| item_id | TEXT | No | — | FK → `items.id` |
| quantity | INTEGER | No | 0 | base units |
| dosage | TEXT | Yes | NULL | |
| frequency | TEXT | Yes | NULL | |

---

### `sales`
**Purpose:** Sales / sales invoice header (Arabic: فاتورة بيع). Financial amounts are money minor units.

| Field | Type | Nullable | Default | Notes |
|--------|------|----------|---------|-------|
| id | TEXT | No | UUID | Primary Key |
| invoice_number | TEXT | No | — | Unique, auto-generated |
| customer_id | TEXT | Yes | NULL | FK → `customers.id` |
| user_id | TEXT | No | — | FK → `users.id` (cashier) |
| subtotal | INTEGER | No | 0 | money minor units |
| discount_amount | INTEGER | No | 0 | money minor units |
| tax_amount | INTEGER | No | 0 | money minor units |
| total | INTEGER | No | 0 | money minor units |
| payment_method | TEXT | No | — | 'cash','card','mixed' |
| amount_paid | INTEGER | No | 0 | money minor units |
| change_amount | INTEGER | No | 0 | money minor units |
| status | TEXT | No | 'completed' | 'completed','voided' |
| is_return | INTEGER | No | 0 | 1 when this document is a return/credit |
| created_at | INTEGER | No | now | |

### `sale_items`

| Field | Type | Nullable | Default | Notes |
|--------|------|----------|---------|-------|
| id | TEXT | No | UUID | Primary Key |
| sale_id | TEXT | No | — | FK → `sales.id` |
| item_id | TEXT | No | — | FK → `items.id` |
| batch_id | TEXT | Yes | NULL | FK → `batches.id` (batch actually sold — FEFO) |
| quantity_base | INTEGER | No | 0 | signed; +/- for hybrid returns (§14) |
| unit_price | INTEGER | No | 0 | money minor units |
| discount | INTEGER | No | 0 | money minor units |
| total | INTEGER | No | 0 | money minor units |
| cost_of_goods | INTEGER | No | 0 | batch cost at sale time, money minor units (for profit) |

**Rules:** Cost of goods is snapshotted from the batch at sale time so historical profit is never distorted.

---

### `purchases`
**Purpose:** Purchase / purchase invoice header (Arabic: فاتورة شراء). Financial amounts are money minor units.

| Field | Type | Nullable | Default | Notes |
|--------|------|----------|---------|-------|
| id | TEXT | No | UUID | Primary Key |
| purchase_number | TEXT | No | — | Unique, auto-generated |
| supplier_id | TEXT | No | — | FK → `suppliers.id` |
| user_id | TEXT | No | — | FK → `users.id` |
| subtotal | INTEGER | No | 0 | money minor units |
| discount_amount | INTEGER | No | 0 | money minor units |
| tax_amount | INTEGER | No | 0 | money minor units |
| total | INTEGER | No | 0 | money minor units |
| status | TEXT | No | 'pending' | 'pending','received','cancelled' |
| expected_date | INTEGER | Yes | NULL | |
| received_date | INTEGER | Yes | NULL | |
| created_at | INTEGER | No | now | |

### `purchase_items`

| Field | Type | Nullable | Default | Notes |
|--------|------|----------|---------|-------|
| id | TEXT | No | UUID | Primary Key |
| purchase_id | TEXT | No | — | FK → `purchases.id` |
| item_id | TEXT | No | — | FK → `items.id` |
| batch_id | TEXT | Yes | NULL | FK → `batches.id` (created batch, set on receive) |
| quantity_base | INTEGER | No | 0 | purchased quantity in base units (net of bonuses) |
| received_quantity_base | INTEGER | No | 0 | received quantity in base units |
| unit_cost | INTEGER | No | 0 | money minor units |
| total | INTEGER | No | 0 | money minor units |
| bonus_1_qty_base | INTEGER | No | 0 | Bonus 1 quantity (base units) |
| bonus_2_qty_base | INTEGER | No | 0 | Bonus 2 quantity (base units) |
| gift_qty_base | INTEGER | No | 0 | Gift quantity (base units) |
| bonus_reference_item_id | TEXT | Yes | NULL | FK → `items.id` when bonus item differs from purchased item (§13) |

**Rules:** Bonus fields support the bonus engine (§13). Effective unit cost is computed as **Total Actual Cost / Total Effective Quantity**.

---

### `returns`
**Purpose:** Hybrid Return documents — a return may contain both positive and negative line quantities and must reverse revenue, cost, profit, and stock transactionally (§14).

| Field | Type | Nullable | Default | Notes |
|--------|------|----------|---------|-------|
| id | TEXT | No | UUID | Primary Key |
| return_number | TEXT | No | — | Unique, auto-generated |
| type | TEXT | No | — | 'sale_return','purchase_return' |
| original_invoice_id | TEXT | No | — | FK → `sales.id` or `purchases.id` (the original document) |
| original_invoice_type | TEXT | No | — | 'sale','purchase' |
| customer_id | TEXT | Yes | NULL | FK → `customers.id` (for sale returns) |
| supplier_id | TEXT | Yes | NULL | FK → `suppliers.id` (for purchase returns) |
| user_id | TEXT | No | — | FK → `users.id` |
| total | INTEGER | No | 0 | money minor units |
| status | TEXT | No | 'completed' | |
| created_at | INTEGER | No | now | |

### `return_items`

| Field | Type | Nullable | Default | Notes |
|--------|------|----------|---------|-------|
| id | TEXT | No | UUID | Primary Key |
| return_id | TEXT | No | — | FK → `returns.id` |
| original_invoice_item_id | TEXT | No | — | FK → original `sale_items.id` / `purchase_items.id` |
| item_id | TEXT | No | — | FK → `items.id` |
| batch_id | TEXT | No | — | FK → `batches.id` (original batch) |
| quantity_base | INTEGER | No | 0 | signed (see §14) |
| amount | INTEGER | No | 0 | money minor units |

**Rules:** Returns reference the **original invoice, original invoice item, and original batch**. Returned stock is restored to the **original batch** whenever valid; arbitrary return-to-another-batch is prevented (§14).

---

### `expenses`
**Purpose:** Expense records (Arabic: مصروف).

| Field | Type | Nullable | Default | Notes |
|--------|------|----------|---------|-------|
| id | TEXT | No | UUID | Primary Key |
| category | TEXT | No | — | 'rent','utilities','salaries','other' |
| description | TEXT | No | — | |
| amount | INTEGER | No | 0 | money minor units |
| receipt_path | TEXT | Yes | NULL | |
| created_by | TEXT | No | — | FK → `users.id` |
| created_at | INTEGER | No | now | |

---

### `cashbox_transactions`
**Purpose:** Cash Box ledger (Arabic: الصندوق).

| Field | Type | Nullable | Default | Notes |
|--------|------|----------|---------|-------|
| id | TEXT | No | UUID | Primary Key |
| type | TEXT | No | — | 'open','close','deposit','withdraw','sale','expense' |
| amount | INTEGER | No | 0 | money minor units (signed) |
| reference_id | TEXT | Yes | NULL | |
| reference_type | TEXT | Yes | NULL | |
| note | TEXT | Yes | NULL | |
| user_id | TEXT | No | — | FK → `users.id` |
| created_at | INTEGER | No | now | |

---

### `accounts` (Chart of Accounts)
**Purpose:** Double-entry accounting foundation (see §25).

| Field | Type | Nullable | Default | Notes |
|--------|------|----------|---------|-------|
| id | TEXT | No | UUID | Primary Key |
| code | TEXT | No | — | Unique account code, e.g., '1000' |
| name | TEXT | No | — | Arabic-first name |
| name_en | TEXT | Yes | NULL | |
| type | TEXT | No | — | 'asset','liability','equity','revenue','expense' |
| parent_id | TEXT | Yes | NULL | FK → `accounts.id` (self-referencing) |
| is_active | INTEGER | No | 1 | |
| created_at | INTEGER | No | now | |

### `journal_entries`
**Purpose:** Accounting journal header (Arabic: قيد محاسبي).

| Field | Type | Nullable | Default | Notes |
|--------|------|----------|---------|-------|
| id | TEXT | No | UUID | Primary Key |
| entry_number | TEXT | No | — | Unique, auto-generated |
| date | INTEGER | No | — | epoch ms |
| description | TEXT | No | — | |
| reference_type | TEXT | No | — | 'sale','purchase','expense','return','manual' |
| reference_id | TEXT | Yes | NULL | |
| is_posted | INTEGER | No | 1 | |
| created_by | TEXT | No | — | FK → `users.id` |
| created_at | INTEGER | No | now | |

### `journal_entry_lines`

| Field | Type | Nullable | Default | Notes |
|--------|------|----------|---------|-------|
| id | TEXT | No | UUID | Primary Key |
| journal_entry_id | TEXT | No | — | FK → `journal_entries.id` |
| account_id | TEXT | No | — | FK → `accounts.id` |
| debit | INTEGER | No | 0 | money minor units |
| credit | INTEGER | No | 0 | money minor units |

**Rules:** Double-entry validation: per entry, sum(debit) == sum(credit). All amounts in money minor units.

---

### `users`
**Purpose:** System users (Arabic: المستخدمون). See §16 for the roles/permissions model.

| Field | Type | Nullable | Default | Notes |
|--------|------|----------|---------|-------|
| id | TEXT | No | UUID | Primary Key |
| username | TEXT | No | — | Unique |
| password_hash | TEXT | No | — | bcrypt hash |
| full_name | TEXT | No | — | |
| role_id | TEXT | No | — | FK → `roles.id` |
| is_active | INTEGER | No | 1 | |
| created_at | INTEGER | No | now | |
| updated_at | INTEGER | No | now | |

---

### `roles` / `permissions` / `role_permissions`
**Purpose:** Granular RBAC (§16). Explicitly **not** a single role string.

`roles`
| Field | Type | Nullable | Default | Notes |
|-------|------|----------|---------|-------|
| id | TEXT | No | UUID | Primary Key |
| name | TEXT | No | — | Unique role name |
| name_ar | TEXT | No | — | Arabic role name |
| is_active | INTEGER | No | 1 | |

`permissions`
| Field | Type | Nullable | Default | Notes |
|-------|------|----------|---------|-------|
| id | TEXT | No | UUID | Primary Key |
| code | TEXT | No | — | Unique permission code (e.g., 'sell','return','view_inventory','change_prices','change_purchase_cost','delete_invoice','manage_users','manage_permissions','modify_settings','adjust_stock') |
| name | TEXT | No | — | |
| name_ar | TEXT | No | — | Arabic label |

`role_permissions`
| Field | Type | Nullable | Default | Notes |
|-------|------|----------|---------|-------|
| id | TEXT | No | UUID | Primary Key |
| role_id | TEXT | No | — | FK → `roles.id` |
| permission_id | TEXT | No | — | FK → `permissions.id` |
| granted | INTEGER | No | 1 | allow/deny |

**Unique:** `(role_id, permission_id)`.

---

### `audit_log`
**Purpose:** Immutable audit trail (Arabic: سجل التدقيق) for sensitive operations (§17).

| Field | Type | Nullable | Default | Notes |
|--------|------|----------|---------|-------|
| id | TEXT | No | UUID | Primary Key |
| user_id | TEXT | No | — | FK → `users.id` |
| action | TEXT | No | — | 'create','update','delete','login','logout','void','restore',... |
| entity_type | TEXT | No | — | 'item','sale','purchase','price_change','batch',... |
| entity_id | TEXT | No | — | id of the targeted record |
| old_value | TEXT | Yes | NULL | JSON snapshot (before) |
| new_value | TEXT | Yes | NULL | JSON snapshot (after) |
| reason | TEXT | Yes | NULL | Reason / notes |
| ip_address | TEXT | Yes | NULL | |
| created_at | INTEGER | No | now | |

**Rules:** Append-only. Rows are never updated or deleted (§28). Default admin user is seeded with a system id.

---

### `lost_sales`
**Purpose:** Record unavailable requested products (Arabic: النواقص) for future purchasing decisions (§15).

| Field | Type | Nullable | Default | Notes |
|--------|------|----------|---------|-------|
| id | TEXT | No | UUID | Primary Key |
| requested_item_name | TEXT | No | — | Requested product / item name |
| barcode | TEXT | Yes | NULL | barcode if known |
| scientific_name | TEXT | Yes | NULL | |
| quantity_requested | INTEGER | No | 0 | base units |
| customer_name | TEXT | Yes | NULL | Customer information if available |
| customer_phone | TEXT | Yes | NULL | |
| user_id | TEXT | No | — | FK → `users.id` |
| status | TEXT | No | 'open' | 'open','ordered','resolved','cancelled' |
| note | TEXT | Yes | NULL | |
| created_at | INTEGER | No | now | |
| updated_at | INTEGER | No | now | |

**Indexes:** `(requested_item_name)`, `status`, `created_at` — to power purchasing-decision reports.

---

## 5. Items / Product Model

> **CRITICAL:** The Items model MUST NOT be reduced to name/barcode/category/price/stock. The complete model is defined below and fully represented in the `items` table in §4 and §4 items.

### Identification
- **Primary Barcode**
- **Secondary Barcode**
- **Trade Name 1**
- **Trade Name 2**
- **Scientific Name**
- **Active Ingredients / Composition**
- **Equivalent Drug**
- **Manufacturer**
- **Main Category**
- **Sub-Category**
- **Therapeutic Group**

### Pharmaceutical Specifications
- **Pharmaceutical Form**
- **Dose / Concentration**
- **Size / Volume**
- **Shelf Location**

### Flags
- **Has Expiry Date**
- **Print Barcode Label**
- **OTC**
- **Controlled Drug**
- **Scale Barcode Alert**
- **Lock Automatic Price Update**

### Units (see §7)
- Large Unit / Box
- Sub-unit / Strip / Fraction
- Number of sub-units per large unit

### Pricing (see §8)
- Purchase Cost
- Purchase Discount %
- Public / Retail Price
- Sub-unit Price
- Wholesale Price
- Half-Wholesale Price
- Custom Price 1
- Custom Price 2
- VAT / Tax %
- Calculated Profit Margin %

All of the above are explicit columns in the `items` table (§4). Domain entity `Item` mirrors these exactly.

---

## 6. Batch Model

The Batch/expiry model is a first-class entity (`batches`, §4). It captures, at minimum:

- ID
- Item ID
- Batch Number
- Expiry Date
- Remaining Quantity in Base Units
- Purchase Cost
- Purchase Date
- Supplier ID
- Bonus Quantity where applicable
- Created At
- Updated At

### FEFO Behavior
- Normal sale selects batches by **earliest expiry first** (FEFO), consuming `remaining_qty_base`.
- For non-expiring items (`has_expiry_date` = 0), FEFO degrades to FIFO by purchase date.
- Expired batches are **excluded** from normal sale selection.

### Expired Stock Handling
- `expired` stock movements are recorded when stock is moved out of sellable inventory due to expiry.
- Expired batches remain visible for reporting and are clearly flagged in the UI; they are never auto-sold.

### Non-Expiring Products
- `expiry_date` = NULL when the item `has_expiry_date` = 0.
- FEFO/expiry logic is skipped for these items.

### Batch-Level Costing / Inventory / Returns
- Cost is tracked per batch; sale cost-of-goods snapshots the batch cost at sale time.
- Remaining quantity is tracked per batch in base units.
- Returns restore quantity to the **original** batch (see §14).

---

## 7. Units & Base Unit Quantity Model

**Authoritative approach: Base Unit quantity model.**

- Every item has a **Base Unit** (the sub-unit / strip / fraction / tablet) and a **Large Unit** (box), with `units_per_large` (number of sub-units per large unit), defined in `item_units`.
- The **authoritative stored quantity is `TotalBaseUnits`** (stored as the integer `*_base` columns throughout the schema: `quantity_base`, `remaining_qty_base`, `current_stock_base`, etc.).
- We **never** maintain separate authoritative values such as:
  - `Boxes = 3`
  - `Fractions = 4`
- Instead, if **1 Box = 10 Fractions**, then **3 Boxes + 4 Fractions = 34 Base Units**.
- **The system derives the display quantities from the base quantity.**
- This rule applies consistently to **Purchases, Sales, Returns, Inventory, Stock adjustments, FEFO, Reports, and Profit calculations.**

### Example
```
Base unit = Fraction/Strip
Large unit = Box
units_per_large = 10

Stock entered as  3 boxes + 4 fractions
TotalBaseUnits     = (3 * 10) + 4 = 34

Display:  3 Boxes + 4 Fractions (derived from 34 base units by the UI layer)
```

---

## 8. Pricing Model

### Required Pricing Fields (all on `items` and/or batches)
- **Purchase Cost**
- **Purchase Discount %**
- **Public / Retail Price**
- **Sub-unit Price**
- **Wholesale Price**
- **Half-Wholesale Price**
- **Custom Price 1**
- **Custom Price 2**
- **VAT / Tax %**
- **Calculated Profit Margin %**

### Master/Default vs Batch/Purchase-Specific Cost — CLEARLY DISTINGUISHED
- **Master/default pricing** lives on `items` (e.g., default `purchase_cost`, `retail_price`, etc.).
- **Batch/purchase-specific cost** lives on `batches` (and on `purchase_items` for the specific invoice).

### Historical Cost Preservation
- A product's **historical purchase cost MUST NOT be overwritten** simply because a newer purchase has a different cost.
- Historical invoices and batches **preserve their original costs** independently.
- When a new purchase is received with a different cost, only the **master default** may be updated (and only when `lock_auto_price_update` is **off**). The new batch stores its own cost; past batches and past invoices keep theirs.
- `lock_auto_price_update` flag: when set, the system will not auto-update the master pricing from a new purchase.

### Calculated Profit Margin
- `profit_margin_pct` is a **derived** value computed from (selling price − cost) relative to cost or selling price, per the configured convention. It is recomputed, not independently edited, except through the price-change workflow which is audited (§17).

---

## 9. Inventory Model

- Inventory is represented by:
  - `items.current_stock_base` — a **cached/derived** total in base units.
  - `batches.remaining_qty_base` — per-batch remaining quantities.
  - The **Stock Movement Ledger** (`stock_movements`) — the authoritative source of truth (§10).
- Low stock alerting uses `minimum_stock_base` (base units) compared against `current_stock_base`.
- Stock adjustments are recorded as `stock_adjustment` (and related) movement types and are permission-gated (`adjust_stock`) and audited.

---

## 10. Stock Movement Ledger

**Purpose:** Preserve a complete, auditable Stock Movements ledger (Arabic: سجل حركة المخزون).

- **Every stock-changing operation MUST create one or more `stock_movements` rows.**
- Required movement types:
  - `opening_balance`
  - `purchase`
  - `sale`
  - `sale_return`
  - `purchase_return`
  - `stock_adjustment`
  - `damaged`
  - `expired`
  - `transfer`
  - `manual_correction`

### Each movement includes
- Item ID
- Batch ID where applicable
- Quantity in Base Units
- Movement Type
- Reference Type
- Reference ID
- Unit Cost
- User ID
- Created At
- Notes

### Source of Truth
- The Stock Movement Ledger is the **auditable history of stock changes** and the authoritative source.
- `current_stock_base` (and per-batch `remaining_qty_base`) are **derived/cache values** and are NOT the sole source of truth. They are re-synchronized from the ledger with a periodic consistency check / reconciliation job.

---

## 11. Sales Model

- Sales are recorded as `sales` (header) + `sale_items` (lines), each line snapshotted with:
  - `item_id`, `batch_id` (FEFO-selected batch), `quantity_base` (signed to support returns/±lines), `unit_price`, `discount`, `total`, and `cost_of_goods` (batch cost).
- A completed sale:
  1. Deducts stock from FEFO batches (creating `stock_movements` of type `sale`),
  2. Creates the sale document,
  3. Records cash box transaction,
  4. Posts the double-entry journal entry,
  5. Writes audit log.
- All of the above happen **transactionally** (§26) — any failure rolls back the entire sale.
- Voiding a sale requires the `delete_invoice` permission and is recorded in the audit log; voids reverse stock/cash/accounting.

---

## 12. Purchase Model

- Purchases are recorded as `purchases` (header) + `purchase_items` (lines), with per-line bonus fields (§13).
- On receiving a purchase:
  1. One or more `batches` are created (with batch number, expiry, remaining qty in base units, purchase cost, supplier, purchase date, bonus qty).
  2. Stock movements of type `purchase` are created.
  3. Supplier balance and accounting journal entry are updated.
  4. Master pricing may be updated only if `lock_auto_price_update` is off.
- All transactional (§26).

---

## 13. Purchase Bonus Engine

**Purpose:** Preserve the complete bonus engine. Supports **Bonus 1**, **Bonus 2**, and **Gift**.

- Fields on `purchase_items`: `bonus_1_qty_base`, `bonus_2_qty_base`, `gift_qty_base`, plus `bonus_reference_item_id`.

### Example
```
100 purchased
+10 Bonus 1
+5  Bonus 2
+2  Gift
Effective Quantity = 117 base units
```

### True Effective Unit Cost
```
Effective Unit Cost = Total Actual Cost / Total Effective Quantity
```
- The **effective** cost (total spent ÷ total effective quantity incl. bonuses) is what is stored on the created batch(es) and used for cost-of-goods and profit.
- **Future scenario:** the bonus item may differ from the purchased item. `bonus_reference_item_id` supports a different item being granted as bonus; when it differs, a separate batch/stock movement for the bonus item is created accordingly.

---

## 14. Returns Model (Hybrid)

**Purpose:** Preserve the **Hybrid Return System**.

- A return/transaction may contain **both positive and negative quantities**.
- Example transaction:
  - Product A +2
  - Product B +1
  - Product C −1
- Returns **MUST reference**:
  - Original Invoice
  - Original Invoice Item
  - Original Batch

### Rules
- Returned stock is restored to the **original batch** whenever valid and possible.
- The system **prevents** arbitrary return-to-another-batch behavior.
- Returns must reverse correctly:
  - **Revenue** (reverse sale amounts),
  - **Cost** (reverse cost of goods),
  - **Profit** (net effect),
  - **Stock** (restore base units to the original batch).
- All reversal happens **transactionally** (§26).

---

## 15. Lost Sales Model (نواقص)

**Purpose:** Preserve the **LostSales** feature using professional Arabic terminology.

- Records unavailable requested products for future purchasing decisions.
- Store (see `lost_sales` table, §4):
  - Requested Product / Item Name
  - Barcode
  - Scientific Name
  - Quantity Requested
  - Customer information if available
  - User
  - Date/Time
  - Status
  - Notes

### UX
- Quick capture from the POS (one tap from the product-search screen when an item is not found).
- Status lifecycle: open → ordered → resolved / cancelled.
- Reporting: supports reports that aggregate lost sales by item/barcode/scientific name to inform purchasing (Phase 3+).

---

## 16. Users, Roles & Permissions

**Purpose:** Granular permissions using **Users, Roles, Permissions, RolePermissions**.

- **Do NOT reduce permissions to a single role string.**
- `users.role_id` points to a `roles` record; each `role` is a set of `role_permissions` granting/denying individual `permissions`.

### Required granular permissions (permission codes)
- `sell`
- `return`
- `view_inventory`
- `change_prices`
- `change_purchase_cost`
- `delete_invoice`
- `manage_users`
- `manage_permissions`
- `modify_settings`
- `adjust_stock`

(The full RBAC extends beyond these; the DB model allows arbitrary permission codes.)

### Enforcement
- Permission checks occur in the **use case layer** (domain) and are enforced in the **UI** (hide/disable unauthorized actions).
- `manage_permissions` gates editing `role_permissions`; only users with this permission can modify the permission matrix.
- Login/session: bcrypt-hashed passwords; inactivity auto-logout.
- Every permission mutation is audited (§17).

---

## 17. Audit Logging

**Purpose:** Comprehensive, immutable auditing.

- Sensitive operations record:
  - User ID
  - Action
  - Entity Type
  - Entity ID
  - Old Value (JSON snapshot)
  - New Value (JSON snapshot)
  - Date/Time
  - **Reason / Notes**
- Audit history is **immutable** — rows are append-only and cannot be updated or deleted (§28).

### Operations audited (non-exhaustive)
- Login / logout
- Item create / update / delete / deactivate
- Price changes (old and new pricing snapshots + reason)
- Purchase cost changes
- Sales / purchases / returns / voids
- Stock adjustments
- User & role & permission changes
- Settings changes
- Backup / restore
- Bulk operations (per-row or a summarized batch record)

---

## 18. Smart Alternatives Engine

**Purpose:** Provide medication alternatives to the cashier with the three matching levels.

- **GREEN:** 100% match — Same active composition + same dose + same pharmaceutical form.
- **YELLOW:** Same active composition but different dose/strength.
- **BLUE:** At least one shared active ingredient.

### Rules
- The matching engine is **independent from the UI** — it lives in Domain as a use case/service over `items` (active_ingredients, dose_concentration, pharmaceutical_form).
- Prefer **dynamically calculated** alternatives rather than permanently storing stale matching results. No `smart_alternatives` table is required; results are computed at request time from current item data.
- An optional cache may be used for performance but must be invalidated when item data changes; the calculation remains the authority.

---

## 19. POS Workspace

**Purpose:** Preserve the exact POS workspace requirement with **10 customer workspaces/tabs plus Return**.

- POS workspaces/tabs: **Customer 1 … Customer 10**, **Return** (11 tabs total).
- Each workspace/tab maintains **independent state**:
  - its own cart,
  - its own selected customer,
  - its own payment state/discounts/items,
  - its own hold-bill state.
- **No cart or customer/payment state may be lost when switching tabs.**
- The POS workspace state is kept in memory (Riverpod families keyed by workspace index) and persisted (held bills) so state survives across the app session.

---

## 20. Barcode Scanner Architecture

**Purpose:** Support a **hardware barcode scanner** independently of any visible focused text field.

- Hardware scanners typically behave as a keyboard that emits rapid keystrokes followed by a terminator (Enter/newline or a suffix).
- Architecture-level handling: a **global scanner buffer** listens to raw key events (independent of focused widgets).

### Flow (authoritative)
```
Scanner
→ Buffer (accumulate keystrokes)
→ Detect completion (terminator / idle timeout)
→ Normalize (trim, clean, handle scan-suffix config)
→ Search (by primary barcode → secondary barcode → item)
→ Item
→ FEFO batch (select batch per FEFO)
→ Active POS cart (add to the current workspace tab's cart)
```

### Rules
- Must **not interfere with normal keyboard shortcuts** (§21). Scanner input is buffered and recognized only when it matches barcode patterns; otherwise keystrokes fall through to shortcuts/fields.
- Configurable: scanner prefix/suffix, terminator, and idle-timeout detection.
- Works regardless of which widget is focused; does not require an open search field.

---

## 21. Keyboard Shortcuts

**Purpose:** Preserve centralized, configurable shortcuts.

Required default shortcuts:
- **F1** → Search
- **F2** → Toggle Box/Fraction (base-unit display toggle)
- **F5** → Hold Bill
- **F12** → Checkout
- **Space / Enter** → Quick Actions
- **Alt + S** → Alternatives

### Rules
- Shortcut handling is **centralized** (a dedicated `ShortcutManager` service in `core/`) and **configurable** (overridable in settings).
- Registered application-level, independent of focused fields, coexisting with the barcode buffer (§20).

---

## 22. Data Grids & Bulk Actions

**Purpose:** Provide professional, high-productivity data grids across modules.

Required grid features:
- **Sorting**
- **Filtering**
- **Multi-column filtering**
- **Search**
- **Column visibility**
- **Column ordering**
- **Inline editing**
- **Multi-row selection**
- **Bulk actions**
- **Keyboard navigation**

### Bulk Actions
- Must be **transactional** and **auditable** (§26, §17).
- Examples: bulk price change, bulk stock adjustment, bulk deactivate, bulk status update — each runs in a transaction and emits audit records.
- Permission-gated according to the affected operation (e.g., `change_prices`, `adjust_stock`).

---

## 23. Financial Precision Strategy

**CRITICAL CORRECTION — Do NOT use floating-point `double`/`REAL` as the authoritative representation for monetary values.**

### Authoritative approach: integer minor (fixed) currency units

- Store monetary values as **integer minor currency units** where practical.
- Example: `$12.50 → 1250` minor units. For a currency requiring more precision (e.g., 4 decimals for some cost bases), use micro-units (e.g., `12.5000 → 125000` micro-units).
- A dedicated `Money` value type (in `core/`) encapsulates:
  - the integer minor-unit amount,
  - the currency and exponent (e.g., 2 or 4 decimals),
  - arithmetic that never introduces floating-point drift,
  - explicit `toString`/round-trip formatting for display.

### Decimal/rounding control
- If a decimal representation is required for a particular calculation (e.g., percentages), the `Money` type controls **exactly** how precision and rounding are applied (banker's or half-up, configurable), and all such derived values snap back to integer minor units before persistence.

### Scope of application (authoritative)
Applies to:
- Purchase costs
- Selling prices
- Discounts
- Taxes
- Invoice totals
- Profit
- Account balances
- Supplier and customer balances (ledger-derived)
- All columns marked `INTEGER (money minor units)` in the schema

### Explicit prohibition
- **SQLite `REAL` is never used as the authoritative accounting amount.**

---

## 24. Arabic-First UX & Localization Rules

**MANDATORY — Arabic-first is a top-level architectural and UX requirement.**

- **Arabic** is:
  - Default language
  - Default locale
  - Default UI direction (RTL)
  - Primary terminology
- English is a **secondary** locale only and must never replace Arabic in the primary UI.

### Scope of Arabic-first content
All user-facing content must use professional natural Arabic (NOT literal machine translation):
- Main menus
- Sidebar
- Navigation
- Buttons
- Forms
- Dialogs
- Tables
- Data grids
- Error messages
- Validation messages
- Notifications
- Tooltips
- Search
- POS
- Inventory
- Purchases
- Sales
- Returns
- Reports
- Accounting
- Settings
- Users
- Permissions
- Audit logs
- Empty states
- Loading states
- Success/failure messages

### Controlled Terminology Glossary (authoritative)
Consistent professional pharmacy/accounting terminology must be used throughout:

| English | العربية (Arabic) |
|---------|------------------|
| Items | المواد / الأصناف |
| Inventory | المخزون |
| Purchase Invoice | فاتورة شراء |
| Sales Invoice | فاتورة بيع |
| Return | مرتجع |
| Supplier | المورد |
| Customer | الزبون / العميل |
| Batch | التشغيلة |
| Expiry Date | تاريخ الصلاحية |
| Stock | المخزون / الكمية |
| Lost Sale | النواقص |
| Alternative | البدائل |
| Cash Box | الصندوق |
| User | المستخدم |
| Permissions | الصلاحيات |
| Audit Log | سجل التدقيق |
| Stock Adjustment | تسوية المخزون |
| Journal Entry | قيد محاسبي |
| Trial Balance | ميزان المراجعة |
| Income Statement | قائمة الدخل |
| Balance Sheet | الميزانية العمومية |
| Account Statement | كشف الحساب |

### Typography
- Use **Cairo or Tajawal** consistently (bundled as app fonts for Windows and Android).
- RTL is implemented at the architecture level, not as an afterthought: `Directionality` driven by locale; `EdgeInsetsDirectional`, `AlignmentDirectional`, `TextAlignDirectional`; `ListTile` leading/trailing; never hardcode left/right.
- The architecture stays localization-ready for future English support, but **English must not replace Arabic in the primary UI**.

---

## 25. Accounting Integration Foundation

**Purpose:** Ensure the database model does not prevent proper double-entry accounting later, even though the full accounting UI is not built in Phase 1.

- The `accounts`, `journal_entries`, `journal_entry_lines` tables (§4) provide the double-entry foundation.
- Accounting must remain compatible with future:
  - Cash Box
  - Daily sales reports
  - Monthly/yearly reports
  - Supplier balances
  - Customer balances
  - Profit reports
  - Income Statement
  - Balance Sheet
  - Trial Balance
  - Account Statements
  - Employee/Doctor revenue if required later

### Design principles
- Every sale, purchase, return, and expense posts a double-entry journal entry (debit == credit) transactionally.
- Supplier/customer balances are **derived** from the ledger, not stored independently as editable values.
- A predefined/default Chart of Accounts is seeded (assets, liabilities, equity, revenue, expenses) including cash/sales/COGS/expense accounts.
- Reports (Trial Balance, Income Statement, Balance Sheet, Account Statement) aggregate from `journal_entries`/`journal_entry_lines` over date ranges, in money minor units.

---

## 26. Transactions

**Documented transactional behavior.**

All of the following logical operations MUST run inside a single SQLite transaction; **any failure rolls back the complete logical operation**:

### Sale
1. Validate stock availability.
2. Deduct stock from FEFO batches + create `stock_movements` (sale).
3. Insert `sales` + `sale_items` (snapshot costs).
4. Insert `cashbox_transactions` (sale).
5. Post `journal_entries`/`journal_entry_lines`.
6. Write `audit_log`.
On any failure → complete rollback (no partial stock deduction, no orphaned invoice).

### Purchase
1. Create `purchases` + `purchase_items`.
2. Create/update `batches`.
3. Create `stock_movements` (purchase + bonus).
4. Update supplier balance (derived).
5. Post journal entry.
6. (Optionally) update master pricing if unlocked.
7. Write `audit_log`.

### Return
1. Create `returns` + `return_items` referencing original invoice/item/batch.
2. Restore stock to the original batch + create `stock_movements` (sale_return / purchase_return).
3. Reverse revenue/cost/profit via a reversing journal entry.
4. Update cash box.
5. Write `audit_log`.

### Stock Adjustment
1. Create `stock_movements` (stock_adjustment / damaged / expired / manual_correction).
2. Recompute derived `current_stock_base`.
3. Post accounting adjustment if required.
4. Write `audit_log`.

### Bulk Operations
- Entire batch of rows processed in one transaction; any failure rolls back the whole bulk op.
- Each affected row emits its own audit record; the operation emits one summary audit record.

---

## 27. Data Integrity

Preserve, at the database level:
- **Foreign keys** (enforced; FK constraints on all relations).
- **Unique constraints** (usernames, invoice/purchase/return/entry numbers, account codes, permission codes, role names, `name_ar` on units, `(role_id, permission_id)`, `(item_id, base_unit_id, large_unit_id)`).
- **NOT NULL constraints** on all required fields.
- **CHECK constraints** (e.g., `quantity_base` sign, `debit`/`credit >= 0`, positive units_per_large, movement_type in enum, staff/amount sanity).
- **Indexes** on all FK columns and `primary_barcode`/`secondary_barcode` (barcode lookup highly optimized via a dedicated index).
- **Referential integrity** (no orphans; cascade rules documented; historical documents keep validity).

### Barcode lookup performance
- The primary barcode index is a unique index with fast single-row lookup; secondary barcode is also indexed.
- Barcode search is normalized (§20) and uses covering indexes on `(primary_barcode)` and `(secondary_barcode)`.

---

## 28. Soft Deletion & Historical Integrity

- **Never physically delete** transactional/financial/history records:
  - Invoices (sales/purchases)
  - Returns
  - Stock movements (ledger is append-only)
  - Journal entries / lines
  - Audit log (immutable)
  - Lost sales (retained, soft status)
- **Master data** (items, categories, suppliers, customers, users, accounts, roles, units) uses **soft-delete / `is_active = 0`** (inactive) rather than physical deletion, where appropriate.
- **Historical invoices must remain valid** even if an item is later deactivated — sale/purchase lines snapshot item id + prices + costs at the time of the transaction, so changing/deactivating master data never corrupts history.

---

## 29. Migration Strategy

- Drift **schema versioning** with explicit, versioned `schemaVersion` increments.
- Every schema change is implemented as a **forward migration** (`MigrationStrategy.onUpgrade`).
- **Never require deleting the database to apply schema changes.**
- Migrations are covered by tests (`migration_test.dart`) that:
  - Create a database at version N,
  - Apply the migration to N+1,
  - Assert schema and data integrity.
- New columns use safe defaults so existing rows are preserved.
- Backup/restore validates schema version on restore (§37).

---

## 30. Performance Requirements

The architecture must support production-scale data:

- **Tens of thousands** of products.
- **Large invoice history.**
- **Large stock movement history.**
- **Thousands of batches.**
- **Fast barcode lookup** (indexed, normalized).
- **Efficient filtering** (indexed WHERE clauses, DB-side filtering via repositories/DAOs).
- **Pagination** where appropriate (grids paginate rather than loading all rows).
- **Low memory usage** (lazy loading, minimal in-memory copies, paginated data grids).

### Concretely
- DAOs use `LIMIT/OFFSET` (or keyset) pagination for grids.
- `current_stock_base` cache avoids scanning full ledger per screen, while the ledger remains the authority; a reconciliation job re-syncs caches.
- All list screens filter/sort in the database layer, not in Dart.

---

## 31. Testing Strategy

| Level | Scope | Tools | Coverage target |
|-------|-------|-------|-----------------|
| Unit | Domain entities, use cases, money arithmetic, pricing, FEFO, bonus engine, returns, permissions, validators | `test` + `mocktail`/`mockito` | 80%+ |
| Widget | Critical widgets (cart, data grid, forms, POS workspace, RTL rendering) | `flutter_test` | Critical paths |
| Integration | Full flows: login → sale → return; purchase → batch → sale; trial balance accuracy | `integration_test` | Critical flows |
| Database | DAOs, migrations, transactional rollback, FEFO query, integrity constraints | `drift` test utilities | All DAOs + migrations |

### Critical test areas (specific to this spec)
- **Money** arithmetic (no floating-point drift; rounding rules).
- **FEFO** selection and **expired batch exclusion**.
- **Bonus engine** effective quantity/cost.
- **Hybrid returns** (positive + negative lines; reversal of revenue/cost/profit/stock; original-batch restore).
- **Base-unit** conversions (boxes/fractions → TotalBaseUnits).
- **RBAC** permission enforcement at use-case level.
- **Transactional rollback** for sale/purchase/return/adjustment/bulk.

---

## 32. Security Considerations

- **Passwords:** bcrypt-hashed; never stored in plain text.
- **RBAC:** granular permissions enforced in domain use cases and reflected in the UI (§16).
- **Audit:** all sensitive mutations recorded; audit log immutable (§17).
- **Local-only:** no network transmission in Phase 1; transport security is N/A. Password hashes are never migrated/synced insecurely.
- **Sensitive operations** (void, price change, purchase cost change, stock adjustment, restore) require elevated permissions and are always audited with reasons.
- **Backup/restore:** user-initiated; restore confirms before replacing data (§37).
- Controlled drugs and prescription-only items enforce selling rules based on `is_controlled_drug` / `requires_prescription`.

---

## 33. Responsive & Desktop / Android UI

**Approach:** `LayoutBuilder` + adaptive widgets, RTL-aware.

### Breakpoints
| Mode | Width | Layout |
|------|-------|--------|
| Desktop (wide) | ≥ 900px | Sidebar navigation + content |
| Desktop/Tablet (narrow) | 600–899px | Collapsed sidebar (icons) + content |
| Mobile | < 600px | Bottom navigation / drawer + content |

### Implementation
- `ResponsiveLayout` widget wraps pages.
- Data tables become card lists on narrow screens.
- Dialogs become full-screen pages on mobile.
- POS adapts: desktop 3-panel (items | cart | payment); tablet 2-panel; mobile tab-based.

---

## 34. Localization & RTL Engineering

**Package:** `flutter_localizations` + `intl` + ARB; `flutter gen-l10n`.

- **Arabic** `app_ar.arb` is the **default** (primary) locale and the default `locale` on app startup.
- **English** `app_en.arb` is secondary.
- RTL: `Directionality` driven by locale; directional widget APIs used everywhere; tested in both RTL and LTR.
- Fonts: **Cairo or Tajawal** bundled and used consistently.
- Terminology follows the glossary (§24) — implemented as a centralized string catalog so the same term maps to the same Arabic string everywhere.

---

## 35. State Management & DI

- **State management:** Riverpod v2+ with code generation. Providers at data/domain boundaries; AsyncNotifier/Notifier per feature page; family providers per POS workspace tab.
- **DI:** get_it + injectable; registers Database, repositories, use cases, core services (ShortcutManager, ScannerService, AuditService, BackupService, PdfService, ExcelService, MoneyService).
- Provider hierarchy: `DatabaseProvider` → repository providers → use case providers → page notifiers → POS workspace family providers.

---

## 36. Navigation

- **GoRouter** with a `ShellRoute` main layout (sidebar) and a `redirect` guard enforcing authentication.
- POS route is full-width (no sidebar) within the shell, containing the 10-customer + return workspace.
- Named, type-safe routes for item detail/edit, purchase/sale invoices, reports, settings, users, etc.
- Arabic-first UI direction applies to all screens; back/forward behavior correct on Windows and Android.

---

## 37. Backup & Restore

**Mechanism:** direct SQLite file copy (with optional zip compression), user-initiated from Settings.

### Backup
1. Copy the SQLite `.db` file to a user-selected directory.
2. Filename: `pharmacy_backup_YYYYMMDD_HHmmss.db` (optionally `.zip` via `archive`).
3. A JSON metadata file records timestamp, app version, and **database schema version**.

### Restore
1. Select a backup `.db` file.
2. Validate integrity (metadata + schema version).
3. Prompt user (data will be replaced).
4. Close DB connection; replace file; reopen.
5. Run pending migrations if needed.
6. Audit-log the restore.

### Auto-backup
- Optional daily automatic backup to a designated folder, configurable in settings.

---

## 38. Git / GitHub Workflow

**Branch strategy:** simplified Git Flow.

```
main                  ← production-ready, tagged releases, protected
  └── develop         ← integration
       ├── feature/*
       ├── bugfix/*
       └── release/v*
```

**Rules:**
- `main` always deployable and protected.
- Work on feature branches from `develop`; merge via PR.
- Conventional Commits (`feat:`, `fix:`, `chore:`, `test:`, `docs:`, `refactor:`).
- No direct pushes to `main`.
- Tags for releases (`v1.0.0`).
- GitHub Actions: full test + build (analyze, unit/widget/integration/database tests, build Windows, build Android).

---

## 39. Windows Build Strategy

**GitHub Actions** builds the Windows EXE on tag pushes and manual dispatch.

```yaml
name: Build Windows
on:
  push: { tags: ['v*'] }
  workflow_dispatch:
jobs:
  build-windows:
    runs-on: windows-latest
    steps:
      - uses: actions/checkout@v4
      - uses: subosito/flutter-action@v2
        with: { flutter-version: '3.x', channel: 'stable' }
      - run: flutter pub get
      - run: flutter analyze
      - run: flutter test
      - run: flutter build windows --release
      - uses: actions/upload-artifact@v4
        with:
          name: pharmacy-pos-windows
          path: build/windows/x64/runner/Release/
```

**Build targets:** Windows release / debug, Android APK. Windows-specific: icon in `windows/runner/.rc`, window title in `main.cpp`, minimum Windows 10.

---

## 40. Phase 1 Deliverables

Phase 1 = **Foundation + Core Master Data + Stock/Items foundation** that fully lock in the corrected data model.

### Scope
- Project scaffolding, folder structure, Docker-free pure Flutter.
- Complete Drift schema for **ALL** tables in §4 (items with every field, units/item_units, batches, stock_movements, categories, suppliers, customers, prescriptions, sales/sale_items, purchases/purchase_items, returns/return_items, expenses, cashbox, accounts, journal_entries/lines, users/roles/permissions/role_permissions, audit_log, lost_sales).
- **Money** type (§23) and validation/error handling.
- Base-units conversion service (§7).
- Arabic-first localization scaffold (ARB) + Cairo/Tajawal fonts + RTL theme (§24, §34).
- RBAC tables + seed default roles/permissions (§16).
- Audit service (§17).
- Backup file layout (schema version metadata) (§37).
- Migration framework with schemaVersion + onUpgrade (§29).
- DAOs + repositories for Items, Units, Batches, StockMovements, Categories (§10).
- Data-grid scaffolding (sorting/filtering/pagination) (§22).
- Unit tests for Money, base-units, FEFO, bonus engine, migration foundation (§31).
- GitHub Actions workflow (test + build) (§39).

### Explicitly NOT in Phase 1
- Full POS guest/customer workspaces, full accounting UI, smart-alternatives UI, barcode-scanner hardware wiring, lost-sales capture UI — these are designed in this document but delivered in later phases.

---

## 41. Future Implementation Roadmap

### Phase 2 — Inventory & Items management
Complete Item form (all identification, pharmaceutical, flags, units, pricing fields), category management, batch entry, stock adjustment UI, low-stock/expiry alerts, item import/export (Excel).

### Phase 3 — Suppliers & Purchases
Supplier CRUD + statements; purchase invoices; batch creation on receive; bonus engine UI; purchase returns; supplier balance reports.

### Phase 4 — Customers & Prescriptions
Customer/patient CRUD + statements; prescriptions with item lines; link prescription to sale.

### Phase 5 — POS core
Barcode-scanner service + 10-customer/return workspace; FEFO cart; payment (cash/card/mixed); receipt PDF; hold bill; Z-report; smart alternatives UI; lost sales quick-capture.

### Phase 6 — Invoices & Returns
Invoice list/view/void/PDF; hybrid returns UI (positive + negative lines); transactional reversals.

### Phase 7 — Cash Box
Open/close, deposits/withdrawals, auto entries from sales/expenses, day-end reconciliation.

### Phase 8 — Expenses
Expense CRUD + categories + receipts.

### Phase 9 — Accounting
Chart of accounts management, manual journal entries, auto-posting from sales/purchases/returns/expenses, period close.

### Phase 10 — Reports
Trial Balance, Income Statement, Balance Sheet, Account Statements, sales/inventory/purchase reports, lost-sales reports, PDF + Excel export, date-range filters, supplier/customer statements.

### Phase 11 — Audit log & Settings
Audit log viewer, app settings (business name, tax rate, currency), user/role/permission management UI.

### Phase 12 — Backup/Restore & Export
Full backup/restore UI, auto-backup, PDF/Excel export for invoices, receipts, reports, data grids.

### Phase 13 — Polish & Hardening
RTL QA, responsive polish, keyboard shortcuts, performance optimization, accessibility, error handling polish.

### Phase 14 — Testing & CI/CD
Reliability/threshold coverage, complete integration suite, Windows + Android release pipelines.

### Phase 15 — Release
Installer (Inno Setup / MSIX), icons/splash, docs, tag `v1.0.0`, GitHub Release artifacts.

---

## 42. Requirements Coverage Checklist

> This checklist reconciles every major original-specification requirement against this Architecture Plan. Each is marked **✅ Covered** unless an explicit decision is required.

### Items / Products (CRITICAL)
- ✅ Primary Barcode — `items.primary_barcode`
- ✅ Secondary Barcode — `items.secondary_barcode`
- ✅ Trade Name 1 / Trade Name 2 — `items.trade_name_1` / `trade_name_2`
- ✅ Scientific Name — `items.scientific_name`
- ✅ Active Ingredients / Composition — `items.active_ingredients`
- ✅ Equivalent Drug — `items.equivalent_drug`
- ✅ Manufacturer — `items.manufacturer`
- ✅ Main Category / Sub-Category — `items.main_category_id` / `items.sub_category_id` → `categories`
- ✅ Therapeutic Group — `items.therapeutic_group`
- ✅ Pharmaceutical Form — `items.pharmaceutical_form`
- ✅ Dose / Concentration — `items.dose_concentration`
- ✅ Size / Volume — `items.size_volume`
- ✅ Shelf Location — `items.shelf_location`
- ✅ Has Expiry Date — `items.has_expiry_date`
- ✅ Print Barcode Label — `items.print_barcode_label`
- ✅ OTC — `items.is_otc`
- ✅ Controlled Drug — `items.is_controlled_drug`
- ✅ Scale Barcode Alert — `items.scale_barcode_alert`
- ✅ Lock Automatic Price Update — `items.lock_auto_price_update`
- ✅ Large Unit / Box, Sub-unit/Strip/Fraction, # sub-units per large unit — `item_units` + `units` (§7)

### Units / Base Unit Quantity Model (CRITICAL)
- ✅ TotalBaseUnits authoritative base-unit model (§7)
- ✅ Derived display quantities; no separate `Boxes=3`/`Fractions=4` authority
- ✅ Applies to Purchases, Sales, Returns, Inventory, Adjustments, FEFO, Reports, Profit

### Batch / Expiry Model (CRITICAL)
- ✅ Dedicated `batches` table with all required fields (§6)
- ✅ FEFO behavior
- ✅ Expired-stock handling; expired never auto-selected for sale
- ✅ Non-expiring products
- ✅ Batch-level costing
- ✅ Batch-level inventory
- ✅ Batch-level returns

### Stock Movement Ledger
- ✅ All 10 movement types (opening, purchase, sale, sale_return, purchase_return, adjustment, damaged, expired, transfer, manual_correction) (§10)
- ✅ Each movement includes item/batch/quantity base/type/reference/unit cost/user/time/notes
- ✅ Ledger is authoritative; `current_stock` is derived/cached, not sole source of truth

### Pricing Model
- ✅ Purchase Cost
- ✅ Purchase Discount %
- ✅ Public / Retail Price
- ✅ Sub-unit Price
- ✅ Wholesale Price
- ✅ Half-Wholesale Price
- ✅ Custom Price 1 / Custom Price 2
- ✅ VAT / Tax %
- ✅ Calculated Profit Margin %
- ✅ Master/default vs batch/purchase-specific distinction
- ✅ Historical purchase cost never overwritten by newer purchase
- ✅ Historical invoices/batches preserve original costs

### Purchase Bonuses
- ✅ Bonus 1 / Bonus 2 / Gift
- ✅ Effective Quantity (e.g., 100+10+5+2 = 117)
- ✅ True Effective Unit Cost = Total Actual Cost / Total Effective Quantity
- ✅ Future scenario: bonus item differs from purchased item (`bonus_reference_item_id`)

### Returns (Hybrid)
- ✅ Positive and negative quantities in one transaction
- ✅ References original invoice / invoice item / batch
- ✅ Restore to original batch; prevents arbitrary batch swapping
- ✅ Reverses revenue, cost, profit, stock transactionally

### Smart Alternatives
- ✅ GREEN (same composition+dose+form)
- ✅ YELLOW (same composition, different dose/strength)
- ✅ BLUE (≥1 shared active ingredient)
- ✅ Matching engine independent of UI
- ✅ Dynamically calculated, not stale stored results

### Lost Sales (نواقص)
- ✅ Professional Arabic terminology (النواقص)
- ✅ Quick recording of unavailable products
- ✅ Fields: requested item/barcode/scientific name/qty/customer/user/datetime/status/notes
- ✅ Future purchasing-decision reports

### Users / Roles / Permissions
- ✅ Users, Roles, Permissions, RolePermissions tables
- ✅ Not reduced to a single role string
- ✅ Sell, Return, View Inventory, Change Prices, Change Purchase Cost, Delete/Cancel Invoice, Manage Users, Manage Permissions, Modify Settings, Adjust Stock

### Audit Log
- ✅ User ID, Action, Entity Type, Entity ID, Old/New Value, Date/Time, Reason/Notes
- ✅ Immutable audit history

### POS Workspace
- ✅ Customer 1–10 + Return (11 tabs)
- ✅ Independent state per tab; no state loss on switch

### Barcode Scanning
- ✅ Scanner → Buffer → Detect completion → Normalize → Search → Item → FEFO batch → Active POS cart
- ✅ Independent of focused field
- ✅ Does not interfere with keyboard shortcuts

### Keyboard Shortcuts
- ✅ F1 Search, F2 Toggle Box/Fraction, F5 Hold Bill, F12 Checkout, Space/Enter Quick Actions, Alt+S Alternatives
- ✅ Centralized and configurable

### Data Grids & Bulk Actions
- ✅ Sorting, filtering, multi-column filtering, search, column visibility, column ordering, inline editing, multi-row selection, bulk actions, keyboard navigation
- ✅ Bulk actions transactional and auditable

### Money / Financial Precision (CRITICAL)
- ✅ Integer minor-unit Money type; no `double`/`REAL` authority
- ✅ Explicit rounding/precision control
- ✅ Applies to costs, prices, discounts, taxes, totals, profit, balances

### Arabic-First Professional UI (MANDATORY)
- ✅ Arabic default language/locale/direction/terminology
- ✅ English secondary only
- ✅ Professional natural Arabic (not machine translation) across all UI areas
- ✅ Controlled terminology glossary (§24)
- ✅ Cairo / Tajawal consistent typography
- ✅ RTL at architecture level

### Accounting Foundation
- ✅ Accounts / Journal Entries / Lines double-entry foundation
- ✅ Compatible with Cash Box, daily/monthly/yearly reports, supplier/customer balances, profit reports, Income Statement, Balance Sheet, Trial Balance, Account Statements, future employee/doctor revenue
- ✅ Accounting UI deferred but DB model supports it

### Database Integrity
- ✅ Foreign keys, unique constraints, NOT NULL, CHECK constraints, indexes, referential integrity
- ✅ Optimized barcode lookup

### Transactions
- ✅ Sale, Purchase, Return, Stock Adjustment, Bulk — full transactional rollback

### Soft Delete / Historical Integrity
- ✅ No physical deletion of invoices/movements/audit/financial history
- ✅ Master data soft-delete/inactive
- ✅ Historical invoices remain valid if item deactivated

### Migrations
- ✅ Drift schema versioning + forward migrations; no DB deletion required

### Performance
- ✅ Tens of thousands of products, large invoice & movement history, thousands of batches, fast barcode lookup, efficient filtering, pagination, low memory

### Architecture Quality
- ✅ Clear separation: Presentation / Domain / Data / Database
- ✅ Business rules independent of UI
- ✅ Database behind repositories/DAOs; replaceable data layer

### Technology & Delivery (from the original overarching requirements)
- ✅ Flutter, Material 3
- ✅ Windows Desktop primary, Android dev/test
- ✅ Arabic RTL primary, English secondary
- ✅ Responsive UI (desktop + Android)
- ✅ Offline-first, local SQLite (Drift)
- ✅ Clean Architecture, feature-based modularity
- ✅ PDF / Excel export
- ✅ Backup & restore
- ✅ Search, filtering, advanced reports
- ✅ Strong validation & error handling
- ✅ Automated tests
- ✅ Windows EXE via GitHub Actions

**Result:** All original major requirements are marked **✅ Covered**. No requirement is silently omitted.

---

*End of document. This is the authoritative architecture blueprint for the Pharmacy Management & POS system.*
