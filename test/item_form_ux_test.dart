import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:pharmacy_pos/core/config/app_config.dart';
import 'package:pharmacy_pos/core/theme/app_theme.dart';
import 'package:pharmacy_pos/core/widgets/app_shell.dart';
import 'package:pharmacy_pos/features/inventory/domain/repositories/inventory_repository.dart';
import 'package:pharmacy_pos/features/inventory/presentation/widgets/item_dialog.dart';
import 'package:pharmacy_pos/features/inventory/presentation/widgets/master_data_dialog.dart';
import 'package:pharmacy_pos/features/suppliers/domain/repositories/supplier_repository.dart';
import 'package:pharmacy_pos/l10n/app_localizations.dart';
import 'package:pharmacy_pos/shared/database/app_database.dart';

/// Phase 17 product-master UX regression tests:
///   1. desktop rail is scrollable so late sections stay reachable,
///   2. the item form guides the user with targeted messages instead of the
///      generic save error when units are missing/invalid,
///   3. التعبئة التجارية / الأجزاء / عدد الأجزاء labels and section order,
///   4. many-to-many supplier chips flow into the draft,
///   5. inline master-data creation auto-selects the created row,
///   6. active-ingredient strength fields flow into the draft,
///   7. partial-sale switch auto-fills the default 20% markup, validates parts,
///      and persists the auto/manual سعر بيع الجزء model.
Widget harness(Widget home) {
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
    id: 'unit_part', name: 'ظرف', isActive: true, createdAt: 0, updatedAt: 0);
const _box = UnitRow(
    id: 'unit_box', name: 'علبة', isActive: true, createdAt: 0, updatedAt: 0);
const _ingredient = ActiveIngredientRow(
    id: 'ing1', name: 'باراسيتامول', isActive: true, createdAt: 0, updatedAt: 0);

SupplierRow _supplier(String id, String name) => SupplierRow(
    id: id,
    name: name,
    openingBalanceMicros: 0,
    balanceMicros: 0,
    creditLimitMicros: 0,
    isActive: true,
    createdAt: 0,
    updatedAt: 0);

/// Finds the editable [TextField] whose label contains [labelPart]. Both
/// `TextFormField`s and the searchable comboboxes render a `TextField`, so this
/// works for every input in the form.
Finder _fieldByLabel(String labelPart) => find.byWidgetPredicate(
    (w) =>
        w is TextField && (w.decoration?.labelText ?? '').contains(labelPart));

/// Exact label match for combobox/tapping targets.
Finder _comboByLabel(String label) => find.byWidgetPredicate(
    (w) => w is TextField && (w.decoration?.labelText ?? '') == label);

Future<void> _enterTradeName(WidgetTester tester, String name) async {
  await tester.enterText(_comboByLabel('الاسم التجاري *'), name);
  await tester.pumpAndSettle();
}

Future<void> _selectCombo(WidgetTester tester, String label, String item) async {
  final field = _comboByLabel(label);
  await tester.ensureVisible(field);
  await tester.pumpAndSettle();
  await tester.tap(field);
  await tester.pumpAndSettle();
  // The opened list is rendered inline inside the dialog scroll view; bring
  // the tile into view before tapping so the hit test cannot miss.
  final tile = find.text(item).last;
  await tester.ensureVisible(tile);
  await tester.pumpAndSettle();
  await tester.tap(tile);
  await tester.pumpAndSettle();
}

Future<void> _tapChip(WidgetTester tester, String label) async {
  await tester.ensureVisible(find.text(label));
  await tester.pumpAndSettle();
  await tester.tap(find.text(label));
  await tester.pumpAndSettle();
}

Future<void> _tapSave(WidgetTester tester) async {
  await tester.tap(find.descendant(
      of: find.byType(AlertDialog).last, matching: find.text('حفظ')));
  await tester.pumpAndSettle();
}

