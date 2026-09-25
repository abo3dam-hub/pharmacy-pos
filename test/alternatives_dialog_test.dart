/// Alternatives dialog widget acceptance.
///
/// Verifies Ali's request: every alternative row is tappable and opens the
/// item's own window ([ProductDetailDialog]) in browse mode (the dialog is
/// shared by the inventory items grid and the product tree), and each row
/// carries a tooltip with the manufacturer + active ingredients.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pharmacy_pos/core/config/app_config.dart';
import 'package:pharmacy_pos/core/di/providers.dart';
import 'package:pharmacy_pos/core/theme/app_theme.dart';
import 'package:pharmacy_pos/features/inventory/domain/repositories/inventory_repository.dart';
import 'package:pharmacy_pos/features/sales/domain/entities/pos_catalog_item.dart';
import 'package:pharmacy_pos/features/sales/domain/entities/smart_alternative.dart';
import 'package:pharmacy_pos/features/sales/domain/repositories/sales_repository.dart';
import 'package:pharmacy_pos/features/sales/presentation/widgets/alternatives_dialog.dart';
import 'package:pharmacy_pos/features/sales/presentation/widgets/product_detail_dialog.dart';
import 'package:pharmacy_pos/l10n/app_localizations.dart';
import 'package:pharmacy_pos/shared/database/app_database.dart';

PosCatalogItem _item({
  required String id,
  required String name,
  String? manufacturer,
  List<String> ingredients = const [],
  Map<String, String> strengths = const {},
}) {
  return PosCatalogItem(
    id: id,
    tradeName: name,
    manufacturerName: manufacturer,
    relationalIngredientNames: ingredients,
    relationalIngredientStrengths: strengths,
    isControlledDrug: false,
    requiresPrescription: false,
    isActive: true,
    sellingPriceMicros: 100000000,
    vatRateBasisPoints: 0,
    currentStockBase: 10,
    availableStockBase: 10,
    baseUnitId: 'u1',
    baseUnitName: 'شريط',
    largeUnitId: 'u2',
    largeUnitName: 'علبة',
    unitsPerLarge: 1,
    partialSaleEnabled: false,
  );
}

class _FakeSalesRepository implements SalesRepository {
  _FakeSalesRepository({required this.requested, required this.alternatives});

  final PosCatalogItem requested;
  final List<SmartAlternative> alternatives;

  @override
  Future<PosCatalogItem?> itemById(String id) async =>
      id == requested.id ? requested : null;

