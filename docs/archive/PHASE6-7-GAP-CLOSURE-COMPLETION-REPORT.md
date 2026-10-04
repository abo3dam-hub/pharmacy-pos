# PHASE 6/7 GAP CLOSURE — COMPLETION REPORT

> **Date:** 2026-09-06
> **Author:** opencode (automated)
> **Report version:** 1.0

---

## 1. Executive Summary

### What was missing

Before this work the following Phase 6/7 functionality was absent:

- **Receipt PDF / Invoice PDF / Z-Report PDF** — no PDF generation at all; no `pdf`/`printing`/`arabic_reshaper` dependencies; no font loading infrastructure.
- **Smart Alternatives UI** — the tier engine (`SmartAlternativesService`) and test coverage existed, but no dialog, no tier badge, no selection-into-POS flow, no Arabic empty states, no keyboard shortcut.
- **Lost Sales Quick Capture** — the `lost_sales` table and migration existed, but no capture dialog, no controller method, no permission gate, no POS toolbar entry.
- **Z-Report (end-of-session summary)** — entity, DAO, provider, and DI wiring existed, but no page, no route, no print button, no drawer reconciliation test, no empty-state handling.
- **POS invoice print** — the invoice view page loaded persisted data but had no print button wired to a PDF service.
- **POS receipt dialog print** — the hold-bill receipt dialog existed but had no PDF print action.
- **Arabic l10n keys** — dozens of UI-facing strings for PDF labels, Z-Report sections, lost-sale dialogs, and print-failure messages were missing.
- **`backup_service_test.dart` regression** — the schema-version assertion (`5`) was stale after the Part 1 migration fix (schema v6); this is fixed below.

### What was implemented (this work)

1. **PDF layer** (`lib/core/pdf/`) — `PdfDocuments`, `PdfFonts`, `PdfArabic`, `ReceiptPdfService`, `InvoicePdfService`, `ZReportPdfService`.
2. **Smart Alternatives dialog** — tier-ranked list inside `_AlternativesDialog`, green/yellow/blue badge, selection into normal POS cart via `addToCart(alt.item)`, Alt+S shortcut.
3. **Lost Sales Quick Capture** — `_showLostSaleDialog`, controller `captureLostSale`, permission gate, snackbar confirmations.
4. **Z-Report page** — full A4 page with auto-loaded today period, date-range picker, sales/returns/voids/drawer sections, print button, empty-state message.
5. **POS print wiring** — invoice page print button, receipt dialog print button.
6. **l10n** — `zReportEmptyPeriod` + ~35 Arabic/English keys for Z-Report, lost-sale, and print-failure labels.
7. **Backup test fix** — updated stale `schemaVersion` assertion from `5` to `6`.

### What was already complete (and therefore not rewritten)

- Smart Alternatives tier engine (`SmartAlternativesService`) — already correct and tested.
- Smart Alternatives catalog DAO (`alternativeCandidates`) — already correct.
- Smart Alternatives repository method (`smartAlternatives`) — already wired.
- Lost Sales entity (`PosLostSaleDraft`), `lost_sales` table definition, schema audit coverage.
- Lost Sales migration (guarded `lost_sales` creation for v1→v6 upgrades).
- Z-Report entity (`ZReport`), DAO (`ZReportDao`), providers.
- Financial posting engine, customer balance engine, sale/return/void accounting, FEFO, partial-sale pricing, prescription enforcement — all from Phase 7.5.
- Existing POS sales flow, cart management, payment orchestration.

---

## 2. Baseline

**Starting commit:** `98f4651f71f29c45944e98a2feaac527c8bfef0e`
`feat(financial): establish financial lifecycle foundation`

This commit established Phase 7.5 (financial lifecycle) as the validated foundation.

---

## 3. Gap Audit