/// Opens the item form dialog via a real button; [onResult] receives the
/// returned draft on save.
Future<void> _openDialog(
  WidgetTester tester, {
  required void Function(ItemFormResult? result) onResult,
  ItemDraft? initial,
  List<CategoryRow> categories = const [_category],
  List<ManufacturerRow> manufacturers = const [_manufacturer],
List<UnitRow> units = const [_part, _box],
    List<SupplierRow> suppliers = const [],
    List<ActiveIngredientRow> activeIngredients = const [_ingredient],
    Future<Object?> Function(MasterDataKind kind, MasterDataDraft draft)?
        onCreateMasterData,
}) async {
    await tester.pumpWidget(harness(Scaffold(
      body: Builder(
        builder: (context) => Center(
          child: ElevatedButton(
            onPressed: () async {
              final result = await showItemFormDialog(
                context,
                title: 'منتج جديد',
                initial: initial,
                categories: categories,
                manufacturers: manufacturers,
                units: units,
                suppliers: suppliers,
                activeIngredients: activeIngredients,
                onCreateMasterData: onCreateMasterData,
                onCreateSupplier: _factorySupplier,
              );
              onResult(result);
            },
            child: const Text('افتح النموذج'),
          ),
        ),
      ),
    )));
    await tester.tap(find.text('افتح النموذج'));
    await tester.pumpAndSettle();
  }

  Future<SupplierRow?> _factorySupplier(SupplierDraft draft) async =>
      SupplierRow(
          id: 'sup_new',
          name: draft.name,
          openingBalanceMicros: 0,
          balanceMicros: 0,
          creditLimitMicros: 0,
          isActive: true,
          createdAt: 1,
          updatedAt: 1);

