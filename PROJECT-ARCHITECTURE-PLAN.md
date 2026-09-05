# Pharmacy Management & POS System — Architecture & Roadmap

## 1. Overall Architecture

**Pattern:** Clean Architecture (3-layer) with Feature-Based Modular Structure

```
┌─────────────────────────────────────────────────────┐
│                   Presentation                       │
│  (Pages, Widgets, Controllers/Blocs, Themes)         │
├─────────────────────────────────────────────────────┤
│                   Domain                             │
│  (Entities, Use Cases, Repository Interfaces)        │
├─────────────────────────────────────────────────────┤
│                   Data                               │
│  (Repository Implementations, Data Sources,          │
│   Models, DTOs, SQLite/Drift, File System)           │
├─────────────────────────────────────────────────────┤
│                Core / Shared                         │
│  (Utils, Constants, Di, Localization, Theme,         │
│   Networking, Error Handling, Validators)             │
└─────────────────────────────────────────────────────┘
```

**Key Principles:**
- Domain layer has **zero** Flutter/framework dependencies
- Data layer depends on packages (Drift, file system) but not on Flutter widgets
- Presentation layer depends on Flutter + Domain
- Cross-cutting concerns (logging, error handling, DI) live in `core/`
- All business logic is platform-agnostic — identical code runs on Windows and Android

**Offline-First Strategy:**
- All data lives in local SQLite (Drift) — no server required for core functionality
- No REST/GraphQL API in initial phases (can be added later as an optional sync layer)
- All CRUD, reports, and POS operations work fully offline
- Backup/restore operates on local files

---

## 2. Complete Folder Structure

```
lib/
├── main.dart                          # App entry point
├── app.dart                           # MaterialApp, theme, routing, localization
│
├── core/
│   ├── constants/
│   │   ├── app_constants.dart
│   │   ├── database_constants.dart
│   │   └── ui_constants.dart
│   ├── errors/
│   │   ├── exceptions.dart
│   │   ├── failures.dart
│   │   └── error_handler.dart
│   ├── utils/
│   │   ├── id_generator.dart
│   │   ├── date_utils.dart
│   │   ├── currency_utils.dart
│   │   ├── validation_utils.dart
│   │   ├── pdf_utils.dart
│   │   ├── excel_utils.dart
│   │   ├── file_utils.dart
│   │   └── backup_utils.dart
│   ├── di/
│   │   └── dependency_injection.dart
│   ├── l10n/
│   │   ├── app_ar.arb
│   │   ├── app_en.arb
│   │   └── l10n.dart                 # Generated localization
│   ├── theme/
│   │   ├── app_theme.dart
│   │   ├── app_colors.dart
│   │   └── app_text_styles.dart
│   ├── router/
│   │   └── app_router.dart
│   ├── widgets/                      # Shared/reusable widgets
│   │   ├── app_drawer.dart
│   │   ├── app_data_table.dart
│   │   ├── confirm_dialog.dart
│   │   ├── loading_overlay.dart
│   │   ├── search_field.dart
│   │   ├── amount_field.dart
│   │   └── responsive_layout.dart
│   └── extensions/
│       ├── string_extensions.dart
│       ├── num_extensions.dart
│       └── context_extensions.dart
│
├── features/
│   ├── auth/
│   │   ├── data/
│   │   │   ├── datasources/
│   │   │   │   └── auth_local_datasource.dart
│   │   │   ├── models/
│   │   │   │   └── user_model.dart
│   │   │   └── repositories/
│   │   │       └── auth_repository_impl.dart
│   │   ├── domain/
│   │   │   ├── entities/
│   │   │   │   └── user.dart
│   │   │   ├── repositories/
│   │   │   │   └── auth_repository.dart
│   │   │   └── usecases/
│   │   │       ├── login.dart
│   │   │       ├── logout.dart
│   │   │       ├── create_user.dart
│   │   │       └── manage_roles.dart
│   │   └── presentation/
│   │       ├── providers/
│   │       ├── pages/
│   │       │   ├── login_page.dart
│   │       │   └── users_management_page.dart
│   │       └── widgets/
│   │           ├── login_form.dart
│   │           └── user_form_dialog.dart
│   │
│   ├── pos/                          # Point of Sale
│   │   ├── data/
│   │   ├── domain/
│   │   └── presentation/
│   │
│   ├── inventory/                    # Medicine & Stock
│   │   ├── data/
│   │   ├── domain/
│   │   └── presentation/
│   │
│   ├── purchases/                    # Purchase Orders
│   │   ├── data/
│   │   ├── domain/
│   │   └── presentation/
│   │
│   ├── suppliers/
│   │   ├── data/
│   │   ├── domain/
│   │   └── presentation/
│   │
│   ├── customers/                    # Customers & Patients
│   │   ├── data/
│   │   ├── domain/
│   │   └── presentation/
│   │
│   ├── prescriptions/
│   │   ├── data/
│   │   ├── domain/
│   │   └── presentation/
│   │
│   ├── invoices/
│   │   ├── data/
│   │   ├── domain/
│   │   └── presentation/
│   │
│   ├── expenses/
│   │   ├── data/
│   │   ├── domain/
│   │   └── presentation/
│   │
│   ├── cashbox/
│   │   ├── data/
│   │   ├── domain/
│   │   └── presentation/
│   │
│   ├── accounting/                   # Chart of Accounts, Journal Entries
│   │   ├── data/
│   │   ├── domain/
│   │   └── presentation/
│   │
│   ├── reports/                      # Trial Balance, Income Statement, etc.
│   │   ├── data/
│   │   ├── domain/
│   │   └── presentation/
│   │
│   ├── audit_log/
│   │   ├── data/
│   │   ├── domain/
│   │   └── presentation/
│   │
│   └── settings/                     # Backup, Restore, App Settings
│       ├── data/
│       ├── domain/
│       └── presentation/
│
└── shared/                           # Cross-feature shared models/repos
    ├── database/
    │   ├── app_database.dart          # Drift database definition
    │   ├── app_database.g.dart
    │   ├── tables/
    │   │   ├── users_table.dart
    │   │   ├── medicines_table.dart
    │   │   ├── categories_table.dart
    │   │   ├── suppliers_table.dart
    │   │   ├── customers_table.dart
    │   │   ├── prescriptions_table.dart
    │   │   ├── prescription_items_table.dart
    │   │   ├── sales_table.dart
    │   │   ├── sale_items_table.dart
    │   │   ├── purchases_table.dart
    │   │   ├── purchase_items_table.dart
    │   │   ├── expenses_table.dart
    │   │   ├── cashbox_transactions_table.dart
    │   │   ├── accounts_table.dart
    │   │   ├── journal_entries_table.dart
    │   │   ├── journal_entry_lines_table.dart
    │   │   └── audit_log_table.dart
    │   ├── daos/                     # Drift DAOs (query logic)
    │   └── migrations/
    │       └── migration_strategy.dart
    └── models/                       # Shared enums, value objects
        ├── enums.dart
        └── money.dart

test/
├── unit/
│   ├── features/
│   │   ├── auth/
│   │   ├── pos/
│   │   ├── inventory/
│   │   └── ...
│   └── core/
├── widget/
│   └── ...
├── integration/
│   └── ...
└── fixtures/                         # Test data
    └── test_data.dart

assets/
├── images/
├── fonts/
└── icons/

.github/
└── workflows/
    └── build_windows.yml

windows/                              # Flutter Windows runner
android/                              # Flutter Android runner
```

