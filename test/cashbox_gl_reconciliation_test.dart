import 'package:drift/drift.dart' show Value;
import 'package:flutter_test/flutter_test.dart';
import 'package:pharmacy_pos/domain/services/cashbox_service.dart';
import 'package:pharmacy_pos/domain/services/customer_payment_service.dart';
import 'package:pharmacy_pos/domain/services/financial_posting_service.dart';
import 'package:pharmacy_pos/shared/database/app_database.dart';
import 'package:pharmacy_pos/shared/models/enums.dart';

import 'helpers.dart';

/// Phase 10 Step 9 — Cash-box ↔ GL reconciliation.
///
/// Invariant: the drawer ledger (SUM of cash-box movements) reconciles to the
/// GL Cash account (1000) balance after any sequence of open + cash moves
/// (deposit / withdraw / adjust / expense / customer payment). The opening
/// float is mirrored into the GL (Dr Cash, Cr Capital) so the two stay equal.
void main() {
  const service = CashboxService();
  const financial = FinancialPostingService();
  final payments = CustomerPaymentService();
  late AppDatabase db;

  setUp(() {
    db = newDatabase();
  });

  tearDown(() async => db.close());

  Future<int> cashboxTotal() async {
    final row = await db.customSelect(
        'SELECT COALESCE(SUM(amount_micros), 0) AS s FROM cashbox_transactions')
        .getSingle();
    return row.read<int>('s');
  }

  Future<int> glCash() async {
    final row = await (db.select(db.accounts)
          ..where((a) => a.code.equals(SystemAccountCode.cash)))
        .getSingle();
    return row.balanceMicros;
  }

  Future<String> seedCustomer() async {
    final id = 'cust_rec_${DateTime.now().millisecondsSinceEpoch}';
    final now = DateTime.now().millisecondsSinceEpoch;
    await db.into(db.customers).insert(CustomersCompanion.insert(
          id: id,
          name: 'عميل السداد',
          hasAccount: const Value(true),
          creditLimitMicros: const Value(10000000),
          isActive: const Value(true),
          createdAt: now,
          updatedAt: now,
        ));
    return id;
  }

  Future<void> expectReconciled() async {
    expect(await glCash(), await cashboxTotal(),
        reason: 'GL Cash (1000) must equal the drawer ledger after cash moves');
  }

  test('drawer ledger reconciles to GL cash across open + manual cash moves',
      () async {
    // Open with a float (mirrored into GL: Dr Cash / Cr Capital).
    await service.openDrawer(db, openingMicros: 50000, userId: 'user_admin');
    await expectReconciled();

    // Deposit cash in the drawer.
    await service.deposit(db,
        amountMicros: 10000, reason: 'إيداع نقدي', userId: 'user_admin');
    await expectReconciled();

    // Withdraw cash out of the drawer.
    await service.withdraw(db,
        amountMicros: 6000, reason: 'سحب نقدي', userId: 'user_admin');
    await expectReconciled();

    // Authorized positive adjustment (cash overage).
    await service.adjustCash(db,
        amountMicros: 500, reason: 'فرق موجب', userId: 'user_admin');
    await expectReconciled();

    // Authorized negative adjustment (cash shortage).
    await service.adjustCash(db,
        amountMicros: -300, reason: 'فرق سالب', userId: 'user_admin');
    await expectReconciled();

    // Cash expense outflow.
    await financial.recordExpense(
      db,
      category: ExpenseCategory.utilities,
      description: 'كهرباء',
      amountMicros: 2000,
      userId: 'user_admin',
    );
    await expectReconciled();
  });

  test('drawer ledger reconciles to GL cash with a customer payment on account',
      () async {
    await service.openDrawer(db, openingMicros: 100000, userId: 'user_admin');
    final customerId = await seedCustomer();

    // Collect 1500 cash on account — reduces receivable, increases drawer.
    await payments.recordCustomerPayment(
      db,
      paymentNumber: 'CP-RECON-1',
      customerId: customerId,
      amountMicros: 1500,
      cashMicros: 1500,
      cardMicros: 0,
      userId: 'user_admin',
    );
    await expectReconciled();

    // Collect split cash/card — only cash enters the drawer; card hits bank.
    await payments.recordCustomerPayment(
      db,
      paymentNumber: 'CP-RECON-2',
      customerId: customerId,
      amountMicros: 3000,
      cashMicros: 1800,
      cardMicros: 1200,
      userId: 'user_admin',
    );
    await expectReconciled();
  });
}
