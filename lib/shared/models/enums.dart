/// Shared domain enums used by entities and the drift schema.
///
/// Enum values are persisted by *name* into a TEXT column, so the names below
/// are part of the database contract and must not be renamed. Names reflect the
/// canonical persistence values from the architecture plan (§4), e.g.
/// `stock_movements.movement_type` stores `'opening_balance'`, `'sale_return'`,
/// etc. matching §§4.9 / 4.18 / 4.19 / 4.21 / 4.28.
library;

// The snake_case member names ARE the persisted enum values (see library doc);
// the naming lint does not apply to them.
// ignore_for_file: constant_identifier_names

/// The ten stock-movement categories (§4.9, §10).
///
/// Opening balance: رصيد افتتاحي | Purchase: شراء | Sale: بيع |
/// Sale return: مرتجع بيع | Purchase return: مرتجع مشتريات |
/// Stock adjustment: جرد/تسوية | Damaged: تالف | Expired: منتهي الصلاحية |
/// Transfer: انتقال/تحويل | Manual correction: تصحيح يدوي
enum MovementType {
  opening_balance,
  purchase,
  sale,
  sale_return,
  purchase_return,
  stock_adjustment,
  damaged,
  expired,
  transfer,
  manual_correction,
}

/// Invoice type (§4.14). Stored values (see the converter): `'sale' |
/// 'hybrid' | 'return'`.
enum InvoiceType { sale, hybrid, return_invoice }

enum SaleStatus { draft, completed, voided }

enum PaymentMethod { cash, card, mixed, credit }

enum PurchaseStatus { pending, received, cancelled }

/// Bonus engine types (§4.18, §13): Bonus 1, Bonus 2, or Gift.
enum PurchaseBonusType { bonus_1, bonus_2, gift }

/// Standalone return document type (§4.19).
enum ReturnType { sale_return, purchase_return }

enum AccountType { asset, liability, equity, revenue, expense }

enum JournalEntryStatus { draft, posted, voided }

/// Journal reference types (§4.23). Stored values (see the converter):
/// `'sale' | 'purchase' | 'return' | 'expense' | 'cashbox' |
/// 'opening_balance' | 'adjustment' | 'manual'`; `returnInvoice` persists as
/// `'return'`.
enum JournalReferenceType {
  sale,
  purchase,
  return_invoice,
  expense,
  cashbox,
  opening_balance,
  adjustment,
  manual,
}

/// Sanctioned audit actions (§4.27, §17). The persisted `audit_logs.action`
/// value is resolved through [AuditService] using the plan's canonical strings
/// (`'void'`, `'price_change'`, `'bulk_op'`, `'audit_config'`,
/// `'restore_backup'`); the member name is only a Dart identifier.
enum AuditAction {
  create,
  update,
  delete,
  login,
  logout,
  loginFailed,
  voidOrder,
  restore,
  priceChange,
  bulkOp,
  auditConfig,
  backup,
  restoreBackup,
}

enum ExpenseCategory {
  rent,
  utilities,
  salaries,
  maintenance,
  transportation,
  taxes,
  marketing,
  other,
}

/// Cash box operations (§4.21): `'open' | 'close' | 'deposit' | 'withdraw' |
/// 'sale' | 'expense'`.
enum CashboxTransactionType { open, close, deposit, withdraw, sale, expense }

/// Lost sales lifecycle (§4.28): `open → ordered → resolved | cancelled`.
enum LostSaleStatus { open, ordered, resolved, cancelled }

enum PrescriptionStatus { active, partially_dispensed, dispensed, expired, cancelled }

/// Administrative status of an account / user record (soft delete).
enum RecordStatus { active, inactive }

/// Backup ledger status (§37). `backup`/`restore_backup` are audited (§17).
enum BackupStatus { completed, failed }