| # | Original requirement | Implementation state | Evidence | Action taken |
|---|---|---|---|---|
| G1 | Receipt PDF for POS printing | Missing entirely | No `pdf`/`printing` deps; no PDF services | Implemented `ReceiptPdfService` + test |
| G2 | Invoice PDF (A4 formal document) | Missing entirely | No A4 PDF generation | Implemented `InvoicePdfService` + test |
| G3 | Z-Report PDF | Missing entirely | No Z-Report PDF | Implemented `ZReportPdfService` + test |
| G4 | Arabic-shaped, RTL, Latin-digit PDF text | Missing entirely | No `PdfArabic` or font loading | Implemented `pdf_arabic.dart` + `pdf_fonts.dart` |
| G5 | Smart Alternatives UI (dialog + tier badge) | Engine existed; no UI | `smart_alternatives_service.dart` (existing) | Built `_AlternativesDialog` + `_TierBadge` |
| G6 | Smart Alternatives → normal POS flow | Not wired | No selection handler | Wired `addToCart(alt.item)` — distinct cartKey |
| G7 | Lost Sales Quick Capture | Table existed; no UI | `lost_sales` table, controller `captureLostSale` missing | Built dialog + controller + permission gate |
| G8 | Z-Report page (period picker, sections) | DAO/Entity existed; no page | `z_report_dao.dart`, `z_report.dart` (existing) | Built `ZReportPage` + route + permissions |
| G9 | Z-Report drawer reconciliation test | Missing | `z_report_dao.dart` had no unit test | Added `test/z_report_dao_test.dart` (2 tests) |
| G10 | Z-Report empty state (§33) | Not implemented | Zero-sales period showed blank | Added `zReportEmptyPeriod` + `_EmptyPeriod` widget |
| G11 | POS invoice page print button | Missing | Page loaded data but no print action | Wired `InvoicePdfService().print(...)` + snackbar |
| G12 | Receipt dialog print button | Missing | Hold-bill dialog existed but no print | Converted to `ConsumerWidget`, added print action |
| G13 | Number-format regression (§36) | Missing | No test enforcing Latin digits in `Money.formatArabicDigits` | Added assertion in `pdf_documents_test.dart` |
| G14 | Backup schema-version regression (§39) | Stale assertion | `test/backup_service_test.dart:88` expected `5` after schema bump to `6` | Updated to assert current schema version (`6`) |

---

## 4. Implemented Features

### 4.1 PDF Layer (`lib/core/pdf/`)

**`PdfDocuments`** — shared typography and table primitives for all three document types:
- `pageA4(...)` and `pageReceipt(...)` with Cairo font injected via `PageTheme`.
- `invoiceLinesTable(...)`, `totalsTable(...)`, `fieldRow(...)`, `heading(...)`.
- `timestamp(int millis)` and `money(int micros)` static helpers.

**`PdfFonts`** — loads the Cairo TrueType font from `assets/fonts/Cairo-Regular.ttf` via `rootBundle.load`; wraps as `pw.Font.ttf(ByteData.view(...))`.

**`PdfArabic`** — Arabic text shaping via `arabic_reshaper` + `bidirectional` package:
- `shape(String)` — reshapes Arabic text to presentation forms; Latin passes through unchanged.
- `textDirection(String)` — RTL for Arabic content, LTR for Latin.
- `textStyle(...)` — directional text style for PDF widgets.
- `pharmacyFallbackName()` — returns `AppConfig.appName`.
- `pharmacyNameSettingKey` — settings key for pharmacy display name.

**`ReceiptPdfService`** — 80 mm thermal receipt PDF:
- Pharmacy name from settings with fallback.
- Invoice number, date, customer, line items, totals table, cash/card/credit breakdown, change, thank-you footer.
- `buildBytes(...)` returns `Uint8List`; `print(...)` sends to platform print dialog via `Printing.layoutPdf`.

**`InvoicePdfService`** — A4 sale invoice PDF:
- Full page header (pharmacy, document label, serial, date, operator, customer).
- Line items table, totals table, notes section.
- `buildBytes(...)` + `print(...)`.

**`ZReportPdfService`** — A4 end-of-session summary PDF:
- Three sections: Sales Summary (invoices count, units sold, subtotal, discount, VAT, total, cash/card/credit, paid, change), Returns & Voids (returns count/value, voids count/value, customer collected/refunded), Drawer Reconciliation (opening, net moves, expected closing, running balance, declared close, difference).
- `buildBytes(...)` + `print(...)`.

### 4.2 Smart Alternatives UI

**`_AlternativesDialog`** (`pos_workspace_page.dart:1425–1491`):
- Triggered by row button (swap_horiz icon, `Perm.viewAlternatives` gate) or Alt+S shortcut.
- `FutureBuilder` loads `salesRepository.smartAlternatives(requested)`.
- Each alternative shows: `_TierBadge` (28×28 circle, green/yellow/blue with tier number), trade name, scientific name, dose, form, available stock, unit price.
- Selection: `onPick → Navigator.pop → notifier.addToCart(alt.item)` — the alternative enters the normal POS workflow as its own cart line (`cartKey = '${item.id}::${unitMode.name}'`), so existing Rx/stock/pricing rules apply.
- Empty state: `l10n.posAlternativesEmpty` = "لا توجد بدائل متاحة حالياً".
- Error state: `l10n.posAlternativesFailed` = "تعذر تحميل البدائل".

