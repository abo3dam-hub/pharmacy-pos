/// Phase 8 Cash Box integration: the drawer dashboard reconciles with the
/// financial engine and reproduces the exact sums the Z-Report DAO computes
/// (`opening + net moves = expected = declared`).
library;

import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:flutter_test/flutter_test.dart';
import 'package:pharmacy_pos/core/data_grid/page_request.dart';
import 'package:pharmacy_pos/domain/services/cashbox_service.dart';
import 'package:pharmacy_pos/domain/services/sale_service.dart';
import 'package:pharmacy_pos/features/accounts/data/cashbox_dao.dart';
import 'package:pharmacy_pos/features/accounts/domain/entities/cashbox_session.dart';
import 'package:pharmacy_pos/features/sales/data/z_report_dao.dart';
import 'package:pharmacy_pos/shared/database/app_database.dart';
import 'package:pharmacy_pos/shared/models/enums.dart';

import 'helpers.dart';

void main() {
  const service = CashboxService();

  late AppDatabase db;
  late CashboxDao dao;
  late ZReportDao zDao;

  setUp(() async {
    db = newDatabase();
    dao = CashboxDao(db);
    zDao = ZReportDao(db);
  });

  tearDown(() async => db.close());

  Future<String> seedItem({int qty = 10}) async {
    final itemId = await insertItem(db);
    await insertBatch(db, itemId, quantityBase: qty, expiryDays: 90);
    return itemId;
  }

  Future<void> seedCustomer({String id = 'cbx_cust'}) async {
    await db.into(db.customers).insert(CustomersCompanion.insert(
          id: id,
          name: 'عميل آجل',
          hasAccount: const Value(true),
          creditLimitMicros: const Value(0),
          isActive: const Value(true),
          createdAt: DateTime.now().millisecondsSinceEpoch,
          updatedAt: DateTime.now().millisecondsSinceEpoch,
        ));
  }

  test('dashboard session reconciles with Z-Report across a full shift',
      () async {
    final itemId = await seedItem();
    await seedCustomer();

    await service.openDrawer(
      db,
      openingMicros: 50000,
      userId: 'user_admin',
      note: 'شيفت صباحي',
    );

    // Cash sale: 2 × 20.00 → +40000.
    final sale1 = await SaleService().recordSale(
      db,
      SaleRequest(
        invoiceNumber: 'SI-CBX1',
        lines: [
          SaleLineRequest(
              itemId: itemId,
              quantityBase: 2,
              unitPriceMicros: 20000,
              unitTypeId: 'unit_strip'),
        ],
        paymentMethod: PaymentMethod.cash,
        userId: 'user_admin',
        paidMicros: 40000,
      ),
    );

    // Credit sale: 1 × 5.00, nothing paid → no cash movement.
    await SaleService().recordSale(
      db,
      SaleRequest(
        invoiceNumber: 'SI-CBX2',
        lines: [
          SaleLineRequest(
              itemId: itemId,
              quantityBase: 1,
              unitPriceMicros: 5000,
              unitTypeId: 'unit_strip'),
        ],
        paymentMethod: PaymentMethod.credit,
        userId: 'user_admin',
        paidMicros: 0,
        customerId: 'cbx_cust',
      ),
    );

    // Manual cash deposit 15000.
    await service.deposit(
      db,
      amountMicros: 15000,
      reason: 'تحصيل سند',
      userId: 'user_admin',
    );

    // Expected running cash: 50000 + 40000 + 15000 = 105000.
    final s = await dao.currentSession();
    expect(s.status, CashboxStatus.open);
    expect(s.salesCashMicros, 40000,
        reason: 'only collected cash enters the drawer; the open A/R of the '
            'no-down-payment credit sale contributes nothing here');
    expect(s.depositsMicros, 15000);
    expect(s.netMovesMicros, 55000);
    expect(s.expectedClosingMicros, 105000);

    await service.closeDrawer(
      db,
      declaredCloseMicros: 105000,
      reason: 'مطابقة نهاية النوبة',
      userId: 'user_admin',
    );

    final closed = await dao.currentSession();
    expect(closed.status, CashboxStatus.closed);
    expect(closed.differenceMicros, 0);
    expect(closed.declaredCloseMicros, 105000);

    // Cross-check with the Z-Report DAO over the whole shift window.
    final z = await zDao.aggregate(
      fromMillis: closed.openedAtMillis!,
      toMillis: closed.closedAtMillis! + 1,
    );
    expect(z.drawerOpeningMicros, 50000);
    expect(z.drawerNetMovesMicros, 55000);
    expect(z.expectedClosingMicros, 105000);
    expect(z.drawerDeclaredCloseMicros, 105000);
    expect(z.lastRemainingMicros, 105000);
    expect(z.drawerDifferenceMicros, 0);

    // The sale amounts are visible in the Z-Report too.
    expect(z.cashMicros, 40000);
    expect(z.creditMicros, 5000);
    expect(sale1.invoice.id, isNotEmpty);
  });

  test('history is paged, newest-first and DB-side filtered', () async {
    await service.openDrawer(db, openingMicros: 10000, userId: 'user_admin');
    await service.deposit(
      db,
      amountMicros: 5000,
      reason: 'سند 1',
      userId: 'user_admin',
    );
    await service.withdraw(
      db,
      amountMicros: 2000,
      reason: 'مصروف',
      userId: 'user_admin',
    );

    final page1 = await dao.history(page: const PageRequest(page: 1, pageSize: 2));
    expect(page1.items.length, 2);
    expect(page1.total, 3,
        reason: 'open + deposit + withdraw = 3 rows');
    expect(page1.items.first.type, CashboxTransactionType.withdraw,
        reason: 'newest first');
    expect(page1.items.map((e) => e.userName), everyElement(isNotEmpty));
    expect(page1.items.first.remainingMicros, 13000);

    final page2 = await dao.history(
        page: const PageRequest(page: 2, pageSize: 2));
    expect(page2.items.length, 1);
    expect(page2.items.single.type, CashboxTransactionType.open);
    expect(page2.items.single.amountMicros, 10000);

    final depositsOnly = await dao.history(
        page: const PageRequest(page: 1, pageSize: 10),
        type: CashboxTransactionType.deposit);
    expect(depositsOnly.total, 1);
    expect(depositsOnly.items.single.amountMicros, 5000);
    expect(depositsOnly.items.single.note, 'سند 1');
  });

  test('a shortage and deposits survive a full close + reopening', () async {
    await service.openDrawer(db, openingMicros: 50000, userId: 'user_admin');
    await service.deposit(
      db,
      amountMicros: 10000,
      reason: 'سند',
      userId: 'user_admin',
    );
    // Declare 58000 while the drawer should hold 60000 (shortage 2000).
    await service.closeDrawer(
      db,
      declaredCloseMicros: 58000,
      reason: 'عجز 2000',
      userId: 'user_admin',
    );
    final closed = await dao.currentSession();
    expect(closed.status, CashboxStatus.closed);
    expect(closed.differenceMicros, -2000);
    expect(closed.hasDifference, isTrue);

    // New shift: opening now continues the running balance history.
    await service.openDrawer(db, openingMicros: 30000, userId: 'user_admin');
    final reopened = await dao.currentSession();
    expect(reopened.status, CashboxStatus.open);
    expect(reopened.openingMicros, 30000);
    expect(reopened.expectedClosingMicros, 30000,
        reason: 'new session window starts at the second open');
  });
}