/// Z-Report aggregation gap closure: the DAO reproduces the persisted
/// documents into a single summary window — collected sales (drafts/voids
/// excluded), standalone returns, customer credit payments, and the cash-box
/// reconciliation where `opening + net moves = running balance`.
library;

import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:flutter_test/flutter_test.dart';
import 'package:pharmacy_pos/domain/services/customer_payment_service.dart';
import 'package:pharmacy_pos/domain/services/return_service.dart';
import 'package:pharmacy_pos/domain/services/sale_service.dart';
import 'package:pharmacy_pos/features/sales/data/z_report_dao.dart';
import 'package:pharmacy_pos/shared/database/app_database.dart';
import 'package:pharmacy_pos/shared/models/enums.dart';

import 'helpers.dart';

void main() {
  late AppDatabase db;
  late ZReportDao dao;

  setUp(() {
    db = newDatabase();
    dao = ZReportDao(db);
  });

  tearDown(() async => db.close());

  Future<String> seedItem({int qty = 10}) async {
    final itemId = await insertItem(db);
    await insertBatch(db, itemId, quantityBase: qty, expiryDays: 90);
    return itemId;
  }

  Future<String> seedCustomer() async {
    final id = 'zr_cust';
    await db.into(db.customers).insert(CustomersCompanion.insert(
          id: id,
          name: 'عميل آجل',
          hasAccount: const Value(true),
          creditLimitMicros: const Value(0),
          isActive: const Value(true),
          createdAt: DateTime.now().millisecondsSinceEpoch,
          updatedAt: DateTime.now().millisecondsSinceEpoch,
        ));
    return id;
  }

  Future<({int from, int to})> openDrawer(int openingMicros) async {
    final now = DateTime.now().millisecondsSinceEpoch;
    final from = now - 60 * 60 * 1000;
    await db.into(db.cashboxTransactions).insert(
          CashboxTransactionsCompanion.insert(
            id: 'zr_open',
            type: CashboxTransactionType.open,
            amountMicros: openingMicros,
            remainingMicros: openingMicros,
            userId: 'user_admin',
            createdAt: from,
          ),
        );
    return (from: from, to: now + 60 * 60 * 1000);
  }

  Future<void> closeDrawer(int closingMicros) async {
    await db.into(db.cashboxTransactions).insert(
      CashboxTransactionsCompanion.insert(
        id: 'zr_close',
        type: CashboxTransactionType.close,
        amountMicros: closingMicros,
        remainingMicros: closingMicros,
        userId: 'user_admin',
        createdAt: DateTime.now().millisecondsSinceEpoch + 1,
      ),
    );
  }

  test('aggregates collected sales, returns, voids and customer payments',
      () async {
    final itemId = await seedItem();
    final cust = await seedCustomer();
    final range = await openDrawer(50000);

    // Cash sale 2 × 20.00 paid cash.
    final sale1 = await SaleService().recordSale(
      db,
      SaleRequest(
        invoiceNumber: 'SI-Z1',
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

    // Credit sale 1 × 5.00 (unpaid balance goes to customer account).
    await SaleService().recordSale(
      db,
      SaleRequest(
        invoiceNumber: 'SI-Z2',
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

    // Third cash sale then voided → must appear only in the void section.
    final voidable = await SaleService().recordSale(
      db,
      SaleRequest(
        invoiceNumber: 'SI-Z3',
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
      invoiceId: voidable.invoice.id,
      userId: 'user_admin',
      reason: 'إدخال خاطئ',
    );

    // Return half the first sale (1 × 20.00 cash) — standalone return order.
    final line = await (db.select(db.salesInvoiceItems)
          ..where((i) => i.invoiceId.equals(sale1.invoice.id)))
        .getSingle();
    await ReturnService().recordSaleReturn(
      db,
      SaleReturnRequest(
        returnNumber: 'RT-Z1',
        originalInvoiceItemId: line.id,
        quantityBase: 1,
        userId: 'user_admin',
      ),
    );

    // Customer settles 30.00 cash on their account.
    await CustomerPaymentService().recordCustomerPayment(
      db,
      paymentNumber: 'CP-Z1',
      customerId: cust,
      amountMicros: 30000,
      cashMicros: 30000,
      cardMicros: 0,
      userId: 'user_admin',
    );

    // Declared closing equals the running balance: open 50000 + net cash moves
    // (sale1 40000 + sale3 10000 − void reversal 10000 − return 20000 + payment
    // 30000) = 100000.
    await closeDrawer(100000);

    final z = await dao.aggregate(
      fromMillis: range.from,
      toMillis: range.to,
    );

    expect(z.invoiceCount, 2, reason: 'voided invoice must be excluded');
    expect(z.subtotalMicros, 45000);
    expect(z.vatMicros, 0);
    expect(z.totalMicros, 45000);
    expect(z.paidMicros, 40000);
    expect(z.changeMicros, 0);
    expect(z.cashMicros, 40000);
    expect(z.cardMicros, 0);
    expect(z.creditMicros, 5000);
    expect(z.unitsSold, 3);

    expect(z.voidCount, 1);
    expect(z.voidTotalMicros, 10000);
    expect(z.returnsCount, 1);
    expect(z.returnsTotalMicros, 20000,
        reason: 'return amount reported as a positive refund');
    expect(z.customerPaidMicros, 30000);
    expect(z.customerRefundMicros, 0);

    expect(z.drawerOpeningMicros, 50000);
    expect(z.drawerNetMovesMicros, 50000,
        reason: 'open/close declarations are not net moves');
    expect(z.expectedClosingMicros, 100000);
    expect(z.lastRemainingMicros, 100000);
    expect(z.drawerDeclaredCloseMicros, 100000);
    expect(z.drawerDifferenceMicros, 0,
        reason: 'declared closing reconciles with the running balance');
  });

  test('empty window yields zeros and excludes drafts', () async {
    final now = DateTime.now().millisecondsSinceEpoch;

    // Draft invoice inside the window must be excluded.
    await db.into(db.salesInvoices).insert(
      SalesInvoicesCompanion.insert(
        id: 'inv_draft',
        invoiceNumber: 'SI-D1',
        invoiceType: InvoiceType.sale,
        saleStatus: SaleStatus.draft,
        paymentMethod: PaymentMethod.cash,
        customerId: const Value(null),
        paidMicros: const Value(0),
        userId: 'user_admin',
        createdAt: now,
        updatedAt: now,
      ),
    );

    final z = await dao.aggregate(
      fromMillis: now - 1000,
      toMillis: now + 1000,
    );
    expect(z.invoiceCount, 0);
    expect(z.totalMicros, 0);
    expect(z.voidCount, 0);
    expect(z.returnsCount, 0);
    expect(z.customerPaidMicros, 0);
    expect(z.drawerNetMovesMicros, 0);
    expect(z.lastRemainingMicros, 0);
    expect(z.drawerDeclaredCloseMicros, isNull);
  });
}