void main() {
  testWidgets('desktop rail is scrollable; settings stays reachable',
      (tester) async {
    tester.view.physicalSize = const Size(1280, 560);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(harness(const AppShell()));
    await tester.pumpAndSettle();

    final rail = tester.widget<NavigationRail>(find.byType(NavigationRail));
    expect(rail.scrollable, isTrue,
        reason: '12 destinations overflow short viewports; the rail must scroll');

    final scrollable = find.descendant(
      of: find.byType(NavigationRail),
      matching: find.byType(Scrollable),
    );
    expect(scrollable, findsWidgets);
    await tester.drag(scrollable.first, const Offset(0, -600));
    await tester.pumpAndSettle();

    await tester.tap(find.text('الإعدادات').first, warnIfMissed: false);
    await tester.pumpAndSettle();
    expect(find.widgetWithText(AppBar, 'الإعدادات'), findsOneWidget);
  });

  testWidgets(
      'missing/invalid parts guidance is targeted and the parts relation saves',
      (tester) async {
    tester.view.physicalSize = const Size(1100, 1500);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    ItemFormResult? submitted;
    await _openDialog(tester, onResult: (r) => submitted = r);

    await _enterTradeName(tester, 'بانادول');
    await _selectCombo(tester, 'التصنيف', 'أدوية');

    // No parts unit selected → targeted guidance (was the generic save-error
    // regression) and the dialog must stay open.
    await _tapSave(tester);
    expect(find.text('اختر الأجزاء'), findsOneWidget,
        reason: 'missing parts-unit guidance must surface, not a generic error');
    expect(find.byType(AlertDialog), findsOneWidget);

    // Select the parts unit → packaging is auto-suggested.
    await _selectCombo(tester, 'الأجزاء', 'ظرف');
    await tester.pumpAndSettle();

    // parts = 0 is rejected with a targeted message.
    await tester.enterText(_fieldByLabel('عدد الأجزاء'), '0');
    await tester.pumpAndSettle();
    await _tapSave(tester);
    expect(find.text('عدد الأجزاء يجب أن يكون أكبر من صفر'), findsOneWidget);

    // Valid values → the draft carries the unit relation.
    await tester.enterText(_fieldByLabel('عدد الأجزاء'), '10');
    await tester.pumpAndSettle();
    await _tapSave(tester);

    expect(submitted, isNotNull);
    final relation = submitted!.draft.units;
    expect(relation, isNotNull);
    expect(relation!.baseUnitId, 'unit_part');
    expect(relation.largeUnitId, 'unit_part',
        reason: 'packaging is auto-suggested from the parts unit when unset');
    expect(relation.unitsPerLarge, 10);
  });

  testWidgets('labels and section order match the Phase 17 product master',
      (tester) async {
    tester.view.physicalSize = const Size(1100, 1500);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await _openDialog(tester, onResult: (_) {});

    // Phase 17 packaging/parts labels are used (no legacy unit naming).
    expect(find.text('التعبئة التجارية'), findsOneWidget);
    expect(find.text('الأجزاء'), findsOneWidget);
    expect(find.text('عدد الأجزاء'), findsOneWidget);

    double y(String text) => tester.getTopLeft(find.text(text)).dy;

    // Documented order: classification → parts/pricing → stock.
    expect(y('التصنيف والمعلومات الدوائية'),
        lessThan(y('التكلفة / السعر / الأجزاء')));
    expect(y('الموردون'), lessThan(y('التكلفة / السعر / الأجزاء')));
    expect(y('التكلفة / السعر / الأجزاء'), lessThan(y('الرصيد')),
        reason: 'pricing section precedes the stock section');
  });

  testWidgets('supplier chips toggle a many-to-many selection in the draft',
      (tester) async {
    tester.view.physicalSize = const Size(1100, 1500);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    ItemFormResult? submitted;
    await _openDialog(
      tester,
      onResult: (r) => submitted = r,
      suppliers: [_supplier('sup_a', 'مورد الأول'), _supplier('sup_b', 'مورد الثاني')],
    );

    await _enterTradeName(tester, 'منتج بموردين');
    await _selectCombo(tester, 'التصنيف', 'أدوية');
    await _tapChip(tester, 'مورد الأول');
    await _tapChip(tester, 'مورد الثاني');
    await _selectCombo(tester, 'الأجزاء', 'ظرف');
    await _tapSave(tester);

    final withBoth = submitted;
    expect(withBoth, isNotNull);
    expect(withBoth!.draft.supplierIds, unorderedEquals(['sup_a', 'sup_b']));

    // Re-open in edit mode with both suppliers pre-selected; untoggling a
    // chip removes it on save.
    submitted = null;
    await _openDialog(
      tester,
      onResult: (r) => submitted = r,
      suppliers: [_supplier('sup_a', 'مورد الأول'), _supplier('sup_b', 'مورد الثاني')],
      initial: const ItemDraft(
        tradeName: 'منتج بمورد واحد',
        categoryId: 'cat1',
        units: ItemUnitRelation(
            baseUnitId: 'unit_part', largeUnitId: 'unit_box', unitsPerLarge: 10),
        supplierIds: ['sup_a', 'sup_b'],
      ),
    );
    await _tapChip(tester, 'مورد الأول');
    await _tapSave(tester);

    final withOne = submitted;
    expect(withOne, isNotNull);
    expect(withOne!.draft.supplierIds, ['sup_b']);
  });

  testWidgets('inline category creation auto-selects the created row',
      (tester) async {
    tester.view.physicalSize = const Size(1100, 1500);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    ItemFormResult? submitted;
    await _openDialog(
      tester,
      onResult: (r) => submitted = r,
      onCreateMasterData: (kind, draft) async => CategoryRow(
          id: 'cat_new', name: draft.name, isActive: true, createdAt: 1, updatedAt: 1),
    );

    // Inline "+" exists for category / manufacturer / packaging / parts units /
    // active ingredient / indication / supplier.
    expect(find.byIcon(Icons.add_circle_outline), findsNWidgets(7));
    await tester.tap(find.byIcon(Icons.add_circle_outline).at(0));
    await tester.pumpAndSettle();
    expect(find.text('إضافة تصنيف جديد'), findsOneWidget);

    await tester.enterText(_fieldByLabel('اسم التصنيف'), 'فئة جديدة');
    await tester.pumpAndSettle();
    await _tapSave(tester);

    // Back on the item form the created category is shown, then saved.
    await _enterTradeName(tester, 'منتج بتصنيف جديد');
    await _selectCombo(tester, 'الأجزاء', 'ظرف');
    await _tapSave(tester);

    final saved = submitted;
    expect(saved, isNotNull);
    expect(saved!.draft.categoryId, 'cat_new',
        reason: 'the inline-created category is auto-selected');
  });

  testWidgets('active-ingredient strength flows into the draft',
      (tester) async {
    tester.view.physicalSize = const Size(1100, 1500);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    ItemFormResult? submitted;
    await _openDialog(tester, onResult: (r) => submitted = r);

    await _enterTradeName(tester, 'منتج بالعيار');
    await _selectCombo(tester, 'التصنيف', 'أدوية');
    // The active-ingredient selector is searchable (§Phase 18): type to reveal
    // matches, then tap the row to add it with its strength.
    await tester.enterText(_fieldByLabel('ابحث عن مادة فعالة…'), 'باراسيتا');
    await tester.pumpAndSettle();
    await tester.tap(find.text('باراسيتامول').last);
    await tester.pumpAndSettle();
    await tester.enterText(_fieldByLabel('العيار'), '500 ملغ');
    await tester.pumpAndSettle();
    await _selectCombo(tester, 'الأجزاء', 'ظرف');
    await _tapSave(tester);

    final saved = submitted;
    expect(saved, isNotNull);
    if (saved == null) return;
    final d = saved.draft;
    expect(d.activeIngredientIds, ['ing1']);
    expect(d.activeIngredientStrengths, {'ing1': '500 ملغ'});
  });

  testWidgets('partial-sale default 20% markup, validation and part price',
      (tester) async {
    tester.view.physicalSize = const Size(1100, 1500);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    ItemFormResult? submitted;
    await _openDialog(tester, onResult: (r) => submitted = r);

    await _enterTradeName(tester, 'منتج جزئي');
    await _selectCombo(tester, 'التصنيف', 'أدوية');
    await _selectCombo(tester, 'الأجزاء', 'ظرف');
    await tester.enterText(_fieldByLabel('عدد الأجزاء'), '2');
    await tester.pumpAndSettle();

    // Enable partial selling → default 20% markup is auto-filled.
    await tester.tap(find.byType(Switch).first);
    await tester.pumpAndSettle();
    expect(find.text('20'), findsOneWidget,
        reason: 'enabling partial sale pre-fills the default 20% markup');

    // Parts == 1 is rejected with a targeted message.
    await tester.enterText(_fieldByLabel('عدد الأجزاء'), '1');
    await tester.pumpAndSettle();
    await _tapSave(tester);
    expect(find.text('عدد الأجزاء في العبوة يجب أن يكون أكبر من 1'),
        findsOneWidget);

    // Valid partial-sale config persists the default markup as 2000 bps and
    // keeps the auto derived part price (no manual override).
    await tester.enterText(_fieldByLabel('عدد الأجزاء'), '2');
    await tester.pumpAndSettle();
    await _tapSave(tester);

    final saved = submitted;
    expect(saved, isNotNull);
    final d = saved!.draft;
    expect(d.partialSaleEnabled, isTrue);
    expect(d.sellablePartUnitId, 'unit_part',
        reason: 'the parts unit is the sellable part unit');
    expect(d.partsPerFullProduct, 2);
    expect(d.sellablePartBaseQuantity, 1);
    expect(d.partialSaleMarkupBasisPoints, 2000,
        reason: 'the auto-filled default markup is persisted');
    expect(d.partialSalePriceMicros, isNull,
        reason: 'no manual part price was entered');

    // A manually typed part price becomes the persisted override.
    submitted = null;
    await _openDialog(
      tester,
      onResult: (r) => submitted = r,
      initial: const ItemDraft(
        tradeName: 'منتج جزئي يدوي',
        categoryId: 'cat1',
        units: ItemUnitRelation(
            baseUnitId: 'unit_part', largeUnitId: 'unit_box', unitsPerLarge: 2),
      ),
    );
    await _enterTradeName(tester, 'منتج جزئي يدوي');
    await _selectCombo(tester, 'التصنيف', 'أدوية');
    await _selectCombo(tester, 'الأجزاء', 'ظرف');
    await tester.tap(find.byType(Switch).first);
    await tester.pumpAndSettle();
    await tester.enterText(_fieldByLabel('سعر بيع الجزء'), '5.00');
    await tester.pumpAndSettle();
    await _tapSave(tester);

    final manual = submitted;
    expect(manual, isNotNull);
    expect(manual!.draft.partialSalePriceMicros, isNotNull,
        reason: 'a manual سعر بيع الجزء is persisted as the override');
  });
}