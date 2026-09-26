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

/// 2026-09-26 redesign regression tests for the single 3-column item window:
///   1. desktop rail is scrollable so late sections stay reachable,
///   2. the item form guides the user with targeted messages instead of the
///      generic save error when units are missing/invalid,
///   3. all seven sections render at once — no tabs, no quick/detailed modes,
///   4. many-to-many supplier chips flow into the draft,
///   5. inline master-data creation auto-selects the created row,
///   6. active-ingredient strength fields flow into the draft,
///   7. partial-sale switch auto-fills the default 20% markup, validates parts,
///      and persists the auto/manual سعر بيع الجزء model,
///   8. retired UI fields (usage instructions / notes / license) keep their
///      stored data on save,
///   9. edit mode pre-fills existing values; modified values persist,
///  10. the alternatives section opens the existing alternatives view,
///  11. the window is RTL with a fixed header and footer.
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

Finder _fieldByHint(String hintPart) => find.byWidgetPredicate(
    (w) =>
        w is TextField && (w.decoration?.hintText ?? '').contains(hintPart));

/// Toggles an option inside a SearchableMultiSelectField identified by its
/// search hint text. The dropdown renders inline; tapping the trade-name
/// field (always visible on wide screens) dismisses it.
Future<void> _toggleMultiOption(
    WidgetTester tester, String hintPart, String option) async {
  await tester.pumpAndSettle();
  final searchField = _fieldByHint(hintPart);
  await tester.ensureVisible(searchField);
  await tester.pumpAndSettle();
  // Type the option name to filter the list, then tap the single match.
  await tester.enterText(searchField, option);
  await tester.pumpAndSettle();
  await tester.tap(find.widgetWithText(CheckboxListTile, option));
  await tester.pumpAndSettle();
  await tester.enterText(searchField, '');
  await tester.pumpAndSettle();
  await tester.tap(_comboByLabel('الاسم التجاري *'));
  await tester.pumpAndSettle();
}

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
  // The opened list is rendered inline inside the column scroll view; bring
  // the tile into view before tapping so the hit test cannot miss.
  final tile = find.text(item).last;
  await tester.ensureVisible(tile);
  await tester.pumpAndSettle();
  await tester.tap(tile);
  await tester.pumpAndSettle();
}

Future<void> _tapSave(WidgetTester tester) async {
  await tester.tap(find.descendant(
      of: find.byType(Dialog).last, matching: find.text('حفظ')));
  await tester.pumpAndSettle();
}

/// Taps the inline "+" of the master-data dropdown labelled [fieldLabel].
Future<void> _tapInlineAdd(WidgetTester tester, String fieldLabel) async {
  final field = _comboByLabel(fieldLabel);
  final row = find.ancestor(of: field, matching: find.byType(Row)).first;
  await tester.tap(find.descendant(
      of: row, matching: find.byIcon(Icons.add_circle_outline)));
  await tester.pumpAndSettle();
}

