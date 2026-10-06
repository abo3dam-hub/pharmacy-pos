/// On-device end-to-end sale flow: seed one sellable item, then drive the
/// REAL app UI exactly like a pharmacist — search, add to cart, change
/// quantity, pay cash, receipt — and assert the database end state
/// (invoice persisted, stock decreased).
///
/// Run on Windows:  `flutter test integration_test`
/// Run on Android:   connect a device/emulator, then `flutter test integration_test`
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:pharmacy_pos/shared/database/app_database.dart';
import 'package:pharmacy_pos/shared/models/enums.dart';

import 'e2e_helpers.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('e2e: search -> add -> qty 2 -> cash pay -> receipt -> persisted',
      (tester) async {
    final harness = await pumpE2EApp(tester);
    final AppDatabase db = harness.db;

    // Seed: "بانادول" at 1.00/package, 100 units per package, 300 base units.
    final itemId = await seedSellableItem(db);
    expect(await onHandBase(db, itemId), 300);

    // Log in and open the POS workspace.
    await loginViaUI(tester);
    await goToSales(tester);
    expect(find.text('السلة فارغة — أضف أصنافاً للبيع'), findsOneWidget);

    // Search and add the item to the cart.
    await tester.enterText(find.byType(TextField).first, 'بانادول');
    await tester.pump(const Duration(milliseconds: 700));
    await tester.pumpAndSettle();
    expect(find.widgetWithText(ListTile, 'بانادول (Panadol)'), findsOneWidget);
    await tester.tap(find.widgetWithText(ListTile, 'بانادول (Panadol)'));
    await tester.pumpAndSettle();
    expect(find.textContaining('1 علبة'), findsOneWidget);

    // Bump quantity to 2 packages.
    await tester.tap(find.byIcon(Icons.add_circle_outline));
    await tester.pumpAndSettle();
    expect(find.textContaining('2 علبة'), findsOneWidget);

    // Pay 5.00 cash for the 2.00 total.
    await tester.tap(find.text('دفع (F12)'));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.widgetWithText(TextField, 'المبلغ المقبوض'),
      '5',
    );
    await tester.pumpAndSettle();
    expect(find.text('الباقي: 3.00'), findsOneWidget);
    await tester.tap(find.widgetWithText(FilledButton, 'دفع (F12)').last);
    await tester.pumpAndSettle();

    // Receipt shows.
    expect(find.text('ملخص الإيصال'), findsOneWidget);
    expect(find.textContaining('رقم الفاتورة: S'), findsOneWidget);
    expect(find.text('بانادول (Panadol) × 2 علبة'), findsOneWidget);

    // Database end state: exactly one completed invoice, 200 base units sold.
    final invoices = await (db.select(db.salesInvoices)
          ..where((i) => i.saleStatus.equalsValue(SaleStatus.completed)))
        .get();
    expect(invoices, hasLength(1));
    expect(invoices.single.totalMicros, 20000);
    expect(invoices.single.paidMicros, 50000);
    expect(await onHandBase(db, itemId), 100);
  });
}
