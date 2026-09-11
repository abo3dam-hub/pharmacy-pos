# Pharmacy Management & POS System — Authoritative Architecture & Database Specification

> **Document status:** Final technical specification.
> This document is the single source of truth that a developer or an AI agent can rely on to implement the system **without guessing or inventing missing fields or incomplete rules**.
> The **original Pharmacy Management & POS — Architecture & Database Foundation Specification** is the **supreme and most binding reference**. Every requirement in it is preserved in full — nothing is omitted, simplified, renamed, or weakened.
>
> **Scope of this document:** architecture and database specification **only**. No application code, Dart files, Drift table code, or UI is produced here.

---

## Table of Contents

0. [Design System Contract (SSOT & Immutability)](#0-design-system-contract-ssot--immutability)
1. [Project Goals](#1-project-goals)
2. [Technology Stack](#2-technology-stack)
3. [Architecture](#3-architecture)
4. [Complete Database Schema](#4-complete-database-schema)
5. [Items / Product Model](#5-items--product-model)
6. [Batch Model](#6-batch-model)
7. [Units & Base Unit Quantity Model](#7-units--base-unit-quantity-model)
8. [Pricing & Historical Cost](#8-pricing--historical-cost)
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

## 0. Design System Contract (SSOT & Immutability)

> Implemented and enforced across the Flutter codebase. This is the **binding** rule set for every screen, widget, and theme; deviations are defects, not improvements.

### Single source of truth (SSOT)

| Concern | Single source | Notes |
|---------|---------------|-------|
| Color palette (incl. RTL-safe semantic tokens) | `lib/core/theme/app_colors.dart` | Primary medical green `#00696D`, accent muted purple `#7B6A9E`, quiet error; light + dark variants; the only color literals allowed in the app |
| Typography family/hierarchy & numeric/DIN styling | `lib/core/theme/app_text_styles.dart` (`AppTypography`) + `design.md` | Cairo/Tajawal; section/page/table/numeric/caption/label scales via ThemeExtension |
| Spacing/radius/layout breakpoints | `lib/core/theme/app_dimensions.dart` | Unified scale; `AppRadius`, `AppSpacing`, `AppBreakpoints`, `AppLayoutTokens`; no ad-hoc magic numbers in pages |
| Component themes (inputs, dialogs, cards, tables, nav) | `lib/core/theme/app_theme.dart` | Central `ThemeData` — pages never override Material component styling |
| Shared widgets (forms, data grid, dialogs, overlays, search, amount) | `lib/core/widgets/*` | Reuse, never re-implement |
| Responsive rail/drawer + breakpoints | `AppBreakpoints` + `lib/core/widgets/responsive_layout.dart` | Desktop rail / tablet / compact drawer |
| Navigation sections | `lib/core/constants/app_sections.dart` | Single enum → shell rail/drawer + GoRouter routes |

### Immutability rules

- **No new colors, font families, or typography scales** outside the SSOT above; any addition lands in the tokens + `design.md` + a design-system test (§33).
- **No new shared-concern widgets** duplicated in a page; extend `lib/core/widgets/*` instead.
- **No per-page responsive decisions** outside `AppResponsiveLayout`.
- **No hardcoded Arabic/English strings** — all labels via `AppLocalizations` (ARB catalog; 127-key parity ar ⇄ en).
- All build/lint/test gates must stay green (see GitHub Actions).

---

## 1. Project Goals

Build a professional **Pharmacy Management & Point-of-Sale (POS) system** that is:

- **Arabic-first** professional application, with English as a secondary locale and full localization structure.
- **Windows Desktop** as the primary production platform; **Android** supported for development/testing.
- **Offline-first**: a **local SQLite database is the single Source of Truth**; everything works fully offline.
- **Feature-based, Clean Architecture**, so business logic is platform-independent and the same codebase runs on Windows and Android.
- Complete modules: **Items/Products, Inventory, Batches (FEFO), Purchases with Bonus Engine, Suppliers, Customers/Patients, Prescriptions, Sales & Sales Invoices, Hybrid Returns, Lost Sales, Expenses, Cash Box**, and a **future-ready double-entry Accounting foundation** (Trial Balance, Income Statement, Balance Sheet, Account Statements).
- **Financially precise**: all monetary values stored as **integer smallest-currency units** — never floating-point.
- **Fully auditable**: an immutable **Audit Log** and a complete **Stock Movement Ledger**.
- **Extensible**: backup/restore, PDF/Excel export, advanced reports, and optional future synchronization without database redesign.

---

## 2. Technology Stack

| Concern | Choice |
|---------|--------|
| Framework | Flutter (latest stable), Material 3 |
| Primary platform | Windows Desktop |
| Secondary platform | Android (development/testing) |
| State management | Riverpod (v2+, with code generation) |
| Database | Drift (formerly Moor) over SQLite |
| SQLite impl | `drift` + `sqlite3_flutter_libs` (Windows) / `drift_sqflite` (Android) |
| Code generation | `build_runner` + `drift_dev` |
| Navigation | GoRouter (v14+) |
| DI | get_it + injectable |
| Localization | `flutter_localizations` + `intl` + ARB files, `flutter gen-l10n` |
| Financial types | Custom integer smallest-unit `Money` type (§23) |
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

**Pattern:** Clean Architecture (layered) with Feature-Based Modular Structure and a strict dependency rule.

```
┌─────────────────────────────────────────────────────┐
│                   Presentation                       │
│  (Pages, Widgets, Controllers/Notifiers, Theme, UI,  │
│   DataGrids, POS Workspace, RTL-aware widgets)       │
├─────────────────────────────────────────────────────┤
│                   Domain                             │
│  (Entities, Use Cases, Repository Interfaces,        │
│   Domain Services: FEFO, Bonus, Alternatives, Money) │
│   — pure Dart, zero framework dependencies           │
├─────────────────────────────────────────────────────┤
│                   Data                               │
│  (Repository Implementations, DataSources, DTOs,     │
│   Drift DAOs, File System, PDF/Excel)                │
├─────────────────────────────────────────────────────┤
│                   Database                           │
│  (Drift table definitions, schema versioning,        │
│   migrations, integrity constraints)                 │
├─────────────────────────────────────────────────────┤
│                Core / Shared                         │
│  (Money, validators, error handling, DI, l10n,       │
│   ShortcutManager, ScannerService, AuditService)     │
└─────────────────────────────────────────────────────┘
```

### Dependency Rule (authoritative)

- **Domain** depends on nothing framework-specific; entities and use cases are pure Dart.
- **Data** depends on packages (Drift, file system) but never on Flutter widgets.
- **Database** is an implementation detail of the Data layer, accessed only through repositories / DAOs.
- **Presentation** depends on Flutter + Domain only.
- **Core/Shared** hosts cross-cutting concerns (Money, validation, error handling, localization, DI, shortcuts, scanner, audit).
- Business rules live in **Domain use cases and domain services**, independent of the UI.
- The data layer is replaceable/evolvable without rewriting domain or presentation.

### Offline-First Strategy

- **Local SQLite is the Source of Truth.** No server is required for core functionality.
- All CRUD, POS, reports, and accounting operations work fully offline.
- *Future* Backup / Restore / Synchronization must not require a database redesign (see §37, §30).

---

## 4. Complete Database Schema

> **Conventions used in every table below**
>
> - **Money columns** → `INTEGER` (smallest currency unit; see §23). Never `REAL`.
> - **Percentages** → `INTEGER` counting **basis points** where `100 basis points = 1%` (e.g., `15% → 1500`). Documented on each percentage column.
> - **Quantities** → `INTEGER` in **Base Units** (§7), named with `_base` suffix.
> - **Timestamps** → INTEGER Unix epoch **milliseconds** (UTC), display localized.
> - `PK` = Primary Key; `FK` = Foreign Key; `NN` = NOT NULL; `nullable` = NULL allowed.
> - **Audit:** every mutation of sensitive fields requires audit logging (§17).
>
> **Phase 18 change (schema v12, see `PHASE18-PRODUCT-MASTER-CONTRACT-IMPORT-READINESS-COMPLETION-REPORT.md`):**
> the `sub_categories` and `therapeutic_groups` tables were **removed** (legacy replace-data tables are dropped, keeping only the `'therapeutic_group'` audit label key for old audit rows). Item classification collapses to a single **optional** `category_id` FK→`categories.id`; the Phase 18 product contract only requires a **trade name**, and active-ingredient/indication relationships live in the relational `item_active_ingredients` / `item_indications` join tables.

---

### ER Overview (entities & primary relationships)

```
[manufacturers] 1──<[items]
[categories] 1──<[items]         (sub_categories & therapeutic_groups removed in Phase 18/v12)
[units] 1──<[item_units] >──1 [items]

[items] 1──<[item_active_ingredients] >──[active_ingredients]
[items] 1──<[item_indications] >──[indications]
[items] 1──<[item_suppliers] >──[suppliers]

[items] 1──<[batches]
[batches] 1──<[stock_movements]
[items] 1──<[stock_movements]

[suppliers] 1──<[purchase_invoices] 1──<[purchase_invoice_items] 1──<[purchase_bonuses]
[purchase_invoice_items] >──[batches] (creates)
[batch] >──[suppliers]

[customers] 1──<[sales_invoices] 1──<[sales_invoice_items] >──[batches] (FEFO sale)
[sales_invoice_items] --(original)→ [sales_invoice_items] (hybrid returns)

[returns] 1──<[return_items] (reference original invoice/item/batch)

[users] 1──<[sales_invoices]
[users] 1──<[purchase_invoices]
[users] 1──<[stock_movements]
[users] 1──<[cashbox_transactions]
[users] 1──<[audit_logs]
[users] 1──<[lost_sales]

[roles] 1──<[users]
[roles] 1──<[role_permissions] >──[permissions]

[prescriptions] 1──<[prescription_items] >──[items]
[expenses]
[cashbox_transactions]
[accounts] (self-referencing parent) 1──<[journal_entry_lines]
[journal_entries] 1──<[journal_entry_lines]

[smart_alternatives]: computed at query time — no stored table
```

---

### 4.1 `manufacturers`
**Purpose:** independent master list of manufacturers (Item.Manufacturer is a **FK**, not free text).

| Field | Type | NN | Default | Notes |
|-------|------|----|---------|-------|
| id | TEXT | PK | UUID | |
| name | TEXT | NN | — | Unique manufacturer name |
| name_en | TEXT | nullable | NULL | |
| phone | TEXT | nullable | NULL | |
| notes | TEXT | nullable | NULL | |
| is_active | INTEGER | NN | 1 | soft-delete flag |
| created_at | INTEGER | NN | now | |
| updated_at | INTEGER | NN | now | |

**Unique:** `name`. **Index:** `name`.

---

### 4.2 `therapeutic_groups` — *(REMOVED in Phase 18 / schema v12)*
**Purpose (historical):** independent master list of therapeutic groups. The table and its code were dropped in Phase 18; audit rows keep the `'therapeutic_group'` entity-type label. No active code references it.

| Field | Type | NN | Default | Notes |
|-------|------|----|---------|-------|
| id | TEXT | PK | UUID | |
| name_ar | TEXT | NN | — | Unique Arabic name |
| name_en | TEXT | nullable | NULL | |
| description | TEXT | nullable | NULL | |
| is_active | INTEGER | NN | 1 | |
| created_at | INTEGER | NN | now | |
| updated_at | INTEGER | NN | now | |

**Unique:** `name_ar`.

---

### 4.3 `categories` (Main Categories)
**Purpose:** main item categories (Arabic: التصنيف الرئيسي).

| Field | Type | NN | Default | Notes |
|-------|------|----|---------|-------|
| id | TEXT | PK | UUID | |
| name | TEXT | NN | — | Unique Arabic name |
| name_en | TEXT | nullable | NULL | |
| description | TEXT | nullable | NULL | |
| is_active | INTEGER | NN | 1 | |
| created_at | INTEGER | NN | now | |

**Unique:** `name`.

---

### 4.4 `sub_categories` — *(REMOVED in Phase 18 / schema v12)*
**Purpose (historical):** sub-categories belonging to one main category. The table was dropped in Phase 18; classification is a single optional `items.category_id` FK. No active code references it.

| Field | Type | NN | Default | Notes |
|-------|------|----|---------|-------|
| id | TEXT | PK | UUID | |
| category_id | TEXT | FK→`categories.id` | — | owning main category |
| name | TEXT | NN | — | Unique per category |
| name_en | TEXT | nullable | NULL | |
| description | TEXT | nullable | NULL | |
| is_active | INTEGER | NN | 1 | |
| created_at | INTEGER | NN | now | |

**Unique:** `(category_id, name)`. **Index:** `category_id`.

---

### 4.5 `units`
**Purpose:** sellable/buyable unit labels (علبة Box, شريط Strip, قرص Tablet, أمبولة Ampoule, etc.).

| Field | Type | NN | Default | Notes |
|-------|------|----|---------|-------|
| id | TEXT | PK | UUID | |
| name_ar | TEXT | NN | — | Unique Arabic name |
| name_en | TEXT | nullable | NULL | |
| created_at | INTEGER | NN | now | |

**Unique:** `name_ar`.

---

### 4.6 `item_units`
**Purpose:** declares each item's canonical Base Unit + Large Unit relationship (§7).

| Field | Type | NN | Default | Notes |
|-------|------|----|---------|-------|
| id | TEXT | PK | UUID | |
| item_id | TEXT | FK→`items.id` | — | |
| base_unit_id | TEXT | FK→`units.id` | — | Base unit (strip/fraction/tablet) |
| large_unit_id | TEXT | FK→`units.id` | — | Large unit (box) |
| units_per_large | INTEGER | NN | 1 | base units per large unit, e.g., 10 |

**Unique:** `(item_id, base_unit_id, large_unit_id)`. **Index:** `item_id`, `units_per_large`.
**CHECK:** `units_per_large >= 1`.

---

### 4.7 `items` (Medicines / Products — master data)
**Purpose:** the complete master-data record of a product. **Every field from the original specification is an explicit column.**

#### Identification
| Field | Type | NN | Default | Notes |
|-------|------|----|---------|-------|
| id | TEXT | PK | UUID | |
| primary_barcode | TEXT | nullable | NULL | Primary Barcode; lookup-optimized |
| secondary_barcode | TEXT | nullable | NULL | Secondary Barcode |
| trade_name_1 | TEXT | NN | — | Trade Name 1 (الاسم التجاري) |
| trade_name_2 | TEXT | nullable | NULL | Trade Name 2 |
| scientific_name | TEXT | nullable | NULL | Scientific Name (الاسم العلمي) |
| active_ingredients | TEXT | nullable | NULL | Active Ingredients / Composition |
| equivalent_drug | TEXT | nullable | NULL | Equivalent Drug (free reference / note) |
| manufacturer_id | TEXT | FK→`manufacturers.id` | nullable | FK to independent Manufacturers table |
| category_id | TEXT | FK→`categories.id` | nullable | Main Category (التصنيف) — **optional** in the Phase 18 contract |
| ~~sub_category_id~~ | — | — | — | removed in Phase 18/v12 |
| ~~therapeutic_group_id~~ | — | — | — | removed in Phase 18/v12 |

#### Pharmaceutical specifications
| Field | Type | NN | Default | Notes |
|-------|------|----|---------|-------|
| pharmaceutical_form | TEXT | nullable | NULL | شكل صيدلاني |
| dose_concentration | TEXT | nullable | NULL | Dose / Concentration |
| size_volume | TEXT | nullable | NULL | Size / Volume |
| shelf_location | TEXT | nullable | NULL | Shelf Location (عينية / مكان الرف) |

#### Flags
| Field | Type | NN | Default | Notes |
|-------|------|----|---------|-------|
| has_expiry_date | INTEGER | NN | 0 | Has Expiry Date |
| print_barcode_label | INTEGER | NN | 0 | Print Barcode Label |
| is_otc | INTEGER | NN | 0 | OTC (بدون وصفة) |
| is_controlled_drug | INTEGER | NN | 0 | Controlled Drug (دواء مخدر/خاضع للرقابة) |
| scale_barcode_alert | INTEGER | NN | 0 | Scale Barcode Alert |
| lock_auto_price_update | INTEGER | NN | 0 | Lock Automatic Price Update |
| requires_prescription | INTEGER | NN | 0 | Selling rule (وصفة إلزامية) |
| is_active | INTEGER | NN | 1 | Soft-delete flag (§28) |

#### Stock limits & info
| Field | Type | NN | Default | Notes |
|-------|------|----|---------|-------|
| minimum_stock_base | INTEGER | NN | 0 | **Minimum Stock Limit** in base units (حد أدنى) |
| maximum_stock_base | INTEGER | NN | 0 | **Maximum Stock Limit** in base units; 0 = unlimited (حد أقصى) |
| current_stock_base | INTEGER | NN | 0 | **Derived/cached** stock in base units (§10) — NOT source of truth |
| usage_instructions | TEXT | nullable | NULL | **Usage Instructions** (تعليمات الاستخدام) |
| general_notes | TEXT | nullable | NULL | **General Notes** (ملاحظات عامة) |
| license_number | TEXT | nullable | NULL | **License Number** (رقم الترخيص) |

#### Pricing (master/default — see §8)
| Field | Type | NN | Default | Notes |
|-------|------|----|---------|-------|
| purchase_cost | INTEGER | NN | 0 | Master/default Purchase Cost (money) |
| purchase_discount_pct | INTEGER | NN | 0 | Master/default Purchase Discount % (basis points; 100 = 1%) |
| retail_price | INTEGER | NN | 0 | Public / Retail Price (money) |
| sub_unit_price | INTEGER | NN | 0 | Sub-unit Price (money) |
| wholesale_price | INTEGER | NN | 0 | Wholesale Price (money) |
| half_wholesale_price | INTEGER | NN | 0 | Half-Wholesale Price (money) |
| custom_price_1 | INTEGER | NN | 0 | Custom Price 1 (money) |
| custom_price_2 | INTEGER | NN | 0 | Custom Price 2 (money) |
| vat_tax_pct | INTEGER | NN | 0 | VAT / Tax % (basis points; 100 = 1%) |
| profit_margin_pct | INTEGER | NN | 0 | **Calculated** Profit Margin % (derived, §8; basis points) |

#### Timestamps
| Field | Type | NN | Default | Notes |
|-------|------|----|---------|-------|
| created_at | INTEGER | NN | now | |
| updated_at | INTEGER | NN | now | |

**Indexes:** `primary_barcode` (unique where non-null), `secondary_barcode`, `trade_name_1`, `trade_name_2`, `scientific_name`, `active_ingredients` (prefix/search index), `manufacturer_id`, `category_id`. (sub_category / therapeutic_group indexes dropped with their tables in Phase 18.)

**Business rules:**
- Manufacturer, Main Category, Sub-Category, and Therapeutic Group are **FKs to standalone tables** (§4.1–4.4), not free text.
- Master/default pricing is **distinct** from batch/purchase-specific historical cost (§8).
- Historical invoices/batches keep their own cost and are **never mutated** when pricing changes.
- Referential integrity is preserved even if an item is later deactivated (§28).

---

### 4.8 `batches`
**Purpose:** the dedicated **Batch / التشغيلة** entity. Expiry, cost, and operational quantity are **attached to the batch**, never to the item alone.

| Field | Type | NN | Default | Notes |
|-------|------|----|---------|-------|
| id | TEXT | PK | UUID | |
| item_id | TEXT | FK→`items.id` | — | |
| batch_number | TEXT | NN | — | Batch / lot number |
| expiry_date | INTEGER | nullable | NULL | epoch ms; NULL when item `has_expiry_date`=0 |
| remaining_qty_base | INTEGER | NN | 0 | **Remaining Quantity in Base Units** |
| purchase_cost | INTEGER | NN | 0 | **Batch-level purchase cost** (money; effective after bonuses, §13) |
| purchase_date | INTEGER | NN | — | Purchase date |
| supplier_id | TEXT | FK→`suppliers.id` | nullable | |
| bonus_qty_base | INTEGER | NN | 0 | **Bonus quantity** where applicable (base units) |
| created_at | INTEGER | NN | now | |
| updated_at | INTEGER | NN | now | |

**Unique:** `(item_id, batch_number)` — a batch number is unique per item. **Indexes:** `(item_id, expiry_date)` [FEFO], `batch_number`, `supplier_id`, `expiry_date`.

**CHECK:** `remaining_qty_base >= 0`.

**Business rules (§6):**
- Item ⇄ Batch: 1-to-many.
- Batch ⇄ Supplier: many-to-1.
- Non-expiring products: `expiry_date` = NULL, FEFO degrades to FIFO by `purchase_date`.
- **Expired batches are never automatically selected for sale.** Normal sale selection = FEFO.
- Batch-level costing, inventory, and returns are all tracked on the batch.
- **Historical cost retention:** each batch keeps its own cost forever; later purchases never mutate it.

---

### 4.9 `stock_movements` (Stock Movement Ledger)
**Purpose:** complete, auditable, append-only ledger — the **authoritative** inventory history (§10).

| Field | Type | NN | Default | Notes |
|-------|------|----|---------|-------|
| id | TEXT | PK | UUID | |
| item_id | TEXT | FK→`items.id` | — | |
| batch_id | TEXT | FK→`batches.id` | nullable | batch-bound when applicable |
| quantity_base | INTEGER | NN | 0 | signed, base units |
| movement_type | TEXT | NN | — | see list below |
| reference_type | TEXT | nullable | NULL | e.g., sale / purchase / return / adjustment |
| reference_id | TEXT | nullable | NULL | id of the referencing document |
| unit_cost | INTEGER | NN | 0 | unit cost at movement time (money) |
| user_id | TEXT | FK→`users.id` | — | who caused the change |
| note | TEXT | nullable | NULL | note / reason |
| created_at | INTEGER | NN | now | |

**Movement types (authoritative):** `opening_balance`, `purchase`, `sale`, `sale_return`, `purchase_return`, `stock_adjustment`, `damaged`, `expired`, `transfer`, `manual_correction`.

**Indexes:** `(item_id, created_at)`, `(batch_id, created_at)`, `(reference_type, reference_id)`, `movement_type`.

**CHECK:** `quantity_base != 0`.

---

### 4.10 `suppliers`
**Purpose:** supplier master (المورد).

| Field | Type | NN | Default | Notes |
|-------|------|----|---------|-------|
| id | TEXT | PK | UUID | |
| name | TEXT | NN | — | **Supplier Name** |
| phone | TEXT | nullable | NULL | **Phone** |
| secondary_phone | TEXT | nullable | NULL | **Secondary Phone** |
| address | TEXT | nullable | NULL | **Address** |
| contact_person | TEXT | nullable | NULL | **Contact Person** |
| email | TEXT | nullable | NULL | |
| tax_vat_number | TEXT | nullable | NULL | **Tax / VAT Number** |
| license_registration | TEXT | nullable | NULL | **License / Registration** |
| notes | TEXT | nullable | NULL | **Notes** |
| opening_balance | INTEGER | NN | 0 | **Opening Balance** (money; seed for accounting) |
| balance | INTEGER | NN | 0 | Running balance (money) — **derived** from ledger |
| is_active | INTEGER | NN | 1 | Active / Inactive |
| created_at | INTEGER | NN | now | |
| updated_at | INTEGER | NN | now | |

**Indexes:** `name`, `phone`.

---

### 4.11 `customers`
**Purpose:** customer/patient master (الزبون / العميل).

| Field | Type | NN | Default | Notes |
|-------|------|----|---------|-------|
| id | TEXT | PK | UUID | |
| name | TEXT | NN | — | **Customer Name** |
| phone | TEXT | nullable | NULL | **Phone** |
| email | TEXT | nullable | NULL | |
| address | TEXT | nullable | NULL | **Address** |
| notes | TEXT | nullable | NULL | **Notes** |
| has_account | INTEGER | NN | 0 | **Account Balance if enabled** (1 = credit/account allowed) |
| opening_balance | INTEGER | NN | 0 | opening money balance |
| balance | INTEGER | NN | 0 | **Account Balance** (money; derived when `has_account`=1) |
| date_of_birth | INTEGER | nullable | NULL | |
| gender | TEXT | nullable | NULL | |
| medical_history | TEXT | nullable | NULL | |
| is_active | INTEGER | NN | 1 | |
| created_at | INTEGER | NN | now | |
| updated_at | INTEGER | NN | now | |

**Business rule:** **Ordinary cash sale does NOT require creating a customer.** `sales_invoices.customer_id` is nullable; walk-in cash sales proceed without a customer.

---

### 4.12 `prescriptions`
**Purpose:** prescription master (وصفة).

| Field | Type | NN | Default | Notes |
|-------|------|----|---------|-------|
| id | TEXT | PK | UUID | |
| customer_id | TEXT | FK→`customers.id` | — | |
| doctor_name | TEXT | nullable | NULL | |
| notes | TEXT | nullable | NULL | |
| image_path | TEXT | nullable | NULL | scanned image |
| created_by | TEXT | FK→`users.id` | — | |
| created_at | INTEGER | NN | now | |

### 4.13 `prescription_items`

| Field | Type | NN | Default | Notes |
|-------|------|----|---------|-------|
| id | TEXT | PK | UUID | |
| prescription_id | TEXT | FK→`prescriptions.id` | — | |
| item_id | TEXT | FK→`items.id` | — | |
| quantity_base | INTEGER | NN | 0 | base units |
| dosage | TEXT | nullable | NULL | |
| frequency | TEXT | nullable | NULL | |

---

### 4.14 `sales_invoices`
**Purpose:** Sales Invoice header (فاتورة بيع).

| Field | Type | NN | Default | Notes |
|-------|------|----|---------|-------|
| id | TEXT | PK | UUID | |
| invoice_number | TEXT | NN | — | **Invoice Number**, unique, auto-generated |
| invoice_type | TEXT | NN | 'sale' | **Invoice Type**: 'sale' \| 'hybrid' \| 'return' |
| customer_id | TEXT | FK→`customers.id` | nullable | NULL = walk-in cash sale |
| user_id | TEXT | FK→`users.id` | — | cashier |
| date | INTEGER | NN | now | **Date/Time** |
| subtotal | INTEGER | NN | 0 | money |
| discount_amount | INTEGER | NN | 0 | money |
| tax_amount | INTEGER | NN | 0 | money |
| total | INTEGER | NN | 0 | money |
| paid_amount | INTEGER | NN | 0 | **Paid Amount** (money) |
| remaining_amount | INTEGER | NN | 0 | **Remaining Amount** (money; credit customers) |
| change_amount | INTEGER | NN | 0 | change back (money) |
| payment_method | TEXT | NN | 'cash' | 'cash' \| 'card' \| 'mixed' \| 'credit' |
| status | TEXT | NN | 'completed' | 'completed' \| 'voided' |
| notes | TEXT | nullable | NULL | **Notes** |
| created_at | INTEGER | NN | now | |
| updated_at | INTEGER | NN | now | |

**Unique:** `invoice_number`. **Indexes:** `invoice_number`, `date`, `customer_id`, `user_id`, `status`.

---

### 4.15 `sales_invoice_items`
**Purpose:** Sales Invoice line items. Quantity is in **base units** (§7). The line is **linked to the batch** sold (FEFO). Signed quantities enable **hybrid returns** (§14).

| Field | Type | NN | Default | Notes |
|-------|------|----|---------|-------|
| id | TEXT | PK | UUID | |
| invoice_id | TEXT | FK→`sales_invoices.id` | — | |
| item_id | TEXT | FK→`items.id` | — | |
| batch_id | TEXT | FK→`batches.id` | — | **the batch sold from (FEFO)** |
| quantity_base | INTEGER | NN | 0 | signed (base units): + sale, − return |
| unit_type_id | TEXT | FK→`units.id` | — | **Unit Type** at sell time (box/strip/…) |
| unit_price | INTEGER | NN | 0 | money |
| discount | INTEGER | NN | 0 | money |
| tax | INTEGER | NN | 0 | money |
| line_total | INTEGER | NN | 0 | **Line Total** (money; net of discount) |
| cost_of_goods | INTEGER | NN | 0 | **Cost** snapshot from batch (money; signed for returns) |
| profit | INTEGER | NN | 0 | **Profit** = `line_total − cost_of_goods` (money, signed, stored) |
| original_invoice_item_id | TEXT | FK→`sales_invoice_items.id` | nullable | set on return lines (hybrid) |
| return_quantity_base | INTEGER | NN | 0 | cumulative returned qty in base units |
| notes | TEXT | nullable | NULL | |

**Indexes:** `invoice_id`, `item_id`, `batch_id`, `original_invoice_item_id`.

**Business rule:** every positive (sale) line references the **batch sold from (FEFO batch)**; a return line references the **original invoice line** and the **original batch**.

---

### 4.16 `purchase_invoices`
**Purpose:** Purchase Invoice header (فاتورة شراء).

| Field | Type | NN | Default | Notes |
|-------|------|----|---------|-------|
| id | TEXT | PK | UUID | |
| purchase_number | TEXT | NN | — | **Invoice Number**, unique, auto-generated |
| supplier_id | TEXT | FK→`suppliers.id` | — | **Supplier** |
| user_id | TEXT | FK→`users.id` | — | **User** |
| date | INTEGER | NN | now | **Date** |
| subtotal | INTEGER | NN | 0 | money |
| discount_amount | INTEGER | NN | 0 | **Discount** (money) |
| tax_amount | INTEGER | NN | 0 | **Tax** (money) |
| total | INTEGER | NN | 0 | **Total** (money) |
| paid_amount | INTEGER | NN | 0 | **Paid** (money) |
| remaining_amount | INTEGER | NN | 0 | **Remaining** (money) |
| notes | TEXT | nullable | NULL | **Notes** |
| status | TEXT | NN | 'pending' | **Status**: 'pending' \| 'received' \| 'cancelled' |
| expected_date | INTEGER | nullable | NULL | |
| received_date | INTEGER | nullable | NULL | |
| created_at | INTEGER | NN | now | |
| updated_at | INTEGER | NN | now | |

**Unique:** `purchase_number`. **Indexes:** `purchase_number`, `date`, `supplier_id`, `status`.

---

### 4.17 `purchase_invoice_items`
**Purpose:** Purchase Invoice line items.

| Field | Type | NN | Default | Notes |
|-------|------|----|---------|-------|
| id | TEXT | PK | UUID | |
| purchase_id | TEXT | FK→`purchase_invoices.id` | — | |
| item_id | TEXT | FK→`items.id` | — | **Item** |
| batch_id | TEXT | FK→`batches.id` | nullable | **Batch** created on receive (NULL until received) |
| quantity_base | INTEGER | NN | 0 | **Quantity** in base units (purchased, net of bonus) |
| unit_type_id | TEXT | FK→`units.id` | — | **Unit** type |
| unit_cost | INTEGER | NN | 0 | **Purchase Cost** (money) |
| discount | INTEGER | NN | 0 | money |
| tax | INTEGER | NN | 0 | money |
| line_total | INTEGER | NN | 0 | money |
| bonus_qty_base | INTEGER | NN | 0 | total bonus quantity in base units (from §4.18) |
| notes | TEXT | nullable | NULL | |

**Indexes:** `purchase_id`, `item_id`, `batch_id`.

---

### 4.18 `purchase_bonuses`
**Purpose:** explicit Bonus Engine record (بونص / هدية). One row per bonus entry per purchase line; supports Bonus 1, Bonus 2, Gift, and future **Buy A Get B** (different item).

| Field | Type | NN | Default | Notes |
|-------|------|----|---------|-------|
| id | TEXT | PK | UUID | |
| purchase_invoice_item_id | TEXT | FK→`purchase_invoice_items.id` | — | owning purchase line |
| bonus_type | TEXT | NN | — | 'bonus_1' \| 'bonus_2' \| 'gift' |
| item_id | TEXT | FK→`items.id` | nullable | **NULL = same as purchased item**; set = different item (Buy A Get B) |
| quantity_base | INTEGER | NN | 0 | bonus quantity in base units |
| note | TEXT | nullable | NULL | |
| created_at | INTEGER | NN | now | |

**Indexes:** `purchase_invoice_item_id`, `bonus_type`, `item_id`.

---

### 4.19 `returns` / `return_items`
**Purpose:** standalone return documents. **Hybrid return invoices** (sale + return in one invoice) additionally use signed `sales_invoice_items` (§14). Both share the same batch-restore and reversal rules and run transactionally.

#### `returns`
| Field | Type | NN | Default | Notes |
|-------|------|----|---------|-------|
| id | TEXT | PK | UUID | |
| return_number | TEXT | NN | — | unique, auto-generated |
| type | TEXT | NN | — | 'sale_return' \| 'purchase_return' |
| original_invoice_id | TEXT | FK→`sales_invoices.id`\|`purchase_invoices.id` | — | **Original Invoice** |
| original_invoice_type | TEXT | NN | — | 'sale' \| 'purchase' |
| customer_id | TEXT | FK→`customers.id` | nullable | sale returns |
| supplier_id | TEXT | FK→`suppliers.id` | nullable | purchase returns |
| user_id | TEXT | FK→`users.id` | — | |
| total | INTEGER | NN | 0 | money |
| status | TEXT | NN | 'completed' | |
| created_at | INTEGER | NN | now | |

#### `return_items`
| Field | Type | NN | Default | Notes |
|-------|------|----|---------|-------|
| id | TEXT | PK | UUID | |
| return_id | TEXT | FK→`returns.id` | — | |
| original_invoice_item_id | TEXT | FK→ original line table | — | **Original Invoice Item** |
| item_id | TEXT | FK→`items.id` | — | |
| batch_id | TEXT | FK→`batches.id` | — | **Original Batch** (restoration target) |
| quantity_base | INTEGER | NN | 0 | signed |
| amount | INTEGER | NN | 0 | money |

**Unique:** `(return_id, original_invoice_item_id)` — one line per original line.

---

### 4.20 `expenses`

| Field | Type | NN | Default | Notes |
|-------|------|----|---------|-------|
| id | TEXT | PK | UUID | |
| category | TEXT | NN | — | 'rent' \| 'utilities' \| 'salaries' \| 'other' |
| description | TEXT | NN | — | |
| amount | INTEGER | NN | 0 | money |
| receipt_path | TEXT | nullable | NULL | |
| created_by | TEXT | FK→`users.id` | — | |
| created_at | INTEGER | NN | now | |

---

### 4.21 `cashbox_transactions`

| Field | Type | NN | Default | Notes |
|-------|------|----|---------|-------|
| id | TEXT | PK | UUID | |
| type | TEXT | NN | — | 'open' \| 'close' \| 'deposit' \| 'withdraw' \| 'sale' \| 'expense' |
| amount | INTEGER | NN | 0 | money, signed |
| reference_id | TEXT | nullable | NULL | |
| reference_type | TEXT | nullable | NULL | |
| note | TEXT | nullable | NULL | |
| user_id | TEXT | FK→`users.id` | — | |
| created_at | INTEGER | NN | now | |

---

### 4.22 `accounts` (Chart of Accounts)

| Field | Type | NN | Default | Notes |
|-------|------|----|---------|-------|
| id | TEXT | PK | UUID | |
| code | TEXT | NN | — | unique, e.g., '1000' |
| name | TEXT | NN | — | Arabic-first |
| name_en | TEXT | nullable | NULL | |
| type | TEXT | NN | — | 'asset' \| 'liability' \| 'equity' \| 'revenue' \| 'expense' |
| parent_id | TEXT | FK→`accounts.id` | nullable | self-referencing |
| is_active | INTEGER | NN | 1 | |
| created_at | INTEGER | NN | now | |

### 4.23 `journal_entries`

| Field | Type | NN | Default | Notes |
|-------|------|----|---------|-------|
| id | TEXT | PK | UUID | |
| entry_number | TEXT | NN | — | unique |
| date | INTEGER | NN | — | |
| description | TEXT | NN | — | |
| reference_type | TEXT | NN | — | 'sale' \| 'purchase' \| 'expense' \| 'return' \| 'manual' |
| reference_id | TEXT | nullable | NULL | |
| is_posted | INTEGER | NN | 1 | |
| created_by | TEXT | FK→`users.id` | — | |
| created_at | INTEGER | NN | now | |

### 4.24 `journal_entry_lines`

| Field | Type | NN | Default | Notes |
|-------|------|----|---------|-------|
| id | TEXT | PK | UUID | |
| journal_entry_id | TEXT | FK→`journal_entries.id` | — | |
| account_id | TEXT | FK→`accounts.id` | — | |
| debit | INTEGER | NN | 0 | money |
| credit | INTEGER | NN | 0 | money |

**CHECK:** `debit >= 0`, `credit >= 0`, and per entry `debit + credit > 0`. **Business rule:** per entry, `Σ(debit) == Σ(credit)`.

---

### 4.25 `users`

| Field | Type | NN | Default | Notes |
|-------|------|----|---------|-------|
| id | TEXT | PK | UUID | |
| username | TEXT | NN | — | unique |
| password_hash | TEXT | NN | — | bcrypt |
| full_name | TEXT | NN | — | |
| role_id | TEXT | FK→`roles.id` | — | |
| is_active | INTEGER | NN | 1 | |
| created_at | INTEGER | NN | now | |
| updated_at | INTEGER | NN | now | |

---

### 4.26 `roles` / `permissions` / `role_permissions`
**Purpose:** granular RBAC (§16) — **not** a single role string.

`roles`
| Field | Type | NN | Default | Notes |
|-------|------|----|---------|-------|
| id | TEXT | PK | UUID | |
| name | TEXT | NN | — | unique; e.g., admin, pharmacist, cashier |
| name_ar | TEXT | NN | — | Arabic display name |
| is_active | INTEGER | NN | 1 | |

`permissions`
| Field | Type | NN | Default | Notes |
|-------|------|----|---------|-------|
| id | TEXT | PK | UUID | |
| code | TEXT | NN | — | unique permission code (see §16) |
| name | TEXT | NN | — | |
| name_ar | TEXT | NN | — | Arabic label |

`role_permissions`
| Field | Type | NN | Default | Notes |
|-------|------|----|---------|-------|
| id | TEXT | PK | UUID | |
| role_id | TEXT | FK→`roles.id` | — | |
| permission_id | TEXT | FK→`permissions.id` | — | |
| granted | INTEGER | NN | 1 | allow/deny |

**Unique:** `(role_id, permission_id)`.

---

### 4.27 `audit_logs`
**Purpose:** **immutable**, comprehensive audit trail (سجل التدقيق).

| Field | Type | NN | Default | Notes |
|-------|------|----|---------|-------|
| id | TEXT | PK | UUID | |
| user_id | TEXT | FK→`users.id` | — | **User ID** |
| action | TEXT | NN | — | **Action** ('create','update','delete','login','logout','void','price_change','restore',…) |
| entity_type | TEXT | NN | — | **Entity Type** ('item','sales_invoice','purchase_invoice','batch','price',…) |
| entity_id | TEXT | NN | — | **Entity ID** |
| old_value | TEXT | nullable | NULL | **Old Value** (JSON snapshot) |
| new_value | TEXT | nullable | NULL | **New Value** (JSON snapshot) |
| reason | TEXT | nullable | NULL | **Notes / Reason** |
| ip_address | TEXT | nullable | NULL | |
| created_at | INTEGER | NN | now | **Date/Time** |

**Indexes:** `(entity_type, entity_id)`, `user_id`, `created_at`.
**Rules:** append-only; rows are never updated or deleted (§17, §28).

---

### 4.28 `lost_sales`

| Field | Type | NN | Default | Notes |
|-------|------|----|---------|-------|
| id | TEXT | PK | UUID | |
| requested_item_name | TEXT | NN | — | **Requested Item / Product Name** |
| barcode | TEXT | nullable | NULL | **Barcode** if known |
| scientific_name | TEXT | nullable | NULL | **Scientific Name** |
| quantity_requested | INTEGER | NN | 0 | **Quantity Requested** (base units) |
| customer_name | TEXT | nullable | NULL | **Customer info if available** |
| customer_phone | TEXT | nullable | NULL | |
| user_id | TEXT | FK→`users.id` | — | **User** |
| status | TEXT | NN | 'open' | **Status**: 'open' \| 'ordered' \| 'resolved' \| 'cancelled' |
| note | TEXT | nullable | NULL | **Notes** |
| created_at | INTEGER | NN | now | **Date/Time** |
| updated_at | INTEGER | NN | now | |

**Indexes:** `requested_item_name`, `scientific_name`, `status`, `created_at`.

---

### 4.29 Required Tables — Map (verification aid)

| Required entity | Table | Purpose / Reason for existence |
|-----------------|-------|-------------------------------|
| items / medicines | `items` | Product master data |
| batches | `batches` | Batch/expiry/cost/quantity |
| categories | `categories` | Main categories |
| ~~sub_categories~~ | — | removed in Phase 18/v12 |
| ~~therapeutic_groups~~ | — | removed in Phase 18/v12 |
| active_ingredients | `active_ingredients`, `item_active_ingredients` | Active-ingredient master + item joins (strengths) |
| indications | `indications`, `item_indications` | Indication master + item joins |
| manufacturers | `manufacturers` | Independent manufacturer master |
| suppliers | `suppliers` | Supplier master |
| customers | `customers` | Customer/patient master |
| sales_invoices | `sales_invoices` | Sales invoice header |
| sales_invoice_items | `sales_invoice_items` | Sales invoice lines (batch-linked) |
| purchase_invoices | `purchase_invoices` | Purchase invoice header |
| purchase_invoice_items | `purchase_invoice_items` | Purchase invoice lines |
| purchase_bonuses | `purchase_bonuses` | Bonus engine records |
| stock_movements | `stock_movements` | Auditable stock ledger |
| lost_sales | `lost_sales` | Lost sales / النواقص |
| users | `users` | System users |
| roles | `roles` | Roles |
| permissions | `permissions` | Granular permissions |
| role_permissions | `role_permissions` | Role⇄Permission matrix |
| audit_logs | `audit_logs` | Immutable audit trail |
| *units* | `units`, `item_units` | Base/large unit dictionary + item pairing (§7) |
| *prescriptions* | `prescriptions`, `prescription_items` | Prescriptions module |
| *returns* | `returns`, `return_items` | Standalone return documents (§14) |
| *expenses* | `expenses` | Expenses module |
| *cashbox* | `cashbox_transactions` | Cash box ledger |
| *accounting* | `accounts`, `journal_entries`, `journal_entry_lines` | Future double-entry accounting foundation (§25) |

---

## 5. Items / Product Model

> **Critical rule:** The Items model is **never** reduced to only name/barcode/category/price/stock. Every required field is an **explicit column** in `items` (§4.7).

### Identification (explicit columns)
| Requirement | Column |
|-------------|--------|
| Primary Barcode | `items.primary_barcode` |
| Secondary Barcode | `items.secondary_barcode` |
| Trade Name 1 | `items.trade_name_1` |
| Trade Name 2 | `items.trade_name_2` |
| Scientific Name | `items.scientific_name` |
| Active Ingredients / Composition | `items.active_ingredients` |
| Equivalent Drug | `items.equivalent_drug` |
| Manufacturer | `items.manufacturer_id` FK → `manufacturers` |
| Main Category | `items.category_id` FK → `categories` (optional in Phase 18) |
| ~~Sub-Category~~ | removed in Phase 18/v12 |
| ~~Therapeutic Group~~ | removed in Phase 18/v12 |

### Pharmaceutical Specifications
| Requirement | Column |
|-------------|--------|
| Pharmaceutical Form | `items.pharmaceutical_form` |
| Dose / Concentration | `items.dose_concentration` |
| Size / Volume | `items.size_volume` |
| Shelf Location | `items.shelf_location` |

> **Phase 18.1 Excel contract:** the product import/export sheet carries the four
> pharmaceutical columns above plus `الجرعة / العيار` under the merged
> header `المكافئ / الشكل الصيدلاني / الجرعة / العيار / الحجم` as
> **appended columns 23–26** (positional backward-compat with Phase 3 sheets),
> mapped back to `equivalent_drug`, `pharmaceutical_form`,
> `dose_concentration` and `size_volume`. Import **blank = preserve**: blank
> optional cells (financials, VAT, min/max, location, expiry flag, barcodes,
> ingredients/indications, unit relation, EN/scientific/flat ingredient and the
> four new columns) never overwrite existing values; only explicit cells
> change. Export→import is therefore lossless, verified by `test/
> inventory_excel_contract_test.dart` (§31).
>
> **Phase 18.2A matching & scalability (Syrian-database gate):** the item is
> resolved **deterministically and never guessed** — (1) a non-blank barcode is
> matched exactly against the in-memory primary/secondary barcode index; an
> unmatched barcode identifies a brand-new row (no fuzzy edits, source ids are
> never synthesised into barcodes); (2) without a barcode, the normalized trade
> name (Arabic fold via `SmartSearch`) is narrowed by the **composite
> identity**: every provided discriminator (active-ingredient id + strength
> pairs, pharmaceutical form, dose, manufacturer) must match a candidate
> exactly; blank discriminators are ignored (blank = preserve on update);
> (3) exactly one candidate → update, none → create, **more than one →
> conflict/ambiguous** (row reported and skipped). `package_shape`/`size_volume`
> and unit relations are **not** part of the identity. The whole catalog is
> loaded **once** per operation (`InventoryRepository.allItems()` + bulk
> `activeIngredientRelationsForItems` / `indicationIdsForItems` /
> `itemUnitsForItems` projections), barcode/name/composite indexes are built in
> memory, there is **no per-row DB query and no `pageSize: 10000` full-catalog
> scan**, the row loop yields every 256 rows, and in-file duplicate targeting
> (barcode / matched id / creation identity) is rejected with «مكرر داخل
> الملف». Verified by `test/inventory_import_scalability_test.dart`
> (14 001-row export/import proves matching after index 10 000 with exactly one
> catalog load per operation and zero `searchItems` calls).

### Flags
| Requirement | Column |
|-------------|--------|
| Has Expiry Date | `items.has_expiry_date` |
| Print Barcode Label | `items.print_barcode_label` |
| OTC | `items.is_otc` |
| Controlled Drug | `items.is_controlled_drug` |
| Scale Barcode Alert | `items.scale_barcode_alert` |
| Lock Automatic Price Update | `items.lock_auto_price_update` |

### Units
| Requirement | Table |
|-------------|-------|
| Large Unit / Box | `item_units.large_unit_id` → `units` |
| Sub-unit / Strip / Fraction | `item_units.base_unit_id` → `units` |
| Number of Sub-units per Large Unit | `item_units.units_per_large` |

### Stock
| Requirement | Column |
|-------------|--------|
| Minimum Stock Limit | `items.minimum_stock_base` |
| Maximum Stock Limit | `items.maximum_stock_base` |
| Usage Instructions | `items.usage_instructions` |
| General Notes | `items.general_notes` |
| License Number | `items.license_number` |

### Pricing
| Requirement | Column |
|-------------|--------|
| Purchase Cost | `items.purchase_cost` (master default) + `batches.purchase_cost` (historical) |
| Purchase Discount % | `items.purchase_discount_pct` |
| Public / Retail Price | `items.retail_price` |
| Sub-unit Price | `items.sub_unit_price` |
| Wholesale Price | `items.wholesale_price` |
| Half-Wholesale Price | `items.half_wholesale_price` |
| Custom Price 1 | `items.custom_price_1` |
| Custom Price 2 | `items.custom_price_2` |
| VAT / Tax % | `items.vat_tax_pct` |
| Calculated Profit Margin % | `items.profit_margin_pct` (derived) |

None of these fields is summarized in prose only — each is an explicit schema column.

---

## 6. Batch Model

`batches` (§4.8) is the **dedicated batch entity**. Minimum fields present:

- ✅ ID — `id`
- ✅ Item ID — `item_id` (FK)
- ✅ Batch Number — `batch_number`
- ✅ Expiry Date — `expiry_date`
- ✅ Remaining Quantity in Base Units — `remaining_qty_base`
- ✅ Purchase Cost — `purchase_cost`
- ✅ Purchase Date — `purchase_date`
- ✅ Supplier ID — `supplier_id` (FK)
- ✅ Bonus Quantity where applicable — `bonus_qty_base`
- ✅ Created At — `created_at`
- ✅ Updated At — `updated_at`

### Rules

- **Batch ⇄ Item:** one item has many batches.
- **Batch ⇄ Supplier:** many batches to one supplier.
- **Unique rules:** `(item_id, batch_number)` unique.
- **Indexes:** `(item_id, expiry_date)`, `batch_number`, `supplier_id`, `expiry_date`.
- **Non-expiring products:** `expiry_date` = NULL; FEFO → FIFO by `purchase_date`.
- **Prevent selling expired batches:** FEFO selection excludes batches where `expiry_date < today`. An expired batch is **never** automatically selected for sale.
- **Batch selection at sale:** earliest expiry first (FEFO), consuming `remaining_qty_base`, always in **base units** (§7).
- **Return quantity restoration:** returns restore quantity to the **original batch** (§14). Never a random batch.
- **Historical cost retention:** each batch's `purchase_cost` is final; newer purchases never alter it (§8).

> **Note:** `expiry_date` on `items` is **not** used as the inventory source. Expiry, cost, and operational quantity belong **on the batch**.

---

## 7. Units & Base Unit Quantity Model

**Authoritative rule:** **TotalBaseUnits is the only authoritative inventory quantity.**

- Every item has one **Base Unit** (شريط/قرص/وحدة جزئية) and one **Large Unit** (علبة), with `units_per_large` = number of base units per large unit — declared in `item_units`.
- All authoritative quantities are stored as **base-unit integers** in the `_base` columns:
  - `batches.remaining_qty_base`
  - `stock_movements.quantity_base`
  - `sales_invoice_items.quantity_base`
  - `purchase_invoice_items.quantity_base`
  - `purchase_bonuses.quantity_base`
  - `return_items.quantity_base`
  - `items.current_stock_base`, `minimum_stock_base`, `maximum_stock_base`
- **Prohibited:** independent, conflicting authoritative fields such as `boxes_stock + strips_stock`. The system stores one number (base units) and derives the rest.

### How conversion works
```
1 Box = 10 Strips (base unit = Strip)
3 Boxes + 4 Strips → TotalBaseUnits = (3 × 10) + 4 = 34
```

- **Box → Base Units:** `base = qty_boxes × units_per_large`
- **Strip/Fraction → Base Units:** `base = qty_strips × 1` (1:1)
- **Display (Box + remainder):** `boxes = base ~/ units_per_large`, `remainder = base % units_per_large` → "3 علب + 4 شرائط". Display is always **derived**, never stored as two conflicting numbers.

### How every operation uses base units
| Operation | Behavior |
|-----------|----------|
| **Sales** | Cashier may enter in boxes and/or strips; each line is converted and stored as `quantity_base`; `unit_type_id` records the display unit at sale time (line price is per unit type, converted consistently). |
| **Returns** | Reverse in base units against the original batch. |
| **Purchases** | Entered and stored in base units; bonuses are base units; effective quantity (§13) is total base units. |
| **Stock-taking (جرد)** | Counts converted (boxes→base, strips→1:1) before adjustment; the adjustment movement is in base units. |
| **Adjustments** | `stock_movements.quantity_base` is the base-unit delta. |
| **FEFO** | Consumption and remaining quantities are base units. |
| **Reports** | All aggregation is in base units; display breakdown is derived for humans only. |
| **Profit** | Uses base-unit quantities with money in integer minor units. |

---

## 8. Pricing & Historical Cost

### Master/Default pricing vs Batch/Purchase-specific historical cost (explicit separation)

| Concept | Where | Mutability |
|---------|-------|-----------|
| **Master/default pricing** | `items` (`purchase_cost`, `retail_price`, `wholesale_price`, `sub_unit_price`, `half_wholesale_price`, `custom_price_1/2`, `vat_tax_pct`, `purchase_discount_pct`, `profit_margin_pct`) | Editable through the **price-change workflow** — always audited (§17). Optional auto-update from purchases **only if** `lock_auto_price_update` = 0. |
| **Batch/purchase-specific historical cost** | `batches.purchase_cost` + `purchase_invoice_items.unit_cost` | **Immutable after entry.** Never overwritten by later purchases. |
| **Actual Batch Cost** | `batches.purchase_cost` = **effective unit cost after bonuses** (Total Actual Cost ÷ Total Effective Quantity, §13) | Set once when the purchase/purchase line is received. |
| **Selling Price** | `items.retail_price` (default) + chosen price tier at sale time | Per-invoice snapshot on `sales_invoice_items.unit_price`. |
| **Profit** | `sales_invoice_items.profit = line_total − cost_of_goods` (cost snapshot from the batch at sale time) | Stored at sale time; historical profit is never recomputed with later prices. |
| **Historical Cost** | preserved per batch and per `sales_invoice_items.cost_of_goods` and per `purchase_invoice_items.unit_cost` | Immutable history. |

### Rules
1. A newer purchase with a different cost **never** changes existing batches or historical invoices.
2. Only the **master default** may change — guarded by `lock_auto_price_update` and always **audited** (old/new price snapshot + reason).
3. `profit_margin_pct` is **derived** from master cost and retail price, using a configured convention; it is recomputed by the price workflow and **audited**.
4. Financial columns are **integer money**; percentage columns are integer **basis points** (§23).

---

## 9. Inventory Model

- Inventory = `items.current_stock_base` (cached/derived total) + `batches.remaining_qty_base` (per batch) + **Stock Movement Ledger** (`stock_movements`, authoritative).
- **Source of truth:** the ledger. `current_stock_base` is derived and periodically reconciled (§10).
- Low/high stock alerts compare `current_stock_base` against `minimum_stock_base` / `maximum_stock_base`.
- Stock adjustments are ledger movements of type `stock_adjustment` (or `damaged`, `expired`, `manual_correction`), permission-gated by `adjust_stock`, and audited (§16, §17).

---

## 10. Stock Movement Ledger

**Every stock-changing operation MUST create one or more `stock_movements` rows inside the same transaction.**
The ledger is able to **explain why an item's quantity changed** (movement type + reference + user + note).

Movement types (`stock_movements.movement_type`):
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

Each movement records: Item ID, Batch ID (where applicable), Quantity in Base Units, Movement Type, Reference Type, Reference ID, Unit Cost, User ID, Created At, Notes (§4.9).

**Explicit statement:** `items.current_stock_base` and `batches.remaining_qty_base` are **derived/cache values**. They are **NOT the sole source of truth**. A reconciliation job re-syncs them from the ledger.

---

## 11. Sales Model

- Header: `sales_invoices` (§4.14) — supports **Invoice Number, Invoice Type, Customer ID (nullable), User ID, Date/Time, Subtotal, Discount, Tax, Total, Paid Amount, Remaining Amount, Payment Method, Status, Notes, Created At, Updated At**.
- Lines: `sales_invoice_items` (§4.15) — supports **Invoice ID, Item ID, Batch ID, Quantity in Base Units, Unit Type, Unit Price, Discount, Tax, Line Total, Cost, Profit, Original Invoice Item ID, Return Quantity, Notes**.
- **The sale is linked to the exact batch it was sold from (FEFO).**
- Cash sales do not require a customer (`customer_id` nullable).
- Completed sale transaction (§26) → stock deducted, stock movement created, accounting posted, cash box updated, audit written — all or nothing.

---

## 12. Purchase Model

- Header: `purchase_invoices` (§4.16) — **Supplier, Invoice Number, Date, Total, Discount, Tax, Paid, Remaining, Notes, User, Status, Created At, Updated At**.
- Lines: `purchase_invoice_items` (§4.17) — link **Item, Batch (created on receive), Quantity, Unit, Purchase Cost, Discount, Tax, Total, Bonus, Notes**.
- Bonuses: `purchase_bonuses` (§4.18).
- On receiving a purchase: create/update batches, apply bonuses, compute **Effective Quantity** and **Effective Cost** (§13), create stock movements, post accounting, and (if unlocked) update master pricing.

---

## 13. Purchase Bonus Engine

**Bonuses are modeled explicitly** in `purchase_bonuses` — Bonus 1, Bonus 2, and Gift are `bonus_type` values; more rows can be added without schema changes.

### Example
```
100 purchased
+10 Bonus 1     (bonus_type = 'bonus_1')
+5  Bonus 2     (bonus_type = 'bonus_2')
+2  Gift        (bonus_type = 'gift')

Effective Quantity = 100 + 10 + 5 + 2 = 117 base units
```

### True Effective Unit Cost
```
Effective Unit Cost = Total Actual Cost / Total Effective Quantity
```
Applied to: **Profit, Inventory valuation, Cost analysis, Purchase analysis, Pricing analysis** — and stored once on the created batch (`batches.purchase_cost`).

### Buy A Get B (future, supported now)
`purchase_bonuses.item_id` is nullable. When set, the bonus item **differs** from the purchased item (Buy A Get B). The bonus quantity is added to the bonus item's own stock with its own batch/stock movement — inside the same transaction.

---

## 14. Returns Model (Hybrid)

**Two mechanisms, one consistent rule set:**

1. **Hybrid return invoices** (§4.15): a `sales_invoice` of type `'hybrid'` whose lines carry **signed** `quantity_base`:
   ```
   Product A +2   (sale)
   Product B +1   (sale)
   Product C −1   (return, original_invoice_item_id set)
   ```
2. **Standalone returns** (§4.19): `returns` + `return_items`.

### Mandatory rules
- Returns **MUST reference**: **Original Invoice**, **Original Invoice Item**, **Original Batch**.
- Returned stock is restored to the **original batch** whenever valid and possible.
- **Arbitrary return-to-another-batch is prevented** (the UI offers only the original batch; the DB FK requires the referenced batch).
- Returns reverse, transactionally:
  - **Revenue** (reverse amounts),
  - **Cost** (reverse `cost_of_goods`, signed),
  - **Profit** (the net effect),
  - **Stock** (restore base units to the original batch).
- Full rollback on any failure (§26).

---

## 15. Lost Sales Model (النواقص)

- Captured from the POS in one tap when an item is not found; professional Arabic label **النواقص**.
- Table: `lost_sales` (§4.28) — supports **Requested Item/Product Name, Barcode, Scientific Name, Quantity Requested, Customer info if available, User, Date/Time, Status, Notes**.
- Status lifecycle: `open` → `ordered` → `resolved` / `cancelled`.
- Reports aggregate lost sales by product/barcode/scientific name to drive **purchasing decisions** (Phase 3+).

---

## 16. Users, Roles & Permissions

**Granular RBAC** via `users`, `roles`, `permissions`, `role_permissions` (§4.26). The system is **not** limited to a single role string.

### Required granular permissions (canonical codes)
- `sell`
- `return`
- `view_inventory`
- `search`
- `view_alternatives`
- `change_prices`
- `change_purchase_cost`
- `delete_invoice`
- `manage_users`
- `manage_permissions`
- `modify_settings`
- `adjust_stock`

### Reference role definitions (seeded; editable)
| Role | Allowed | Denied |
|------|---------|--------|
| **Admin** | Full access (all permissions) | — |
| **Pharmacist** | `sell`, `return`, `search`, `view_inventory`, `view_alternatives`, `change_prices` | `delete_invoice`, `change_purchase_cost`, `manage_users`, `manage_permissions`, `modify_settings` |
| **Cashier** | `sell`, POS operations, `search` | Denied **authorized returns** only with `return` permission granted explicitly |
| **Viewer** | Read-only: `search`, `view_inventory`, `view_alternatives`, inventory/stock/sales/purchases/customers view, reports view, `cashbox.view`, `expenses.view` | All mutating permissions, `users.*`, `roles.*`, `settings.*`, `backup*` |

> **Phase 2 status (implemented):** full granular RBAC, bcrypt hashing, use-case‑layer enforcement (`ensurePermission` → `UnauthorizedException`), seeded roles/permissions incl. **viewer**, admin-only Users module, and authorization-aware route/section gating. `users.view/create/edit` are the admin-module permissions.

The RBAC model is **extensible** — any new permission is simply a row in `permissions` + grants in `role_permissions`.

### Enforcement
- Checked in the **use case layer** (domain) and reflected in the UI (hide/disable).
- Password hashing: bcrypt. Inactivity auto-logout.
- Permission mutations are audited (§17).

---

## 17. Audit Logging

`audit_logs` (§4.27) is **immutable** — append-only, never updated or deleted.

### Audited operations (at minimum)
- **Price changed**
- **Purchase cost changed**
- **Invoice deleted / cancelled** (void)
- **Inventory manually adjusted**
- **Batch quantity changed**
- **User created / updated / deactivated**
- **Permission changed** (role_permissions mutations)
- **Product edited / deleted**
- Login / logout, Bulk operations, Backup/Restore

> **Phase 2 status (implemented):** `AuditService` writes append-only rows; login success/failure & logout are audited by the application layer; user create/update/activate/deactivate and password change are audited on success. `login_failed` was added to the stored action literals. Unknown-username failures are not auditable because `audit_logs.userId` is NOT NULL — a documented limitation, never a stored-`null` row.

### Recorded fields
- User ID
- Action
- Entity Type
- Entity ID
- Old Value (JSON)
- New Value (JSON)
- Date/Time
- Notes / Reason

---

## 18. Smart Alternatives Engine

**Matching engine implemented in Domain (service/use case), independent of the UI.**

| Level | Color | Rule |
|-------|-------|------|
| **Green** | أخضر | 100% match: same active composition + same dose + same pharmaceutical form |
| **Yellow** | أصفر | Same active composition but different dose/strength |
| **Blue** | أزرق | At least one shared active ingredient |

### Rules
- Computed **dynamically** from current `items` data at request time — never stale stored matches.
- Optional cache only for performance; invalidated whenever item data changes; calculation remains authoritative.
- Extensible: additional rules can be added without UI coupling.
- **Relational-primary matching (Phase 18 + 18.1):** candidates are selected by shared relational `item_active_ingredients`; the legacy flat-token LIKE fallback applies **only** to items that have no relational ingredient ids.
- **Phase 18.1 ranking:** tier (green/yellow/blue) → available stock (desc) → **same manufacturer first** (clear-tie break when both sides carry a `manufacturer_id`) → Arabic trade name, implemented in `SmartAlternativesService.rank`; catalog rows include the item's `manufacturer_id`.

---

## 19. POS Workspace

**Exact layout requirement: 10 customer workspaces + 1 Return tab.**

- Tabs: **Customer 1 … Customer 10**, **Return**.
- Each tab keeps **independent state**:
  - Cart Items
  - Quantities (base units + display unit)
  - Discounts
  - Customer
  - Payment
  - Notes
  - Pending Operations
- **No cart/customer/payment state is lost when switching tabs.**
- State is managed with **Riverpod** (per-tab family providers), and held bills persist across the app session.

---

## 20. Barcode Scanner Architecture

Hardware scanners emit rapid keystrokes + terminator, so the app uses a **global scanner pipeline independent of any focused text field**:

```
Scanner
→ Buffer (global keystroke accumulation)
→ Completion (terminator key or idle timeout)
→ Normalize (trim, clean, configurable suffix)
→ Database Query (primary_barcode → secondary_barcode → item)
→ Item
→ FEFO Batch (select batch per FEFO)
→ Active Cart (add to the current POS workspace tab)
```

- Does **not** depend on a permanently focused TextField.
- Does **not** interfere with keyboard shortcuts (§21): buffered input is recognized only when it matches barcode patterns; otherwise keystrokes fall through.
- Configurable prefix/suffix/terminator/timeout in settings.

---

## 21. Keyboard Shortcuts

| Shortcut | Action |
|----------|--------|
| **F1** | Search |
| **F2** | Toggle Box/Fraction (base-unit display) |
| **F5** | Hold Bill |
| **F12** | Checkout |
| **Space / Enter** | Quick Actions |
| **Alt + S** | Alternatives |

Handling is **centralized** (a `ShortcutManager` in `core/`) and **configurable** (settings), registered app-wide, independent of focused fields, coexisting with the scanner buffer.

---

## 22. Data Grids & Bulk Actions

### Data grids support
- Sorting
- Filtering
- Multi-column search
- Column visibility
- Column order
- Inline editing
- Multi-select
- Bulk actions
- Keyboard navigation

### Inline editing
Examples: **Shelf Location**, **Price**, **Category**. Every inline edit **must pass through business logic + a transaction + audit** (§17, §26) — no direct DB writes from the grid.

### Bulk operations (transactional + audited)
- **Change Shelf Location**
- **Change Category**
- **Adjust Price by %** (requires `change_prices`; computes new integer money safely per §23)
- Validation before commit; single atomic transaction; audit per affected row; **no partial/inconsistent updates**.

---

## 23. Financial Precision Strategy

**Mandatory — floating-point `REAL` is forbidden for sensitive financial math.**

### Authoritative approach: integer smallest currency unit
- All monetary values are **integers of the smallest currency unit** (e.g., USD cents: `$12.50 → 1250`; where cost requires 4 decimals: micro-units, exponent configurable).
- A `Money` value type (in `core/`) encapsulates the integer amount, currency, exponent, and arithmetic that never introduces floating-point drift.
- Percentages stored as **integer basis points** (100 bp = 1%).
- Decimal/rounding: any derived decimal (e.g., percentage application) is computed via `Money` with an explicit rounding mode (e.g., half-up) and snaps back to integer minor units **before persistence**.

### Applied consistently to
- Purchase costs
- Selling prices
- Discounts
- Taxes
- Invoice totals
- Profit
- Supplier balances
- Customer balances
- Cashbox
- Accounting (journal entries)
- Revenue/expense accounts

### Currency
- **Primary: USD.** The design is **configurable** (currency and exponent defined in settings; all stored values are unit-agnostic integers).

**Explicit statement:** `REAL` is never used as the authoritative accounting/storage amount in this design.

---

## 24. Arabic-First UX & Localization Rules

**Mandatory (not optional): the entire application is Arabic-first.**

- **Arabic** is the default language, default locale, default UI direction (RTL), and primary terminology.
- English is supported with a ready localization structure, but **must not replace Arabic in the primary UI**.

### All user-facing content in professional Arabic
Main menus, Sidebar, Navigation, Buttons, Forms, Dialogs, Tables, Data grids, POS, Inventory, Purchases, Sales, Returns, Reports, Settings, Users, Permissions, Notifications, Validation messages, Errors, Empty states, Loading states, Success states, Tooltips, Search interfaces.

**Machine/literal translation is prohibited.** Only professional, natural pharmacy & accounting Arabic is used, governed by a centralized string catalog.

### Controlled terminology glossary (authoritative)
| English | العربية |
|---------|---------|
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
| Prescription Quantity | الكمية <br/>— Phase 18.1: reworded from «الوحدات الأساسية» (`prescriptionQuantity` key + `PartialPriceCalculator` user-facing strings) so a bare quantity label no longer implies a base-unit; the unit term only appears where a unit is actually attached |
| Lost Sale | النواقص (نواقص) |
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

### Typography and RTL
- **Cairo or Tajawal** — choose one and apply uniformly.
- **RTL is the default mode**, implemented at the architecture level (Directionality driven by locale; `EdgeInsetsDirectional`, `AlignmentDirectional`, `TextAlignDirectional`; no hardcoded left/right).
- Localization structure (§34) keeps English ready as secondary.

### Visual Status (not color-only)
| Status | Arabic | Indicator |
|--------|--------|-----------|
| Expired | منتهي الصلاحية | Text + icon + badge + status color |
| Near Expiry | قارب على الانتهاء | Text + icon + badge + status color |
| Low Stock | مخزون منخفض | Text + icon + badge + status color |
| Normal | طبيعي | Text + icon + badge + status color |

Statuses are derived from `batches.expiry_date`/`items.is_active` and `current_stock_base` vs `minimum_stock_base`. **Never rely on color alone** — always include text, icons, and status indicators.

---

## 25. Accounting Integration Foundation

The full accounting **UI** is deferred, but the **database model already supports** proper double-entry accounting:

- `accounts` (Chart of Accounts) — asset/liability/equity/revenue/expense, hierarchical.
- `journal_entries` + `journal_entry_lines` — double-entry with `Σ(debit) == Σ(credit)`.
- Every sale, purchase, return, and expense posts journal entries **transactionally** (§26).
- Supplier/customer balances are **derived** from ledgers (never hand-edited) and support statements.

### Required future compatibility
Cash Box, Daily/Monthly/Yearly reports, Supplier balances, Customer balances, Profit reports, Income Statement, Balance Sheet, Trial Balance, Account Statement, and future **employee/doctor revenue** — all supported without a radical redesign.

---

## 26. Transactions

All of the following are **atomic transactions**. Any failure → **complete rollback.**

### Sale
```
Create Invoice
→ Create Invoice Items
→ Deduct Batch (FEFO)
→ Create Stock Movement (type = sale)
→ Calculate Cost (snapshot batch cost)
→ Calculate Profit (= line_total − cost)
→ Post journal entry + cash box + audit
→ Commit
```

### Purchase
```
Create Purchase
→ Create Purchase Items
→ Create/Update Batch
→ Apply Bonus (purchase_bonuses)
→ Calculate Effective Quantity
→ Calculate Effective Cost (Total Actual Cost ÷ Effective Qty)
→ Create Stock Movement (type = purchase; + bonus movements for different-item bonuses)
→ Post journal entry + audit
→ Commit
```

### Return
```
Create Return
→ Validate Original Transaction (invoice/line/batch exist; not already fully returned)
→ Restore Correct Batch (the original batch only)
→ Create Stock Movement (sale_return / purchase_return)
→ Reverse Revenue
→ Reverse Cost
→ Reverse Profit
→ Post reversing journal entry + cash box + audit
→ Commit
```

### Stock Adjustment / Bulk Operations
- Single transaction; any failure rolls back the whole operation; per-row audit + one summary audit record.

---

## 27. Data Integrity

Explicitly preserved at the database level:
- **Foreign Keys** — enabled (PRAGMA foreign_keys = ON) on every relation.
- **Unique constraints** — usernames; `primary_barcode` (where non-null); invoice/purchase/return/entry numbers; account codes; permission codes; role names; unit names; `(item_id, batch_number)`; `(category_id, name)` on sub_categories; `(role_id, permission_id)`; `(item_id, base_unit_id, large_unit_id)`; `(return_id, original_invoice_item_id)`.
- **NOT NULL** — on every required column (§4).
- **CHECK constraints** — `units_per_large >= 1`, `remaining_qty_base >= 0`, `quantity_base != 0` (movements), `debit/credit >= 0`, money never ≤ 0 where forbidden, enums validated.
- **Referential integrity** — no orphan records; deletion rules documented per table (§28).
- **Cascading rules** — used only where safe (e.g., `sale_items.invoice_id`, `journal_entry_lines.journal_entry_id`, `role_permissions.role_id`, `purchase_bonuses.purchase_invoice_item_id`); **financial & ledger records are never cascade-deleted** (§28).
- **Indexes (minimum required):**
  - Primary Barcode — `items.primary_barcode`
  - Secondary Barcode — `items.secondary_barcode`
  - Scientific Name — `items.scientific_name`
  - Composition — `items.active_ingredients`
  - Trade Names — `items.trade_name_1`, `items.trade_name_2`
  - Batch Number — `batches.batch_number`
  - Expiry — `batches.expiry_date`, `(item_id, expiry_date)`
  - Item ID — all `item_id` FKs on `batches`, `stock_movements`, `sales_invoice_items`, `purchase_invoice_items`
  - Supplier ID — `batches.supplier_id`, `purchase_invoices.supplier_id`
  - Invoice Number — `sales_invoices.invoice_number`, `purchase_invoices.purchase_number`
  - Invoice Date — `sales_invoices.date`, `purchase_invoices.date`

**Barcode lookup must be very fast:** unique index on `primary_barcode`, indexed `secondary_barcode`, normalized input (§20), single-row `WHERE primary_barcode = ? OR secondary_barcode = ?`.

---

## 28. Soft Deletion & Historical Integrity

- **Never physically delete** transactional/financial/history records:
  - Invoices (`sales_invoices`, `purchase_invoices` — `status='voided'` instead)
  - Return documents
  - Stock movements (append-only ledger)
  - Journal entries / lines
  - Audit logs (immutable)
  - Purchase bonuses (part of the purchase record)
  - Lost sales (retained; status-based)
- **Master data** uses **soft-delete flags**: `is_active = 0` (Optionally a `deleted_at` timestamp may be added later for audit; not required in Phase 1.)
- **Historical validity:** invoices remain valid even if an item is later deactivated — lines snapshot item id + prices + batch cost at transaction time.

---

## 29. Migration Strategy

- **Drift schema versioning** — `schemaVersion` increments for every schema change.
- Forward-only migrations in `MigrationStrategy.onUpgrade`.
- **Deleting the database to apply migrations is forbidden.**
- New columns are added **nullable or with safe defaults** so existing rows are preserved.
- New tables are added idempotently within a version bump.
- Migration coverage: `migration_test.dart` builds the DB at version N, runs the upgrade to N+1, and asserts schema + data integrity.
- Restore validates the schema version and applies pending forward migrations (§37).

---

## 30. Performance Requirements

Must support production scale:
- **Tens of thousands of products**
- **Large invoice history**
- **Many stock movements**
- **Thousands of batches**
- **Fast barcode lookup**

**Loading the whole database into memory is forbidden.**
- **Pagination** (LIMIT/OFFSET or keyset) on all grids.
- **Filtering** done in the database layer (indexed WHERE), not in Dart.
- **Indexed queries** per §27.
- **Efficient reactive queries** (Drift `watch` on filtered/paginated DAOs).
- `current_stock_base` cache avoids full-ledger scans; a reconciliation job re-syncs from the ledger in batches.

---

## 31. Testing Strategy

| Level | Scope | Tools | Coverage |
|-------|-------|-------|----------|
| Unit | Entities, use cases, **Money**, base-unit conversions, FEFO, bonus engine, hybrid returns, RBAC, validators | `test` + `mocktail`/`mockito` | 80%+ |
| Widget | Cart, data grid, forms, POS workspace, RTL rendering | `flutter_test` | Critical paths |
| Integration | login→sale→return; purchase→batch→sale; trial balance accuracy | `integration_test` | Critical flows |
| Database | DAOs, migrations, transactional rollback, integrity constraints, barcode lookup speed | `drift` test utils | All DAOs + migrations |

**Critical scenarios:** Money arithmetic (no drift), FEFO + expired exclusion, bonus effective cost, hybrid returns (signed lines, original-batch restore), base-unit conversions, RBAC enforcement, atomic rollback.

---

## 32. Security Considerations

- **Passwords:** bcrypt-hashed; never plain text.
- **RBAC:** granular permissions enforced in domain use cases + UI (§16).
- **Audit:** immutable audit log for sensitive operations (§17).
- **Local-only:** no network in Phase 1; transport security N/A. Hashes never synced insecurely.
- **Sensitive gates:** void, price change, purchase-cost change, stock adjustment, backup/restore require elevated permissions + audit reason.
- **Selling rules:** `is_controlled_drug` / `requires_prescription` enforced at sale time.

---

## 33. Responsive & Desktop / Android UI

- `LayoutBuilder` + adaptive widgets, RTL-aware.
- Desktop wide ≥ 900px: sidebar + content; 600–899px: collapsed sidebar; mobile < 600px: bottom nav / drawer.
- POS: desktop 3-panel (items | cart | payment); tablet 2-panel; mobile tab-based.
- Data tables → cards on narrow screens; dialogs → full-screen on mobile.

---

## 34. Localization & RTL Engineering

- `flutter_localizations` + `intl` + ARB; `flutter gen-l10n`.
- **`app_ar.arb` is the default locale** (Arabic); `app_en.arb` secondary.
- RTL is default; all directional APIs used; tested in both RTL and LTR.
- Font: **Cairo or Tajawal**, chosen once, applied uniformly.
- Terminology follows the §24 glossary via a centralized string catalog.

---

## 35. State Management & DI

- **Riverpod v2+** with code generation; family providers per POS workspace tab.
- **get_it + injectable** DI: Database, repositories, use cases, domain services (FEFO, Bonus, Alternatives, Money), core services (ShortcutManager, ScannerService, AuditService, BackupService, PdfService, ExcelService).
- Provider chain: DatabaseProvider → repositories → use cases → page notifiers → POS tab families.

> **Phase 2 status (implemented):** `get_it` (manual, no `injectable`) registers the auth/user graph (UserDao, AuthRepository, per-action use cases, AuthController, UsersViewController); Riverpod `StateNotifierProvider`s (`authControllerProvider`, `usersViewControllerProvider`) wrap the singletons so widgets stay provider-reactive while state stays in controllers.

---

## 36. Navigation

- **GoRouter** with a `ShellRoute` (sidebar) and an auth-guard `redirect`.
- POS route = full-width workspace (10 customers + return tabs) inside the shell.
- Named type-safe routes; Arabic-first direction on all screens; correct back/forward on Windows and Android.

> **Phase 2 status (implemented):** GoRouter v14 with an auth-aware `redirect`, `/login` + `/access-denied` routes, a single `ShellRoute` hosting one route per `AppSection` (real UsersPage + placeholders), and a refresh `Listenable` bridged from the AuthController stream. Unauthenticated → `/login`; authenticated hitting `/login` → `/`; `/users` without `users.view` → `/access-denied`.

---

## 37. Backup & Restore

**Mechanism:** direct SQLite file copy, optionally compressed (`.zip` via `archive`), user-initiated from Settings.

- **Backup:** copy `.db` to user-selected directory; filename `pharmacy_backup_YYYYMMDD_HHmmss.db`; JSON metadata (timestamp, app version, schema version).
- **Restore:** select file → validate integrity + schema version → warn → close DB → replace → reopen → apply pending migrations → audit-log the restore.
- **Auto-backup:** optional daily backup, configurable in settings.
- Designed so that **future synchronization** can be layered on without database redesign (all entity ids are stable UUIDs; timestamps UTC).

---

## 38. Git / GitHub Workflow

```
main          ← production-ready, tagged, protected
  └─ develop  ← integration
       ├─ feature/*
       ├─ bugfix/*
       └─ release/v*
```

- PRs required; Conventional Commits (`feat:`, `fix:`, `docs:`, `test:`, `chore:`, `refactor:`); no direct pushes to `main`; tags for releases.
- GitHub Actions: analyze + test + build Windows + build Android on every PR and on release tags.

---

## 39. Windows Build Strategy

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

Build targets: Windows release / debug; Android APK. Windows-specific: icon in `windows/runner/.rc`, window title in `main.cpp`, minimum Windows 10.

---

## 40. Phase 1 Deliverables

Phase 1 = **Foundation + complete corrected Database model + core master-data repositories.**

### Scope
- Project scaffolding, folder structure.
- Complete Drift schema for **all** tables in §4 (items with every field, units/item_units, batches, categories/sub_categories, therapeutic_groups, manufacturers, suppliers, customers, prescriptions, sales_invoices/items, purchase_invoices/items, purchase_bonuses, returns/items, stock_movements, expenses, cashbox, accounts, journal_entries/lines, users/roles/permissions/role_permissions, audit_logs, lost_sales).
- `Money` type (§23) + base-unit conversion service (§7) + validation/error handling.
- Arabic-first localization scaffold + Cairo/Tajawal + RTL theme (§24, §34).
- RBAC seed roles/permissions (§16); audit service (§17).
- Backup metadata layout + migration framework (§29, §37).
- DAOs/repositories for Items, Units, Batches, StockMovements, Categories/SubCategories, Manufacturers, TherapeuticGroups (§4).
- Data-grid scaffolding (sort/filter/pagination) (§22).
- Unit tests: Money, base units, FEFO, bonus engine, migration foundation (§31).
- GitHub Actions workflow (§39).

### Explicitly NOT in Phase 1
Full POS workspaces UI, full accounting UI, smart-alternatives UI, scanner hardware wiring, lost-sales capture UI, hybrid-return UI — designed here, delivered in later phases.

---

## 41. Future Implementation Roadmap

> Phase numbering follows delivery order. **Phase 2 (Authentication & Users) shipped ahead of the UI roadmap below** because every subsequent module runs inside the authenticated shell. Auth/user roadmap items below that are already delivered are marked *(delivered in Phase 2)*.

- **Phase 2 (delivered) — Authentication & Users:** in-memory session, login/logout, bcrypt, granular RBAC, admin Users module (create/edit/deactivate/reactivate/change password, search + pagination, desktop table + compact cards), login scaffold, user + audit seeding, auth/use-case/controller/widget tests.
- **Phase 3 (delivered) — Items & Inventory:** complete item form (all identification/pharma/flags/units/pricing/stock fields), category/sub-category/manufacturer/therapeutic-group management, batch entry (manual → `stock_adjustment` ledger op), stock adjustment UI (increase/decrease), expiry/low-stock alerts (status chips), Excel import/export (round-trip), bulk grid edits (§22), inventory + master-data pages/tabs, use-case + repository + Excel tests.
- **Phase 4 (delivered) — Suppliers & Purchases:** supplier CRUD + كشف حساب (statements with running balances), derived supplier balances; purchase invoices (pending → receive with batch number/expiry entry); bonus engine (bonus_1/bonus_2/gift, Buy A Get B); purchase returns; cancel-void of pending invoices; purchase/suppliers permissions + audit; see `PHASE4-REPORT.md`.
- **Phase 5 (delivered) — Customers & Prescriptions:** customer/patient CRUD + statements (كشف حساب العميل with running balances), derived customer balances; prescriptions with item lines (create + detail), unique `RX-` numbers, stock-quantity validation; "prepare prescription for sale" snapshot that hands Phase 6 a customer + line list to attach; `prescriptions.view/create` + `customers.view/create/edit` permissions and audit; see `PHASE5-REPORT.md`.
- **Phase 6 — POS core:** scanner service; 10-customer + return workspace; FEFO cart; cash/card/mixed payment; receipt PDF; hold bill; Z-report; smart alternatives UI; lost-sales quick capture.
- **Phase 7 — Invoices & Returns:** invoice list/view/void/PDF; hybrid returns UI (signed lines); transactional reversals.
- **Phase 8 — Cash Box:** open/close, deposits/withdrawals, auto entries, day-end reconciliation.
- **Phase 9 — Expenses:** CRUD + categories + receipts.
- **Phase 10 — Accounting:** chart of accounts UI, manual journal entries, auto-posting, period close.
- **Phase 11 — Reports:** Trial Balance, Income Statement, Balance Sheet, Account Statements, sales/inventory/purchase reports, lost-sales reports, PDF + Excel export, date filters, supplier/customer statements.
- **Phase 12 — Audit log & Settings:** audit viewer, app settings (business name, tax, currency), user/role/permission management UI.
- **Phase 13 — Backup/Restore & Export:** full backup/restore UI, auto-backup, PDF/Excel export everywhere.
- **Phase 14 — Polish & Hardening:** RTL QA, responsive polish, shortcuts, performance, accessibility.
- **Phase 15 — Testing & CI/CD:** coverage thresholds, integration suite, release pipelines.
- **Phase 16 — Release:** installer (Inno Setup/MSIX), icons/splash, docs, tag `v1.0.0`, GitHub Release artifacts.
- **Phase 18 (delivered) — Product Master Contract & Import Readiness:** schema v12 (dropped `sub_categories` + `therapeutic_groups`, nullable `category_id`), simplified product contract (trade name required; units/parts/category optional), relational active-ingredient + indication joins surfaced on product views, searchable multi-row ingredient selector, relational Smart Alternatives with flat-token fallback, minimal-row Excel import with trade-name matching and `name:strength` ingredient parsing, and targeted (non-generic) save error mapping. Full detail in `PHASE18-PRODUCT-MASTER-CONTRACT-IMPORT-READINESS-COMPLETION-REPORT.md`.
- **Phase 18.1 (delivered) — Product Master Contract Corrections & Syrian DB Import Gate:** hardens the trade-name-only contract end-to-end (product form saves with trade name alone; parts/packaging validations only fire when a unit relation is configured; units always stored as a consistent base+large relation; active-ingredient summary clears when its relational ingredients are removed), the Excel contract adds the `المكافئ / الشكل الصيدلاني / الجرعة / العيار / الحجم` columns (indices 23–26, appended for positional backward-compat) and turns every optional cell into blank-preserves-on-update (financial fields, VAT, min/max, shelf location, barcodes, has-expiry, ingredients/indications, unit relation, EN/scientific/flat ingredient, plus non-sheet fields such as flags, custom prices and partial-sale config so export→import is lossless), Smart Alternatives rank by tier → stock → **same manufacturer** → trade name and the flat-token fallback now only applies to legacy items with no relational ingredients, and the filler terminology uses «الكمية» instead of «الوحدات الأساسية» (`prescriptionQuantity`). Deep-dive in `PHASE18.1-PRODUCT-MASTER-CONTRACT-CORRECTIONS-COMPLETION-REPORT.md`. The step that follows this milestone (importing the Syrian medicine database (~14 000 rows)) is **not part of Phase 18.1** and is gated on this report's DoD.
- **Phase 18.2A (delivered) — Product Master Contract Closure & Scalable Import Engine:** closes the import-gate contract and removes every scaling hazard for the ~14 000-row Syrian catalog. Product master contract closed (trade name required, everything else optional, parts/packaging relations never erased by a blank edit, prices/cost never an import condition, each active ingredient stays paired with its strength). Excel/import matching is now **deterministic and safe** — barcode-exact first, then a composite identity (ingredients+strengths, form, dose, manufacturer) that must match a candidate exactly, ambiguity surfaces as a conflict instead of a guess, an unmatched barcode creates (never a fuzzy edit and never a synthesised source-id barcode), and `package_shape`/units are excluded from identity. **Scalability:** catalog loaded once per operation plus bulk relational projections (`allItems()`, `itemUnitsForItems`, `activeIngredientRelationsForItems`, `indicationIdsForItems`), in-memory barcode/name/composite indexes, no `pageSize: 10000`, no per-row catalog scan (`searchItems`/`_findByScanned` removed from the pipeline), periodic event-loop yields, and in-file duplicate targeting rejected. `InventoryViewBuilder.buildMany` is bulk (one round trip per page for categories/manufacturers/units/ingredients/indications). Verified by `test/inventory_import_scalability_test.dart` (14 001-row round-trip, no-scan proof via call-counting repository wrapper, duplicate-name disambiguation, ambiguous conflict, non-identity of package_shape/units, in-file dedupe, re-import-no-duplicate) with the Excel contract A–G suite still green. Deep-dive in `PHASE18.2A-PRODUCT-MASTER-IMPORT-SCALABILITY-COMPLETION-REPORT.md`. **The Syrian medicine database import is still NOT started** — it proceeds only as a separately-scoped follow-up.

---

## 42. Requirements Coverage Checklist

> Every requirement from the original specification and this review brief. No requirement is `Missing`.

| Requirement | Covered? | Where | Notes |
|-------------|----------|-------|-------|
| Items full model (all identifiers/pharma/flags/units/stock/pricing fields) | ✅ | §4.7, §5 | Every field explicit column; manufacturer/category/therapeutic group are FKs to independent tables |
| Units / Base Unit model — TotalBaseUnits authoritative | ✅ | §7 | Single base-unit quantity; derived display; no conflicting boxes+strips fields |
| Batches table (complete) | ✅ | §4.8, §6 | FEFO, expired exclusion, historical cost, batch returns, supplier/bonus |
| Pricing & historical cost separation | ✅ | §8 | Master/default vs batch historical; no overwrite of history |
| Stock Movement Ledger | ✅ | §4.9, §10 | 10 movement types; ledger authoritative; derived caches declared |
| Purchase Invoices (+ items + bonuses) | ✅ | §4.16–4.18, §12 | All required invoice/item fields; explicit `purchase_bonuses` table |
| Purchase Bonus Engine (Bonus1/Bonus2/Gift, effective qty & cost) | ✅ | §4.18, §13 | 100+10+5+2=117; effective unit cost; Buy A Get B supported |
| Sales Invoices & items (batch-linked) | ✅ | §4.14–4.15, §11 | Invoice/lines include all required fields; linked to FEFO batch |
| Hybrid Returns (signed quantities, original refs, transactional reversal) | ✅ | §4.15, §4.19, §14 | A+2/B+1/C−1; original invoice/item/batch; restore original batch only |
| Lost Sales / النواقص | ✅ | §4.28, §15 | All required fields; status lifecycle; purchase reports |
| Smart Alternatives (Green/Yellow/Blue, UI-independent) | ✅ | §18 | Dynamic computation; extensible |
| Suppliers full fields | ✅ | §4.10 | Phone, secondary phone, tax/VAT, license, opening balance, notes, active |
| Customers full fields; cash sale without customer | ✅ | §4.11 | `customer_id` nullable for walk-in cash |
| Users/Roles/Permissions/RolePermissions granular | ✅ | §4.26, §16 | Admin/Pharmacist/Cashier reference matrix; extensible |
| Immutable Audit Log with required operations/fields | ✅ | §4.27, §17 | Append-only; old/new/reason/date |
| POS Workspace 10 customers + Return, per-tab state, Riverpod | ✅ | §19 | Independent cart/customer/payment/pending state |
| Barcode Scanner pipeline (buffer→completion→normalize→query→item→FEFO→cart) | ✅ | §20 | Independent of focused field; no shortcut conflict |
| Keyboard shortcuts (F1/F2/F5/F12/Space·Enter/Alt+S), centralized/configurable | ✅ | §21 | |
| Data grids (sort/filter/multi-column/visibility/order/inline/multi-select/bulk/keyboard) | ✅ | §22 | Inline edits via business logic+transaction+audit |
| Bulk operations (shelf location, category, price by %) transactional + audited | ✅ | §22 | No partial/inconsistent updates |
| Expiry/visual status (Expired/Near/Low/Normal) with text+icon+indicator | ✅ | §24 | Not color-only |
| Database integrity (FK/unique/NOT NULL/CHECK/RI/indexes/cascades/no orphans) | ✅ | §27 | Explicit minimum index list; fast barcode lookup |
| Transactions (sale/purchase/return/adjustment/bulk atomic flows) | ✅ | §26 | Full rollback on any failure |
| Money / Financial precision — no REAL; integer units; USD configurable | ✅ | §23 | Applied to costs/prices/discounts/taxes/totals/profit/balances/cashbox/accounting |
| Soft delete & historical preservation | ✅ | §28 | Financial/history never physically deleted; master uses is_active |
| Migration strategy (Drift versioning, no DB deletion) | ✅ | §29 | Forward migrations; safe defaults; tests |
| Performance (10k+ products, large history, pagination, indexed, no full load) | ✅ | §30 | |
| Arabic-first professional UI (mandatory) + glossary + Cairo/Tajawal + RTL default | ✅ | §24, §34 | English secondary only; glossary table present |
| Offline-First — SQLite source of truth; future backup/restore/sync without redesign | ✅ | §3, §30, §37 | |
| Future Accounting Foundation (cash box, reports, balances, financial statements, employee/doctor revenue) | ✅ | §25 | DB model supports double-entry; UI deferred |
| Required Architecture Tables map | ✅ | §4.29 | All listed entities present with purpose |
| Technology & delivery (Flutter, Material 3, Windows primary, Android dev, offline, CI, Windows EXE) | ✅ | §2, §39 | |
| Phase 1 scope explicitly defined | ✅ | §40 | |
| Requirements Coverage Checklist present | ✅ | §42 | This table |

**Result:** every original requirement is **✅ Covered**. No unresolved or missing requirements.

---

*End of the final specification. This document is the authoritative blueprint for implementing the Pharmacy Management & POS system.*