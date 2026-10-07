import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:flutter_test/flutter_test.dart';
import 'package:pharmacy_pos/domain/services/financial_posting_service.dart';
import 'package:pharmacy_pos/features/dashboard/application/dashboard_controller.dart';
import 'package:pharmacy_pos/features/dashboard/data/dashboard_dao.dart';
import 'package:pharmacy_pos/features/reports/data/reports_dao.dart';
import 'package:pharmacy_pos/features/sales/data/z_report_dao.dart';
import 'package:pharmacy_pos/shared/database/app_database.dart';
import 'package:pharmacy_pos/shared/models/enums.dart';

import 'helpers.dart';

void main() {
  late AppDatabase db;
  late DashboardController controller;

  setUp(() {
    db = newDatabase();
    controller = DashboardController(
      ZReportDao(db),
      DashboardDao(db),
      ReportsDao(db),
    );
  });

  tearDown(() async => db.close());

  Future<void> postSaleJournal({
    required String refId,
    required int totalMicros,
    required int cogsMicros,
    required int atMillis,
  }) {
    // The dashboard summary cards read the ledger (income statement), so the
    // test must post the sale's journal exactly like SaleService does.
    return FinancialPostingService().postJournalEntry(
      db,
      refType: JournalReferenceType.sale,
      refId: refId,
      entryDate: atMillis,
      description: 'بيع اختبار',
      lines: [
        JournalLineDraft(
            accountCode: SystemAccountCode.cash, debitMicros: totalMicros),
        JournalLineDraft(
            accountCode: SystemAccountCode.salesRevenue,
            creditMicros: totalMicros),
        JournalLineDraft(
            accountCode: SystemAccountCode.costOfGoodsSold,
            debitMicros: cogsMicros),
        JournalLineDraft(
            accountCode: SystemAccountCode.inventory, creditMicros: cogsMicros),
      ],
      createdBy: 'user_cashier',
    );
  }

  Future<void> insertSale({
    required String number,
    required int totalMicros,
    int profitMicros = 20000,
    required int atMillis,
    SaleStatus status = SaleStatus.completed,
  }) async {
    final now = DateTime.now().millisecondsSinceEpoch;
    await db
        .into(db.users)
        .insert(
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
    await db
        .into(db.salesInvoices)
        .insert(
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
    await postSaleJournal(
      refId: 'sale_$number',
      totalMicros: totalMicros,
      cogsMicros: totalMicros - profitMicros,
      atMillis: atMillis,
    );
  }

  test('controller loads a real snapshot with today totals', () async {
    final now = DateTime.now().millisecondsSinceEpoch;
    await awaitCategory(db);
    final itemId = await insertItem(db, barcode: '6291041500213');
    // Active-items counts stocked items (2026-10-07): give it stock.
    await (db.update(db.items)..where((i) => i.id.equals(itemId))).write(
      const ItemsCompanion(currentStockBase: Value(10)),
    );
    await insertSale(number: 'S-1', totalMicros: 50000, atMillis: now);

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

  test(
    'dashboard cards are net of returns and count whole packages '
    '(Ali 2026-10-05: 2 boxes of a 3-part item, 1 box returned)',
    () async {
      final now = DateTime.now().millisecondsSinceEpoch;
      await awaitCategory(db);
      final itemId = await insertItem(db, barcode: '6291041500999');
      // The item's commercial package holds 3 base units.
      await db.into(db.itemUnits).insert(
            ItemUnitsCompanion.insert(
              id: 'iu_test_1',
              itemId: itemId,
              baseUnitId: 'u_base',
              largeUnitId: 'u_large',
              unitsPerLarge: const Value(3),
            ),
          );
      // Sale: 2 packages = 6 base units, 47000 revenue, 36000 COGS.
      await insertSale(
        number: 'S-2',
        totalMicros: 47000,
        profitMicros: 11000,
        atMillis: now,
      );
      await db.into(db.salesInvoiceItems).insert(
            SalesInvoiceItemsCompanion.insert(
              id: 'sii_test_1',
              invoiceId: 'sale_S-2',
              itemId: itemId,
              batchId: 'bat_test_1',
              unitTypeId: 'u_large',
              quantityBaseSigned: 6,
              unitPriceMicros: 23500,
              lineTotalMicros: const Value(47000),
              createdAt: now,
            ),
          );
      // Return: 1 package = 3 base units.
      await db.into(db.returns).insert(
            ReturnsCompanion.insert(
              id: 'ret_test_1',
              returnNumber: 'RT-TEST-1',
              type: ReturnType.sale_return,
              originalInvoiceId: 'sale_S-2',
              originalInvoiceType: 'sale',
              userId: 'user_cashier',
              totalMicros: const Value(23500),
              createdAt: now,
              updatedAt: now,
            ),
          );
      await db.into(db.returnItems).insert(
            ReturnItemsCompanion.insert(
              id: 'ri_test_1',
              returnId: 'ret_test_1',
              originalInvoiceItemId: 'sii_test_1',
              itemId: itemId,
              batchId: 'bat_test_1',
              quantityBaseSigned: 3,
              unitCostMicros: 18000,
              amountMicros: 23500,
              createdAt: now,
            ),
          );
      // The return's ledger postings (like ReturnService writes them).
      await FinancialPostingService().postJournalEntry(
        db,
        refType: JournalReferenceType.return_invoice,
        refId: 'ret_test_1',
        entryDate: now,
        description: 'مرتجع اختبار',
        lines: [
          JournalLineDraft(
              accountCode: SystemAccountCode.salesReturns,
              debitMicros: 23500),
          JournalLineDraft(
              accountCode: SystemAccountCode.cash, creditMicros: 23500),
          JournalLineDraft(
              accountCode: SystemAccountCode.inventory, debitMicros: 18000),
          JournalLineDraft(
              accountCode: SystemAccountCode.costOfGoodsSold,
              creditMicros: 18000),
        ],
        createdBy: 'user_cashier',
      );

      final failure = await controller.load();

      expect(failure, isNull);
      final snapshot = controller.state.snapshot!;
      // Net revenue 47000 − 23500, net profit (47000−23500) − (36000−18000).
      expect(snapshot.todayTotalMicros, 23500);
      expect(snapshot.todayProfitMicros, 5500);
      // Net packages: 2 sold − 1 returned (never base units: not 6, not 3).
      expect(snapshot.todayUnitsSold, 1);
      // The invoice itself still exists (returns don't delete invoices).
      expect(snapshot.todayInvoiceCount, 1);
    },
  );

  test(
    'low-stock and out-of-stock counters are derived from policy bounds',
    () async {
      await awaitCategory(db);
      await insertItem(db, barcode: '1111111111111', id: 'it_low');
      await (db.update(db.items)..where((i) => i.id.equals('it_low'))).write(
        ItemsCompanion(
          currentStockBase: const Value(5),
          minimumStockBase: const Value(10),
        ),
      );
      await insertItem(db, barcode: '2222222222222', id: 'it_out');
      await (db.update(db.items)..where((i) => i.id.equals('it_out'))).write(
        ItemsCompanion(currentStockBase: const Value(0)),
      );

      await controller.load();

      final snapshot = controller.state.snapshot!;
      expect(snapshot.lowStockCount, 1);
      expect(snapshot.outOfStockCount, 1);
      expect(snapshot.lowStockItems.single.itemId, 'it_low');
    },
  );

  test('near-expiry batches surface only those within the window', () async {
    final now = DateTime.now().millisecondsSinceEpoch;
    final day = 24 * 60 * 60 * 1000;
    await awaitCategory(db);
    final itemId = await insertItem(db, barcode: '6291041500213');
    await db
        .into(db.batches)
        .insert(
          BatchesCompanion.insert(
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
          ),
        );
    await db
        .into(db.batches)
        .insert(
          BatchesCompanion.insert(
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
          ),
        );

    await controller.load();

    final snapshot = controller.state.snapshot!;
    expect(snapshot.nearExpiryBatches.single.batchId, 'bat_near');
  });

  test('recent activity lists latest sales first', () async {
    final now = DateTime.now().millisecondsSinceEpoch;
    await insertSale(
      number: 'S-OLD',
      totalMicros: 50000,
      atMillis: now - 60000,
    );
    await insertSale(number: 'S-NEW', totalMicros: 90000, atMillis: now);

    await controller.load();

    final snapshot = controller.state.snapshot!;
    expect(snapshot.recentSales.first.number, 'S-NEW');
    expect(snapshot.recentSales.last.number, 'S-OLD');
    expect(snapshot.todayInvoiceCount, 2);
  });
}
