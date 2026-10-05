# Stale-UI Comprehensive Audit — 2026-10-05

Requested by Ali after the void-icon bug (invoice detail AppBar never showed
the delete icon because `_invoice` was assigned without `setState`).

## Scope

- All 73 `State`/`ConsumerState` classes.
- All AppBar actions depending on async-loaded state.
- Dialog → list refresh flows.
- Navigation patterns (`push` vs `go`).
- Permission-gated UI inventory.

## Fixed

### 1. Void icon never appeared (the trigger — real bug)
`pos_invoice_page.dart`: `_load()` assigned `_invoice` after `await` without
`setState`. The body rebuilt via `FutureBuilder`; the AppBar never did.
Fixed with `setState`; regression test `test/invoice_detail_void_icon_test.dart`
(verified: fails without the fix, passes with it).

### 2. Stale expanded-row details in sales history (real bug)
`sales_history_page.dart`: `_detailCache` was never invalidated — re-expanding
an invoice after returning from its detail page showed pre-return data. The
cache entry is now dropped in `_openDetail` after pop.

### 3. Stale session permissions — A1 (real bug)
`auth_controller.dart`: `reloadCurrentUser()` existed but was dead code, never
called anywhere. Editing role permissions (`roles_page.dart`) or a user's role
(`users_page.dart`) kept the old permission set until re-login. Both pages now
call `reloadCurrentUser()` after a successful save.

### 4. Fragile load patterns hardened — B1, B2, B3
These worked only via a trailing `setState`; any early return added above it
would silently reintroduce the stale-UI bug. All now build locals first and
publish via a single `setState`:
- `purchase_form_page.dart` `_loadForEdit` (invoice fields + lines).
- `price_history_page.dart` (`_userNames`/`_itemNames` maps).
- `settings_page.dart` receipt-template card (`_fontSize` etc.); also moved
  loading from `build()`-triggered into `initState`.

## Checked and clear

- The exact original pattern (`if (mounted) _field =` without `setState`):
  zero remaining instances repo-wide.
- `sales_history_page.dart` / `returns_list_page.dart`: `push` + explicit
  reload after return — correct mutation-then-refresh.
- `purchase_detail_page.dart`, `z_report_page.dart`, `prescription_detail_page`,
  `journal_detail`/`cashbox`/`expenses` (Riverpod), `items_tab`/
  `master_data_tabs`/`suppliers`/`customers` (Riverpod mutations reload
  internally), `batches_page._adjustStock` → controller `reloadBatches`,
  `data_management_page` restore → restart prompt, `customer_statement_page`
  reloads after payment, POS return sheet → `refreshReturnInvoice()`.
- Navigation: detail/statement pages use `context.go(...)` (route replacement
  → list recreated fresh on return); only `push` sites are sales-history /
  returns-list / journal-detail — all handled or read-only.
- Dashboard: no in-section mutations; section switching recreates the page.

## Open for discussion (not changed)

Permission-gated controls hide **entirely** instead of showing
disabled-with-reason (void icon, return buttons, purchase receive/return/
cancel, inventory adjust, item add/edit/delete, master-data actions,
customers/suppliers/expenses actions, …). Counter-examples using the
visible-but-disabled pattern: `z_report_page.dart` print button,
`cashbox_page.dart`, `expenses_page.dart`, `journal_detail_page.dart`.
Whether to adopt disabled-with-reason broadly is a UX decision for Ali.

## Verification

- `flutter analyze`: clean.
- New regression test passes; auth/rbac/double-checkout suites pass.
- Full suite: run in CI on the audit commit.