---

## 3. Feature/Module Structure

Each feature follows the same internal Clean Architecture pattern:

```
feature/
├── data/
│   ├── datasources/     # Local data source (Drift DAOs, file access)
│   ├── models/          # Data models (extends Domain entities, adds serialization)
│   └── repositories/    # Implements Domain repository interface
├── domain/
│   ├── entities/        # Pure Dart classes (no framework deps)
│   ├── repositories/    # Abstract interfaces
│   └── usecases/        # Business logic (one class per use case)
└── presentation/
    ├── providers/       # State management (Riverpod providers)
    ├── pages/           # Full-screen page widgets
    └── widgets/         # Feature-specific reusable widgets
```

**Feature Dependency Rule:** Features may depend on `core/` and `shared/` but never on each other directly. Cross-feature communication uses domain events or shared entities through `shared/`.

### Feature Map

| Feature | Key Entities | Key Use Cases |
|---------|-------------|---------------|
| **auth** | User, Role, Permission | Login, Logout, CRUD Users, Manage Roles |
| **pos** | Cart, CartItem, Sale | CreateSale, ApplyDiscount, ProcessPayment, DailyClose |
| **inventory** | Medicine, Category, StockMovement | CRUD Medicine, AdjustStock, CheckLowStock, ExpiryAlerts |
| **purchases** | PurchaseOrder, PurchaseItem | CreatePO, ReceivePO, ReturnToSupplier |
| **suppliers** | Supplier | CRUD Suppliers, SupplierStatement |
| **customers** | Customer, Patient | CRUD Customers, CustomerStatement |
| **prescriptions** | Prescription, PrescriptionItem | CreatePrescription, LinkToSale |
| **invoices** | Invoice, InvoiceItem | GenerateInvoice, VoidInvoice, PDFExport |
| **expenses** | Expense, ExpenseCategory | CRUD Expenses, Categorize |
| **cashbox** | CashboxTransaction | OpenDrawer, Deposit, Withdraw, CloseDay |
| **accounting** | Account, JournalEntry, JournalLine | PostEntry, ClosePeriod, ChartOfAccounts |
| **reports** | (various report models) | TrialBalance, IncomeStatement, BalanceSheet, AccountStatement |
| **audit_log** | AuditEntry | LogAction, ViewAuditTrail |
| **settings** | AppSettings, BackupRecord | Backup, Restore, AppPreferences |

