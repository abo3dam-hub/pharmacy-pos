import 'package:drift/drift.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pharmacy_pos/core/errors/exceptions.dart';
import 'package:pharmacy_pos/core/util/ids.dart';
import 'package:pharmacy_pos/domain/services/accounting_period_service.dart';
import 'package:pharmacy_pos/domain/services/customer_payment_service.dart';
import 'package:pharmacy_pos/domain/services/financial_posting_service.dart';
import 'package:pharmacy_pos/shared/database/app_database.dart';
import 'package:pharmacy_pos/shared/models/enums.dart';

import 'helpers.dart';

/// Phase 10.1 — Item A (customer payment/refund posting) and the customer side
/// of Item B (closed-period rejection). Pins the reversal semantics:
/// a refund is a distinct event flagged `isReversal` and linked back to the
/// most recent original payment journal.
void main() {
  late AppDatabase db;
  const financial = FinancialPostingService();
  final payments = CustomerPaymentService();
  final periods = AccountingPeriodService();

  setUp(() {
    db = newDatabase();
  });

  tearDown(() async {
    await db.close();
  });

  Future<String> seedCustomer() async {
    final id = 'cust_${newId('c')}';
    final now = DateTime.now().millisecondsSinceEpoch;
    await db.into(db.customers).insert(CustomersCompanion.insert(
          id: id,
          name: 'عميل آجل',
          hasAccount: const Value(true),
          creditLimitMicros: const Value(0),
          isActive: const Value(true),
          createdAt: now,
          updatedAt: now,
        ));
    return id;
  }

  Future<int> accountBalance(String code) async {
    final row = await (db.select(db.accounts)
          ..where((a) => a.code.equals(code)))
        .getSingle();
    return row.balanceMicros;
  }

  Future<int> cashboxTotal() async {
    final row = await db.customSelect(
        'SELECT COALESCE(SUM(amount_micros), 0) AS s FROM cashbox_transactions').getSingle();
    return row.read<int>('s');
  }

  Future<int> runCount(String table) async {
    final row =
        await db.customSelect('SELECT COUNT(*) AS c FROM $table').getSingle();
    return row.read<int>('c');
  }

  Future<JournalEntryRow> journalFor(String refId) async {
    return (db.select(db.journalEntries)
          ..where((j) => j.refId.equals(refId)))
        .getSingle();
  }

  Future<JournalEntryRow> lastOriginalPaymentJournal() async {
    return (db.select(db.journalEntries)
          ..where((j) =>
              j.refType.equalsValue(JournalReferenceType.customer_payment) &
              j.isReversal.equals(false))
          ..orderBy([(o) => OrderingTerm.desc(o.createdAt)])
          ..limit(1))
        .getSingle();
  }

  Future<List<int>> journalTotals(String refId) async {
    final row = await db.customSelect(
      'SELECT total_debit_micros AS d, total_credit_micros AS c '
      'FROM journal_entries WHERE ref_id = ?1',
      variables: [Variable.withString(refId)],
    ).getSingle();
    return [row.read<int>('d'), row.read<int>('c')];
  }

  Future<void> closeTodayPeriod() async {
    final now = DateTime.now();
    final start = DateTime(now.year, now.month, now.day)
        .millisecondsSinceEpoch;
    final end = start + 2 * 24 * 60 * 60 * 1000;
    final id = await periods.createPeriod(db,
        name: 'اليوم', startDate: start, endDate: end, userId: 'user_admin');
    await periods.closePeriod(db,
        periodId: id, userId: 'user_admin', closeReason: 'إقفال للاختبار');
  }

  // ── Item A: payment postings ──────────────────────────────────────────

  test('customer payment posts exactly one original journal + drawer + audit',
      () async {
    final cust = await seedCustomer();
    final p = await payments.recordCustomerPayment(
      db,
      paymentNumber: 'CP-A1',
      customerId: cust,
      amountMicros: 20000,
      cashMicros: 20000,
      cardMicros: 0,
      userId: 'user_admin',
    );

    final entry = await journalFor(p.id);
    expect(entry.refType, JournalReferenceType.customer_payment);
    expect(entry.isReversal, isFalse);
    expect(await journalTotals(p.id), [20000, 20000]);

    // Single original event: one journal + one drawer row + one audit record.
    expect(await runCount('journal_entries'), 1);
    expect(await cashboxTotal(), 20000);
    expect(await accountBalance(SystemAccountCode.cash), 20000);
    expect(await accountBalance(SystemAccountCode.accountsReceivable), -20000);
    final audits = await db.select(db.auditLogs).get();
    expect(
        audits.where((a) => a.entityType == 'customer_payment'), hasLength(1));
  });

  test('repeating the same payment reference is rejected by the guard',
      () async {
    await expectLater(
      financial.postCustomerPayment(
        db,
        paymentId: 'p-dup',
        paymentNumber: 'CP-A2',
        amountMicros: 20000,
        cashMicros: 20000,
        cardMicros: 0,
        userId: 'user_admin',
        atMillis: DateTime.now().millisecondsSinceEpoch,
      ),
      completes,
    );
    await expectLater(
      financial.postCustomerPayment(
        db,
        paymentId: 'p-dup',
        paymentNumber: 'CP-A2',
        amountMicros: 20000,
        cashMicros: 20000,
        cardMicros: 0,
        userId: 'user_admin',
        atMillis: DateTime.now().millisecondsSinceEpoch,
      ),
      throwsA(isA<InvalidOperationException>()),
    );
    expect(await runCount('journal_entries'), 1);
    expect(await cashboxTotal(), 20000);
  });

  test('refund posts as a distinct reversal linked to the original payment',
      () async {
    final cust = await seedCustomer();
    await payments.recordCustomerPayment(
      db,
      paymentNumber: 'CP-B1',
      customerId: cust,
      amountMicros: 20000,
      cashMicros: 20000,
      cardMicros: 0,
      userId: 'user_admin',
    );
    final p2 = await payments.recordCustomerPayment(
      db,
      paymentNumber: 'CP-B2',
      customerId: cust,
      amountMicros: 5000,
      cashMicros: 5000,
      cardMicros: 0,
      userId: 'user_admin',
    );

    final refund = await payments.recordCustomerRefund(
      db,
      paymentNumber: 'CP-B3',
      customerId: cust,
      amountMicros: 5000,
      cashMicros: 5000,
      cardMicros: 0,
      userId: 'user_admin',
    );

    // Refund is a distinct event: its own reference, flagged as a reversal.
    final refundEntry = await journalFor(refund.id);
    expect(refundEntry.isReversal, isTrue);
    expect(refundEntry.refId, refund.id);
    expect(refundEntry.refType, JournalReferenceType.customer_payment);

    // It links back to the most recent original payment (p2), not to the
    // earlier one and never to itself.
    final original = await lastOriginalPaymentJournal();
    expect(original.refId, p2.id);
    expect(refundEntry.reversalOfEntryId, original.id);
    expect(refundEntry.id, isNot(original.id));

    // Balanced reversal journal; drawer back to +20000 (20000+5000-5000).
    expect(await journalTotals(refund.id), [5000, 5000]);
    expect(await cashboxTotal(), 20000);
    expect(await accountBalance(SystemAccountCode.accountsReceivable), -20000);

    // Audit exists for payment and refund.
    final audits = await db.select(db.auditLogs).get();
    final paymentAudits =
        audits.where((a) => a.entityType == 'customer_payment');
    expect(paymentAudits, hasLength(3));
    expect(audits.any((a) => (a.afterData ?? '').contains('refund_micros')),
        isTrue);
  });

  test('same refund cannot be posted twice', () async {
    final now = DateTime.now().millisecondsSinceEpoch;
    await financial.postCustomerRefund(
      db,
      paymentId: 'ref-dup',
      paymentNumber: 'CP-B4',
      amountMicros: 1000,
      cashMicros: 1000,
      cardMicros: 0,
      userId: 'user_admin',
      atMillis: now,
    );
    await expectLater(
      financial.postCustomerRefund(
        db,
        paymentId: 'ref-dup',
        paymentNumber: 'CP-B4',
        amountMicros: 1000,
        cashMicros: 1000,
        cardMicros: 0,
        userId: 'user_admin',
        atMillis: now,
      ),
      throwsA(isA<InvalidOperationException>()),
    );
    expect(await runCount('journal_entries'), 1);
  });

  test('refund cannot exceed the refundable credit balance', () async {
    final cust = await seedCustomer();

    // No credit balance yet → service refuses at business level.
    await expectLater(
      payments.recordCustomerRefund(
        db,
        paymentNumber: 'CP-C1',
        customerId: cust,
        amountMicros: 5000,
        cashMicros: 5000,
        cardMicros: 0,
        userId: 'user_admin',
      ),
      throwsA(isA<InvalidOperationException>()),
    );

    // Build a −20000 credit, then refund more than it → refused again.
    await payments.recordCustomerPayment(
      db,
      paymentNumber: 'CP-C2',
      customerId: cust,
      amountMicros: 20000,
      cashMicros: 20000,
      cardMicros: 0,
      userId: 'user_admin',
    );
    await expectLater(
      payments.recordCustomerRefund(
        db,
        paymentNumber: 'CP-C3',
        customerId: cust,
        amountMicros: 30000,
        cashMicros: 30000,
        cardMicros: 0,
        userId: 'user_admin',
      ),
      throwsA(isA<InvalidOperationException>()),
    );
    expect(await runCount('customer_payments'), 1);
  });

  test('original payment remains traceable from the refund', () async {
    final cust = await seedCustomer();
    final p1 = await payments.recordCustomerPayment(
      db,
      paymentNumber: 'CP-D1',
      customerId: cust,
      amountMicros: 10000,
      cashMicros: 10000,
      cardMicros: 0,
      userId: 'user_admin',
    );
    final refund = await payments.recordCustomerRefund(
      db,
      paymentNumber: 'CP-D2',
      customerId: cust,
      amountMicros: 4000,
      cashMicros: 4000,
      cardMicros: 0,
      userId: 'user_admin',
    );

    final refundEntry = await journalFor(refund.id);
    final linked = await (db.select(db.journalEntries)
          ..where((j) => j.id.equals(refundEntry.reversalOfEntryId!)))
        .getSingle();
    expect(linked.refId, p1.id);
    expect(linked.isReversal, isFalse);
    expect(linked.refType, JournalReferenceType.customer_payment);
  });

  // ── Item B: closed-period enforcement on the payment path ──────────────

  test('customer payment inside a closed period is rejected atomically',
      () async {
    final cust = await seedCustomer();
    await closeTodayPeriod();

    final paymentsBefore = await runCount('customer_payments');
    final journalsBefore = await runCount('journal_entries');
    final cashboxBefore = await runCount('cashbox_transactions');
    final auditBefore = await runCount('audit_logs');

    await expectLater(
      payments.recordCustomerPayment(
        db,
        paymentNumber: 'CP-E1',
        customerId: cust,
        amountMicros: 20000,
        cashMicros: 20000,
        cardMicros: 0,
        userId: 'user_admin',
      ),
      throwsA(isA<InvalidOperationException>()),
    );

    expect(await runCount('customer_payments'), paymentsBefore);
    expect(await runCount('journal_entries'), journalsBefore);
    expect(await runCount('cashbox_transactions'), cashboxBefore);
    expect(await runCount('audit_logs'), auditBefore);
  });

  test('customer refund inside a closed period is rejected atomically',
      () async {
    final cust = await seedCustomer();
    // Build a credit while the ledger is open.
    await payments.recordCustomerPayment(
      db,
      paymentNumber: 'CP-F1',
      customerId: cust,
      amountMicros: 10000,
      cashMicros: 10000,
      cardMicros: 0,
      userId: 'user_admin',
    );
    await closeTodayPeriod();

    final paymentsBefore = await runCount('customer_payments');
    final journalsBefore = await runCount('journal_entries');
    final cashboxBefore = await runCount('cashbox_transactions');

    await expectLater(
      payments.recordCustomerRefund(
        db,
        paymentNumber: 'CP-F2',
        customerId: cust,
        amountMicros: 4000,
        cashMicros: 4000,
        cardMicros: 0,
        userId: 'user_admin',
      ),
      throwsA(isA<InvalidOperationException>()),
    );

    expect(await runCount('customer_payments'), paymentsBefore);
    expect(await runCount('journal_entries'), journalsBefore);
    expect(await runCount('cashbox_transactions'), cashboxBefore);
  });
}