**`_TierBadge`** (`pos_workspace_page.dart:1493–1540`):
- Tier 1 → `Color(0xFF2E7D32)` (green), Tier 2 → `Color(0xFFF9A825)` (amber), Tier 3 → `Color(0xFF1976D2)` (blue).
- Tooltip: Arabic tier description.

### 4.3 Lost Sales Quick Capture

**Dialog** (`pos_workspace_page.dart:1304–1373`):
- Triggered by empty search results (primary) or barcode scan of unknown product.
- Fields: product name (prefilled with search query/barcode), scientific name, note, quantity (default 1, clamped 1–99999).
- Actions: Save (`commonSave`) / Cancel (`commonCancel`).

**Controller** (`pos_workspace_controller.dart:583–624`):
- Permission gate: `Perm.lostSalesCreate` or `Perm.salesCreate`.
- Builds `PosLostSaleDraft` and calls `salesRepository.recordLostSale(...)`.
- On success: state cleared (search query reset), POS remains live, `SnackBar(posLostSaleSaved)` = "تم تسجيل المنتج الناقص".

**Repository** (`sales_repository_impl.dart:427–459`):
- Single insert into `lost_sales` table — no `sales_invoices`, `stock_movements`, `cashbox_transactions`, or accounting tables touched.

**Keyboard**: Alt+L shortcut (`pos_shortcuts.dart`) opens lost-sale dialog when search returns no results.

### 4.4 Z-Report Page

**`ZReportPage`** (`z_report_page.dart`):
- Permission gate: `Perm.reportsViewSales` (router redirect to `/access-denied`).
- Default period: today (auto-loaded on `initState` via `addPostFrameCallback`).
- Date-range picker via `showDateRangePicker`.
- Sections: Sales Summary (invoice count, units sold, subtotal, discount, VAT, total, cash/card/credit, paid, change), Returns & Voids (returns count/value, voids count/value, customer collected/refunded), Drawer Reconciliation (opening, net moves, expected, running balance, declared close, difference).
- Print: `ZReportPdfService().print(...)` via AppBar and toolbar button; pharmacy name from settingsDao + fallback; error → `SnackBar(posPrintFailed)`.
- Empty state (§33): when `invoiceCount == 0`, shows `_EmptyPeriod` with `l10n.zReportEmptyPeriod` = "لا توجد مبيعات ضمن الفترة المحددة" (not a broken blank screen).

**Route**: `/sale/z-report` under the sale section; redirect requires both `Perm.salesView` (section-level) and `Perm.reportsViewSales`.

**POS toolbar**: Z-Report `IconButton` (summarize_outlined) visible only when `_permissions.contains(Perm.reportsViewSales)`, navigates to `/sale/z-report`.

### 4.5 POS Print Wiring

**Invoice page** (`pos_invoice_page.dart`):
- Loads persisted `PosInvoiceView` via `invoiceViewById(widget.invoiceId)`.
- Print button enabled when invoice is loaded.
- `_printInvoice()`: settings-based pharmacy name → `InvoicePdfService().print(invoice, pharmacy)` → error `SnackBar(posPrintFailed)`.

**Receipt dialog** (`pos_workspace_page.dart`):
- `_ReceiptDialog` converted to `ConsumerWidget`.
- "Print Receipt" button: `ReceiptPdfService().print(invoice, pharmacy)` → error snackbar.

---

## 5. Architecture Changes

No architectural redesign performed. All gap-closure work was built on top of the existing:

- Drift-based DAO/repository pattern.
- Riverpod providers + `getIt` DI.
- `PosWorkspaceController` state management.
- Existing POS sales flow (`SaleService`, `ReturnService`, `CustomerPaymentService`).
- Existing `SalesRepositoryImpl` pattern.

The only structural additions were:
- New files under `lib/core/pdf/` (read-only PDF generation layer).
- New `_AlternativesDialog`, `_TierBadge`, `_Row` (Z-Report), `_EmptyPeriod` widgets.
- New `zReportEmptyPeriod` l10n key.
- `zReportEmptyPeriod` added to AR and EN `.arb` files + regenerated l10n.

