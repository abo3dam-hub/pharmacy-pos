/// Phase 11 read-only reporting DAO. Seeds a realistic, balanced journal
/// through the canonical services (SaleService, PurchaseService, ReturnService,
/// FinancialPostingService) plus direct rows for lost sales, then asserts the
/// projected trial balance, income statement, balance sheet, sales / purchase /
/// inventory / lost-sales reports and their filter boundaries.
library;

import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:flutter_test/flutter_test.dart';
import 'package:pharmacy_pos/domain/services/financial_posting_service.dart';
import 'package:pharmacy_pos/domain/services/purchase_service.dart';
import 'package:pharmacy_pos/domain/services/return_service.dart';
import 'package:pharmacy_pos/domain/services/sale_service.dart';
import 'package:pharmacy_pos/features/reports/data/reports_dao.dart';
import 'package:pharmacy_pos/features/reports/domain/entities/report_models.dart';
import 'package:pharmacy_pos/shared/database/app_database.dart';
import 'package:pharmacy_pos/shared/models/enums.dart';

import 'helpers.dart';

const _dayMillis = 24 * 60 * 60 * 1000;

void main() {
  late AppDatabase db;
  late ReportsDao dao;
  late int base;
  late int from;
  late int to;

  setUp(() async {
    db = newDatabase();
    dao = ReportsDao(db);
    base = DateTime.now().millisecondsSinceEpoch;
    // Financial projections use a calendar-independent window: prior-period
    // activity falls strictly before [from], current-period strictly inside.
    from = base - 2 * _dayMillis + 3600000;
    to = base + 3600000;
  });

  tearDown(() async => db.close());

  Future<void> post(
    String refType,
    String refId,
    int entryDate,
    String description,
    List<JournalLineDraft> lines) {
    return FinancialPostingService().postJournalEntry(
      db,
      refType: JournalReferenceType.values.firstWhere((e) => e.name == refType),
      refId: refId,
      entryDate: entryDate,
      description: description,
      lines: lines,
      createdBy: 'user_admin',
    );
  }

  /// Balanced picture without returns:
  ///   prior   : +10,000,000 capital cash; inventory cash purchase 100,000
  ///   current : cash sale 50,000 (+COGS 30,000 / −inventory), rent 10,000
  /// Net position: cash 9,940,000 · inventory 70,000 · equity 10,000,000 +
  /// retained 10,000 ⇒ Assets 10,010,000 = Liabilities 0 + Equity 10,010,000.
  Future<void> seedFinancials() async {
    await post('opening_balance', 'OPEN-1', from - _dayMillis, 'رأس المال', [
      JournalLineDraft(
          accountCode: SystemAccountCode.cash, debitMicros: 10000000),
      JournalLineDraft(
          accountCode: SystemAccountCode.capital, creditMicros: 10000000),
    ]);
    await post('opening_balance', 'OPEN-2', from - _dayMillis, 'شراء مخزون', [
      JournalLineDraft(
          accountCode: SystemAccountCode.inventory, debitMicros: 100000),
      JournalLineDraft(
          accountCode: SystemAccountCode.cash, creditMicros: 100000),
    ]);

    await post('manual', 'J-CUR-1', from + 1000, 'بيع نقدي', [
      JournalLineDraft(
          accountCode: SystemAccountCode.cash, debitMicros: 50000),
      JournalLineDraft(
          accountCode: SystemAccountCode.salesRevenue, creditMicros: 50000),
      JournalLineDraft(
          accountCode: SystemAccountCode.costOfGoodsSold, debitMicros: 30000),
      JournalLineDraft(
          accountCode: SystemAccountCode.inventory, creditMicros: 30000),
    ]);
    await post('manual', 'J-CUR-2', from + 2000, 'إيجار', [
      JournalLineDraft(accountCode: SystemAccountCode.rent, debitMicros: 10000),
      JournalLineDraft(
          accountCode: SystemAccountCode.cash, creditMicros: 10000),
    ]);
  }

  /// Sales-return contra entry (dr 4001 / cr cash) used only by the income
  /// statement group so the balance sheet keeps a non-zero retained figure.
  Future<void> seedReturn() async {
    await post('manual', 'J-CUR-3', from + 3000, 'مرتجع مبيعات', [
      JournalLineDraft(
          accountCode: SystemAccountCode.salesReturns, debitMicros: 10000),
      JournalLineDraft(
          accountCode: SystemAccountCode.cash, creditMicros: 10000),
    ]);
  }

  group('trial balance', () {
    test('splits opening (pre-period) and period movements by sign', () async {
      await seedFinancials();
      final report = await dao.trialBalance(fromMillis: from, toMillis: to);
      TrialBalanceAccountRow byCode(String code) =>
          report.accounts.firstWhere((a) => a.code == code);

      expect(byCode('1000').openingBalanceMicros, 9900000);
      expect(byCode('1000').periodDebitMicros, 50000);
      expect(byCode('1000').periodCreditMicros, 10000);

      expect(byCode('1200').openingBalanceMicros, 100000);
      expect(byCode('1200').periodCreditMicros, 30000);

      expect(byCode('3000').openingBalanceMicros, 10000000);
      expect(byCode('3000').periodDebitMicros, 0);
      expect(byCode('3000').periodCreditMicros, 0);

      expect(byCode('4000').periodCreditMicros, 50000);
      expect(byCode('5000').periodDebitMicros, 30000);
      expect(byCode('5101').periodDebitMicros, 10000);

      // Prior-period activity must never leak into the period columns.
      final sumOfPeriodMoves = report.accounts.fold<int>(
          0, (s, a) => s + a.periodDebitMicros + a.periodCreditMicros);
      expect(sumOfPeriodMoves, 180000);
    });

    test('period debit columns sum to credit columns (balanced journal)',
        () async {
      await seedFinancials();
      final report = await dao.trialBalance(fromMillis: from, toMillis: to);
      final debit =
          report.accounts.fold<int>(0, (s, a) => s + a.periodDebitMicros);
      final credit =
          report.accounts.fold<int>(0, (s, a) => s + a.periodCreditMicros);
      expect(debit, credit);

      // Classic closing columns also balance under the sign convention.
      var classicDebit = 0;
      var classicCredit = 0;
      for (final a in report.accounts) {
        final inDebit = a.accountType == AccountType.asset ||
            a.accountType == AccountType.expense;
        final closing = inDebit
            ? a.openingBalanceMicros + a.periodDebitMicros - a.periodCreditMicros
            : a.openingBalanceMicros - a.periodDebitMicros + a.periodCreditMicros;
        if (inDebit) {
          classicDebit += closing;
        } else {
          classicCredit += closing;
        }
      }
      expect(classicDebit, classicCredit);
    });
  });

  group('income statement', () {
    test('projects revenue, contra return, COGS and operating expenses',
        () async {
      await seedFinancials();
      await seedReturn();
      final report = await dao.incomeStatement(fromMillis: from, toMillis: to);
      expect(report.salesRevenueMicros, 50000);
      expect(report.salesReturnsMicros, 10000);
      expect(report.costOfGoodsSoldMicros, 30000);
      expect(report.operatingExpenses, hasLength(1));
      expect(report.operatingExpenses.single.code, '5101');
      expect(report.operatingExpenses.single.amountMicros, 10000);
    });

    test('prior-period rows are excluded', () async {
      await seedFinancials();
      final report = await dao.incomeStatement(
          fromMillis: from, toMillis: from + 500);
      expect(report.salesRevenueMicros, 0);
      expect(report.salesReturnsMicros, 0);
      expect(report.costOfGoodsSoldMicros, 0);
      expect(report.operatingExpenses, isEmpty);
    });
  });

  group('balance sheet', () {
    test('equates assets with liabilities plus equity incl. retained earnings',
        () async {
      await seedFinancials();
      final report = await dao.balanceSheet(asOfMillis: to);

      int sum(Iterable<BalanceSheetItem> items) =>
          items.fold(0, (s, i) => s + i.amountMicros);

      final assets = sum(report.assets.items);
      final liabilities = sum(report.liabilities.items);
      final equity = sum(report.equity.items);
      expect(assets, liabilities + equity);

      expect(report.assets.items.firstWhere((i) => i.code == '1000')
          .amountMicros, 9940000);
      expect(report.assets.items.firstWhere((i) => i.code == '1200')
          .amountMicros, 70000);
      expect(assets, 10010000);
      expect(report.equity.items.firstWhere((i) => i.code == '3000')
          .amountMicros, 10000000);
      expect(report.equity.items.firstWhere((i) => i.code == 'P&L')
          .amountMicros, 10000);
    });

    test('is point-in-time: later entries are excluded', () async {
      await seedFinancials();
      final before =
          await dao.balanceSheet(asOfMillis: from + 1000);
      expect(before.assets.items.firstWhere((i) => i.code == '1000')
          .amountMicros, 9900000);

      final after = await dao.balanceSheet(asOfMillis: to);
      expect(after.assets.items.firstWhere((i) => i.code == '1000')
          .amountMicros, 9940000);
    });
  });

  group('sales report', () {
    Future<String> seedItemWithStock() async {
      final itemId = await insertItem(db);
      await insertBatch(db, itemId, quantityBase: 100, unitCostMicros: 10000);
      return itemId;
    }

    Future<String> seedCreditCustomer() async {
      final id = 'rpt_cust';
      await db.into(db.customers).insert(CustomersCompanion.insert(
            id: id,
            name: 'عميل تقارير',
            hasAccount: const Value(true),
            creditLimitMicros: const Value(0),
            isActive: const Value(true),
            createdAt: base,
            updatedAt: base,
          ));
      return id;
    }

    /// sale1 cash 2×20 cash → returned 1×20 · sale2 credit 1×5 (customer) ·
    /// sale3 cash 1×10 → voided.
    Future<void> seedSales() async {
      final itemId = await seedItemWithStock();
      final cust = await seedCreditCustomer();

      final sale1 = await SaleService().recordSale(
        db,
        SaleRequest(
          invoiceNumber: 'SR-1',
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

      await SaleService().recordSale(
        db,
        SaleRequest(
          invoiceNumber: 'SR-2',
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
          customerId: cust,
        ),
      );

      final sale3 = await SaleService().recordSale(
        db,
        SaleRequest(
          invoiceNumber: 'SR-3',
          lines: [
            SaleLineRequest(
                itemId: itemId,
                quantityBase: 1,
                unitPriceMicros: 10000,
                unitTypeId: 'unit_strip'),
          ],
          paymentMethod: PaymentMethod.cash,
          userId: 'user_admin',
          paidMicros: 10000,
        ),
      );
      await SaleService().voidInvoice(
        db,
        invoiceId: sale3.invoice.id,
        userId: 'user_admin',
        reason: 'إدخال خاطئ',
      );

      final sale1Line = await (db.select(db.salesInvoiceItems)
            ..where((i) => i.invoiceId.equals(sale1.invoice.id)))
          .getSingle();
      await ReturnService().recordSaleReturn(
        db,
        SaleReturnRequest(
          returnNumber: 'RT-SR1',
          originalInvoiceItemId: sale1Line.id,
          quantityBase: 1,
          userId: 'user_admin',
        ),
      );
    }

    test('aggregates sold, voided and returned invoices per day', () async {
      await seedSales();
      final report = await dao.salesReport(
          fromMillis: base - 3600000, toMillis: base + _dayMillis);

      expect(report.days, hasLength(1));
      final day = report.days.single;
      expect(day.invoiceCount, 2, reason: 'voided invoice excluded from sold');
      expect(day.unitsSold, 3);
      expect(day.subtotalMicros, 45000);
      expect(day.vatMicros, 0);
      expect(day.totalMicros, 45000);
      expect(day.paidMicros, 40000);
      expect(day.cashMicros, 40000);
      expect(day.creditMicros, 5000);
      expect(day.voidCount, 1);
      expect(day.voidTotalMicros, 10000);
      expect(day.returnCount, 1);
      expect(day.returnTotalMicros, 20000);
      expect(day.profitMicros, 15000);
    });

    test('customer filter narrows the window', () async {
      await seedSales();
      final customerRow = await db.select(db.customers).getSingle();
      final report = await dao.salesReport(
        fromMillis: base - 3600000,
        toMillis: base + _dayMillis,
        customerId: customerRow.id,
      );
      expect(report.days.single.invoiceCount, 1);
      expect(report.days.single.creditMicros, 5000);
      expect(report.days.single.returnCount, 0,
          reason: 'the return belongs to the cash (non-filtered) invoice');
    });
  });

  group('purchase report', () {
    test('aggregates purchase invoices and returns, supplier-filtered',
        () async {
      final itemId = await insertItem(db);
      await insertBatch(db, itemId, quantityBase: 50, unitCostMicros: 1000);
      final supplier = await insertSupplier(db);

      final outcome = await PurchaseService().recordPurchase(
        db,
        PurchaseRequest(
          invoiceNumber: 'PR-1',
          supplierId: supplier,
          invoiceDate: base,
          lines: [
            PurchaseLineRequest(
              itemId: itemId,
              quantityBase: 5,
              unitCostMicros: 2000,
              unitTypeId: 'unit_strip',
              batchNumber: 'RPT-B1',
            ),
          ],
          userId: 'user_admin',
          paidMicros: 10000,
        ),
      );

      await db.into(db.returns).insert(ReturnsCompanion.insert(
            id: 'rpt_pret',
            returnNumber: 'PRR-1',
            type: ReturnType.purchase_return,
            originalInvoiceId: outcome.invoice.id,
            originalInvoiceType: 'purchase',
            supplierId: Value(supplier),
            userId: 'user_admin',
            totalMicros: const Value(-4000),
            createdAt: base,
            updatedAt: base,
          ));

      final report = await dao.purchaseReport(
          fromMillis: base - 3600000, toMillis: base + _dayMillis);
      final day = report.days.single;
      expect(day.invoiceCount, 1);
      expect(day.subtotalMicros, 10000);
      expect(day.taxMicros, 0);
      expect(day.totalMicros, 10000);
      expect(day.paidMicros, 10000);
      expect(day.remainingMicros, 0);
      expect(day.returnCount, 1);
      expect(day.returnTotalMicros, 4000,
          reason: 'negative return total is reported as a positive amount');

      final filtered = await dao.purchaseReport(
        fromMillis: base - 3600000,
        toMillis: base + _dayMillis,
        supplierId: supplier,
      );
      expect(filtered.days.single.invoiceCount, 1);
      expect(filtered.days.single.returnCount, 1);

      final missed = await dao.purchaseReport(
        fromMillis: base - 3600000,
        toMillis: base + _dayMillis,
        supplierId: 'nobody',
      );
      expect(missed.days, isEmpty);
    });
  });

  group('inventory report', () {
    test('snapshots stock and movement summaries for the window', () async {
      final itemId = await insertItem(db);
      await insertBatch(db, itemId, quantityBase: 10, unitCostMicros: 10000);
      await SaleService().recordSale(
        db,
        SaleRequest(
          invoiceNumber: 'IR-1',
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

      final report = await dao.inventoryReport(
          fromMillis: base - 3600000, toMillis: base + 3600000);

      final item = report.items.single;
      expect(item.currentStockBase, 8);
      expect(item.stockValueMicros, 80000);
      expect(item.unitCostMicros, 10000);

      final byType = {
        for (final m in report.movements) m.movementType: m,
      };
      expect(byType[MovementType.purchase]!.movementCount, 1);
      expect(byType[MovementType.purchase]!.quantityBaseSigned, 10);
      expect(byType[MovementType.purchase]!.totalMicros, 100000);
      expect(byType[MovementType.sale]!.movementCount, 1);
      expect(byType[MovementType.sale]!.quantityBaseSigned, -2);
      expect(byType[MovementType.sale]!.totalMicros, -20000);
    });
  });

  group('lost sales report', () {
    Future<void> seedLostSales() async {
      await db.into(db.lostSales).insert(LostSalesCompanion.insert(
            id: 'ls_open',
            requestedItemName: 'بانادول',
            quantityRequested: 2,
            userId: 'user_admin',
            status: LostSaleStatus.open,
            createdAt: base - 3600000,
            updatedAt: base - 3600000,
          ));
      await db.into(db.lostSales).insert(LostSalesCompanion.insert(
            id: 'ls_resolved',
            requestedItemName: 'فولتارين',
            barcode: const Value('6291041500213'),
            quantityRequested: 1,
            customerName: const Value('سارة'),
            userId: 'user_admin',
            status: LostSaleStatus.resolved,
            createdAt: base,
            updatedAt: base,
          ));
      await db.into(db.lostSales).insert(LostSalesCompanion.insert(
            id: 'ls_old',
            requestedItemName: 'قديم',
            quantityRequested: 1,
            userId: 'user_admin',
            status: LostSaleStatus.open,
            createdAt: base - 2 * _dayMillis,
            updatedAt: base - 2 * _dayMillis,
          ));
    }

    test('filters by date window and status', () async {
      await seedLostSales();
      final report = await dao.lostSalesReport(
          fromMillis: base - 2 * 3600000, toMillis: base + 2 * _dayMillis);
      expect(report.rows.map((r) => r.id),
          containsAll(['ls_open', 'ls_resolved']));
      expect(report.rows.map((r) => r.id), isNot(contains('ls_old')));

      final onlyOpen = await dao.lostSalesReport(
        fromMillis: base - 2 * 3600000,
        toMillis: base + 2 * _dayMillis,
        status: LostSaleStatus.open,
      );
      expect(onlyOpen.rows.map((r) => r.id), ['ls_open']);

      final onlyResolved = await dao.lostSalesReport(
        fromMillis: base - 2 * 3600000,
        toMillis: base + 2 * _dayMillis,
        status: LostSaleStatus.resolved,
      );
      expect(onlyResolved.rows.single.id, 'ls_resolved');
      expect(onlyResolved.rows.single.customerName, 'سارة');
      expect(onlyResolved.rows.single.barcode, '6291041500213');
    });
  });
}