---

## 4. Database Schema & Relationships

### Entity-Relationship Overview

```
Users ─────────────────────────────────────────────────┐
  │ (created_by)                                        │
  ├── Sales ──────── SaleItems ──── Medicines ──── Categories
  │    │                              │
  │    └── Invoices                   └── StockMovements
  │
  ├── Purchases ──── PurchaseItems ── Medicines
  │    │
  │    └── Suppliers
  │
  ├── Prescriptions ── PrescriptionItems ── Medicines
  │    │
  │    └── Customers
  │
  ├── Expenses
  │
  ├── CashboxTransactions
  │
  ├── JournalEntries ── JournalEntryLines ── Accounts
  │
  └── AuditLog

Accounts ──(self-referencing parent)── Accounts
```

### Detailed Table Schemas

#### `users`
| Column | Type | Notes |
|--------|------|-------|
| id | TEXT PK | UUID |
| username | TEXT UNIQUE | |
| password_hash | TEXT | bcrypt hash |
| full_name | TEXT | |
| role | TEXT | 'admin', 'pharmacist', 'cashier', 'accountant' |
| is_active | INTEGER | boolean |
| created_at | INTEGER | timestamp |
| updated_at | INTEGER | timestamp |

#### `categories`
| Column | Type | Notes |
|--------|------|-------|
| id | TEXT PK | UUID |
| name | TEXT | |
| name_en | TEXT | |
| description | TEXT | nullable |
| parent_id | TEXT FK | self-referencing, nullable |
| created_at | INTEGER | |

#### `medicines`
| Column | Type | Notes |
|--------|------|-------|
| id | TEXT PK | UUID |
| name | TEXT | |
| name_en | TEXT | |
| barcode | TEXT | nullable, indexed |
| category_id | TEXT FK | → categories |
| supplier_id | TEXT FK | → suppliers, nullable |
| cost_price | REAL | |
| selling_price | REAL | |
| current_stock | INTEGER | computed or cached |
| minimum_stock | INTEGER | reorder threshold |
| expiry_date | INTEGER | nullable, timestamp |
| requires_prescription | INTEGER | boolean |
| is_active | INTEGER | boolean |
| created_at | INTEGER | |
| updated_at | INTEGER | |

#### `stock_movements`
| Column | Type | Notes |
|--------|------|-------|
| id | TEXT PK | UUID |
| medicine_id | TEXT FK | → medicines |
| type | TEXT | 'purchase', 'sale', 'adjustment', 'return' |
| quantity | INTEGER | positive or negative |
| reference_id | TEXT | sale_id or purchase_id |
| reference_type | TEXT | 'sale' or 'purchase' |
| note | TEXT | nullable |
| created_by | TEXT FK | → users |
| created_at | INTEGER | |

#### `suppliers`
| Column | Type | Notes |
|--------|------|-------|
| id | TEXT PK | UUID |
| name | TEXT | |
| contact_person | TEXT | nullable |
| phone | TEXT | nullable |
| email | TEXT | nullable |
| address | TEXT | nullable |
| tax_number | TEXT | nullable |
| balance | REAL | running balance |
| is_active | INTEGER | boolean |
| created_at | INTEGER | |
| updated_at | INTEGER | |

#### `customers`
| Column | Type | Notes |
|--------|------|-------|
| id | TEXT PK | UUID |
| name | TEXT | |
| phone | TEXT | nullable |
| email | TEXT | nullable |
| date_of_birth | INTEGER | nullable |
| gender | TEXT | nullable |
| address | TEXT | nullable |
| medical_history | TEXT | nullable |
| balance | REAL | running balance |
| is_active | INTEGER | boolean |
| created_at | INTEGER | |
| updated_at | INTEGER | |

#### `prescriptions`
| Column | Type | Notes |
|--------|------|-------|
| id | TEXT PK | UUID |
| customer_id | TEXT FK | → customers |
| doctor_name | TEXT | |
| notes | TEXT | nullable |
| image_path | TEXT | nullable, scanned image |
| created_by | TEXT FK | → users |
| created_at | INTEGER | |

#### `prescription_items`
| Column | Type | Notes |
|--------|------|-------|
| id | TEXT PK | UUID |
| prescription_id | TEXT FK | → prescriptions |
| medicine_id | TEXT FK | → medicines |
| quantity | INTEGER | |
| dosage | TEXT | |
| frequency | TEXT | |