---

## 6. Database Changes

**Schema version bumped from 5 → 6** (Part 1, `lost_sales` migration fix).

This is the only schema change. The v5→v6 migration:
- Creates the `lost_sales` table if missing (guarded creation for upgraded databases).
- Existing tables untouched.

No new tables added in Part 2. All gap-closure features read existing data:
- `sales_invoices`, `sales_invoice_items` — for Z-Report aggregation.
- `returns` — for Z-Report returns section.
- `customer_payments` — for Z-Report customer credit ledger.
- `cashbox_transactions` — for Z-Report drawer reconciliation.
- `items`, `batches` — for Smart Alternatives candidate lookup.
- `lost_sales` — for Lost Sales quick capture (single insert).
- `app_settings` — for pharmacy name in PDFs.

---

## 7. Tests

### Test count

| Metric | Value |
|---|---|
| Previous test count (baseline 98f4651) | 304 |
| New tests added | 22 |
| Final test count | **326** |
| Final result | **ALL PASS** |

### New test files

| File | Tests | What it covers |
|---|---|---|
| `test/pdf_documents_test.dart` | 5 | PdfArabic shaping contract (Arabic→presentation forms, Latin passthrough, RTL direction); Money Latin-digit regression; receipt/invoice/Z-Report structural PDF assertions (header, trailer, xref, embedded TrueType font via ASCII85 decode, Tf/TJ operators) |
| `test/z_report_dao_test.dart` | 2 | Full aggregation (cash+credit sales, void, return, customer payment, drawer open/close) with reconciliation assertions (opening + netMoves == lastRemaining == expectedClosing, declaredClose − expected == 0); empty-window zeros + draft exclusion |
| `test/smart_alternatives_repo_test.dart` | 3 | Candidate superset correctness; tier ranking (tier1/tier2/tier3 assignment); hydration carries dose/pharmaForm |
| `test/lost_sale_test.dart` | 4 | Enhanced draft persistence (scientificName/note); controller capture with permissions; **no side-effect assertion** (batch qty unchanged, sales_invoices=0, stock_movements unchanged); permission guard |

### Modified test files

| File | Change |
|---|---|
| `test/migration_test.dart` | +59 lines: v1→v6 upgrade path with lost_sales table verification |
| `test/pos_domain_test.dart` | +202 lines: Smart Alternatives engine (tokenizer, tier1/tier2/tier3, stock-drop, ordering, limit); lost-sale controller integration (captureLostSale, no-permission guard); Z-Report DAO integration; addToCart merge-by-cartKey, Rx-linked add, stock-exceeded guard |
| `test/backup_service_test.dart` | `schemaVersion` assertion updated from `5` to `6` (stale after Part 1 migration fix) |

---

## 8. Static Analysis

```
$ flutter analyze
Analyzing pharmacy-pos...
No issues found! (ran in 2.7s)
```

---

## 9. Acceptance Matrix

