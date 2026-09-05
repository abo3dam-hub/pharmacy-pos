/// Shared domain enums used by entities and the drift schema.
///
/// Enum values are persisted by *name* into a TEXT column, so the names below
/// are part of the database contract and must not be renamed.
library;

/// The ten stock-movement categories.
///
/// Opening balance:رصيد افتتاحي | Purchase: شراء | Sale: بيع |
/// Sale return: مرتجع بيع | Purchase return: مرتجع مشتريات |
/// Stock adjustment: جرد/تسوية | Damaged: تالف | Expired: منتهي الصلاحية |
/// Transfer: انتقال/تحويل | Manual correction: تصحيح يدوي
enum MovementType {
  openingBalance,
  purchase,
  sale,
  saleReturn,
  purchaseReturn,
  stockAdjustment,
  damaged,
  expired,
  transfer,
  manualCorrection,
}

enum InvoiceType { sale, hybrid, returnInvoice }

enum SaleStatus { draft, completed, voided }

enum PaymentMethod { cash, network, mixed, credit }

enum PurchaseStatus { pending, received, cancelled }

enum PurchaseBonusType { freeGoods, priceDiscount }

enum ReturnType { saleReturn, purchaseReturn }

enum AccountType { asset, liability, equity, revenue, expense }

enum JournalEntryStatus { draft, posted, voided }

enum JournalReferenceType {
  sale,
  purchase,
  returnInvoice,
  expense,
  cashbox,
  openingBalance,
  adjustment,
  manual,
}

enum AuditAction {
  create,
  update,
  delete,
  login,
  logout,
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

enum CashboxTransactionType {
  opening,
  closing,
  sale,
  purchase,
  expense,
  deposit,
  withdrawal,
  adjustment,
}

enum LostSaleStatus { open, ordered, fulfilled, closed }

enum PrescriptionStatus { active, dispensed, expired, cancelled }

/// Administrative status of an account / user record (soft delete).
enum RecordStatus { active, inactive }