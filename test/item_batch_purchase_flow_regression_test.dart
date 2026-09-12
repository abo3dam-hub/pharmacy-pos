import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:pharmacy_pos/core/config/app_config.dart';
import 'package:pharmacy_pos/core/theme/app_theme.dart';
import 'package:pharmacy_pos/features/inventory/domain/repositories/inventory_repository.dart';
import 'package:pharmacy_pos/features/inventory/presentation/widgets/batch_dialog.dart';
import 'package:pharmacy_pos/features/inventory/presentation/widgets/item_dialog.dart';
import 'package:pharmacy_pos/l10n/app_localizations.dart';

/// Workstream: chained "save and continue" + error-message clarity.
///   1. the item form shows "حفظ و اضافة الى المخزون" on create and returns
///      the saveContinue action,
///   2. a batch on an expiry-tracked item never closes silently unexplained —
///      it surfaces "تاريخ الانتهاء مطلوب لمنتج بتاريخ صلاحية" inline and
///      keeps the dialog open,
///   3. the batch form's "حفظ و اضافة فاتورة" button returns the
///      saveAndAddPurchase action with the filled input.
Widget harness(Widget home) {
  return MaterialApp(
    theme: AppTheme.light(),
    locale: const Locale(AppConfig.defaultLocale),
    supportedLocales: AppLocalizations.supportedLocales,
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    home: home,
  );
}

Finder _fieldByLabel(String labelPart) => find.byWidgetPredicate(
    (w) =>
        w is TextField && (w.decoration?.labelText ?? '').contains(labelPart));

Future<void> _tapInDialog(WidgetTester tester, String label) async {
  await tester.tap(find.descendant(
      of: find.byType(AlertDialog).last, matching: find.text(label)));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets(
      'item form save-and-continue action is only offered on create and '
      'returns ItemFormAction.saveContinue', (tester) async {
    tester.view.physicalSize = const Size(1100, 1500);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    ItemFormResult? submitted;
    await tester.pumpWidget(harness(Scaffold(
      body: Builder(
        builder: (context) => Center(
          child: ElevatedButton(
            onPressed: () async {
              final result = await showItemFormDialog(
                context,
                title: 'منتج جديد',
                categories: const [],
                manufacturers: const [],
                units: const [],
                showContinueAction: true,
              );
              submitted = result;
            },
            child: const Text('افتح النموذج'),
          ),
        ),
      ),
    )));
    await tester.tap(find.text('افتح النموذج'));
    await tester.pumpAndSettle();

    expect(find.text('حفظ و اضافة الى المخزون'), findsOneWidget,
        reason: 'create mode offers the save-and-continue button');

    await tester.enterText(_fieldByLabel('الاسم التجاري *'), 'بانادول');
    await tester.pumpAndSettle();
    await _tapInDialog(tester, 'حفظ و اضافة الى المخزون');

    expect(submitted, isNotNull);
    expect(submitted!.action, ItemFormAction.saveContinue,
        reason: 'the continue button returns the saveContinue action');
    expect(submitted!.draft.tradeName, 'بانادول');
  });

  testWidgets(
      'edit mode hides the save-and-continue button (single save action)',
      (tester) async {
    tester.view.physicalSize = const Size(1100, 1500);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(harness(Scaffold(
      body: Builder(
        builder: (context) => Center(
          child: ElevatedButton(
            onPressed: () => showItemFormDialog(
              context,
              title: 'تعديل منتج',
              initial: const ItemDraft(tradeName: 'قديم'),
              categories: const [],
              manufacturers: const [],
              units: const [],
              showContinueAction: true,
            ),
            child: const Text('افتح النموذج'),
          ),
        ),
      ),
    )));
    await tester.tap(find.text('افتح النموذج'));
    await tester.pumpAndSettle();

    expect(find.text('حفظ و اضافة الى المخزون'), findsNothing,
        reason: 'edit keeps the single save action');
  });

  testWidgets(
      'batch on an expiry-tracked item blocks silently with an inline reason',
      (tester) async {
    tester.view.physicalSize = const Size(900, 700);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    BatchFormResult? submitted;
    await tester.pumpWidget(harness(Scaffold(
      body: Builder(
        builder: (context) => Center(
          child: ElevatedButton(
            onPressed: () async {
              submitted = await showBatchFormDialog(
                context,
                itemId: 'item_1',
                hasExpiry: true,
              );
            },
            child: const Text('افتح التشغيلة'),
          ),
        ),
      ),
    )));
    await tester.tap(find.text('افتح التشغيلة'));
    await tester.pumpAndSettle();

    await tester.enterText(_fieldByLabel('رقم الدفعة'), 'B1');
    await tester.enterText(_fieldByLabel('الكمية'), '10');
    await tester.enterText(_fieldByLabel('تكلفة الوحدة'), '5');
    await tester.pumpAndSettle();

    await _tapInDialog(tester, 'حفظ');

    expect(find.text('تاريخ الانتهاء مطلوب لمنتج بتاريخ صلاحية'), findsOneWidget,
        reason: 'the missing expiry is explained inline instead of a silent '
            'close with an unexplained error');
    expect(find.byType(AlertDialog), findsOneWidget,
        reason: 'the dialog stays open so the user can fix the expiry');
    expect(submitted, isNull);
  });

  testWidgets(
      'batch save-and-add-invoice button returns its action with filled input',
      (tester) async {
    tester.view.physicalSize = const Size(900, 700);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    BatchFormResult? submitted;
    await tester.pumpWidget(harness(Scaffold(
      body: Builder(
        builder: (context) => Center(
          child: ElevatedButton(
            onPressed: () async {
              submitted = await showBatchFormDialog(
                context,
                itemId: 'item_1',
                hasExpiry: false,
              );
            },
            child: const Text('افتح التشغيلة'),
          ),
        ),
      ),
    )));
    await tester.tap(find.text('افتح التشغيلة'));
    await tester.pumpAndSettle();

    expect(find.text('حفظ و اضافة فاتورة'), findsOneWidget);
    await tester.enterText(_fieldByLabel('رقم الدفعة'), 'B1');
    await tester.enterText(_fieldByLabel('الكمية'), '24');
    await tester.enterText(_fieldByLabel('تكلفة الوحدة'), '12.5');
    await tester.pumpAndSettle();

    await tester.tap(find.descendant(
        of: find.byType(AlertDialog).last,
        matching: find.text('حفظ و اضافة فاتورة')));
    await tester.pumpAndSettle();

    expect(submitted, isNotNull);
    expect(submitted!.action, BatchFormAction.saveAndAddPurchase,
        reason: 'the continue button carries the action to the caller');
    expect(submitted!.input.itemId, 'item_1');
    expect(submitted!.input.quantityBase, 24);
    expect(submitted!.input.unitCostMicros, 125000,
        reason: '12.5 is parsed into integer money units (scale 4)');
  });
}