| Requirement | Status | Evidence |
|---|---|---|
| Smart Alternatives engine reused | **PASS** | `smart_alternatives_service.dart` (existing, unchanged); `SmartAlternativesService().rank(item, candidates)` at `sales_repository_impl.dart:418–420` |
| Smart Alternatives UI (dialog, tier badge) | **PASS** | `_AlternativesDialog` at `pos_workspace_page.dart:1425–1491`; `_TierBadge` at `1493–1540` |
| Alternative selection → normal POS flow | **PASS** | `onPick → notifier.addToCart(alt.item)` at `pos_workspace_page.dart:254–259`; distinct `cartKey` at `pos_cart.dart:68`; addToCart enforces Rx/stock/pricing at `pos_workspace_controller.dart:92–163` |
| Lost Sales Quick Capture | **PASS** | `_showLostSaleDialog` at `pos_workspace_page.dart:569–588`; dialog at `1304–1373` |
| Lost Sales persistence | **PASS** | `sales_repository_impl.dart:427–459`: single insert into `lost_sales` table |
| No unintended stock/financial mutation | **PASS** | `test/lost_sale_test.dart:93–133`: batch qty unchanged, `sales_invoices` count=0, `stock_movements` unchanged; code path touches only `lost_sales` table |
| Receipt PDF | **PASS** | `ReceiptPdfService` at `pdf_documents.dart:205–265`; structural test at `pdf_documents_test.dart:145–151` |
| Arabic PDF support | **PASS** | `PdfArabic.shape(...)` reshapes Arabic to presentation forms; RTL `textDirection`; Cairo font embedded; test at `pdf_documents_test.dart:114–135` |
| Latin digits (no Arabic-Indic) | **PASS** | `Money.formatArabicDigits()` delegates to `Money.format()` which outputs ASCII digits; regression test at `pdf_documents_test.dart:131–135` |
| Invoice PDF | **PASS** | `InvoicePdfService` at `pdf_documents.dart:268–322`; structural test at `pdf_documents_test.dart:153–164` |
| Historical invoice integrity (read-only) | **PASS** | `pos_invoice_page.dart:31–37`: loads persisted `PosInvoiceView` via `invoiceViewById`; PDF uses `invoice.subtotalMicros`, `line.unitPriceMicros` etc. (never current product prices); `InvoicePdfService.buildBytes(...)` reads without mutation |
| Z-Report | **PASS** | `ZReportPage` at `z_report_page.dart`; `ZReportDao.aggregate()` at `z_report_dao.dart:18–91` |
| Z-Report reconciliation | **PASS** | `test/z_report_dao_test.dart:199–206`: `drawerOpeningMicros=50000`, `drawerNetMovesMicros=50000`, `expectedClosingMicros=100000`, `lastRemainingMicros=100000`, `drawerDifferenceMicros=0` |
| Existing Phase 6 regression | **PASS** | `flutter test` all 326 tests pass; `pos_domain_test.dart` covers addToCart/merge/Rx/stock/pricing; `pos_workspace_page_test.dart` covers search→pay→receipt and lost-sale flow |
| Existing Phase 7 regression | **PASS** | `test/financial_lifecycle_test.dart` (sales, returns, voids, credit, customer payments) — all pass at baseline; not modified in this work |
| Phase 7.5 regression | **PASS** | `test/migration_test.dart` (v1→v6 upgrade) all pass; `test/financial_lifecycle_test.dart` all pass |
| `flutter analyze` | **PASS** | **No issues found** (ran in 2.7s) |
| `flutter test` | **PASS** | **326 tests, ALL PASS** |

---

## 10. Deferred Work

The following are intentionally NOT implemented in this task because they belong to later phases:

### Phase 8 — Cash Box
- Full cash-box UI with drawer management.
- Cash-box open/close workflow (the current `_drawer()` method in Z-Report DAO reads raw `cashbox_transactions`; Phase 8 will add the proper UI for managing this).
- Cash-flow detail per transaction type.

### Phase 8 — Credit Sales UI
- Dedicated credit-sales entry screen for non-POS credit management.
- Credit limit enforcement UI.
- Account statement view.
- (Credit *engine* is complete and tested in Phase 7.5; only the credit *sales management UI* is deferred.)

### Phase 9 — Expenses
- Expense tracking and categorization.
- Expense section in the Z-Report.

### Phase 10 — Accounting
- Journal entries, chart of accounts, financial statements.
- The Z-Report does not create accounting entries (by design per §28).

### Phase 11 — Full Reports / Dashboard
- General-purpose reporting framework.
- Sales dashboard, trend analytics.
- The Z-Report is a dedicated, self-contained end-of-session summary; no competing reporting architecture was created.

### Not in scope for Phase 6/7
- Lost-sales listing/management page (only the Quick Capture dialog is implemented; no listing UI with filters, export, or "لا توجد طلبات مسجلة" empty state was built).
- Actual Windows physical printer integration (PDF is generated and sent to the platform print dialog via `Printing.layoutPdf`; the user handles physical printing from the system dialog).
- Product-price recalculation in historical PDFs (intentionally avoided per §23).

---

## 11. Known Technical Debt

1. **Backup test schema version**: `test/backup_service_test.dart:88` asserts hard-coded `6`. Future schema bumps (Phase 8+) will require updating this value. Consider deriving from `AppDatabase` class metadata.
2. **Smart Alternatives widget test**: `test/pos_workspace_page_test.dart` has no dedicated widget test for the alternatives dialog selection flow. The tier engine and repository-level selection are tested; the dialog→addToCart widget integration is covered only by the controller integration test (`pos_domain_test.dart`), not by a full widget test.
3. **Lost Sales widget test**: The lost-sale capture dialog is tested via controller integration and via a single widget test (`pos_workspace_page_test.dart:213–244`) that asserts the button appears on empty search. Full dialog-field interaction (typing name, quantity, saving) is not tested at the widget level.
4. **Z-Report page widget test**: No widget-level test exists for the Z-Report page. The DAO-level aggregation and reconciliation are thoroughly tested; the page's date-range picker, auto-load, and empty-state rendering are covered only by static code analysis.