#### `sales`
| Column | Type | Notes |
|--------|------|-------|
| id | TEXT PK | UUID |
| invoice_number | TEXT UNIQUE | auto-generated |
| customer_id | TEXT FK | → customers, nullable |
| user_id | TEXT FK | → users (cashier) |
| subtotal | REAL | |
| discount_amount | REAL | |
| tax_amount | REAL | |
| total | REAL | |
| payment_method | TEXT | 'cash', 'card', 'mixed' |
| amount_paid | REAL | |
| change_amount | REAL | |
| status | TEXT | 'completed', 'voided', 'returned' |
| created_at | INTEGER | |

#### `sale_items`
| Column | Type | Notes |
|--------|------|-------|
| id | TEXT PK | UUID |
| sale_id | TEXT FK | → sales |
| medicine_id | TEXT FK | → medicines |
| quantity | INTEGER | |
| unit_price | REAL | |
| discount | REAL | |
| total | REAL | |

#### `purchases`
| Column | Type | Notes |
|--------|------|-------|
| id | TEXT PK | UUID |
| order_number | TEXT UNIQUE | auto-generated |
| supplier_id | TEXT FK | → suppliers |
| user_id | TEXT FK | → users |
| subtotal | REAL | |
| tax_amount | REAL | |
| total | REAL | |
| status | TEXT | 'pending', 'received', 'cancelled' |
| expected_date | INTEGER | nullable |
| received_date | INTEGER | nullable |
| created_at | INTEGER | |

#### `purchase_items`
| Column | Type | Notes |
|--------|------|-------|
| id | TEXT PK | UUID |
| purchase_id | TEXT FK | → purchases |
| medicine_id | TEXT FK | → medicines |
| quantity | INTEGER | |
| received_quantity | INTEGER | |
| unit_cost | REAL | |
| total | REAL | |

#### `expenses`
| Column | Type | Notes |
|--------|------|-------|
| id | TEXT PK | UUID |
| category | TEXT | 'rent', 'utilities', 'salaries', 'other' |
| description | TEXT | |
| amount | REAL | |
| receipt_path | TEXT | nullable |
| created_by | TEXT FK | → users |
| created_at | INTEGER | |

#### `cashbox_transactions`
| Column | Type | Notes |
|--------|------|-------|
| id | TEXT PK | UUID |
| type | TEXT | 'open', 'close', 'deposit', 'withdraw', 'sale', 'expense' |
| amount | REAL | |
| reference_id | TEXT | nullable |
| reference_type | TEXT | nullable |
| note | TEXT | nullable |
| user_id | TEXT FK | → users |
| created_at | INTEGER | |

#### `accounts` (Chart of Accounts)
| Column | Type | Notes |
|--------|------|-------|
| id | TEXT PK | UUID |
| code | TEXT UNIQUE | e.g. '1000', '1100', '2000' |
| name | TEXT | |
| name_en | TEXT | |
| type | TEXT | 'asset', 'liability', 'equity', 'revenue', 'expense' |
| parent_id | TEXT FK | self-referencing, nullable |
| is_active | INTEGER | boolean |
| created_at | INTEGER | |

#### `journal_entries`
| Column | Type | Notes |
|--------|------|-------|
| id | TEXT PK | UUID |
| entry_number | TEXT UNIQUE | auto-generated |
| date | INTEGER | timestamp |
| description | TEXT | |
| reference_type | TEXT | 'sale', 'purchase', 'expense', 'manual' |
| reference_id | TEXT | nullable |
| is_posted | INTEGER | boolean |
| created_by | TEXT FK | → users |
| created_at | INTEGER | |

#### `journal_entry_lines`
| Column | Type | Notes |
|--------|------|-------|
| id | TEXT PK | UUID |
| journal_entry_id | TEXT FK | → journal_entries |
| account_id | TEXT FK | → accounts |
| debit | REAL | |
| credit | REAL | |

#### `audit_log`
| Column | Type | Notes |
|--------|------|-------|
| id | TEXT PK | UUID |
| user_id | TEXT FK | → users |
| action | TEXT | 'create', 'update', 'delete', 'login', 'logout' |
| entity_type | TEXT | 'medicine', 'sale', etc. |
| entity_id | TEXT | |
| old_value | TEXT | JSON, nullable |
| new_value | TEXT | JSON, nullable |
| ip_address | TEXT | nullable |
| created_at | INTEGER | |

---

## 5. Main Entities/Models

**Domain entities** are pure Dart classes (immutable, no framework dependencies):

```dart
// Example pattern (not actual code, just structure):
class Medicine {
  final String id;
  final String name;
  final String? nameEn;
  final String? barcode;
  final String categoryId;
  final String? supplierId;
  final double costPrice;
  final double sellingPrice;
  final int currentStock;
  final int minimumStock;
  final DateTime? expiryDate;
  final bool requiresPrescription;
  final bool isActive;
  final DateTime createdAt;
  final DateTime updatedAt;
}

class Sale {
  final String id;
  final String invoiceNumber;
  final String? customerId;
  final String userId;
  final double subtotal;
  final double discountAmount;
  final double taxAmount;
  final double total;
  final PaymentMethod paymentMethod;
  final double amountPaid;
  final double changeAmount;
  final SaleStatus status;
  final DateTime createdAt;
  final List<SaleItem> items;
}
```

