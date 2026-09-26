/// Responsive fit tests for the 2026-09-26 redesigned item window plus the
/// other major dialogs.
///
/// Item dialog (all four required viewports: 1280×800, 1280×900, 1920×1080,
/// 390×844):
///   • no overflow / layout exceptions,
///   • the main window never scrolls — only long inner lists may,
///   • the footer (إلغاء / حفظ / حفظ و اضافة الى المخزون) is always visible
///     and fully inside the viewport,
///   • essential fields stay reachable,
///   • RTL,
///   • add/edit, validation, save, save-and-add-to-inventory and cancel all
///     work; existing values appear in edit and modified values persist.
///
/// Other dialogs keep their original two-viewport coverage (unchanged UI).
///
/// Ali's requirement: «بدي كلشي يتكيف مع حجم الشاشة» — fields, dialogs and
/// lists adapt to the screen size; nothing important may hide off-screen.
library;

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:pharmacy_pos/core/config/app_config.dart';
import 'package:pharmacy_pos/core/di/providers.dart';
import 'package:pharmacy_pos/core/theme/app_theme.dart';
import 'package:pharmacy_pos/features/inventory/domain/repositories/inventory_repository.dart';
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

/// The four viewports the redesigned item window must support.
const _itemSizes = <String, Size>{
  'desktop 1280x800': Size(1280, 800),
  'desktop 1280x900': Size(1280, 900),
  'desktop 1920x1080': Size(1920, 1080),
  'phone 390x844': Size(390, 844),
};

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

/// Handle capturing a dialog's result future. The dialog opens through a
/// real button tap; [result] completes when the dialog pops.
class _DialogHandle<T> {
  Future<T?>? result;
}

