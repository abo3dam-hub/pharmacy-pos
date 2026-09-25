import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pharmacy_pos/core/config/app_config.dart';
import 'package:pharmacy_pos/core/di/providers.dart';
import 'package:pharmacy_pos/core/theme/app_theme.dart';
import 'package:pharmacy_pos/features/dashboard/presentation/dashboard_page.dart';
import 'package:pharmacy_pos/l10n/app_localizations.dart';
import 'package:pharmacy_pos/shared/database/app_database.dart';

import 'auth_harness.dart';

void main() {
  Widget harness(ProviderContainer container) {
    return UncontrolledProviderScope(
      container: container,
      child: MaterialApp(
        theme: AppTheme.light(),
        locale: const Locale(AppConfig.defaultLocale),
        supportedLocales: AppLocalizations.supportedLocales,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        home: const Scaffold(body: DashboardPage()),
      ),
    );
  }

  Future<void> pumpDashboard(
    WidgetTester tester,
    ProviderContainer container,
  ) async {
    tester.view.physicalSize = const Size(1280, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(harness(container));
    await tester.pumpAndSettle();
  }

  Future<void> seedBlankRole(
    AppDatabase db, {
    String username = 'blank',
    String password = 'Blank@123',
  }) async {
    final now = DateTime.now().millisecondsSinceEpoch;
    await db
        .into(db.roles)
        .insert(
          RoleRow(
            id: 'role_blank',
            name: 'blank',
            nameAr: 'بدون صلاحيات',
            isSystem: false,
            isActive: true,
            createdAt: now,
            updatedAt: now,
          ),
        );
    await seedExtraUser(
      db,
      username: username,
      password: password,
      roleId: 'role_blank',
    );
  }

  group('DashboardPage financial summary', () {
    testWidgets(
      'income statement strip shows for a role with reports.view_profit',
      (tester) async {
        final h = await buildAuthHarness();
        addTearDown(h.db.close);
        addTearDown(h.container.dispose);
        await h.container
            .read(authControllerProvider.notifier)
            .login('admin', 'Admin@123');

        await pumpDashboard(tester, h.container);

        expect(find.text('قائمة دخل اليوم'), findsOneWidget);
        expect(find.text('إيرادات المبيعات'), findsOneWidget);
        expect(find.text('تكلفة البضاعة المباعة'), findsOneWidget);
        expect(find.text('مجمل الربح'), findsOneWidget);
        expect(find.text('صافي الربح'), findsOneWidget);
      },
    );

    testWidgets(
      'income statement strip is hidden without reports.view_profit',
      (tester) async {
        final h = await buildAuthHarness();
        addTearDown(h.db.close);
        addTearDown(h.container.dispose);
        await seedBlankRole(h.db);
        await h.container
            .read(authControllerProvider.notifier)
            .login('blank', 'Blank@123');

        await pumpDashboard(tester, h.container);

        expect(find.text('قائمة دخل اليوم'), findsNothing);
        expect(find.text('صافي الربح'), findsNothing);
        // The rest of the dashboard still renders for restricted roles.
        expect(find.text('نظرة عامة'), findsOneWidget);
      },
    );
  });

  group('DashboardPage fit-to-screen', () {
    Future<void> pumpAt(
      WidgetTester tester,
      ProviderContainer container,
      Size size,
    ) async {
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(harness(container));
      await tester.pumpAndSettle();
    }

    testWidgets('fits viewports without scrolling or overflow', (tester) async {
      final h = await buildAuthHarness();
      addTearDown(h.db.close);
      addTearDown(h.container.dispose);
      await h.container
          .read(authControllerProvider.notifier)
          .login('admin', 'Admin@123');

      // Any RenderFlex overflow throws during pump — reaching these
      // expectations proves the layout fits.
      for (final size in const [
        Size(1280, 900),
        Size(1024, 640),
        Size(800, 600),
      ]) {
        await pumpAt(tester, h.container, size);
        // No scrollable root: everything is visible in the viewport.
        expect(find.byType(Scrollable), findsNothing);
        expect(find.text('نظرة عامة'), findsOneWidget);
      }
    });
  });
}
