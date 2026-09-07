import 'package:drift/drift.dart';

import '../../core/constants/permission_codes.dart';
import '../../core/errors/exceptions.dart';
import '../../core/util/ids.dart';
import '../../shared/database/app_database.dart';
import '../../shared/models/enums.dart';
import 'audit_service.dart';
import 'financial_posting_service.dart';
import 'permission_service.dart';

/// Customer payments on account (§13, §18): collecting what the customer owes
/// (payment) or returning an overpayment (refund). Each movement updates the
/// derived customer balance, the drawer/bank ledger, the double-entry journal
/// and the audit trail in one transaction.
class CustomerPaymentService {
  CustomerPaymentService({
    AuditService? audit,
    PermissionService? permissions,
    FinancialPostingService? financial,
  })  : _audit = audit ?? const AuditService(),
        _permissions = permissions ?? const PermissionService(),
        _financial = financial ?? const FinancialPostingService();

  final AuditService _audit;
  final PermissionService _permissions;
  final FinancialPostingService _financial;

  /// Money received from [customerId] (reduces their balance). [amountMicros]
  /// must be positive; the cash/card split must sum to it.
  Future<CustomerPaymentRow> recordCustomerPayment(
    AppDatabase db, {
    required String paymentNumber,
    required String customerId,
    required int amountMicros,
    required int cashMicros,
    required int cardMicros,
    String? invoiceId,
    String? note,
    required String userId,
  }) {
    if (amountMicros <= 0) {
      throw ValidationException('مبلغ السداد يجب أن يكون موجباً');
    }
    return _record(
      db,
      paymentNumber: paymentNumber,
      customerId: customerId,
      signedAmountMicros: amountMicros,
      cashMicros: cashMicros,
      cardMicros: cardMicros,
      invoiceId: invoiceId,
      note: note,
      userId: userId,
    );
  }

  /// Money refunded to [customerId] (reduces credit back toward zero).
  /// [amountMicros] is the positive refund size; the cash/card split must sum
  /// to it.
  Future<CustomerPaymentRow> recordCustomerRefund(
    AppDatabase db, {
    required String paymentNumber,
    required String customerId,
    required int amountMicros,
    required int cashMicros,
    required int cardMicros,
    String? invoiceId,
    String? note,
    required String userId,
  }) {
    if (amountMicros <= 0) {
      throw ValidationException('مبلغ الاسترداد يجب أن يكون موجباً');
    }
    return _record(
      db,
      paymentNumber: paymentNumber,
      customerId: customerId,
      signedAmountMicros: -amountMicros,
      cashMicros: cashMicros,
      cardMicros: cardMicros,
      invoiceId: invoiceId,
      note: note,
      userId: userId,
    );
  }

  Future<CustomerPaymentRow> _record(
    AppDatabase db, {
    required String paymentNumber,
    required String customerId,
    required int signedAmountMicros,
    required int cashMicros,
    required int cardMicros,
    String? invoiceId,
    String? note,
    required String userId,
  }) async {
    await _permissions.requireUserPermission(
        db, userId, Perm.salesCreate);
    if (paymentNumber.trim().isEmpty) {
      throw ValidationException('رقم سند السداد مطلوب');
    }
    if (cashMicros < 0 || cardMicros < 0) {
      throw ValidationException('مبالغ السداد لا يمكن أن تكون سالبة');
    }
    final absAmount = signedAmountMicros.abs();
    if (cashMicros + cardMicros != absAmount) {
      throw ValidationException(
          'تقسيم السداد (نقدي + بطاقة) يجب أن يساوي المبلغ $absAmount');
    }
    final isRefund = signedAmountMicros < 0;

    return db.transaction(() async {
      final now = DateTime.now().millisecondsSinceEpoch;

      final customer = await (db.select(db.customers)
            ..where((c) => c.id.equals(customerId)))
          .getSingleOrNull();
      if (customer == null) {
        throw NotFoundException('العميل غير موجود: $customerId');
      }
      if (!customer.hasAccount) {
        throw ValidationException('العميل لا يملك حساب آجل (has_account)');
      }
      if (!customer.isActive) {
        throw ValidationException('العميل غير نشط');
      }
      if (isRefund) {
        final creditBalance = customer.balanceMicros;
        if (creditBalance >= 0 || absAmount > -creditBalance) {
          throw InvalidOperationException(
              'لا يوجد رصيد دائن كافٍ للعميل لاسترداد $absAmount '
              '(رصيده الحالي: $creditBalance)');
        }
      }
      if (invoiceId != null) {
        final invoice = await (db.select(db.salesInvoices)
              ..where((i) => i.id.equals(invoiceId)))
            .getSingleOrNull();
        if (invoice == null) {
          throw NotFoundException('الفاتورة غير موجودة: $invoiceId');
        }
      }

      final paymentMethod = cardMicros == 0
          ? PaymentMethod.cash
          : cashMicros == 0
              ? PaymentMethod.card
              : PaymentMethod.mixed;

      final paymentId = newId('cpay');
      await db.into(db.customerPayments).insert(
            CustomerPaymentsCompanion.insert(
              id: paymentId,
              paymentNumber: paymentNumber.trim(),
              customerId: customerId,
              invoiceId:
                  invoiceId != null ? Value(invoiceId) : const Value(null),
              amountMicros: signedAmountMicros,
              cashMicros: Value(cashMicros),
              cardMicros: Value(cardMicros),
              paymentMethod: paymentMethod,
              note: note != null ? Value(note) : const Value(null),
              userId: userId,
              createdAt: now,
              updatedAt: now,
            ),
          );

      if (isRefund) {
        // Phase 10.1: link the refund back to the customer's most recent
        // original payment journal (explicit reversal-of relationship). The
        // refund stays a distinct event with its own reference.
        String? reversalEntryId;
        final originalPayment = await (db.select(db.customerPayments)
              ..where((p) =>
                  p.customerId.equals(customerId) &
                  p.amountMicros.isBiggerThanValue(0))
              ..orderBy([(o) => OrderingTerm.desc(o.createdAt)])
              ..limit(1))
            .getSingleOrNull();
        if (originalPayment != null) {
          final originalEntry = await (db.select(db.journalEntries)
                ..where((je) =>
                    je.refType.equalsValue(
                        JournalReferenceType.customer_payment) &
                    je.refId.equals(originalPayment.id) &
                    je.isReversal.equals(false)))
              .getSingleOrNull();
          reversalEntryId = originalEntry?.id;
        }
        await _financial.postCustomerRefund(
          db,
          paymentId: paymentId,
          paymentNumber: paymentNumber.trim(),
          amountMicros: absAmount,
          cashMicros: cashMicros,
          cardMicros: cardMicros,
          userId: userId,
          atMillis: now,
          reversalOfEntryId: reversalEntryId,
        );
      } else {
        await _financial.postCustomerPayment(
          db,
          paymentId: paymentId,
          paymentNumber: paymentNumber.trim(),
          amountMicros: absAmount,
          cashMicros: cashMicros,
          cardMicros: cardMicros,
          userId: userId,
          atMillis: now,
        );
      }

      await _financial.syncCustomerBalance(db, customerId, at: now);

      await _audit.write(
        db,
        userId: userId,
        action: AuditAction.create,
        entityType: 'customer_payment',
        entityId: paymentId,
        after: {
          'payment_number': paymentNumber.trim(),
          if (isRefund) 'refund_micros': absAmount else 'payment_micros': absAmount,
          'customer_id': customerId,
        },
      );

      return (await (db.select(db.customerPayments)
            ..where((p) => p.id.equals(paymentId)))
          .getSingle());
    });
  }
}