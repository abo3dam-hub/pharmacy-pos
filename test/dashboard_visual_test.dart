import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:pharmacy_pos/core/config/app_config.dart';
import 'package:pharmacy_pos/core/constants/app_sections.dart';
import 'package:pharmacy_pos/core/di/providers.dart';
import 'package:pharmacy_pos/core/theme/app_theme.dart';
import 'package:pharmacy_pos/core/theme/dashboard_palette.dart';
import 'package:pharmacy_pos/features/dashboard/presentation/dashboard_carousel.dart';
import 'package:pharmacy_pos/features/dashboard/presentation/dashboard_page.dart';
import 'package:pharmacy_pos/l10n/app_localizations.dart';

import 'auth_harness.dart';

/// Visual-refresh tests (2026-10-04): the dashboard's colorful KPI cards,
/// hero carousel and alert headers are all tappable and navigate to their
/// related pages.
void main() {
  Widget harness(ProviderContainer container, GoRouter router) {
    return UncontrolledProviderScope(
      container: container,
      child: MaterialApp.router(
        theme: AppTheme.light(),
        locale: const Locale(AppConfig.defaultLocale),
        supportedLocales: AppLocalizations.supportedLocales,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        routerConfig: router,
      ),
    );
  }

  GoRouter buildRouter() {
    return GoRouter(
      initialLocation: AppSection.dashboard.path,
      routes: [
        GoRoute(
          path: AppSection.dashboard.path,
          builder: (context, state) => const Scaffold(
            body: DashboardPage(carouselAutoPlay: false),
          ),
        ),
        GoRoute(
          path: salesHistoryPath(),
          builder: (context, state) =>
              const Scaffold(body: Text('MARKER_SALES_HISTORY')),
        ),
        GoRoute(
          path: AppSection.inventory.path,
          builder: (context, state) =>
              const Scaffold(body: Text('MARKER_INVENTORY')),
        ),
        GoRoute(
          path: AppSection.sale.path,
          builder: (context, state) =>
              const Scaffold(body: Text('MARKER_SALE')),
        ),
        GoRoute(
          path: AppSection.reports.path,
          builder: (context, state) =>
              const Scaffold(body: Text('MARKER_REPORTS')),
        ),
      ],
    );
  }

  Future<GoRouter> pumpDashboard(
    WidgetTester tester,
    ProviderContainer container,
  ) async {
    final router = buildRouter();
    tester.view.physicalSize = const Size(1280, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(harness(container, router));
    await tester.pumpAndSettle();
    return router;
  }

  Future<ProviderContainer> loggedInContainer() async {
    final h = await buildAuthHarness();
    addTearDown(h.db.close);
    addTearDown(h.container.dispose);
    await h.container
        .read(authControllerProvider.notifier)
        .login('admin', 'Admin@123');
    return h.container;
  }

  group('Dashboard KPI cards navigation', () {
    testWidgets('tapping daily-sales card opens the sales history',
        (tester) async {
      final container = await loggedInContainer();
      await pumpDashboard(tester, container);

      // The label appears twice (carousel slide + KPI card); the KPI card
      // is the second occurrence in tree order.
      await tester.tap(find.text('مبيعات اليوم').last);
      await tester.pumpAndSettle();

      expect(find.text('MARKER_SALES_HISTORY'), findsOneWidget);
    });

    testWidgets('tapping active-items card opens inventory', (tester) async {
      final container = await loggedInContainer();
      await pumpDashboard(tester, container);

      await tester.tap(find.text('المنتجات النشطة'));
      await tester.pumpAndSettle();

      expect(find.text('MARKER_INVENTORY'), findsOneWidget);
    });

    testWidgets('tapping profit card opens reports', (tester) async {
      final container = await loggedInContainer();
      await pumpDashboard(tester, container);

      await tester.tap(find.text('ربح اليوم'));
      await tester.pumpAndSettle();

      expect(find.text('MARKER_REPORTS'), findsOneWidget);
    });
  });

  group('Dashboard hero carousel', () {
    List<DashboardSlide> testSlides() => const [
          DashboardSlide(
            icon: Icons.attach_money,
            label: 'مبيعات اليوم',
            value: '100',
            hint: 'اضغط للفتح',
            tint: DashboardTint.teal,
            route: '/sale/history',
          ),
          DashboardSlide(
            icon: Icons.warning_amber,
            label: 'تنبيهات المخزون',
            value: '3',
            hint: 'اضغط للفتح',
            tint: DashboardTint.amber,
            route: '/inventory',
          ),
          DashboardSlide(
            icon: Icons.update,
            label: 'قرب انتهاء الصلاحية',
            value: '5',
            hint: 'اضغط للفتح',
            tint: DashboardTint.rose,
            route: '/inventory',
          ),
          DashboardSlide(
            icon: Icons.point_of_sale,
            label: 'بيع جديد',
            value: 'ابدأ عملية بيع',
            hint: 'اضغط للفتح',
            tint: DashboardTint.indigo,
            route: '/sale',
          ),
        ];

    Widget carouselHarness(List<DashboardSlide> slides) {
      return MaterialApp(
        theme: AppTheme.light(),
        locale: const Locale(AppConfig.defaultLocale),
        supportedLocales: AppLocalizations.supportedLocales,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        home: Scaffold(
          body: SizedBox(
            width: 1248,
            child: DashboardCarousel(
              slides: slides,
              autoPlay: false,
            ),
          ),
        ),
      );
    }

    testWidgets('renders the first slide and one dot per slide',
        (tester) async {
      tester.view.physicalSize = const Size(1280, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(carouselHarness(testSlides()));
      await tester.pumpAndSettle();

      expect(find.byType(PageView), findsOneWidget);
      expect(find.text('مبيعات اليوم'), findsOneWidget);
      expect(
        find.descendant(
          of: find.byType(DashboardCarousel),
          matching: find.byType(AnimatedContainer),
        ),
        findsNWidgets(4),
      );
    });

    testWidgets('swiping advances to the next slide', (tester) async {
      tester.view.physicalSize = const Size(1280, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(carouselHarness(testSlides()));
      await tester.pumpAndSettle();

      // PageView.builder only builds the visible page. NOTE (RTL): in a
      // right-to-left PageView the next page sits to the LEFT, so the user
      // drags RIGHT to advance (mirrored from LTR). Drag past half the
      // page width so the page snaps instead of springing back.
      await tester.drag(find.byType(PageView), const Offset(700, 0));
      await tester.pumpAndSettle();
      expect(find.text('تنبيهات المخزون'), findsOneWidget);

      await tester.drag(find.byType(PageView), const Offset(700, 0));
      await tester.pumpAndSettle();
      expect(find.text('قرب انتهاء الصلاحية'), findsOneWidget);

      await tester.drag(find.byType(PageView), const Offset(700, 0));
      await tester.pumpAndSettle();
      expect(find.text('بيع جديد'), findsOneWidget);
    });

    testWidgets('auto-play advances slides on its own', (tester) async {
      tester.view.physicalSize = const Size(1280, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light(),
          locale: const Locale(AppConfig.defaultLocale),
          supportedLocales: AppLocalizations.supportedLocales,
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          home: Scaffold(
            body: SizedBox(
              width: 1248,
              child: DashboardCarousel(
                slides: testSlides(),
                autoPlay: true,
                autoPlayInterval: const Duration(seconds: 2),
              ),
            ),
          ),
        ),
      );
      await tester.pump();
      expect(find.text('مبيعات اليوم'), findsOneWidget);

      // Timer fires → page animates (450ms) → settle.
      await tester.pump(const Duration(seconds: 2));
      await tester.pump(const Duration(milliseconds: 600));
      expect(find.text('تنبيهات المخزون'), findsOneWidget);
    });

    testWidgets('tapping a slide navigates to its page', (tester) async {
      final container = await loggedInContainer();
      await pumpDashboard(tester, container);

      // The first slide's InkWell (today's sales → sales history).
      final slideTap = find.descendant(
        of: find.byType(DashboardCarousel),
        matching: find.byType(InkWell),
      );
      expect(slideTap, findsWidgets);
      await tester.tap(slideTap.first);
      await tester.pumpAndSettle();

      expect(find.text('MARKER_SALES_HISTORY'), findsOneWidget);
    });
  });

  group('Dashboard alert cards', () {
    testWidgets('tapping an alert header opens its list page',
        (tester) async {
      final container = await loggedInContainer();
      await pumpDashboard(tester, container);

      await tester.tap(find.text('أصناف منخفضة المخزون'));
      await tester.pumpAndSettle();

      expect(find.text('MARKER_INVENTORY'), findsOneWidget);
    });
  });
}