**Enums** defined in `shared/models/enums.dart`:
- `UserRole`: admin, pharmacist, cashier, accountant
- `PaymentMethod`: cash, card, mixed
- `SaleStatus`: completed, voided, returned
- `PurchaseOrderStatus`: pending, received, cancelled
- `AccountType`: asset, liability, equity, revenue, expense
- `StockMovementType`: purchase, sale, adjustment, return
- `CashboxTransactionType`: open, close, deposit, withdraw, sale, expense

**Data models** extend domain entities and add serialization (toJson/fromJson, fromDrift/toDrift).

---

## 6. State Management Recommendation

**Primary: Riverpod (v2+ with code generation)**

Rationale:
- Compile-time safety (no runtime errors from missing providers)
- Testability (provider overrides for testing)
- No BuildContext dependency (works outside widget tree)
- Excellent for Clean Architecture (providers at data/domain boundary)
- Code generation reduces boilerplate (`@riverpod` annotations)
- Good community support and active maintenance

**Provider Hierarchy:**
```
DatabaseProvider          → Drift AppDatabase instance
RepositoryProviders       → One per repository (e.g., medicineRepositoryProvider)
UseCaseProviders          → One per use case (e.g., getMedicinesProvider)
Notifiers/StateProviders  → Feature-level state (e.g., cartNotifierProvider)
```

**Feature state pattern:** Each feature page gets a StateNotifier or AsyncNotifier that wraps use cases and exposes typed state.

---

## 7. SQLite/Database Package Recommendation

**Primary: Drift (formerly Moor)**

Rationale:
- Type-safe SQL with compile-time verification
- Built-in reactive streams (watch queries for live UI updates)
- Excellent DAO support (organizes queries by feature)
- Migration support with schema versioning
- Works identically on Windows and Android (uses native SQLite via `drift_sqflite` or `sqlite3`)
- Code generation for models, DAOs, and database class
- Strong community and documentation

**Packages:**
| Package | Purpose |
|---------|---------|
| `drift` | Core ORM |
| `drift_sqflite` | SQLite implementation for sqflite (mobile) |
| `sqlite3_flutter_libs` | Native SQLite for Windows/desktop |
| `drift_dev` + `build_runner` | Code generation |

**Alternative consideration:** If Drift's code generation becomes problematic, `sqflite` + manual SQL is a fallback. Drift is strongly preferred for type safety.

---

## 8. Navigation Strategy

**Primary: GoRouter (v14+)**

Rationale:
- Declarative route definitions
- Named routes with type-safe parameters
- Shell route for persistent layouts (sidebar + content area)
- Redirect logic for auth guards
- Deep linking support (useful for Android)
- Back button handling on Windows

**Layout Structure:**
```
ShellRoute (MainLayout with Sidebar)
├── /pos                  → POS Page (full-width, no sidebar in POS mode)
├── /inventory            → Inventory Page
│   ├── /inventory/list
│   ├── /inventory/add
│   └── /inventory/:id/edit
├── /purchases            → Purchases
├── /suppliers            → Suppliers
├── /customers            → Customers
├── /prescriptions        → Prescriptions
├── /invoices             → Invoices
├── /expenses             → Expenses
├── /cashbox              → Cashbox
├── /accounting           → Accounting
│   ├── /accounting/chart-of-accounts
│   └── /accounting/journal-entries
├── /reports              → Reports
│   ├── /reports/trial-balance
│   ├── /reports/income-statement
│   ├── /reports/balance-sheet
│   └── /reports/account-statement
├── /audit-log            → Audit Log
├── /settings             → Settings
│   ├── /settings/users
│   ├── /settings/backup
│   └── /settings/general
└── /login                → Login Page (outside shell)
```

---

## 9. Localization and RTL Strategy

**Package: `flutter_localizations` + `intl` + ARB files**

**Languages:**
- Arabic (`app_ar.arb`) — primary, RTL
- English (`app_en.arb`) — secondary, LTR

**RTL Implementation:**
- Use `Directionality` widget driven by locale
- All layouts use `Directionality`-aware widgets (no hardcoded `left`/`right`)
- Use `EdgeInsetsDirectional`, `AlignmentDirectional`, `EdgeInsetsDirectional`
- Text fields: `TextAlignDirectional` for Arabic
- `ListTile` with `leading`/`trailing` handles RTL automatically
- Test all screens in both RTL and LTR modes

