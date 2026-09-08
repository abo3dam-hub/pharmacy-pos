/// POS Phase 7 widget tests for the workspace page (search → cart → payment →
/// receipt) against a real in-memory Drift database, plus the empty-search
/// (lost-sale) and customer-picker flows. The page is pumped directly with
/// provider overrides so no router/bootstrap is required.
library;

import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pharmacy_pos/core/config/app_config.dart';
import 'package:pharmacy_pos/core/data_grid/page_request.dart';
import 'package:pharmacy_pos/core/di/providers.dart';
import 'package:pharmacy_pos/core/theme/app_theme.dart';
import 'package:pharmacy_pos/domain/services/return_service.dart';
import 'package:pharmacy_pos/domain/services/sale_service.dart';
import 'package:pharmacy_pos/domain/services/stock_service.dart';
import 'package:pharmacy_pos/features/sales/data/pos_catalog_dao.dart';
import 'package:pharmacy_pos/features/sales/data/sales_repository_impl.dart';
import 'package:pharmacy_pos/features/sales/presentation/controllers/pos_workspace_controller.dart';
import 'package:pharmacy_pos/features/sales/presentation/pages/pos_workspace_page.dart';
import 'package:pharmacy_pos/l10n/app_localizations.dart';
import 'package:pharmacy_pos/shared/database/app_database.dart';

import 'auth_harness.dart';
import 'helpers.dart';

Widget _harness(
  ProviderContainer base,
  List<Override> overrides,
  Widget home,
) {
  return UncontrolledProviderScope(
    container: base,
    child: ProviderScope(
      overrides: overrides,
      child: MaterialApp(
        theme: AppTheme.light(),
        locale: const Locale(AppConfig.defaultLocale),
        supportedLocales: AppLocalizations.supportedLocales,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        home: Scaffold(body: home),
      ),
    ),
  );
}

({SalesRepositoryImpl repo, List<Override> overrides}) _posOverrides(
  AppDatabase db,
) {
  final repo = SalesRepositoryImpl(
    db,
    PosCatalogDao(db),
    const StockService(),
    SaleService(),
    ReturnService(),
  );
  final overrides = <Override>[
    salesRepositoryProvider.overrideWithValue(repo),
  ];
  for (var i = 0; i < posTabCount; i++) {
    overrides.add(
      posWorkspaceControllerProvider(i).overrideWith(
        (ref) => PosWorkspaceController(tabIndex: i, repository: repo),
      ),
    );
  }
  return (repo: repo, overrides: overrides);
}

const int posTabCount = 11;

Future<String> _seedSellableItem(
  AppDatabase db, {
  int sellingPriceMicros = 10000,
  int stockBase = 300,
}) async {
  final now = DateTime.now().millisecondsSinceEpoch;
  final itemId = await insertItem(db);
  await (db.update(db.items)..where((i) => i.id.equals(itemId))).write(
        ItemsCompanion(
          sellingPriceMicros: Value(sellingPriceMicros),
          vatRateBasisPoints: const Value(0),
          isActive: const Value(true),
        ),
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
          id: 'iu_$itemId',
          itemId: itemId,
          baseUnitId: 'unit_strip',
          largeUnitId: 'unit_box',
          unitsPerLarge: Value(100),
        ),
        mode: InsertMode.insertOrIgnore,
      );
  await insertBatch(db, itemId, quantityBase: stockBase);
  return itemId;
}

Future<String> _seedCustomer(
  AppDatabase db, {
  String name = 'عميل تجريبي',
  String phone = '0000000000',
}) async {
  final now = DateTime.now().millisecondsSinceEpoch;
  final id = 'customer_widget_$now';
  await db.into(db.customers).insert(
        CustomersCompanion.insert(
          id: id,
          name: name,
          phone: Value(phone),
          createdAt: now,
          updatedAt: now,
        ),
      );
  return id;
}

