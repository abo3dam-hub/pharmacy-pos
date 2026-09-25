/// Responsive fit tests: every major dialog must fit a 1280×800 desktop
/// window and a 390×844 phone screen with no overflow exceptions and its
/// primary action visible + tappable without scrolling.
///
/// Ali's requirement: «بدي كلشي يتكيف مع حجم الشاشة» — fields, dialogs and
/// lists adapt to the screen size; nothing important may hide off-screen.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:pharmacy_pos/core/config/app_config.dart';
import 'package:pharmacy_pos/core/di/providers.dart';
import 'package:pharmacy_pos/core/theme/app_theme.dart';
import 'package:pharmacy_pos/features/inventory/presentation/widgets/batch_dialog.dart';
import 'package:pharmacy_pos/features/inventory/presentation/widgets/item_dialog.dart';
import 'package:pharmacy_pos/features/inventory/presentation/widgets/stock_adjust_dialog.dart';
import 'package:pharmacy_pos/features/sales/domain/entities/pos_catalog_item.dart';
import 'package:pharmacy_pos/features/sales/domain/entities/smart_alternative.dart';
import 'package:pharmacy_pos/features/sales/domain/repositories/sales_repository.dart';
import 'package:pharmacy_pos/features/sales/presentation/widgets/alternatives_dialog.dart';
import 'package:pharmacy_pos/features/suppliers/domain/repositories/supplier_repository.dart';
import 'package:pharmacy_pos/features/suppliers/presentation/widgets/supplier_dialog.dart';
import 'package:pharmacy_pos/l10n/app_localizations.dart';
import 'package:pharmacy_pos/shared/database/app_database.dart';

const _desktop = Size(1280, 800);
const _phone = Size(390, 844);

Widget _harness(Widget home) {
  return MaterialApp(
    theme: AppTheme.light(),
    locale: const Locale(AppConfig.defaultLocale),
    supportedLocales: AppLocalizations.supportedLocales,
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    home: home,
  );
}

const _category = CategoryRow(
    id: 'cat1', name: 'أدوية', isActive: true, createdAt: 0, updatedAt: 0);
const _manufacturer = ManufacturerRow(
    id: 'manu1', name: 'شركة المصنع', isActive: true, createdAt: 0, updatedAt: 0);
const _part = UnitRow(
    id: 'unit_part', name: 'شريط', isActive: true, createdAt: 0, updatedAt: 0);
const _box = UnitRow(
    id: 'unit_box', name: 'علبة', isActive: true, createdAt: 0, updatedAt: 0);

void _setSize(WidgetTester tester, Size size) {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);
}

/// Opens a dialog through a real button tap so [MediaQuery] sizing applies.
Future<void> _openDialog(
  WidgetTester tester,
  Future<void> Function(BuildContext context) open,
) async {
  await tester.pumpWidget(_harness(Scaffold(
    body: Builder(
      builder: (context) => Center(
        child: ElevatedButton(
          onPressed: () => open(context),
          child: const Text('افتح'),
        ),
      ),
    ),
  )));
  await tester.tap(find.text('افتح'));
  await tester.pumpAndSettle();
}

/// Fails if any overflow/layout exception was reported while pumping.
void _expectNoOverflow(WidgetTester tester) {
  final exception = tester.takeException();
  expect(exception, isNull,
      reason: 'layout overflow at ${tester.view.physicalSize}');
}

/// The dialog's primary action must be fully inside the viewport and
/// tappable — no scrolling to reach it.
Future<void> _expectActionReachable(WidgetTester tester, String label) async {
  final button = find.descendant(
    of: find.byType(AlertDialog),
    matching: find.widgetWithText(FilledButton, label),
  );
  expect(button, findsOneWidget, reason: '$label button missing');
  final rect = tester.getRect(button);
  final screen = Offset.zero & tester.view.physicalSize;
  expect(screen.contains(rect.topLeft) && screen.contains(rect.bottomRight),
      isTrue,
      reason: '$label $rect not fully visible on $screen');
  await tester.tap(button);
  await tester.pumpAndSettle();
}

