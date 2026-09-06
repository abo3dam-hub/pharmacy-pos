import 'package:flutter_test/flutter_test.dart';
import 'package:pharmacy_pos/domain/services/audit_service.dart';
import 'package:pharmacy_pos/shared/models/enum_value_converter.dart';
import 'package:pharmacy_pos/shared/models/enums.dart';

/// Contracts the schema depends on: the persisted values written by the
/// `textEnum` columns equal the enum member *names* (§4), and the custom
/// converters used where the plan's stored literal is not a legal Dart
/// identifier. Renaming any member below silently changes the DB contract.
void main() {
  group('persisted enum values are part of the DB contract', () {
    test('MovementType (§4.9)', () {
      expect(MovementType.opening_balance.name, 'opening_balance');
      expect(MovementType.purchase.name, 'purchase');
      expect(MovementType.sale.name, 'sale');
      expect(MovementType.sale_return.name, 'sale_return');
      expect(MovementType.purchase_return.name, 'purchase_return');
      expect(MovementType.stock_adjustment.name, 'stock_adjustment');
      expect(MovementType.damaged.name, 'damaged');
      expect(MovementType.expired.name, 'expired');
      expect(MovementType.transfer.name, 'transfer');
      expect(MovementType.manual_correction.name, 'manual_correction');
    });

    test('ReturnType / PurchaseBonusType / Cashbox / LostSale (§4.19/18/21/28)',
        () {
      expect(ReturnType.sale_return.name, 'sale_return');
      expect(ReturnType.purchase_return.name, 'purchase_return');
      expect(PurchaseBonusType.bonus_1.name, 'bonus_1');
      expect(PurchaseBonusType.bonus_2.name, 'bonus_2');
      expect(PurchaseBonusType.gift.name, 'gift');
      expect(CashboxTransactionType.open.name, 'open');
      expect(CashboxTransactionType.withdraw.name, 'withdraw');
      expect(CashboxTransactionType.sale.name, 'sale');
      expect(CashboxTransactionType.expense.name, 'expense');
      expect(CashboxTransactionType.payment.name, 'payment');
      expect(CashboxTransactionType.refund.name, 'refund');
      expect(CashboxTransactionType.adjustment.name, 'adjustment');
      expect(LostSaleStatus.open.name, 'open');
      expect(LostSaleStatus.ordered.name, 'ordered');
    });

    test('invoice lifecycle + journal reference types (§19, §4.23)', () {
      expect(SaleStatus.draft.name, 'draft');
      expect(SaleStatus.completed.name, 'completed');
      expect(SaleStatus.partially_returned.name, 'partially_returned');
      expect(SaleStatus.fully_returned.name, 'fully_returned');
      expect(SaleStatus.voided.name, 'voided');
      expect(JournalReferenceType.sale.name, 'sale');
      expect(JournalReferenceType.return_invoice.name, 'return_invoice');
      expect(
          journalReferenceTypeValues.toSql(JournalReferenceType.return_invoice), 'return');
      expect(JournalReferenceType.customer_payment.name, 'customer_payment');
      expect(journalReferenceTypeValues.toSql(JournalReferenceType.customer_payment),
          'customer_payment');
    });

    test('audit actions map to the plan literals (§4.27)', () {
      expect(auditActionToStored(AuditAction.create), 'create');
      expect(auditActionToStored(AuditAction.update), 'update');
      expect(auditActionToStored(AuditAction.delete), 'delete');
      expect(auditActionToStored(AuditAction.login), 'login');
      expect(auditActionToStored(AuditAction.logout), 'logout');
      expect(auditActionToStored(AuditAction.voidOrder), 'void');
      expect(auditActionToStored(AuditAction.restore), 'restore');
      expect(auditActionToStored(AuditAction.priceChange), 'price_change');
      expect(auditActionToStored(AuditAction.bulkOp), 'bulk_op');
      expect(auditActionToStored(AuditAction.auditConfig), 'audit_config');
      expect(auditActionToStored(AuditAction.backup), 'backup');
      expect(auditActionToStored(AuditAction.restoreBackup), 'restore_backup');
    });
  });
}