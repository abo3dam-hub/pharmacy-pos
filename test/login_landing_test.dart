import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pharmacy_pos/main.dart';
import 'package:pharmacy_pos/shared/database/app_database.dart';
import 'package:pharmacy_pos/shared/models/enums.dart';

import 'auth_harness.dart';
import 'helpers.dart';

/// Repro harness: login into the real app with a RICH database (sales,
/// purchases, batches with nulls/voids, customers, suppliers) and verify the
/// dashboard lands. If a data-dependent query throws after login this fails.
void main() {
  testWidgets('login lands on dashboard with a rich real-world database',
      (tester) async {
    tester.view.physicalSize = const Size(1280, 800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    final harness = await buildAuthHarness();
    addTearDown(harness.db.close);
    addTearDown(harness.container.dispose);
    final db = harness.db;

    final itemId = await insertItem(db);
    await insertBatch(db, itemId, quantityBase: 3, expiryDays: 20);
    await insertBatch(db, itemId, quantityBase: 2, expiryDays: 400);
    // Non-expiring batch.
    await insertBatch(db, itemId, quantityBase: 5, expiryDays: null);
    await insertSupplier(db);
    await insertSupplier(db);

    final now = DateTime.now().millisecondsSinceEpoch;
    final day = 24 * 60 * 60 * 1000;

    final customerId = 'customer_repro';
    await db.into(db.customers).insert(
          CustomersCompanion.insert(
            id: customerId,
            name: 'عميل تجريبي',
            createdAt: now,
            updatedAt: now,
          ),
        );

    // Completed invoices inside + outside today.
    for (var i = 0; i < 4; i++) {
      final created = now - (i == 2 ? 2 * day : 0) - 30000;
      await db.into(db.salesInvoices).insert(
            SalesInvoicesCompanion.insert(
              id: 'inv_repro_$i',
              invoiceNumber: 'SI-REPRO-$i',
              invoiceType: InvoiceType.sale,
              saleStatus: SaleStatus.completed,
              paymentMethod: PaymentMethod.cash,
              customerId: Value(customerId),
              subtotalMicros: Value(100000),
              discountTotalMicros: Value(0),
              vatTotalMicros: Value(15000),
              totalMicros: Value(115000),
              paidMicros: Value(115000),
              changeMicros: Value(0),
              cashMicros: Value(115000),
              cardMicros: Value(0),
              creditMicros: Value(0),
              profitMicros: Value(40000),
              userId: 'user_admin',
              createdAt: created,
              updatedAt: created,
            ),
          );
    }
    // A voided + a draft invoice must not leak into KPIs.
    await db.into(db.salesInvoices).insert(
          SalesInvoicesCompanion.insert(
            id: 'inv_repro_void',
            invoiceNumber: 'SI-REPRO-VOID',
            invoiceType: InvoiceType.sale,
            saleStatus: SaleStatus.completed,
            paymentMethod: PaymentMethod.cash,
            totalMicros: Value(99999999),
            userId: 'user_admin',
            voidedBy: Value('user_admin'),
            voidedAt: Value(now),
            createdAt: now,
            updatedAt: now,
          ),
        );
    await db.into(db.salesInvoices).insert(
          SalesInvoicesCompanion.insert(
            id: 'inv_repro_draft',
            invoiceNumber: 'SI-REPRO-DRAFT',
            invoiceType: InvoiceType.sale,
            saleStatus: SaleStatus.draft,
            paymentMethod: PaymentMethod.cash,
            totalMicros: Value(99999999),
            userId: 'user_admin',
            createdAt: now,
            updatedAt: now,
          ),
        );

    await db.into(db.purchaseInvoices).insert(
          PurchaseInvoicesCompanion.insert(
            id: 'pur_repro',
            invoiceNumber: 'PO-REPRO-1',
            supplierId: 'sup_x',
            purchaseStatus: PurchaseStatus.received,
            invoiceDate: now,
            totalMicros: Value(500000),
            isVoided: Value(false),
            userId: 'user_admin',
            createdAt: now,
            updatedAt: now,
          ),
        );

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: harness.container,
        child: const PharmacyApp(),
      ),
    );
    await tester.pumpAndSettle();

    await tester.enterText(
        find.widgetWithText(TextFormField, 'اسم المستخدم'), 'admin');
    await tester.enterText(
        find.widgetWithText(TextFormField, 'كلمة المرور'), 'Admin@123');
    await tester.tap(find.text('دخول'));
    await tester.pumpAndSettle();

    expect(find.byType(NavigationRail), findsOneWidget);
    expect(find.text('الرئيسية'), findsWidgets);
  });
}