**ARB File Pattern:**
```json
// app_en.arb
{
  "@@locale": "en",
  "appTitle": "Pharmacy POS",
  "login": "Login",
  "medicine": "Medicine",
  "@medicine": { "description": "A pharmaceutical product" }
}

// app_ar.arb
{
  "@@locale": "ar",
  "appTitle": "نظام إدارة الصيدلية",
  "login": "تسجيل الدخول",
  "medicine": "دواء"
}
```

**Code Generation:** `flutter gen-l10n` generates `AppLocalizations` class with type-safe access.

**Font:** Use a font that supports Arabic well (e.g., Noto Sans Arabic, Cairo, Tajawal) as the primary app font.

---

## 10. Responsive UI Strategy

**Approach: LayoutBuilder + Adaptive Widgets**

**Breakpoints:**
| Mode | Width | Layout |
|------|-------|--------|
| **Desktop (wide)** | ≥ 900px | Sidebar navigation + content |
| **Desktop (narrow)** | 600–899px | Collapsed sidebar (icons only) + content |
| **Tablet** | 600–899px | Collapsed sidebar + content |
| **Mobile** | < 600px | Bottom navigation or hamburger drawer + content |

**Implementation:**
- `ResponsiveLayout` widget in `core/widgets/` wraps all pages
- Sidebar collapses/expands based on width
- POS page uses full width on all sizes (different layouts for item grid vs list)
- Data tables become card-based lists on narrow screens
- Dialogs become full-screen pages on mobile

**Key Pattern:**
```
ResponsiveLayout(
  mobile: MobileLayout(),
  tablet: TabletLayout(),
  desktop: DesktopLayout(),
)
```

**POS-Specific Responsive:**
- Desktop: 3-panel layout (items grid | cart | payment)
- Tablet: 2-panel (items + cart overlay)
- Mobile: Tab-based (items tab | cart tab)

---

## 11. Security and Permissions Model

**Role-Based Access Control (RBAC):**

| Permission | Admin | Pharmacist | Cashier | Accountant |
|------------|-------|-----------|---------|-----------|
| POS/Sales | ✅ | ✅ | ✅ | ❌ |
| Void Sale | ✅ | ✅ | ❌ | ❌ |
| Inventory CRUD | ✅ | ✅ | ❌ | ❌ |
| Purchases | ✅ | ✅ | ❌ | ❌ |
| Prescriptions | ✅ | ✅ | ❌ | ❌ |
| Customers | ✅ | ✅ | ✅ | ❌ |
| Expenses | ✅ | ❌ | ❌ | ✅ |
| Cashbox | ✅ | ✅ | ✅ | ❌ |
| Accounting | ✅ | ❌ | ❌ | ✅ |
| Reports (financial) | ✅ | ❌ | ❌ | ✅ |
| Reports (sales) | ✅ | ✅ | ✅ | ✅ |
| User Management | ✅ | ❌ | ❌ | ❌ |
| Audit Log | ✅ | ❌ | ❌ | ❌ |
| Backup/Restore | ✅ | ❌ | ❌ | ❌ |

**Implementation:**
- Passwords hashed with bcrypt (package: `bcrypt`)
- Session managed via local state (auto-logout after inactivity)
- Permission checks in use cases AND UI (hide/disable unauthorized actions)
- Audit log records all data mutations with user reference
- No network transmission (all local), so transport security is N/A in initial phase

---

## 12. Backup/Restore Strategy

**Mechanism: Direct SQLite file copy**

**Backup:**
1. User triggers backup from Settings
2. App copies the SQLite `.db` file to a user-selected directory
3. Backup filename: `pharmacy_backup_YYYYMMDD_HHmmss.db`
4. Optional: Compress with `archive` package to `.zip`
5. Metadata file (JSON) records: timestamp, app version, database version

**Restore:**
1. User selects a backup `.db` file
2. Validate backup integrity (check metadata, schema version)
3. Confirm with user (warning: current data will be replaced)
4. Close current database connection
5. Replace current `.db` file with backup
6. Reopen database connection
7. Run any pending migrations if needed

**Package:** `path_provider` for app directory, `file_picker` for user selection, `archive` for compression.

**Auto-Backup (optional):** Daily automatic backup to a designated folder, configurable in settings.

---

## 13. Testing Strategy

| Level | Scope | Tools | Coverage Target |
|-------|-------|-------|----------------|
| **Unit Tests** | Domain entities, use cases, repository logic, utilities | `test`, `mockito`/`mocktail` | 80%+ |
| **Widget Tests** | Individual widgets, forms, dialogs | `flutter_test` | Key widgets |
| **Integration Tests** | Full feature flows (login → sale → report) | `integration_test` | Critical paths |
| **Database Tests** | Drift DAOs, migrations, queries | `drift` test utilities | All DAOs |