Finder _fieldByLabel(String labelPart) => find.byWidgetPredicate(
    (w) => w is TextField && (w.decoration?.labelText ?? '').contains(labelPart));

// ---------------------------------------------------------------------------
// Item dialog
// ---------------------------------------------------------------------------

Future<ItemFormResult?> _openItemDialog(
  WidgetTester tester, {
  bool detailed = false,
}) async {
  ItemFormResult? result;
  await _openDialog(
      tester,
      (context) => showItemFormDialog(
            context,
            title: 'منتج جديد',
            categories: const [_category],
            manufacturers: const [_manufacturer],
            units: const [_part, _box],
          ).then((r) => result = r));
  if (detailed) {
    await tester.tap(find.text('إدخال مفصّل'));
    await tester.pumpAndSettle();
  }
  return result;
}

Future<void> _fillTradeName(WidgetTester tester) async {
  final field = find.byWidgetPredicate((w) =>
      w is TextField && (w.decoration?.labelText ?? '') == 'الاسم التجاري *');
  await tester.enterText(field, 'بنادول');
  await tester.pumpAndSettle();
}

void _itemDialogTests(String name, Size size) {
  group('item dialog @ $name', () {
    testWidgets('quick mode fits; save reachable without scrolling',
        (tester) async {
      _setSize(tester, size);
      await _openItemDialog(tester);
      _expectNoOverflow(tester);
      await _fillTradeName(tester);
      await _expectActionReachable(tester, 'حفظ');
      _expectNoOverflow(tester);
    });

    testWidgets('detailed mode: all four tabs fit; save stays reachable',
        (tester) async {
      _setSize(tester, size);
      await _openItemDialog(tester, detailed: true);
      _expectNoOverflow(tester);
      for (final tab in [
        'البيانات الأساسية',
        'المواد والجهات',
        'التسعير والمخزون',
        'ملاحظات',
      ]) {
        await tester.tap(find.descendant(
            of: find.byType(TabBar), matching: find.text(tab)));
        await tester.pumpAndSettle();
        _expectNoOverflow(tester);
      }
      // Back to the first tab where the trade-name field lives.
      await tester.tap(find.descendant(
          of: find.byType(TabBar), matching: find.text('البيانات الأساسية')));
      await tester.pumpAndSettle();
      await _fillTradeName(tester);
      await _expectActionReachable(tester, 'حفظ');
      _expectNoOverflow(tester);
    });
  });
}

// ---------------------------------------------------------------------------
// Batch dialog
// ---------------------------------------------------------------------------

void _batchDialogTests(String name, Size size) {
  testWidgets('batch dialog @ $name fits; save reachable without scrolling',
      (tester) async {
    _setSize(tester, size);
    BatchFormResult? result;
    await _openDialog(
        tester,
        (context) => showBatchFormDialog(
              context,
              itemId: 'item_1',
              // Expiry stays optional here so save succeeds without a
              // date-picker interaction; the required-expiry path is
              // covered by the existing batch flow regression test.
              hasExpiry: false,
              unitsPerLarge: 10,
              baseUnitName: 'شريط',
              largeUnitName: 'علبة',
            ).then((r) => result = r));
    _expectNoOverflow(tester);
    await tester.enterText(_fieldByLabel('رقم الدفعة'), 'B123');
    await tester.enterText(_fieldByLabel('الكمية'), '5');
    await tester.pumpAndSettle();
    await _expectActionReachable(tester, 'حفظ');
    _expectNoOverflow(tester);
    expect(result, isNotNull);
    // 5 packages × 10 parts = 50 base units (package conversion intact).
    expect(result!.input.quantityBase, 50);
  });
}

// ---------------------------------------------------------------------------
// Stock-adjust dialog
// ---------------------------------------------------------------------------