/// Sellable item with a custom name/barcode (quick-add tests need more than
/// the single hard-coded `بانادول` product).
Future<String> _seedNamedSellableItem(
  AppDatabase db, {
  required String name,
  required String barcode,
}) async {
  final now = DateTime.now().millisecondsSinceEpoch;
  await awaitCategory(db);
  final id =
      'item_${now}_${DateTime.now().microsecondsSinceEpoch % 100000}';
  await db.into(db.items).insert(
        ItemsCompanion.insert(
          id: id,
          primaryBarcode: Value(barcode),
          tradeName: name,
          tradeNameEn: Value(name),
          scientificName: Value(name),
          categoryId: 'cat_test_default',
          sellingPriceMicros: const Value(10000),
          vatRateBasisPoints: const Value(0),
          isActive: const Value(true),
          createdAt: now,
          updatedAt: now,
        ),
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
          unitsPerLarge: Value(100),
        ),
        mode: InsertMode.insertOrIgnore,
      );
  await insertBatch(db, id, quantityBase: 300);
  return id;
}

void main() {
  group('PosWorkspacePage', () {
    testWidgets('search → add to cart → qty → pay → receipt → persisted',
        (tester) async {
      tester.view.physicalSize = const Size(1280, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      final base = await buildAuthHarness();
      addTearDown(base.db.close);
      addTearDown(base.container.dispose);
      final db = base.db;
      await base
          .container
          .read(authControllerProvider.notifier)
          .login('admin', 'Admin@123');
      await _seedSellableItem(db);
      final pos = _posOverrides(db);

      await tester.pumpWidget(
        _harness(base.container, pos.overrides, const PosWorkspacePage()),
      );
      await tester.pumpAndSettle();

      expect(find.text('السلة فارغة — أضف أصنافاً للبيع'), findsOneWidget);
      expect(find.text('لا توجد نتائج مطابقة'), findsOneWidget);

      await tester.enterText(find.byType(TextField).first, 'بانادول');
      await tester.pump(const Duration(milliseconds: 700));
      await tester.pumpAndSettle();

      expect(find.widgetWithText(ListTile, 'بانادول'), findsOneWidget);
      await tester.tap(find.widgetWithText(ListTile, 'بانادول'));
      await tester.pumpAndSettle();

      expect(find.text('1 علبة'), findsOneWidget);
      expect(find.text('1.00'), findsWidgets);

      await tester.tap(find.byIcon(Icons.add_circle_outline));
      await tester.pumpAndSettle();

      expect(find.text('2 علبة'), findsOneWidget);
      expect(find.text('2.00'), findsWidgets);

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

      expect(find.text('ملخص الإيصال'), findsOneWidget);
      expect(find.textContaining('رقم الفاتورة: SI-'), findsOneWidget);
      expect(find.text('بانادول × 200'), findsOneWidget);

      final search = await pos.repo.searchSaleInvoices(
        const PageRequest(page: 1, pageSize: 10),
      );
      expect(search.total, 1);
      expect(search.items.single.totalMicros, 20000);
      expect(search.items.single.paidMicros, 50000);
      expect(search.items.single.changeMicros, 30000);

      await tester.tap(find.text('إغلاق'));
      await tester.pumpAndSettle();
      expect(find.text('السلة فارغة — أضف أصنافاً للبيع'), findsOneWidget);
      expect(find.text('الباقي: 3.00'), findsNothing);
    });

    testWidgets('empty search shows no-results and the lost-sale action',
        (tester) async {
      tester.view.physicalSize = const Size(1280, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      final base = await buildAuthHarness();
      addTearDown(base.db.close);
      addTearDown(base.container.dispose);
      final db = base.db;
      await base
          .container
          .read(authControllerProvider.notifier)
          .login('admin', 'Admin@123');
      final pos = _posOverrides(db);

      await tester.pumpWidget(
        _harness(base.container, pos.overrides, const PosWorkspacePage()),
      );
      await tester.pumpAndSettle();

      await tester.enterText(
        find.byType(TextField).first,
        'غير موجود نهائياً',
      );
      await tester.pump(const Duration(milliseconds: 700));
      await tester.pumpAndSettle();

      expect(find.text('لا توجد نتائج مطابقة'), findsOneWidget);
      expect(find.text('تسجيل منتج ناقص'), findsOneWidget);
      expect(find.text('السلة فارغة — أضف أصنافاً للبيع'), findsOneWidget);
    });

    testWidgets('customer picker attaches the selected customer to the header',
        (tester) async {
      tester.view.physicalSize = const Size(1280, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      final base = await buildAuthHarness();
      addTearDown(base.db.close);
      addTearDown(base.container.dispose);
      final db = base.db;
      await base
          .container
          .read(authControllerProvider.notifier)
          .login('admin', 'Admin@123');
      await _seedCustomer(db);
      final pos = _posOverrides(db);

      await tester.pumpWidget(
        _harness(base.container, pos.overrides, const PosWorkspacePage()),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.byIcon(Icons.person_outline));
      await tester.pumpAndSettle();

      await tester.enterText(find.byType(TextField).last, 'عميل');
      await tester.pumpAndSettle();

      expect(find.text('عميل تجريبي'), findsOneWidget);
      await tester.tap(find.text('عميل تجريبي'));
      await tester.pumpAndSettle();

      expect(find.text('عميل تجريبي · 0000000000'), findsOneWidget);
    });

    testWidgets('Enter on a unique search result adds it and clears the query',
        (tester) async {
      tester.view.physicalSize = const Size(1280, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      final base = await buildAuthHarness();
      addTearDown(base.db.close);
      addTearDown(base.container.dispose);
      final db = base.db;
      await base
          .container
          .read(authControllerProvider.notifier)
          .login('admin', 'Admin@123');
      await _seedSellableItem(db);
      final pos = _posOverrides(db);

      await tester.pumpWidget(
        _harness(base.container, pos.overrides, const PosWorkspacePage()),
      );
      await tester.pumpAndSettle();

      await tester.enterText(find.byType(TextField).first, 'بانادول');
      // Long enough for the search debounce AND the scanner-buffer idle reset
      // to have run, so Enter is a plain keyboard submit (not a scan end).
      await tester.pump(const Duration(milliseconds: 700));
      await tester.pumpAndSettle();

      expect(find.widgetWithText(ListTile, 'بانادول'), findsOneWidget);

      await tester.testTextInput.receiveAction(TextInputAction.done);
      await tester.pumpAndSettle();

      expect(find.text('1 علبة'), findsOneWidget,
          reason: 'the single result joined the cart directly');
      expect(find.text('لا توجد نتائج مطابقة'), findsOneWidget,
          reason: 'the field + results were cleared for the next item');
    });

    testWidgets('Enter on ambiguous results keeps the searchable list',
        (tester) async {
      tester.view.physicalSize = const Size(1280, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      final base = await buildAuthHarness();
      addTearDown(base.db.close);
      addTearDown(base.container.dispose);
      final db = base.db;
      await base
          .container
          .read(authControllerProvider.notifier)
          .login('admin', 'Admin@123');
      await _seedSellableItem(db);
      await _seedNamedSellableItem(db, name: 'بانادول فوار', barcode: '6291041500220');
      final pos = _posOverrides(db);

      await tester.pumpWidget(
        _harness(base.container, pos.overrides, const PosWorkspacePage()),
      );
      await tester.pumpAndSettle();

      await tester.enterText(find.byType(TextField).first, 'بانادول');
      await tester.pump(const Duration(milliseconds: 700));
      await tester.pumpAndSettle();

      expect(find.byType(ListTile), findsNWidgets(2));
      expect(find.widgetWithText(ListTile, 'بانادول'), findsOneWidget);

      await tester.testTextInput.receiveAction(TextInputAction.done);
      await tester.pumpAndSettle();

      expect(find.byType(ListTile), findsNWidgets(2),
          reason: 'ambiguous results are never picked from silently');
      expect(find.text('السلة فارغة — أضف أصنافاً للبيع'), findsOneWidget,
          reason: 'nothing was added to the cart');
    });

    testWidgets('Enter right after scan keystrokes stays a scan (priority)',
        (tester) async {
      tester.view.physicalSize = const Size(1280, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      final base = await buildAuthHarness();
      addTearDown(base.db.close);
      addTearDown(base.container.dispose);
      final db = base.db;
      await base
          .container
          .read(authControllerProvider.notifier)
          .login('admin', 'Admin@123');
      await _seedSellableItem(db);
      final pos = _posOverrides(db);

      await tester.pumpWidget(
        _harness(base.container, pos.overrides, const PosWorkspacePage()),
      );
      await tester.pumpAndSettle();

      // Scan a barcode: submit before the 400ms idle window elapses, so the
      // terminator completes the in-progress scan (existing §5 behavior).
      await tester.enterText(find.byType(TextField).first, '6291041500213');
      await tester.pump(const Duration(milliseconds: 50));
      await tester.testTextInput.receiveAction(TextInputAction.done);
      await tester.pumpAndSettle();

      expect(find.text('1 علبة'), findsOneWidget,
          reason: 'the completed scan adds the barcode-matched product');
    });
  });
}