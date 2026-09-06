import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:pharmacy_pos/core/config/app_config.dart';
import 'package:pharmacy_pos/core/theme/app_colors.dart';
import 'package:pharmacy_pos/core/theme/app_dimensions.dart';
import 'package:pharmacy_pos/core/theme/app_text_styles.dart';
import 'package:pharmacy_pos/core/theme/app_theme.dart';
import 'package:pharmacy_pos/core/widgets/amount_field.dart';
import 'package:pharmacy_pos/core/widgets/app_data_table.dart';
import 'package:pharmacy_pos/core/widgets/app_shell.dart';
import 'package:pharmacy_pos/core/widgets/confirm_dialog.dart';
import 'package:pharmacy_pos/core/widgets/loading_overlay.dart';
import 'package:pharmacy_pos/core/widgets/search_field.dart';
import 'package:pharmacy_pos/l10n/app_localizations.dart';
import 'package:pharmacy_pos/main.dart';

/// Widget harness reusing the app's own Arabic-first localization delegates.
Widget harness(Widget home) {
  return MaterialApp(
    theme: AppTheme.light(),
    locale: const Locale(AppConfig.defaultLocale),
    supportedLocales: AppLocalizations.supportedLocales,
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    home: home,
  );
}

void main() {
  group('Design System — palette, typography, tokens', () {
    test('light theme is wired to the single color-source and Cairo', () {
      final theme = AppTheme.light();
      // Primary green identity + muted-purple accent + quiet error.
      expect(theme.colorScheme.primary, AppColors.primarySeed);
      expect(theme.colorScheme.secondary, AppColors.accent);
      expect(theme.colorScheme.error, AppColors.error);
      // Typography family + hierarchy via the central ThemeExtension.
      expect(theme.textTheme.bodyLarge?.fontFamily, AppConfig.fontFamilyArabic);
      final type = theme.extension<AppTypography>();
      expect(type, isNotNull);
      expect(type!.pageTitle.fontSize, 28);
      expect(type.table.fontFeatures, isNotNull);
      expect(type.numeric.fontFeatures, isNotEmpty);
      // Central component themes exist (single source, no per-page styling).
      expect(theme.inputDecorationTheme, isNotNull);
      expect(theme.dialogTheme, isNotNull);
      expect(theme.cardTheme, isNotNull);
      expect(theme.dataTableTheme, isNotNull);
      expect(theme.navigationRailTheme, isNotNull);
      expect(theme.navigationDrawerTheme, isNotNull);
    });

    test('dark variant reuses the same token set', () {
      final dark = AppTheme.dark();
      expect(dark.colorScheme.error, AppColors.darkError);
      expect(dark.scaffoldBackgroundColor, AppColors.darkCanvas);
      expect(dark.extension<AppTypography>(), isNotNull);
    });

    test('spacing and breakpoints follow the unified scale', () {
      expect(AppBreakpoints.layoutFor(1280), AppLayout.desktop);
      expect(AppBreakpoints.layoutFor(760), AppLayout.tablet);
      expect(AppBreakpoints.layoutFor(390), AppLayout.compact);
      expect(AppRadius.lg, greaterThan(AppRadius.sm));
      expect(AppSpacing.xxxl, AppSpacing.s * 4);
    });
  });

  group('Design System — RTL / LTR', () {
    testWidgets('Arabic is the default locale and renders RTL',
        (tester) async {
      await tester.pumpWidget(const PharmacyApp());
      await tester.pumpAndSettle();
      final ctx = tester.element(find.text('الرئيسية').first);
      expect(Directionality.of(ctx), TextDirection.rtl);
    });

    testWidgets('English locale renders LTR through the same pipeline',
        (tester) async {
      await tester.pumpWidget(
        PharmacyApp(locale: const Locale('en')),
      );
      await tester.pumpAndSettle();
      expect(find.text('Dashboard'), findsWidgets);
      final ctx = tester.element(find.text('Dashboard').first);
      expect(Directionality.of(ctx), TextDirection.ltr);
    });
  });

  group('Design System — responsive foundation (§33)', () {
    testWidgets('compact width uses drawer navigation', (tester) async {
      tester.view.physicalSize = const Size(400, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(harness(const AppShell()));
      await tester.pumpAndSettle();
      expect(find.byType(NavigationRail), findsNothing);
      expect(find.byType(NavigationDrawer), findsNothing);

      await tester.tap(find.byIcon(Icons.menu));
      await tester.pumpAndSettle();
      expect(find.byType(NavigationDrawer), findsOneWidget);
    });

    testWidgets('desktop width uses the persistent rail', (tester) async {
      tester.view.physicalSize = const Size(1280, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(harness(const AppShell()));
      await tester.pumpAndSettle();
      expect(find.byType(NavigationRail), findsOneWidget);
      expect(find.text('المخزون'), findsOneWidget);
    });
  });

  group('Design System — shared widgets', () {
    testWidgets('LoadingOverlay blocks only when visible', (tester) async {
      await tester.pumpWidget(harness(LoadingOverlay(
        visible: true,
        label: 'جارٍ التحميل...',
        child: const SizedBox(key: Key('under'), width: 100, height: 100),
      )));
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      expect(find.text('جارٍ التحميل...'), findsOneWidget);

      await tester.pumpWidget(harness(LoadingOverlay(
        visible: false,
        child: const SizedBox(key: Key('under'), width: 100, height: 100),
      )));
      expect(find.byType(CircularProgressIndicator), findsNothing);
    });

    testWidgets('SearchField debounces and clears', (tester) async {
      final calls = <String>[];
      await tester.pumpWidget(harness(Scaffold(
        body: SearchField(
          hintText: 'بحث',
          delay: Duration.zero,
          onChanged: calls.add,
        ),
      )));

      await tester.enterText(find.byType(TextField), 'بانادول');
      await tester.pumpAndSettle();
      expect(calls, ['بانادول']);

      await tester.tap(find.byIcon(Icons.clear));
      await tester.pumpAndSettle();
      expect(calls.last, '');
    });

    testWidgets('ConfirmDialog resolves on cancel and confirm', (tester) async {
      bool? result;
      await tester.pumpWidget(harness(Scaffold(
        body: Builder(
          builder: (context) => Center(
            child: ElevatedButton(
              onPressed: () async {
                result = await showAppConfirmDialog(
                  context,
                  title: 'حذف الفاتورة',
                  message: 'لا يمكن التراجع عن هذا الإجراء.',
                );
              },
              child: const Text('open'),
            ),
          ),
        ),
      )));

      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();
      expect(find.text('حذف الفاتورة'), findsOneWidget);

      await tester.tap(find.text('إلغاء'));
      await tester.pumpAndSettle();
      expect(result, isFalse);
    });

    testWidgets('AppDataTable renders rows and an empty state',
        (tester) async {
      final columns = [for (final c in ['الاسم', 'المخزون']) DataColumn(label: Text(c))];
      final rows = [
        DataRow(cells: [const DataCell(Text('آسبرين')), const DataCell(Text('25'))]),
      ];
      await tester.pumpWidget(
        harness(SizedBox(width: 600, height: 400, child: AppDataTable(
          columns: columns,
          rows: rows,
        ))),
      );
      expect(find.text('آسبرين'), findsOneWidget);

      await tester.pumpWidget(
        harness(SizedBox(width: 600, height: 400, child: AppDataTable(
          columns: columns,
          rows: const [],
          emptyMessage: 'لا توجد نتائج',
        ))),
      );
      expect(find.text('لا توجد نتائج'), findsOneWidget);
    });

    testWidgets('AmountField accepts money-shaped digits only', (tester) async {
      final values = <String>[];
      await tester.pumpWidget(harness(Scaffold(
        body: AmountField(hintText: 'المبلغ', onChanged: values.add),
      )));

      await tester.enterText(find.byType(TextField), '1234.5678');
      await tester.pumpAndSettle();
      expect(values.last, '1234.5678');

      // Letters and extra decimals are rejected by the formatter.
      await tester.enterText(find.byType(TextField), '12.99999');
      await tester.pumpAndSettle();
      expect(values.last, '1234.5678');
    });
  });
}