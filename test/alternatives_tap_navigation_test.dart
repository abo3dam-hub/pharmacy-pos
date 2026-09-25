/// Regression test for Ali's black-screen/freeze bug (2026-09-25).
///
/// Root cause: the app runs under a go_router ShellRoute (nested navigator)
/// while showDialog pushes dialogs onto the ROOT navigator. The old code
/// called `Navigator.of(pageContext).pop()` to close the alternatives
/// dialog — which targeted the shell navigator instead, popping the page
/// itself and corrupting the router (black screen + freeze).
///
/// Contract under test: [AlternativesDialog] dismisses ITSELF with its own
/// build context when a browse-mode row is tapped, then invokes [onOpenItem].
/// Callers must not pop. The host page underneath must stay intact.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pharmacy_pos/core/config/app_config.dart';
import 'package:pharmacy_pos/core/di/providers.dart';
import 'package:pharmacy_pos/core/theme/app_theme.dart';
import 'package:pharmacy_pos/features/inventory/presentation/widgets/item_dialog.dart';
import 'package:pharmacy_pos/features/sales/domain/entities/pos_catalog_item.dart';
import 'package:pharmacy_pos/features/sales/domain/entities/smart_alternative.dart';
import 'package:pharmacy_pos/features/sales/domain/repositories/sales_repository.dart';
import 'package:pharmacy_pos/features/sales/presentation/widgets/alternatives_dialog.dart';
import 'package:pharmacy_pos/l10n/app_localizations.dart';

PosCatalogItem _item({required String id, required String name}) {
  return PosCatalogItem(
    id: id,
    tradeName: name,
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

/// Mirrors the fixed `_ItemsTabState._openItemFromAlternatives`: NO pop here
/// (the dialog dismisses itself); async work, then the item window opens.
Future<void> _openItemFromAlternativesFixed(
  BuildContext hostContext,
  String id,
) async {
  // Stand-in for the awaited DB calls (findItem / itemUnitsFor / relations).
  await Future<void>.delayed(const Duration(milliseconds: 50));
  if (!hostContext.mounted) return;
  await showItemFormDialog(
    hostContext,
    title: 'تعديل الصنف',
    categories: const [],
    manufacturers: const [],
    units: const [],
  );
}

void main() {
  testWidgets(
    'tapping a browse-mode alternative closes its dialog, opens the item '
    'window, and leaves the host page intact',
    (tester) async {
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

      final openedIds = <String>[];
      late BuildContext hostContext;
      await tester.pumpWidget(
        ProviderScope(
          overrides: [salesRepositoryProvider.overrideWithValue(salesRepo)],
          child: MaterialApp(
            theme: AppTheme.light(),
            locale: const Locale(AppConfig.defaultLocale),
            supportedLocales: AppLocalizations.supportedLocales,
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            // Nested navigator mimics go_router's ShellRoute navigator: the
            // host page lives here, dialogs land on the root navigator.
            home: Navigator(
              onGenerateRoute: (_) => MaterialPageRoute(
                builder: (ctx) {
                  hostContext = ctx;
                  return Scaffold(
                    body: Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Text('host page marker'),
                          TextButton(
                            onPressed: () => showDialog<void>(
                              context: ctx,
                              builder: (_) => AlternativesDialog(
                                requestedItemId: 'item_1',
                                onOpenItem: (id) {
                                  openedIds.add(id);
                                  _openItemFromAlternativesFixed(
                                    hostContext,
                                    id,
                                  );
                                },
                              ),
                            ),
                            child: const Text('open alternatives'),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Open the alternatives dialog (lands on the ROOT navigator).
      await tester.tap(find.text('open alternatives'));
      await tester.pumpAndSettle();
      expect(find.text('الدواء البديل'), findsOneWidget);

      // Tap the alternative row → dialog dismisses itself, opener runs.
      await tester.tap(find.widgetWithText(ListTile, 'الدواء البديل'));
      for (var i = 0; i < 40; i++) {
        await tester.pump(const Duration(milliseconds: 100));
      }

      // 1. The opener was invoked exactly once with the alternative id.
      expect(openedIds, ['item_2']);
      // 2. The alternatives dialog is GONE (it dismissed itself).
      expect(
        find.widgetWithText(ListTile, 'الدواء البديل'),
        findsNothing,
        reason: 'alternatives dialog must close when its row is tapped',
      );
      // 3. The item window opened on top.
      expect(find.text('تعديل الصنف'), findsOneWidget);
      // 4. The host page underneath was NOT popped (the old bug popped the
      //    shell navigator's page → black screen).
      expect(find.text('host page marker'), findsOneWidget);

      // Close the item window: the host page is still there, app recovers.
      await tester.tap(find.text('إلغاء').first);
      await tester.pumpAndSettle();
      expect(find.text('host page marker'), findsOneWidget);
    },
    timeout: const Timeout(Duration(seconds: 60)),
  );

  testWidgets(
    'POS-mode tap still picks into the cart and closes the dialog',
    (tester) async {
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
      await tester.pumpWidget(
        ProviderScope(
          overrides: [salesRepositoryProvider.overrideWithValue(salesRepo)],
          child: MaterialApp(
            theme: AppTheme.light(),
            locale: const Locale(AppConfig.defaultLocale),
            supportedLocales: AppLocalizations.supportedLocales,
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            home: Navigator(
              onGenerateRoute: (_) => MaterialPageRoute(
                builder: (ctx) => Scaffold(
                  body: Center(
                    child: TextButton(
                      onPressed: () => showDialog<void>(
                        context: ctx,
                        builder: (_) => AlternativesDialog(
                          requestedItemId: 'item_1',
                          // Dialog dismisses itself, like production.
                          onPick: (a) => picked = a,
                        ),
                      ),
                      child: const Text('open alternatives'),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('open alternatives'));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(ListTile, 'الدواء البديل'));
      await tester.pumpAndSettle();

      expect(picked, isNotNull);
      expect(picked!.item.id, 'item_2');
      // The dialog closed itself after picking.
      expect(
        find.widgetWithText(ListTile, 'الدواء البديل'),
        findsNothing,
      );
    },
    timeout: const Timeout(Duration(seconds: 60)),
  );
}