void _stockAdjustTests(String name, Size size) {
  testWidgets('stock adjust @ $name fits; save reachable without scrolling',
      (tester) async {
    _setSize(tester, size);
    StockAdjustFormResult? result;
    await _openDialog(
        tester,
        (context) => showStockAdjustDialog(
              context,
              itemId: 'item_1',
              batches: const [],
            ).then((r) => result = r));
    _expectNoOverflow(tester);
    await tester.enterText(_fieldByLabel('الكمية'), '3');
    await tester.pumpAndSettle();
    await _expectActionReachable(tester, 'حفظ');
    _expectNoOverflow(tester);
    expect(result, isNotNull);
    expect(result!.input.deltaBase, 3);
  });
}

// ---------------------------------------------------------------------------
// Supplier dialog
// ---------------------------------------------------------------------------

void _supplierDialogTests(String name, Size size) {
  testWidgets('supplier dialog @ $name fits; save reachable without scrolling',
      (tester) async {
    _setSize(tester, size);
    SupplierDraft? result;
    await _openDialog(
        tester,
        (context) => showSupplierFormDialog(context, title: 'مورد جديد')
            .then((r) => result = r));
    _expectNoOverflow(tester);
    await tester.enterText(_fieldByLabel('الاسم'), 'مورد الاختبار');
    await tester.pumpAndSettle();
    await _expectActionReachable(tester, 'حفظ');
    _expectNoOverflow(tester);
    expect(result, isNotNull);
    expect(result!.name, 'مورد الاختبار');
  });
}

// ---------------------------------------------------------------------------
// Alternatives dialog (fake repository, browse mode)
// ---------------------------------------------------------------------------

PosCatalogItem _catalogItem({required String id, required String name}) {
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

void _alternativesTests(String name, Size size) {
  testWidgets('alternatives dialog @ $name fits; close reachable',
      (tester) async {
    _setSize(tester, size);
    final requested = _catalogItem(id: 'item_1', name: 'الدواء المطلوب');
    final repo = _FakeSalesRepository(
      requested: requested,
      alternatives: [
        for (var i = 0; i < 12; i++)
          SmartAlternative(
            item: _catalogItem(id: 'alt_$i', name: 'بديل $i'),
            tier: SmartAlternativeTier.tier1,
            matchPercent: 100,
          ),
      ],
    );
    await tester.pumpWidget(
      ProviderScope(
        overrides: [salesRepositoryProvider.overrideWithValue(repo)],
        child: _harness(const Scaffold(
          body: AlternativesDialog(requestedItemId: 'item_1'),
        )),
      ),
    );
    await tester.pumpAndSettle();
    _expectNoOverflow(tester);
    // A dozen rows must scroll internally; the close action stays put.
    final close = find.descendant(
      of: find.byType(AlertDialog),
      matching: find.text('إغلاق'),
    );
    expect(close, findsOneWidget);
    final rect = tester.getRect(close);
    final screen = Offset.zero & tester.view.physicalSize;
    expect(screen.contains(rect.topLeft) && screen.contains(rect.bottomRight),
        isTrue,
        reason: 'close $rect not fully visible on $screen');
    await tester.tap(close);
    await tester.pumpAndSettle();
    _expectNoOverflow(tester);
  });
}

void main() {
  _itemDialogTests('desktop 1280x800', _desktop);
  _itemDialogTests('phone 390x844', _phone);
  _batchDialogTests('desktop 1280x800', _desktop);
  _batchDialogTests('phone 390x844', _phone);
  _stockAdjustTests('desktop 1280x800', _desktop);
  _stockAdjustTests('phone 390x844', _phone);
  _supplierDialogTests('desktop 1280x800', _desktop);
  _supplierDialogTests('phone 390x844', _phone);
  _alternativesTests('desktop 1280x800', _desktop);
  _alternativesTests('phone 390x844', _phone);
}
