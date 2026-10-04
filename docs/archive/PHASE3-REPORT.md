# Phase 3 Report — Items & Inventory

**Status:** Implemented · **Span:** inventory domain/data/presentation on top of Phase 2 · **Tests:** all green across safety suite + inventory suite.

## In Scope (done)

- **Item form (§5)** — full profile in `item_dialog.dart`:
  - Identification: primary/secondary barcode, trade name (ar/en), scientific name, active ingredient, equivalent drug, license number.
  - Classification: category, sub-category, manufacturer, therapeutic group, pharma form, dose, size/volume, shelf location.
  - Flags: has-expiry, print-barcode-label, OTC, controlled drug, scale-barcode alert, lock auto-price-update, requires prescription.
  - Units: base + large unit relation (`units_per_large`), driven by seeded units.
  - Pricing/stock: cost, purchase discount (basis points), selling/sub-unit/wholesale/half-wholesale/custom-1/custom-2 prices (integer micro-units), VAT rate (basis points), min/max stock, usage instructions, general notes.
- **Master data management (`master_data_tabs.dart`)** — categories, sub-categories, manufacturers, therapeutic groups, units: list/table + create/edit via `master_data_dialog.dart`, active toggling. `TherapeuticGroupRow` has no `name_en` (matches schema).
- **Batch entry (`batch_dialog.dart`)** — batch number, expiry, received date, quantity, unit cost, supplier, notes. Manual entry posts a `stock_adjustment` ledger movement (`ref_type = 'batch'`); the batch balance is established by the ledger, not seeded directly.
- **Stock adjustment UI (`stock_adjust_dialog.dart`)** — increase/decrease with mandatory non-zero signed delta (`MovementType.stock_adjustment`), audited.
- **Void batch** — flattens remaining balance via `manual_correction` and flags the batch.
- **Expiry / low-stock alerts (`status_chips.dart`)** — §24 `StockStatus {normal, low, out}` from `current_stock_base` vs `minimum_stock_base`; `BatchStatus {normal, nearExpiry, expired}` with `nearExpiryDays = 90`; text + icon + badge, never color-only.
- **Excel import/export (`inventory_excel_service.dart`)** — items matched by primary barcode, master data by name; round-trip test. Export gated on `inventory.view`, import on `inventory.create`.
- **Bulk grid editing (§22)** — change category / shelf location / price-by-percent (integer Money math, `change_prices` gate); per-row + one summarised `bulk_op` audit record.
- **Inventory page (`inventory_page.dart`)** — 5-tab host (Items, Categories, Manufacturers, Groups, Units) with `BatchesPage` nested per item; permission-aware redirect; search + active-only filter + pager (page size 30).
- **Permissions** — reads `inventory.view`; item create `inventory.create`; item edit/toggle + master-data mutations `inventory.edit`; batch entry/void + adjust `stock.adjust`; batch/movement lists `stock.view`; bulk price-% `change_prices`.
- **Money/percent integrity** — integer micro-units (scale 4) via `money/money.dart`; percentages as integer basis points; no floating-point money anywhere.

## Bugs fixed during this phase

- `InventoryRepositoryImpl.updateItem` ran an unconditional `UPDATE` (no `WHERE id`), affecting all rows → added `..where((i) => i.id.equals(id))`.
- `insertBatch` seeded `batch.quantity_base` twice (direct write + ledger), double-counting on-hand → seeded to `0` and let the single `stock_adjustment` ledger movement establish the balance.
- `updateItem` required units on *every* call (broke bulk category/shelf edits) → units now required only for `createItem`; updates keep the existing relation unless a new one is supplied.

## Deferred / Future Phase

Explicitly **NOT** in this phase (no DB changes made toward these):
- Suppliers, purchases/invoices, purchase returns, bonus engine beyond batch fields.
- Customers, patients, prescriptions.
- POS, sales, invoices & returns, lost sales.
- Cash box, expenses.
- Accounting (chart of accounts, journal entries, auto-posting), period close.
- Reports (trial balance, income statement, balance sheet, statements, PDF/Excel report export).
- Backup/restore, cloud/network sync, REST/GraphQL transport.
- Audit-log & settings viewer UIs, role/permission management UI.

## Test coverage added

`test/inventory_test.dart` (8 tests): item create + search view, update & `price_change` audit, batch open + on-hand, void batch flatten + `manual_correction`, stock adjust ±, bulk category+bulk_op audit, permission gate (viewer denied create), Excel export→import round-trip. Baseline Phase 2 suite (117) + inventory suite → **125 passing**.

## Verify

- `flutter analyze` → 0 issues.
- `flutter test` → 125 passed.