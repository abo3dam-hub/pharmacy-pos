import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:flutter_test/flutter_test.dart';
import 'package:pharmacy_pos/features/dashboard/application/dashboard_controller.dart';
import 'package:pharmacy_pos/features/dashboard/data/dashboard_dao.dart';
import 'package:pharmacy_pos/features/sales/data/z_report_dao.dart';
import 'package:pharmacy_pos/shared/database/app_database.dart';
import 'package:pharmacy_pos/shared/models/enums.dart';

import 'helpers.dart';

void main() {
  late AppDatabase db;
  late DashboardController controller;

  setUp(() {
    db = newDatabase();
    controller = DashboardController(ZReportDao(db), DashboardDao(db));
  });

  tearDown(() async => db.close());

  Future<void> insertSale({
    required String number,
    required int totalMicros,
    int profitMicros = 20000,
    required int atMillis,
    SaleStatus status = SaleStatus.completed,
  }) async {
    final now = DateTime.now().millisecondsSinceEpoch;
    await db.into(db.users).insert(
          UsersCompanion.insert(
            id: 'user_cashier',
            username: 'cashier',
            fullName: 'كاشير',
            passwordHash: 'x',
            roleId: 'role_admin',
            isActive: const Value(true),
            createdAt: now,
            updatedAt: now,
          ),
          mode: InsertMode.insertOrIgnore,
        );
    await db.into(db.salesInvoices).insert(
          SalesInvoicesCompanion.insert(
            id: 'sale_$number',
            invoiceNumber: number,
            invoiceType: InvoiceType.sale,
            saleStatus: status,
            userId: 'user_cashier',
            subtotalMicros: Value(totalMicros),
            discountTotalMicros: const Value(0),
            vatTotalMicros: const Value(0),
            totalMicros: Value(totalMicros),
            paidMicros: Value(totalMicros),
            profitMicros: Value(profitMicros),
            paymentMethod: PaymentMethod.cash,
            changeMicros: const Value(0),
            cashMicros: Value(totalMicros),
            cardMicros: const Value(0),
            creditMicros: const Value(0),
            remainingMicros: const Value(0),
            createdAt: atMillis,
            updatedAt: atMillis,
          ),
          mode: InsertMode.insertOrIgnore,
        );
  }

  test('controller loads a real snapshot with today totals', () async {
    final now = DateTime.now().millisecondsSinceEpoch;
    await awaitCategory(db);
    await insertItem(db, barcode: '6291041500213');
    await insertSale(
        number: 'S-1', totalMicros: 50000, atMillis: now);

    final failure = await controller.load();

    expect(failure, isNull);
    final state = controller.state;
    expect(state.status, DashboardStatus.ready);
    final snapshot = state.snapshot!;
    expect(snapshot.todayInvoiceCount, 1);
    expect(snapshot.todayTotalMicros, 50000);
    expect(snapshot.todayProfitMicros, 20000);
    expect(snapshot.activeItems, 1);
  });

  test('low-stock and out-of-stock counters are derived from policy bounds',
      () async {
    await awaitCategory(db);
    await insertItem(db,
        barcode: '1111111111111',
        id: 'it_low');
    await (db.update(db.items)..where((i) => i.id.equals('it_low'))).write(
        ItemsCompanion(
      currentStockBase: const Value(5),
      minimumStockBase: const Value(10),
    ));
    await insertItem(db,
        barcode: '2222222222222',
        id: 'it_out');
    await (db.update(db.items)..where((i) => i.id.equals('it_out'))).write(
        ItemsCompanion(currentStockBase: const Value(0)));

    await controller.load();

    final snapshot = controller.state.snapshot!;
    expect(snapshot.lowStockCount, 1);
    expect(snapshot.outOfStockCount, 1);
    expect(snapshot.lowStockItems.single.itemId, 'it_low');
  });

  test('near-expiry batches surface only those within the window',
      () async {
    final now = DateTime.now().millisecondsSinceEpoch;
    final day = 24 * 60 * 60 * 1000;
    await awaitCategory(db);
    final itemId = await insertItem(db, barcode: '6291041500213');
    await db.into(db.batches).insert(BatchesCompanion.insert(
          id: 'bat_near',
          itemId: itemId,
          batchNumber: 'B-NEAR',
          quantityBase: const Value(5),
          originalQuantityBase: 5,
          unitCostMicros: const Value(1000),
          isVoided: const Value(false),
          expiryDate: Value(now + 30 * day),
          createdAt: now,
          updatedAt: now,
        ));
    await db.into(db.batches).insert(BatchesCompanion.insert(
          id: 'bat_far',
          itemId: itemId,
          batchNumber: 'B-FAR',
          quantityBase: const Value(5),
          originalQuantityBase: 5,
          unitCostMicros: const Value(1000),
          isVoided: const Value(false),
          expiryDate: Value(now + 400 * day),
          createdAt: now,
          updatedAt: now,
        ));

    await controller.load();

    final snapshot = controller.state.snapshot!;
    expect(snapshot.nearExpiryBatches.single.batchId, 'bat_near');
  });

  test('recent activity lists latest sales first', () async {
    final now = DateTime.now().millisecondsSinceEpoch;
    await insertSale(
        number: 'S-OLD', totalMicros: 50000, atMillis: now - 60000);
    await insertSale(
        number: 'S-NEW', totalMicros: 90000, atMillis: now);

    await controller.load();

    final snapshot = controller.state.snapshot!;
    expect(snapshot.recentSales.first.number, 'S-NEW');
    expect(snapshot.recentSales.last.number, 'S-OLD');
    expect(snapshot.todayInvoiceCount, 2);
  });
}