/// Opens a dialog through a real button tap so [MediaQuery] sizing applies.
/// All [WidgetTester] calls are awaited sequentially in the test body;
/// [handle.result] completes with the dialog's result when it pops.
Future<void> _openDialog<T>(
  WidgetTester tester,
  _DialogHandle<T> handle,
  Future<T?> Function(BuildContext context) open,
) async {
  final completer = Completer<T?>();
  handle.result = completer.future;
  await tester.pumpWidget(_harness(Scaffold(
    body: Builder(
      builder: (context) => Center(
        child: ElevatedButton(
          // Runs outside the test's guarded zone; completing the future
          // here is safe.
          onPressed: () => completer.complete(open(context)),
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

/// A button must be fully inside the viewport and tappable — no scrolling
/// to reach it.
Future<void> _expectButtonReachable(WidgetTester tester, Finder button) async {
  expect(button, findsOneWidget);
  final rect = tester.getRect(button);
  final screen = Offset.zero & tester.view.physicalSize;
  expect(screen.contains(rect.topLeft) && screen.contains(rect.bottomRight),
      isTrue,
      reason: 'button $rect not fully visible on $screen');
  await tester.tap(button);
  await tester.pumpAndSettle();
}

Finder _fieldByLabel(String labelPart) => find.byWidgetPredicate(
    (w) => w is TextField && (w.decoration?.labelText ?? '').contains(labelPart));

// ---------------------------------------------------------------------------
// Item dialog — fit at all four required viewports
// ---------------------------------------------------------------------------

/// Opens the item dialog; [handle.result] completes with the form result
/// when the dialog pops.
Future<void> _openItemDialog(
  WidgetTester tester,
  _DialogHandle<ItemFormResult?> handle, {
  ItemDraft? initial,
  bool showContinueAction = false,
}) {
  return _openDialog(
      tester,
      handle,
      (context) => showItemFormDialog(
            context,
            title: 'منتج جديد',
            initial: initial,
            categories: const [_category],
            manufacturers: const [_manufacturer],
            units: const [_part, _box],
            showContinueAction: showContinueAction,
          ));
}

Future<void> _fillTradeName(WidgetTester tester) async {
  final field = find.byWidgetPredicate((w) =>
      w is TextField && (w.decoration?.labelText ?? '') == 'الاسم التجاري *');
  await tester.enterText(field, 'بنادول');
  await tester.pumpAndSettle();
}

void _itemDialogFitTests(String name, Size size) {
  group('item dialog @ $name', () {
    testWidgets('fits; main window does not scroll; save reachable',
        (tester) async {
      _setSize(tester, size);
      final handle = _DialogHandle<ItemFormResult?>();
      await _openItemDialog(tester, handle);
      _expectNoOverflow(tester);

      // The header title and the footer actions are pinned — neither sits
      // inside a scrollable, so the main window itself never scrolls.
      expect(
          find.ancestor(
              of: find.text('منتج جديد'),
              matching: find.byType(Scrollable)),
          findsNothing,
          reason: 'header must not scroll');
      final save = find.widgetWithText(FilledButton, 'حفظ');
      expect(
          find.ancestor(of: save, matching: find.byType(Scrollable)),
          findsNothing,
          reason: 'footer must not scroll');

      await _fillTradeName(tester);
      await _expectButtonReachable(tester, save);
      _expectNoOverflow(tester);
    });
  });
}

// ---------------------------------------------------------------------------
// Item dialog — behavior at desktop + phone
// ---------------------------------------------------------------------------

void _itemDialogBehaviorTests(String name, Size size) {
  final phone = size.width < 960;
  group('item dialog behavior @ $name', () {
    testWidgets('all sections reachable; RTL', (tester) async {
      _setSize(tester, size);
      final handle = _DialogHandle<ItemFormResult?>();
      await _openItemDialog(tester, handle);
      _expectNoOverflow(tester);

      expect(Directionality.of(tester.element(find.byType(Dialog).first)),
          TextDirection.rtl);

      if (phone) {
        // Narrow screens switch the three column groups explicitly — no
        // tabs, no wizard, no new navigation.
        expect(find.byType(TabBar), findsNothing);
        await tester.tap(find.text('التعبئة والمبيعات'));
        await tester.pumpAndSettle();
        expect(find.text('التعبئة التجارية'), findsOneWidget);
        _expectNoOverflow(tester);
        await tester.tap(find.text('التصنيفات والاستطبابات'));
        await tester.pumpAndSettle();
        expect(find.text('التصنيفات والاستطبابات'), findsWidgets);
        _expectNoOverflow(tester);
        await tester.tap(find.text('معلومات أساسية'));
        await tester.pumpAndSettle();
      } else {
        // Desktop: all seven sections visible at once.
        for (final section in [
          'معلومات أساسية',
          'التفاصيل الفنية',
          'التعبئة والمبيعات',
          'التسعير',
          'المخزون والتسعير المتقدم',
          'التصنيفات والاستطبابات',
          'البدائل',
        ]) {
          expect(find.text(section), findsOneWidget);
        }
      }
      _expectNoOverflow(tester);
    });

    testWidgets('validation blocks empty save; targeted message',
        (tester) async {
      _setSize(tester, size);
      var submitted = false;
      // The dialog stays open on validation failure, so its result future
      // never completes — track submission via a side effect instead.
      final handle = _DialogHandle<ItemFormResult?>();
      await _openDialog(tester, handle, (context) {
        return showItemFormDialog(
          context,
          title: 'منتج جديد',
          categories: const [_category],
          manufacturers: const [_manufacturer],
          units: const [_part, _box],
        ).then((r) {
          submitted = true;
          return r;
        });
      });
      _expectNoOverflow(tester);
      await _expectButtonReachable(
          tester, find.widgetWithText(FilledButton, 'حفظ'));
      expect(submitted, isFalse, reason: 'invalid form must not submit');
      expect(find.text('الاسم مطلوب'), findsOneWidget);
      expect(find.byType(Dialog), findsOneWidget,
          reason: 'dialog stays open on validation failure');
      _expectNoOverflow(tester);
    });

    testWidgets('save persists the draft; cancel discards', (tester) async {
      _setSize(tester, size);
      final handle = _DialogHandle<ItemFormResult?>();
      await _openItemDialog(tester, handle);
      await _fillTradeName(tester);
      await _expectButtonReachable(
          tester, find.widgetWithText(FilledButton, 'حفظ'));
      final result = await handle.result;
      expect(result?.draft.tradeName, 'بنادول');
      expect(result?.action, ItemFormAction.save);
      _expectNoOverflow(tester);

      // Cancel path.
      final cancelHandle = _DialogHandle<ItemFormResult?>();
      await _openDialog(
          tester,
          cancelHandle,
          (context) => showItemFormDialog(
                context,
                title: 'منتج جديد',
                categories: const [_category],
                manufacturers: const [_manufacturer],
                units: const [_part, _box],
              ));
      await _expectButtonReachable(tester, find.text('إلغاء'));
      expect(await cancelHandle.result, isNull, reason: 'cancel returns null');
      _expectNoOverflow(tester);
    });

    testWidgets('save-and-add-to-inventory action flows through',
        (tester) async {
      _setSize(tester, size);
      final handle = _DialogHandle<ItemFormResult?>();
      await _openItemDialog(tester, handle, showContinueAction: true);
      _expectNoOverflow(tester);
      await _fillTradeName(tester);
      await _expectButtonReachable(tester, find.text('حفظ و اضافة الى المخزون'));
      final result = await handle.result;
      expect(result?.action, ItemFormAction.saveContinue);
      expect(result?.draft.tradeName, 'بنادول');
      _expectNoOverflow(tester);
    });

    testWidgets('edit pre-fills existing values; modified values persist',
        (tester) async {
      _setSize(tester, size);
      final handle = _DialogHandle<ItemFormResult?>();
      await _openItemDialog(
        tester,
        handle,
        initial: const ItemDraft(
          tradeName: 'بنادول إكسترا',
          dose: '500mg',
          categoryId: 'cat1',
        ),
      );
      _expectNoOverflow(tester);

      final nameField = find.byWidgetPredicate((w) =>
          w is TextField &&
          (w.decoration?.labelText ?? '') == 'الاسم التجاري *');
      expect(tester.widget<TextField>(nameField).controller!.text,
          'بنادول إكسترا',
          reason: 'existing values appear in edit mode');

      await tester.enterText(nameField, 'بنادول معدل');
      await tester.pumpAndSettle();
      await _expectButtonReachable(
          tester, find.widgetWithText(FilledButton, 'حفظ'));
      final result = await handle.result;
      expect(result?.draft.tradeName, 'بنادول معدل',
          reason: 'modified values persist');
      expect(result?.draft.dose, '500mg');
      expect(result?.draft.categoryId, 'cat1');
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
    final handle = _DialogHandle<BatchFormResult?>();
    await _openDialog(
        tester,
        handle,
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
            ));
    _expectNoOverflow(tester);
    await tester.enterText(_fieldByLabel('رقم الدفعة'), 'B123');
    await tester.enterText(_fieldByLabel('الكمية'), '5');
    await tester.pumpAndSettle();
    await _expectButtonReachable(
        tester, find.widgetWithText(FilledButton, 'حفظ'));
    _expectNoOverflow(tester);
    final result = await handle.result;
    expect(result, isNotNull);
    // 5 packages × 10 parts = 50 base units (package conversion intact).
    expect(result?.input.quantityBase, 50);
  });
}

// ---------------------------------------------------------------------------
// Stock-adjust dialog
// ---------------------------------------------------------------------------

void _stockAdjustTests(String name, Size size) {
  testWidgets('stock adjust @ $name fits; save reachable without scrolling',
      (tester) async {
    _setSize(tester, size);
    final handle = _DialogHandle<StockAdjustFormResult?>();
    await _openDialog(
        tester,
        handle,
        (context) => showStockAdjustDialog(
              context,
              itemId: 'item_1',
              batches: const [],
            ));
    _expectNoOverflow(tester);
    await tester.enterText(_fieldByLabel('الكمية'), '3');
    await tester.pumpAndSettle();
    await _expectButtonReachable(
        tester, find.widgetWithText(FilledButton, 'حفظ'));
    _expectNoOverflow(tester);
    final result = await handle.result;
    expect(result, isNotNull);
    expect(result?.input.deltaBase, 3);
  });
}

// ---------------------------------------------------------------------------
// Supplier dialog
// ---------------------------------------------------------------------------

void _supplierDialogTests(String name, Size size) {
  testWidgets('supplier dialog @ $name fits; save reachable without scrolling',
      (tester) async {
    _setSize(tester, size);
    final handle = _DialogHandle<SupplierDraft?>();
    await _openDialog(
        tester,
        handle,
        (context) => showSupplierFormDialog(context, title: 'مورد جديد'));
    _expectNoOverflow(tester);
    await tester.enterText(_fieldByLabel('الاسم'), 'مورد الاختبار');
    await tester.pumpAndSettle();
    await _expectButtonReachable(
        tester, find.widgetWithText(FilledButton, 'حفظ'));
    _expectNoOverflow(tester);
    final result = await handle.result;
    expect(result, isNotNull);
    expect(result?.name, 'مورد الاختبار');
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
  // Item dialog: fit at all four required viewports…
  for (final entry in _itemSizes.entries) {
    _itemDialogFitTests(entry.key, entry.value);
  }
  // …full behavior at desktop + phone.
  _itemDialogBehaviorTests('desktop 1280x800', _desktop);
  _itemDialogBehaviorTests('phone 390x844', _phone);

  _batchDialogTests('desktop 1280x800', _desktop);
  _batchDialogTests('phone 390x844', _phone);
  _stockAdjustTests('desktop 1280x800', _desktop);
  _stockAdjustTests('phone 390x844', _phone);
  _supplierDialogTests('desktop 1280x800', _desktop);
  _supplierDialogTests('phone 390x844', _phone);
  _alternativesTests('desktop 1280x800', _desktop);
  _alternativesTests('phone 390x844', _phone);
}