**Test Organization:**
```
test/
├── unit/
│   ├── core/utils/
│   │   ├── validation_utils_test.dart
│   │   └── currency_utils_test.dart
│   └── features/
│       ├── inventory/domain/usecases/
│       │   └── get_medicines_test.dart
│       └── pos/domain/usecases/
│           └── create_sale_test.dart
├── widget/
│   ├── features/
│   │   └── pos/presentation/widgets/
│   │       └── cart_widget_test.dart
│   └── core/widgets/
│       └── search_field_test.dart
├── integration/
│   ├── pos_sale_flow_test.dart
│   └── inventory_management_test.dart
└── database/
    ├── daos_test.dart
    └── migration_test.dart
```

**CI:** All tests run on every PR via GitHub Actions.

---

## 14. Git/GitHub Workflow

**Branch Strategy: Git Flow (simplified)**

```
main                    ← production-ready, tagged releases
  └── develop           ← integration branch
       ├── feature/pos-sell-flow
       ├── feature/inventory-crud
       ├── feature/accounting-journal
       ├── bugfix/fix-stock-calculation
       └── release/v1.0.0
```

**Rules:**
- `main` is always deployable; protected branch
- `develop` is the integration branch
- Feature branches from `develop`, merge back via PR
- PR required with at least 1 review (or self-merge for solo dev with CI green)
- Commit messages: Conventional Commits (`feat:`, `fix:`, `chore:`, `test:`)
- No direct pushes to `main`
- Tags for releases: `v1.0.0`, `v1.1.0`, etc.

**PR Template:**
```
## Description
## Type of Change
## Testing
## Checklist
```

---

## 15. Windows Build Strategy

**GitHub Actions Workflow:**

```yaml
# .github/workflows/build_windows.yml
name: Build Windows

on:
  push:
    tags: ['v*']
  workflow_dispatch:

jobs:
  build-windows:
    runs-on: windows-latest
    steps:
      - uses: actions/checkout@v4
      - uses: subosito/flutter-action@v2
        with:
          flutter-version: '3.x'
          channel: 'stable'
      - run: flutter pub get
      - run: flutter test
      - run: flutter build windows --release
      - uses: actions/upload-artifact@v4
        with:
          name: pharmacy-pos-windows
          path: build/windows/x64/runner/Release/
```

**Build Targets:**
| Platform | Command | Output |
|----------|---------|--------|
| Windows Release | `flutter build windows --release` | `build/windows/x64/runner/Release/` |
| Windows Debug | `flutter run -d windows` | Debug executable |
| Android APK | `flutter build apk --release` | `build/app/outputs/flutter-apk/` |

**Windows-Specific:**
- App icon configured in `windows/runner/.rc`
- Window title set in `main.cpp`
- Minimum Windows version: 10 (version 1803+)
- Bundle name, version, and icon configured in `pubspec.yaml` under `msix_config` if using MSIX

---

## 16. Detailed Phased Implementation Roadmap

### Phase 1: Foundation (Weeks 1–2)
```
☐ Project setup (flutter create, pubspec.yaml, folder structure)
☐ Core utilities (ID generator, date utils, currency utils, validators)
☐ Drift database setup with ALL tables
☐ Database migrations strategy
☐ DI setup (get_it + injectable or manual)
☐ Theme (Material 3, Arabic-friendly fonts, light theme)
☐ Localization setup (ARB files for ar/en, gen-l10n)
☐ Router setup (GoRouter with shell route)
☐ ResponsiveLayout widget
☐ Shared widgets (DataTable, SearchField, ConfirmDialog, LoadingOverlay)
☐ Error handling (exceptions, failures, ErrorHandler)
☐ Git repo init, .gitignore, README
☐ GitHub Actions: test + build workflow
```

### Phase 2: Authentication & Users (Week 3)
```
☐ User entity, model, repository, use cases
☐ Auth local datasource (Drift DAO)
☐ Login page (Arabic RTL, responsive)
☐ Password hashing (bcrypt)
☐ Session management (auto-logout)
☐ Users CRUD page (admin only)
☐ Role/permission definitions
☐ Audit log entity & basic logging
☐ Unit tests for auth use cases
```

### Phase 3: Inventory & Categories (Weeks 4–5)
```
☐ Category entity, CRUD
☐ Medicine entity, full CRUD
☐ Barcode support (search by barcode)
☐ Stock movement tracking
☐ Low stock alerts
☐ Expiry date tracking & alerts
☐ Inventory list page (searchable, filterable, responsive)
☐ Medicine form (add/edit dialog or page)
☐ Category management page
☐ Unit tests for inventory use cases
```

### Phase 4: Suppliers & Purchases (Week 6)
```
☐ Supplier entity, full CRUD
☐ Supplier statement (transactions list)
☐ Purchase order creation
☐ Purchase order list (with status filters)
☐ Receive purchase order (updates stock)
☐ Return to supplier
☐ Unit tests
```

