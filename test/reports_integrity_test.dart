/// Phase 11 cross-report integrity: the same balanced journal must pierce every
/// projection without mutating anything. Trial balance columns balance, the
/// income statement reconciles to the balance-sheet retained figure, and the
/// balance sheet satisfies Assets = Liabilities + Equity. Seeding mirrors
/// `reports_dao_test.dart` but goes through the real sale / purchase services
/// so accounts, inventory rows and the journal share one verified dataset.
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:pharmacy_pos/domain/services/purchase_service.dart';
import 'package:pharmacy_pos/domain/services/sale_service.dart';
import 'package:pharmacy_pos/features/reports/data/reports_dao.dart';
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
    from = base - 2 * _dayMillis + 3600000;
    to = base + 3600000;
  });

  tearDown(() async => db.close());

  /// One cash sale through [SaleService] (posts revenue/COGS/inventory and
  /// stock movements) plus one cash purchase through [PurchaseService]
  /// (posts inventory/AP-cash), dated strictly inside the current window.
  Future<void> seedDocuments() async {
    final itemId = await insertItem(db);
    await insertBatch(db, itemId, quantityBase: 10, unitCostMicros: 10000);
    await insertSupplier(db);

    await SaleService().recordSale(
      db,
      SaleRequest(
        invoiceNumber: 'IG-S1',
        lines: [
          SaleLineRequest(
              itemId: itemId,
              quantityBase: 1,
              unitPriceMicros: 30000,
              unitTypeId: 'unit_strip'),
        ],
        paymentMethod: PaymentMethod.cash,
        userId: 'user_admin',
        paidMicros: 30000,
      ),
    );

    await PurchaseService().recordPurchase(
      db,
      PurchaseRequest(
        invoiceNumber: 'IG-P1',
        supplierId: (await db.select(db.suppliers).getSingle()).id,
        invoiceDate: base,
        lines: [
          PurchaseLineRequest(
            itemId: itemId,
            quantityBase: 5,
            unitCostMicros: 8000,
            unitTypeId: 'unit_strip',
            batchNumber: 'IG-B1',
          ),
        ],
        userId: 'user_admin',
        paidMicros: 40000,
      ),
    );
  }

  test('trial balance, income statement and balance sheet intersect cleanly',
      () async {
    // A sale service checks item stock and an exact barcode; the projection of
    // deliveries must leave the DB untouched, so compare row counts first.
    await seedDocuments();
    final beforeRows = <String>[
      await db.select(db.journalEntries).get().then((r) => r.length.toString()),
      await db.select(db.journalEntryLines).get().then((r) => r.length.toString()),
      await db.select(db.accounts).get().then((r) => r.fold<int>(0, (s, a) => s + a.balanceMicros).toString()),
    ];

    final tb = await dao.trialBalance(fromMillis: from, toMillis: to);
    final income = await dao.incomeStatement(fromMillis: from, toMillis: to);
    final bs = await dao.balanceSheet(asOfMillis: to);

    // Read-only guarantee: no journal/transaction side effects.
    final afterRows = <String>[
      await db.select(db.journalEntries).get().then((r) => r.length.toString()),
      await db.select(db.journalEntryLines).get().then((r) => r.length.toString()),
      await db.select(db.accounts).get().then((r) => r.fold<int>(0, (s, a) => s + a.balanceMicros).toString()),
    ];
    expect(afterRows, beforeRows);

    // TB: debit columns balance and classic closing columns balance.
    final periodDebit =
        tb.accounts.fold<int>(0, (s, a) => s + a.periodDebitMicros);
    final periodCredit =
        tb.accounts.fold<int>(0, (s, a) => s + a.periodCreditMicros);
    expect(periodDebit, periodCredit);
    var classicDebit = 0;
    var classicCredit = 0;
    for (final a in tb.accounts) {
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

    // IS net income equals the balance-sheet retained figure (P&L item).
    final netIncome = income.salesRevenueMicros -
        income.salesReturnsMicros -
        income.costOfGoodsSoldMicros -
        income.operatingExpenses.fold<int>(0, (s, e) => s + e.amountMicros);
    final retained = bs.equity.items
        .firstWhere((i) => i.code == 'P&L')
        .amountMicros;
    expect(retained, netIncome);

    // BS identity with the P&L balance closed into equity.
    final assets = bs.assets.items.fold<int>(0, (s, i) => s + i.amountMicros);
    final liabilities =
        bs.liabilities.items.fold<int>(0, (s, i) => s + i.amountMicros);
    final equity = bs.equity.items.fold<int>(0, (s, i) => s + i.amountMicros);
    expect(assets, liabilities + equity);
    // Assets = the financing posted: purchase 5×8,000 inventory funding made
    // available by the sale proceeds; sanity-check the absolute magnitude.
    expect(assets, greaterThan(0));
    expect(bs.equity.items.firstWhere((i) => i.code == 'P&L'),
        isNotNull);
  });
}