  @override
  Future<List<SmartAlternative>> smartAlternatives(PosCatalogItem item) async =>
      alternatives;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _FakeInventoryRepository implements InventoryRepository {
  _FakeInventoryRepository(this.item);

  final ItemRow item;

  @override
  Future<ItemRow?> findItem(String id) async => id == item.id ? item : null;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

ItemRow _itemRow(String id, String name) {
  return ItemRow(
    id: id,
    tradeName: name,
    hasExpiry: false,
    isControlledDrug: false,
    lockAutoPriceUpdate: false,
    requiresPrescription: false,
    costMicros: 80000000,
    purchaseDiscountBasisPoints: 0,
    sellingPriceMicros: 100000000,
    subUnitPriceMicros: 0,
    wholesalePriceMicros: 0,
    halfWholesalePriceMicros: 0,
    customPrice1Micros: 0,
    customPrice2Micros: 0,
    vatRateBasisPoints: 0,
    profitMarginBasisPoints: 2500,
    minimumStockBase: 0,
    maximumStockBase: 0,
    currentStockBase: 10,
    partialSaleEnabled: false,
    isActive: true,
    createdAt: 0,
    updatedAt: 0,
  );
}

void main() {
  Future<void> pumpDialog(
    WidgetTester tester, {
    ValueChanged<String>? onOpenItem,
  }) async {
    final requested = _item(id: 'item_1', name: 'الدواء المطلوب');
    final alt = _item(
      id: 'item_2',
      name: 'الدواء البديل',
      manufacturer: 'شركة الشفاء',
      ingredients: ['باراسيتامول'],
      strengths: {'باراسيتامول': '500 ملغ'},
    );
    final salesRepo = _FakeSalesRepository(
      requested: requested,
      alternatives: [
        SmartAlternative(
          item: alt,
          tier: SmartAlternativeTier.tier1,
          matchPercent: 100,
        ),
      ],
    );
    final inventoryRepo = _FakeInventoryRepository(
      _itemRow('item_2', 'الدواء البديل'),
    );

    tester.view.physicalSize = const Size(1280, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          salesRepositoryProvider.overrideWithValue(salesRepo),
          inventoryRepositoryProvider.overrideWithValue(inventoryRepo),
        ],
        child: MaterialApp(
          theme: AppTheme.light(),
          locale: const Locale(AppConfig.defaultLocale),
          supportedLocales: AppLocalizations.supportedLocales,
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          home: Scaffold(
            body: AlternativesDialog(
              requestedItemId: 'item_1',
              onOpenItem: onOpenItem,
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('browse-mode rows are tappable and open the item window', (
    tester,
  ) async {
    await pumpDialog(tester);

    // The alternative row renders…
    expect(find.text('الدواء البديل'), findsOneWidget);
    // …and is tappable (browse mode: no onPick).
    final tile = tester.widget<ListTile>(
      find.widgetWithText(ListTile, 'الدواء البديل'),
    );
    expect(tile.onTap, isNotNull);

    await tester.tap(find.widgetWithText(ListTile, 'الدواء البديل'));
    await tester.pumpAndSettle();

    // The item's own window opens on top.
    expect(find.byType(ProductDetailDialog), findsOneWidget);
    expect(find.text('الدواء البديل'), findsWidgets);
  });

  testWidgets(
    'browse-mode tap calls onOpenItem with the alternative id when supplied',
    (tester) async {
      final opened = <String>[];
      await pumpDialog(tester, onOpenItem: opened.add);

      await tester.tap(find.widgetWithText(ListTile, 'الدواء البديل'));
      await tester.pumpAndSettle();

      // The caller's item window opens (via the callback), not the generic
      // read-only detail dialog.
      expect(opened, ['item_2']);
      expect(find.byType(ProductDetailDialog), findsNothing);
    },
  );

  testWidgets('row tooltip shows manufacturer and active ingredients', (
    tester,
  ) async {
    await pumpDialog(tester);

    final tooltip = tester.widget<Tooltip>(
      find.byWidgetPredicate(
        (w) =>
            w is Tooltip &&
            (w.message ?? '').contains('شركة الشفاء'),
      ),
    );
    expect(tooltip.message, contains('باراسيتامول'));
    expect(tooltip.message, contains('500 ملغ'));
  });

  testWidgets('POS mode rows still pick into the cart on tap', (tester) async {
    final requested = _item(id: 'item_1', name: 'الدواء المطلوب');
    final alt = _item(id: 'item_2', name: 'الدواء البديل');
    final salesRepo = _FakeSalesRepository(
      requested: requested,
      alternatives: [
        SmartAlternative(
          item: alt,
          tier: SmartAlternativeTier.tier1,
          matchPercent: 100,
        ),
      ],
    );

    SmartAlternative? picked;
    tester.view.physicalSize = const Size(1280, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [salesRepositoryProvider.overrideWithValue(salesRepo)],
        child: MaterialApp(
          theme: AppTheme.light(),
          locale: const Locale(AppConfig.defaultLocale),
          supportedLocales: AppLocalizations.supportedLocales,
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          home: Scaffold(
            body: AlternativesDialog(
              requestedItemId: 'item_1',
              onPick: (a) => picked = a,
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.widgetWithText(ListTile, 'الدواء البديل'));
    await tester.pumpAndSettle();

    // Tapping in POS mode calls onPick (cart), not the detail window.
    expect(picked, isNotNull);
    expect(picked!.item.id, 'item_2');
    expect(find.byType(ProductDetailDialog), findsNothing);
  });
}