### Phase 5: Customers & Prescriptions (Week 7)
```
☐ Customer entity, full CRUD
☐ Customer statement (purchases, payments)
☐ Patient-specific fields (DOB, gender, medical history)
☐ Prescription entity, creation, linking to customer
☐ Prescription items (medicine list from prescription)
☐ Unit tests
```

### Phase 6: POS Core (Weeks 8–10)
```
☐ Cart state management (Notifier/StateNotifier)
☐ POS main page (3-panel desktop layout)
☐ Medicine search & add to cart (barcode scanner support)
☐ Quantity adjustment, discount per item
☐ Customer selection (optional)
☐ Prescription linking (optional)
☐ Payment processing (cash, card, mixed)
☐ Change calculation
☐ Receipt generation (PDF)
☐ Sale completion flow (stock deduction, journal entry)
☐ Void sale
☐ Daily Z-report (end-of-day summary)
☐ POS responsive layouts (desktop, tablet, mobile)
☐ Widget tests for POS components
☐ Integration test for full sale flow
```

### Phase 7: Invoices & Expenses (Week 11)
```
☐ Invoice generation from sales
☐ Invoice list, view, void
☐ PDF invoice export
☐ Expense entity, CRUD
☐ Expense categories
☐ Expense list with filters
☐ Unit tests
```

### Phase 8: Cashbox (Week 12)
```
☐ Cashbox opening (initial amount)
☐ Cashbox transactions (deposit, withdraw)
☐ Automatic entries from sales/expenses
☐ Cashbox closing (reconciliation)
☐ Cashbox history
☐ Unit tests
```

### Phase 9: Accounting System (Weeks 13–15)
```
☐ Chart of Accounts (predefined + custom)
☐ Account types (asset, liability, equity, revenue, expense)
☐ Journal entry creation (manual + automatic)
☐ Double-entry validation (debit == credit)
☐ Automatic journal entries for: sales, purchases, expenses
☐ Account ledger view
☐ Period close process
☐ Unit tests for accounting logic
```

### Phase 10: Reports (Weeks 16–17)
```
☐ Trial Balance report
☐ Income Statement (Profit & Loss)
☐ Balance Sheet
☐ Account Statement (per account, date range)
☐ Sales reports (daily, weekly, monthly, by medicine, by category)
☐ Inventory reports (stock value, low stock, expiry)
☐ Purchase reports
☐ Supplier statements
☐ Customer statements
☐ PDF export for all reports
☐ Excel export for all reports
☐ Date range filters on all reports
☐ Unit tests for report calculations
```

### Phase 11: Audit Log & Settings (Week 18)
```
☐ Audit log page (filterable by user, entity, date)
☐ App settings page (business name, tax rate, currency, etc.)
☐ User preferences
☐ Audit log for all CRUD operations
☐ Unit tests
```

### Phase 12: Backup/Restore & Export (Week 19)
```
☐ Backup to file (SQLite copy + optional compression)
☐ Restore from file (with validation & confirmation)
☐ Auto-backup setting
☐ PDF export for invoices, receipts, reports
☐ Excel export for data tables and reports
☐ Unit tests
```

### Phase 13: Polish & Hardening (Weeks 20–21)
```
☐ Responsive UI polish across all pages
☐ RTL testing and fixes
☐ Error handling improvements
☐ Loading states & empty states
☐ Keyboard shortcuts (POS speed)
☐ Input validation on all forms
☐ Performance optimization (large datasets)
☐ Widget tests for critical paths
☐ Integration tests for critical flows
☐ Accessibility review
```

### Phase 14: Testing & CI/CD (Week 22)
```
☐ Achieve 80%+ unit test coverage
☐ Complete integration test suite
☐ Fix all failing tests
☐ GitHub Actions: full test + build pipeline
☐ Windows release build + artifact upload
☐ Android APK build + artifact upload
☐ Test both builds end-to-end
```

### Phase 15: Release (Week 23)
```
☐ Final QA pass
☐ App icon and splash screen
☐ Windows installer (Inno Setup or MSIX)
☐ Documentation (README, setup guide)
☐ Git tag v1.0.0
☐ GitHub Release with artifacts
```

---

## Summary of Key Technology Decisions

| Decision | Choice | Rationale |
|----------|--------|-----------|
| State Management | **Riverpod** (code gen) | Type-safe, testable, no context needed |
| Database | **Drift** | Type-safe, reactive, migration support |
| Navigation | **GoRouter** | Declarative, shell routes, auth redirects |
| Localization | **intl + ARB** | Flutter standard, RTL support |
| DI | **get_it + injectable** | Simple, widely used, works with Drift |
| HTTP (future) | **dio** | Interceptors, cancellation, logging |
| PDF | **pdf** + **printing** | Dart-native PDF generation |
| Excel | **excel** package | XLSX generation |
| Hashing | **bcrypt** | Secure password hashing |
| UUID | **uuid** package | Consistent ID generation |
| Testing | **mocktail** + **flutter_test** | Mocking without code gen |