Future<void> _openDialog(
  WidgetTester tester, {
  required void Function(ItemFormResult? result) onResult,
  ItemDraft? initial,
  String? itemId,
  Future<void> Function()? onViewAlternatives,
  bool showContinueAction = false,
  List<CategoryRow> categories = const [_category],
  List<ManufacturerRow> manufacturers = const [_manufacturer],
  List<UnitRow> units = const [_part, _box],
  List<SupplierRow> suppliers = const [],
  List<ActiveIngredientRow> activeIngredients = const [_ingredient],
  List<IndicationRow> indications = const [],
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
              itemId: itemId,
              categories: categories,
              manufacturers: manufacturers,
              units: units,
              suppliers: suppliers,
              activeIngredients: activeIngredients,
              indications: indications,
              onCreateMasterData: onCreateMasterData,
              onCreateSupplier: _factorySupplier,
              onViewAlternatives: onViewAlternatives,
              showContinueAction: showContinueAction,
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
      'trade-name-only saves; parts guidance targets only configured units',
      (tester) async {
    tester.view.physicalSize = const Size(1100, 1500);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    ItemFormResult? submitted;
    await _openDialog(tester, onResult: (r) => submitted = r);

    // Phase 18.1 trade-name-only contract: category, units and prices are all
    // optional — the trade name alone must save.
    await _enterTradeName(tester, 'بانادول');
    await _tapSave(tester);
    expect(submitted, isNotNull,
        reason: 'trade name alone satisfies the Product Master contract');
    expect(submitted!.draft.units, isNull,
        reason: 'no parts/packaging selected → no unit relation is forced');
    expect(submitted!.draft.categoryId, isNull,
        reason: 'classification is optional');

    // Once the parts unit is configured, an invalid parts count is rejected
    // with targeted guidance (not the generic save-error) and the dialog stays
    // open.
    submitted = null;
    await _openDialog(tester, onResult: (r) => submitted = r);
    await _enterTradeName(tester, 'بانادول');
    await _selectCombo(tester, 'الأجزاء', 'ظرف');
    await tester.pumpAndSettle();
    await tester.enterText(_fieldByLabel('عدد الأجزاء'), '0');
    await tester.pumpAndSettle();
    await _tapSave(tester);
    expect(find.text('عدد الأجزاء يجب أن يكون أكبر من صفر'), findsOneWidget,
        reason: 'targeted guidance surfaces when a unit relation is built');
    expect(find.byType(Dialog), findsOneWidget);

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

  testWidgets(
      'single-window layout shows all seven sections; no tabs or entry modes',
      (tester) async {
    tester.view.physicalSize = const Size(1280, 800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await _openDialog(tester, onResult: (_) {});

    // All seven sections render at once in the 3-column window.
    for (final section in [
      'معلومات أساسية',
      'التفاصيل الفنية',
      'التعبئة والمبيعات',
      'التسعير',
      'المخزون والتسعير المتقدم',
      'التصنيفات والاستطبابات',
      'البدائل',
    ]) {
      expect(find.text(section), findsOneWidget,
          reason: 'section "$section" must be visible without navigation');
    }

    // The old quick/detailed modes and tabs are gone.
    expect(find.byType(TabBar), findsNothing);
    expect(find.text('إدخال سريع'), findsNothing);
    expect(find.text('إدخال مفصّل'), findsNothing);

    // Phase 17 packaging/parts labels (no legacy unit naming).
    expect(find.text('التعبئة التجارية'), findsOneWidget);
    expect(find.text('الأجزاء'), findsOneWidget);
    expect(find.text('عدد الأجزاء'), findsOneWidget);

    // In create mode the alternatives section explains alternatives appear
    // after saving — no invented editing UI.
    expect(find.text('تظهر البدائل بعد حفظ الصنف'), findsOneWidget);
    expect(find.text('عرض البدائل'), findsNothing);
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
    await _toggleMultiOption(tester, 'الموردون', 'مورد الأول');
    await _toggleMultiOption(tester, 'الموردون', 'مورد الثاني');
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
    await _toggleMultiOption(tester, 'الموردون', 'مورد الأول');
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

    // Inline "+" exists for category / manufacturer and for packaging /
    // parts units; the multi-selects (indication / ingredient / supplier)
    // carry their own inline add-new row instead.
    expect(find.byIcon(Icons.add_circle_outline), findsNWidgets(4));
    await _tapInlineAdd(tester, 'التصنيف');
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
    // The active-ingredient multi-select is searchable: type to filter, then
    // tap the checkbox row to add it with its strength.
    await tester.tap(_fieldByHint('ابحث عن مادة فعالة'));
    await tester.pumpAndSettle();
    await tester.enterText(_fieldByHint('ابحث عن مادة فعالة'), 'باراسيتا');
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(CheckboxListTile, 'باراسيتامول'));
    await tester.pumpAndSettle();
    // Dismiss the inline dropdown by tapping the trade-name field.
    await tester.tap(_comboByLabel('الاسم التجاري *'));
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

  testWidgets('retired UI fields keep their stored data on save',
      (tester) async {
    tester.view.physicalSize = const Size(1280, 800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    ItemFormResult? submitted;
    await _openDialog(
      tester,
      onResult: (r) => submitted = r,
      initial: const ItemDraft(
        tradeName: 'منتج بملاحظات قديمة',
        usageInstructions: 'بعد الأكل',
        generalNotes: 'ملاحظة عامة',
        licenseNumber: 'LIC-123',
      ),
    );

    // The retired fields are intentionally not shown in this window…
    expect(_fieldByLabel('تعليمات الاستخدام'), findsNothing);
    expect(_fieldByLabel('رقم الترخيص'), findsNothing);

    await _tapSave(tester);

    // …but their stored values survive the save untouched.
    expect(submitted, isNotNull);
    final kept = submitted!;
    expect(kept.draft.usageInstructions, 'بعد الأكل',
        reason: 'removal from UI must not delete stored data');
    expect(kept.draft.generalNotes, 'ملاحظة عامة');
    expect(kept.draft.licenseNumber, 'LIC-123');
  });

  testWidgets('edit mode pre-fills existing values; modified values persist',
      (tester) async {
    tester.view.physicalSize = const Size(1280, 800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    ItemFormResult? submitted;
    await _openDialog(
      tester,
      onResult: (r) => submitted = r,
      initial: const ItemDraft(
        tradeName: 'بنادول إكسترا',
        tradeNameEn: 'Panadol Extra',
        categoryId: 'cat1',
        manufacturerId: 'manu1',
        dose: '500mg',
        primaryBarcode: '6214001000011',
      ),
    );

    // Existing values appear in the form.
    expect(
        tester
            .widget<TextField>(_comboByLabel('الاسم التجاري *'))
            .controller!
            .text,
        'بنادول إكسترا');
    expect(
        tester
            .widget<TextField>(_comboByLabel('الاسم التجاري (إنجليزي)'))
            .controller!
            .text,
        'Panadol Extra');
    expect(
        tester.widget<TextField>(_comboByLabel('الجرعة')).controller!.text,
        '500mg');

    // Modify one value, keep the rest, save.
    await tester.enterText(_comboByLabel('الاسم التجاري *'), 'بنادول معدل');
    await _tapSave(tester);

    expect(submitted, isNotNull);
    final d = submitted!.draft;
    expect(d.tradeName, 'بنادول معدل');
    expect(d.tradeNameEn, 'Panadol Extra');
    expect(d.categoryId, 'cat1');
    expect(d.manufacturerId, 'manu1');
    expect(d.dose, '500mg');
    expect(d.primaryBarcode, '6214001000011');
  });

  testWidgets(
      'alternatives section opens the existing alternatives view in edit mode',
      (tester) async {
    tester.view.physicalSize = const Size(1280, 800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    var opened = false;
    await _openDialog(
      tester,
      onResult: (_) {},
      itemId: 'item_1',
      onViewAlternatives: () async {
        opened = true;
      },
    );

    await tester.tap(find.text('عرض البدائل'));
    await tester.pumpAndSettle();
    expect(opened, isTrue,
        reason: 'the section delegates to the existing alternatives logic');
  });

  testWidgets('header and footer stay fixed outside any scrollable; RTL',
      (tester) async {
    tester.view.physicalSize = const Size(1280, 800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await _openDialog(tester, onResult: (_) {});

    expect(Directionality.of(tester.element(find.byType(Dialog).first)),
        TextDirection.rtl);

    // The title (header) and the save action (footer) must never sit inside
    // a scrollable — they are pinned while only column content may scroll.
    final save = find.widgetWithText(FilledButton, 'حفظ');
    expect(save, findsOneWidget);
    expect(find.ancestor(of: save, matching: find.byType(Scrollable)),
        findsNothing,
        reason: 'footer save must not scroll away');
    final title = find.text('منتج جديد');
    expect(find.ancestor(of: title, matching: find.byType(Scrollable)),
        findsNothing,
        reason: 'header title must not scroll away');
    // All three footer actions exist.
    expect(find.text('إلغاء'), findsOneWidget);
  });

  testWidgets('cancel discards the draft without saving', (tester) async {
    tester.view.physicalSize = const Size(1280, 800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    var called = false;
    ItemFormResult? submitted;
    await _openDialog(
      tester,
      onResult: (r) {
        called = true;
        submitted = r;
      },
    );

    await _enterTradeName(tester, 'لن يحفظ');
    await tester.tap(find.text('إلغاء'));
    await tester.pumpAndSettle();

    expect(called, isTrue, reason: 'cancel pops the dialog with null');
    expect(submitted, isNull, reason: 'cancel returns null');
    expect(find.byType(Dialog), findsNothing);
  });

  testWidgets('save-and-add-to-inventory action flows through', (tester) async {
    tester.view.physicalSize = const Size(1280, 800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    ItemFormResult? submitted;
    await _openDialog(
      tester,
      onResult: (r) => submitted = r,
      showContinueAction: true,
    );

    await _enterTradeName(tester, 'منتج للمخزون');
    await tester.tap(find.text('حفظ و اضافة الى المخزون'));
    await tester.pumpAndSettle();

    expect(submitted, isNotNull);
    expect(submitted!.action, ItemFormAction.saveContinue);
    expect(submitted!.draft.tradeName, 'منتج للمخزون');
  });

  testWidgets('empty trade name is rejected with a targeted message',
      (tester) async {
    tester.view.physicalSize = const Size(1280, 800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    ItemFormResult? submitted;
    await _openDialog(tester, onResult: (r) => submitted = r);

    await _tapSave(tester);
    expect(submitted, isNull, reason: 'invalid form must not submit');
    expect(find.text('الاسم مطلوب'), findsOneWidget);
    expect(find.byType(Dialog), findsOneWidget,
        reason: 'the dialog stays open on validation failure');
  });
}