---

## 12. Final Status

**PASS**

---

## ROADMAP INTEGRITY STATEMENT

The Phase 6/7 Gap Closure work did not intentionally reorder, merge, split, or reinterpret the project's approved roadmap. Functionality was implemented only where it belongs to the already-approved Phase 6 or Phase 7 scope. Later-phase functionality remains deferred.

---

## PHASE 8 HANDOFF

### Ready for Phase 8

Everything that Phase 8 (Cash Box) can safely consume:

- **Financial posting engine** — `SaleService.recordSale`, `ReturnService.recordSaleReturn`, `SaleService.voidInvoice` all post atomically via Drift transactions; all postings tested.
- **Customer balance engine** — `CustomerPaymentService.recordCustomerPayment` handles credit payments and refunds; customer `balanceMicros` column updated in-place.
- **Sale accounting** — cash/card/credit/change micros are split at sale time and stored on the invoice row.
- **Return accounting** — standalone returns update batch stock and issue reversal drawer transactions.
- **Invoice void reversal** — voided invoices are marked with `voidedAt`; the Z-Report excludes their cash/card/credit splits from collected totals.
- **Existing POS sales flow** — `PosWorkspaceController.checkout(...)` → `SaleService().recordSale(...)` — complete, tested, atomic.
- **FEFO (First-Expired-First-Out)** — batch selection respects expiry; tested.
- **Partial-sale pricing** — `PosLinePricer` decomposes box→strip pricing; `batchRemaining` tracking enforced; tested.
- **Prescription enforcement** — Rx items require remaining prescription match; controlled drugs require prescription; tested.
- **Smart Alternatives** — tier engine + UI complete; alternative selection enters normal POS flow with all rules enforced.
- **Lost Sales** — quick capture dialog + controller + repository complete; single-table insert, no side effects.
- **Receipt/Invoice/Z-Report PDFs** — all three services complete and tested; Arabic-shaped, Latin-digit, Cairo-font-embedded.
- **Z-Report DAO** — `ZReportDao.aggregate(...)` is read-only; all figures come from persisted documents; drawer reconciliation formula tested.
- **Settings DAO** — `SettingsDao.getString(pharmacyNameSettingKey)` for pharmacy display name.
- **`lost_sales` table** — schema v6 includes the table; migration creates it for upgraded databases.

### Must NOT be rebuilt in Phase 8

- Financial posting engine.
- Customer balance engine.
- Sale/return/void accounting.
- FEFO, partial-sale pricing, prescription enforcement.
- Smart Alternatives engine, Lost Sales quick capture.
- Receipt/Invoice PDF services.
- Z-Report aggregation DAO.
- Arabic shaping infrastructure (`pdf_arabic.dart`).
- The `lost_sales` table and its migration.

### Intentionally Deferred to Phase 8

- **Cash-box UI** — drawer management, cash-box open/close workflow.
- **Credit-sales management UI** — dedicated non-POS credit entry, account statements, credit-limit enforcement UI.
- **Cash-flow detail in Z-Report** — Phase 8 may extend the drawer section with per-transaction-type detail.

### Important constraints for Phase 8

1. The `cashbox_transactions` table's `open`/`close` transaction types are currently created by manual DB seeding in tests (e.g., `test/z_report_dao_test.dart:49–63`). Phase 8 should provide proper UI for creating these.
2. The Z-Report DAO excludes `open`/`close` from `netMoves` (intentional per §27 reconciliation rule). Phase 8 must maintain this contract.
3. Drawer reconciliation formula: `expectedClosing = drawerOpening + drawerNetMoves`; `difference = declaredClose − expectedClosing`. Phase 8 should use the same formula for any cash-box summary UI.
4. All monetary values use micro-units (scale 4, `Money.format()` outputs Latin digits with `,`/`.` separators). Phase 8 must use the same formatter.
5. The `financial_lifecycle_test.dart` suite tests the complete sale→return→void→payment→balance chain. Phase 8 should run this suite as a regression gate before merging.

---

*End of report.*
