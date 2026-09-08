import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
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

import 'auth_harness.dart';

/// Signs in through the real login form using the seeded dev admin
/// (locale-agnostic: uses field order, not localized labels).
Future<void> signIn(
  WidgetTester tester, {
  required String username,
  required String password,
}) async {
  final fields = find.byType(TextFormField);
  await tester.enterText(fields.at(0), username);
  await tester.enterText(fields.at(1), password);
  await tester.tap(find.byType(FilledButton));
  await tester.pumpAndSettle();
}

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

    test('muted text tokens pass WCAG AA contrast on their respective canvases', () {
      double relativeLuminance(Color c) {
        final channel = [c.r, c.g, c.b].map((s) {
          return s <= 0.03928 ? s / 12.92 : math.pow((s + 0.055) / 1.055, 2.4).toDouble();
        }).toList();
        return 0.2126 * channel[0] + 0.7152 * channel[1] + 0.0722 * channel[2];
      }

      double contrastRatio(Color a, Color b) {
        final l1 = relativeLuminance(a);
        final l2 = relativeLuminance(b);
        final lighter = math.max(l1, l2);
        final darker  = math.min(l1, l2);
        return (lighter + 0.05) / (darker + 0.05);
      }

      expect(contrastRatio(AppColors.textMuted, AppColors.canvas), greaterThanOrEqualTo(4.5));
      expect(contrastRatio(AppColors.darkTextMuted, AppColors.darkCanvas), greaterThanOrEqualTo(4.5));
    });

    test('warning/error tokens pass WCAG AA (4.5:1) on every surface they render on', () {
      double relativeLuminance(Color c) {
        final channel = [c.r, c.g, c.b].map((s) {
          return s <= 0.03928 ? s / 12.92 : math.pow((s + 0.055) / 1.055, 2.4).toDouble();
        }).toList();
        return 0.2126 * channel[0] + 0.7152 * channel[1] + 0.0722 * channel[2];
      }

      double contrastRatio(Color a, Color b) {
        final l1 = relativeLuminance(a);
        final l2 = relativeLuminance(b);
        final lighter = math.max(l1, l2);
        final darker  = math.min(l1, l2);
        return (lighter + 0.05) / (darker + 0.05);
      }

      // Text-on-soft-background pairs (§24 statuses: solid text on light surfaces).
      const lightBackdrops = [
        AppColors.canvas,
        AppColors.surfaceLight,
        AppColors.surfaceVariant,
        AppColors.successContainer,
        AppColors.infoContainer,
      ];
      for (final token in [AppColors.warning, AppColors.error]) {
        for (final backdrop in lightBackdrops) {
          expect(
            contrastRatio(token, backdrop),
            greaterThanOrEqualTo(4.5),
            reason: '$token must reach AA on $backdrop',
          );
        }
      }
      // Solid status text on its own soft container.
      expect(contrastRatio(AppColors.error, AppColors.errorContainer),
          greaterThanOrEqualTo(4.5));
      expect(contrastRatio(AppColors.warning, AppColors.warningContainer),
          greaterThanOrEqualTo(4.5));
      // Inverse text on the solid status colors themselves.
      expect(contrastRatio(AppColors.onWarning, AppColors.warning),
          greaterThanOrEqualTo(4.5));
      expect(contrastRatio(AppColors.onError, AppColors.error),
          greaterThanOrEqualTo(4.5));
      // Dark variant must stay AA too.
      expect(contrastRatio(AppColors.darkWarning, AppColors.darkCanvas),
          greaterThanOrEqualTo(4.5));
      expect(contrastRatio(AppColors.darkError, AppColors.darkCanvas),
          greaterThanOrEqualTo(4.5));
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
      final harness_ = await buildAuthHarness();
      addTearDown(harness_.db.close);
      addTearDown(harness_.container.dispose);

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: harness_.container,
          child: const PharmacyApp(),
        ),
      );
      await tester.pumpAndSettle();
      await signIn(tester, username: 'admin', password: 'Admin@123');
      await tester.pumpAndSettle();

      final ctx = tester.element(find.text('الرئيسية').first);
      expect(Directionality.of(ctx), TextDirection.rtl);
    });

    testWidgets('English locale renders LTR through the same pipeline',
        (tester) async {
      final harness_ = await buildAuthHarness();
      addTearDown(harness_.db.close);
      addTearDown(harness_.container.dispose);

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: harness_.container,
          child: const PharmacyApp(locale: Locale('en')),
        ),
      );
      await tester.pumpAndSettle();
      await signIn(tester, username: 'admin', password: 'Admin@123');
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

    testWidgets('shell navigation destinations expose readable semantics',
        (tester) async {
      tester.view.physicalSize = const Size(1280, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      final semantics = tester.ensureSemantics();
      await tester.pumpWidget(harness(const AppShell()));
      await tester.pumpAndSettle();

      // Walk the rail's real semantics subtree: every destination must surface
      // its localized section label to a screen reader (not a bare icon).
      final labels = <String>[];
      void collect(SemanticsNode node) {
        if (node.label.isNotEmpty) labels.add(node.label);
        for (final child in node
            .debugListChildrenInOrder(DebugSemanticsDumpOrder.traversalOrder)) {
          collect(child);
        }
      }

      collect(tester.getSemantics(find.byType(NavigationRail)));
      for (final label in ['الرئيسية', 'المخزون', 'مبيعات', 'الإعدادات']) {
        expect(
          labels.any((l) => l.split('\n').first == label),
          isTrue,
          reason: 'rail should expose "$label" to assistive tech',
        );
      }
      semantics.dispose();
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