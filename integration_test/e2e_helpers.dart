/// Shared scaffolding for on-device end-to-end tests (`integration_test/`).
///
/// These tests drive the REAL app on a real device (Windows desktop or
/// Android) through the same UI a pharmacist uses. They reuse the hermetic
/// in-memory test database from `test/auth_harness.dart`, so every run
/// starts from a clean, seeded state and never touches the real database.
///
/// Run on Windows:  `flutter test integration_test`
/// Run on Android:   connect a device/emulator, then `flutter test integration_test`
library;

import 'package:drift/drift.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pharmacy_pos/main.dart';
import 'package:pharmacy_pos/shared/database/app_database.dart';
import 'package:pharmacy_pos/domain/services/stock_service.dart';

import '../test/auth_harness.dart';
import '../test/helpers.dart';

export '../test/auth_harness.dart';
export '../test/helpers.dart';
/// Pumps the real app wired to a fresh in-memory test database.
/// Returns the harness (container + db) for seeding and assertions.
Future<({ProviderContainer container, AppDatabase db})> pumpE2EApp(
  WidgetTester tester,
) async {
  final harness = await buildAuthHarness();
  addTearDown(harness.db.close);
  addTearDown(harness.container.dispose);

  await tester.pumpWidget(
    UncontrolledProviderScope(
      container: harness.container,
      child: const PharmacyApp(),
    ),
  );
  await tester.pumpAndSettle();
  return (container: harness.container, db: harness.db);
}

/// Logs in through the real login UI with the seeded admin account.
Future<void> loginViaUI(WidgetTester tester) async {
  expect(find.text('دخول'), findsOneWidget);
  await tester.enterText(
      find.widgetWithText(TextFormField, 'اسم المستخدم'), 'admin');
  await tester.enterText(
      find.widgetWithText(TextFormField, 'كلمة المرور'), 'Admin@123');
  await tester.tap(find.text('دخول'));
  await tester.pumpAndSettle();
  expect(find.byType(NavigationRail), findsOneWidget);
}

/// Opens the POS workspace ("مبيعات"), handling both the wide-screen
/// NavigationRail (desktop) and the compact drawer (phone).
Future<void> goToSales(WidgetTester tester) async {
  if (find.byType(NavigationRail).evaluate().isNotEmpty) {
    await tester.tap(find.widgetWithText(NavigationRailDestination, 'مبيعات'));
  } else {
    // Compact layout: open the navigation drawer first.
    await tester.tap(find.byIcon(Icons.menu));
    await tester.pumpAndSettle();
    await tester
        .tap(find.widgetWithText(NavigationDrawerDestination, 'مبيعات').first);
  }
  await tester.pumpAndSettle();
}

/// Seeds one sellable packaged item ("بانادول", 1.00/package, 100 units per
/// package) with 300 base units of stock. Mirrors the unit-test seeding so
/// E2E expectations match the widget-test contract.
Future<String> seedSellableItem(AppDatabase db) async {
  final now = DateTime.now().millisecondsSinceEpoch;
  await awaitCategory(db);
  const id = 'item_e2e_panadol';
  await db.into(db.items).insert(
        ItemsCompanion.insert(
          id: id,
          primaryBarcode: const Value('6291041500213'),
          tradeName: 'بانادول',
          tradeNameEn: const Value('Panadol'),
          scientificName: const Value('Paracetamol'),
          categoryId: const Value('cat_test_default'),
          sellingPriceMicros: const Value(10000),
          vatRateBasisPoints: const Value(0),
          isActive: const Value(true),
          createdAt: now,
          updatedAt: now,
        ),
        mode: InsertMode.insertOrIgnore,
      );
  await db.into(db.units).insert(
        UnitsCompanion.insert(
          id: 'unit_strip',
          name: 'شريط',
          createdAt: now,
          updatedAt: now,
        ),
        mode: InsertMode.insertOrIgnore,
      );
  await db.into(db.units).insert(
        UnitsCompanion.insert(
          id: 'unit_box',
          name: 'علبة',
          createdAt: now,
          updatedAt: now,
        ),
        mode: InsertMode.insertOrIgnore,
      );
  await db.into(db.itemUnits).insert(
        ItemUnitsCompanion.insert(
          id: 'iu_$id',
          itemId: id,
          baseUnitId: 'unit_strip',
          largeUnitId: 'unit_box',
          unitsPerLarge: const Value(100),
        ),
        mode: InsertMode.insertOrIgnore,
      );
  await insertBatch(db, id, quantityBase: 300);
  return id;
}

/// Returns the current on-hand base units for [itemId] (expiry-valid,
// non-voided batches) via the real [StockService].
Future<int> onHandBase(AppDatabase db, String itemId) =>
    const StockService().availableQuantity(db, itemId);
