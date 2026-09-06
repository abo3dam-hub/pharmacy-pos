import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pharmacy_pos/core/config/app_config.dart';
import 'package:pharmacy_pos/core/di/providers.dart';
import 'package:pharmacy_pos/core/theme/app_theme.dart';
import 'package:pharmacy_pos/features/auth/presentation/pages/users_page.dart';
import 'package:pharmacy_pos/l10n/app_localizations.dart';

import 'auth_harness.dart';

void main() {
  /// Pumps [UsersPage] inside the app's Arabic-first localization pipeline
  /// with a pre-authenticated session on the harness container.
  Widget harness(ProviderContainer container) {
    return UncontrolledProviderScope(
      container: container,
      child: MaterialApp(
        theme: AppTheme.light(),
        locale: const Locale(AppConfig.defaultLocale),
        supportedLocales: AppLocalizations.supportedLocales,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        home: const Scaffold(body: UsersPage()),
      ),
    );
  }

  Future<void> signInAsAdmin(ProviderContainer container) async {
    await container.read(authControllerProvider.notifier).login(
          'admin',
          'Admin@123',
        );
  }

Future<void> signInAs(
      ProviderContainer container, {
      required String username,
      required String password,
    }) async {
    await signInAsAdmin(container);
    await container.read(authControllerProvider.notifier).logout();
    await container.read(authControllerProvider.notifier).login(
          username,
          password,
        );
  }

  /// Finds the row [tooltip] action closest to the vertical center of
  /// [rowAnchor] (DataTable rows are cells in a single `Table`, so actions are
  /// matched by row position rather than widget ancestry).
  Finder rowAction(WidgetTester tester, Finder rowAnchor, String tooltip) {
    final anchorDy = tester.getCenter(rowAnchor).dy;
    final candidates = find.byTooltip(tooltip).evaluate().toList();
    Finder ofElement(Element e) => find.byElementPredicate((c) => identical(c, e));
    candidates.sort((a, b) => (tester.getCenter(ofElement(a)).dy - anchorDy)
        .abs()
        .compareTo((tester.getCenter(ofElement(b)).dy - anchorDy).abs()));
    return ofElement(candidates.first);
  }

  group('UsersPage (admin, Arabic)', () {
    testWidgets('loads the grid with action buttons for the admin',
        (tester) async {
      tester.view.physicalSize = const Size(1280, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      final h = await buildAuthHarness();
      addTearDown(h.db.close);
      addTearDown(h.container.dispose);
      await signInAsAdmin(h.container);

      await tester.pumpWidget(harness(h.container));
      await tester.pumpAndSettle();

      expect(find.byType(NavigationRail), findsNothing);
      expect(find.text('admin'), findsOneWidget);
      expect(find.text('مدير النظام'), findsWidgets);
      // Column header + admin's status chip.
      expect(find.text('مفعّل'), findsNWidgets(2));
      expect(find.text('إضافة مستخدم'), findsOneWidget);
      expect(find.byTooltip('تعديل'), findsWidgets);
      expect(find.byTooltip('تغيير كلمة المرور'), findsWidgets);
      expect(find.byTooltip('تعطيل'), findsWidgets);
    });

    testWidgets('creates a viewer user through the dialog', (tester) async {
      tester.view.physicalSize = const Size(1280, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      final h = await buildAuthHarness();
      addTearDown(h.db.close);
      addTearDown(h.container.dispose);
      await signInAsAdmin(h.container);

      await tester.pumpWidget(harness(h.container));
      await tester.pumpAndSettle();

      await tester.tap(find.text('إضافة مستخدم'));
      await tester.pumpAndSettle();

      await tester.enterText(
          find.widgetWithText(TextFormField, 'اسم المستخدم'), 'viewer1');
      await tester.enterText(
          find.widgetWithText(TextFormField, 'الاسم الكامل'), 'مشاهد جديد');
      await tester.enterText(
          find.widgetWithText(TextFormField, 'كلمة المرور الجديدة'), 'View@12345');
      await tester.enterText(
          find.widgetWithText(TextFormField, 'تأكيد كلمة المرور'), 'View@12345');

      await tester.tap(find.byType(DropdownButtonFormField<String>));
      await tester.pumpAndSettle();
      await tester.tap(find.text('مشاهد').last);
      await tester.pumpAndSettle();

      await tester.tap(find.text('حفظ'));
      await tester.pumpAndSettle();

      expect(find.text('تم إنشاء المستخدم'), findsOneWidget);
      expect(find.text('viewer1'), findsOneWidget);
      expect(find.text('مشاهد جديد'), findsOneWidget);

      final stored = await h.repository.findByUsername('viewer1');
      expect(stored!.roleId, 'role_viewer');
      expect(stored.displayName, 'مشاهد جديد');
    });

    testWidgets('deactivates a user after confirmation', (tester) async {
      tester.view.physicalSize = const Size(1280, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      final h = await buildAuthHarness();
      addTearDown(h.db.close);
      addTearDown(h.container.dispose);
      await seedExtraUser(h.db); // 'cashier' كاشير
      await signInAsAdmin(h.container);

      await tester.pumpWidget(harness(h.container));
      await tester.pumpAndSettle();

      expect(find.text('كاشير'), findsWidgets);
      expect(find.text('غير مفعّل'), findsNothing);

      final deactivateButton =
          rowAction(tester, find.text('cashier'), 'تعطيل');
      await tester.tap(deactivateButton);
      await tester.pumpAndSettle();

      // Confirmation dialog mentions the target user.
      expect(find.text('تعطيل المستخدم'), findsOneWidget);
      expect(find.text('هل تريد تعطيل المستخدم «كاشير»؟'), findsOneWidget);

      await tester.tap(find.widgetWithText(FilledButton, 'تعطيل'));
      await tester.pumpAndSettle();

      expect(find.text('تم تعطيل المستخدم'), findsOneWidget);
      expect(find.text('غير مفعّل'), findsOneWidget);
      final stored = await h.repository.findByUsername('cashier');
      expect(stored!.isActive, isFalse);
    });

    testWidgets('changes a user password from the row action', (tester) async {
      tester.view.physicalSize = const Size(1280, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      final h = await buildAuthHarness();
      addTearDown(h.db.close);
      addTearDown(h.container.dispose);
      await seedExtraUser(h.db);
      await signInAsAdmin(h.container);

      await tester.pumpWidget(harness(h.container));
      await tester.pumpAndSettle();

      final pwButton =
          rowAction(tester, find.text('cashier'), 'تغيير كلمة المرور');
      await tester.tap(pwButton);
      await tester.pumpAndSettle();

      await tester.enterText(
          find.widgetWithText(TextFormField, 'كلمة المرور الجديدة'), 'New@12345');
      await tester.enterText(
          find.widgetWithText(TextFormField, 'تأكيد كلمة المرور'), 'New@12345');

      await tester.tap(find.widgetWithText(FilledButton, 'تغيير كلمة المرور'));
      await tester.pumpAndSettle();

      expect(find.text('تم تغيير كلمة المرور'), findsOneWidget);
    });
  });

  group('UsersPage (permission-aware)', () {
    testWidgets('non-admin roles see no create/edit actions', (tester) async {
      tester.view.physicalSize = const Size(1280, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      final h = await buildAuthHarness();
      addTearDown(h.db.close);
      addTearDown(h.container.dispose);
      await seedExtraUser(h.db); // cashier
      await signInAs(h.container,
          username: 'cashier', password: 'Cashier@123');

      await tester.pumpWidget(harness(h.container));
      await tester.pumpAndSettle();

      expect(find.text('إضافة مستخدم'), findsNothing);
      expect(find.byTooltip('تعديل'), findsNothing);
      expect(find.byTooltip('تغيير كلمة المرور'), findsNothing);
      expect(find.byTooltip('تعطيل'), findsNothing);
    });

    testWidgets('compact layout renders user cards', (tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      final h = await buildAuthHarness();
      addTearDown(h.db.close);
      addTearDown(h.container.dispose);
      await seedExtraUser(h.db);
      await signInAsAdmin(h.container);

      await tester.pumpWidget(harness(h.container));
      await tester.pumpAndSettle();

      expect(find.byType(Card), findsNWidgets(2));
      expect(find.text('كاشير'), findsWidgets);
      expect(find.textContaining('دخول أخير'), findsNWidgets(2));
    });
  });
}