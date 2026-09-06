import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:pharmacy_pos/main.dart';

import 'auth_harness.dart';

void main() {
  testWidgets('app starts unauthenticated on the Login page', (tester) async {
    tester.view.physicalSize = const Size(1280, 800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    final harness = await buildAuthHarness();
    addTearDown(harness.db.close);
    addTearDown(harness.container.dispose);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: harness.container,
        child: const PharmacyApp(),
      ),
    );
    await tester.pumpAndSettle();

    // Arabic-first login surface; no navigation yet.
    expect(find.text('دخول'), findsOneWidget);
    expect(find.byType(NavigationRail), findsNothing);
  });

  testWidgets('admin signs in and reaches the Arabic RTL workspace on desktop',
      (tester) async {
    tester.view.physicalSize = const Size(1280, 800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    final harness = await buildAuthHarness();
    addTearDown(harness.db.close);
    addTearDown(harness.container.dispose);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: harness.container,
        child: const PharmacyApp(),
      ),
    );
    await tester.pumpAndSettle();

    await tester.enterText(
        find.widgetWithText(TextFormField, 'اسم المستخدم'), 'admin');
    await tester.enterText(
        find.widgetWithText(TextFormField, 'كلمة المرور'), 'Admin@123');
    await tester.tap(find.text('دخول'));
    await tester.pumpAndSettle();

    // Desktop layout: persistent rail with labels, Arabic default locale.
    expect(find.byType(NavigationRail), findsOneWidget);
    expect(find.text('الرئيسية'), findsWidgets);
    expect(find.text('مبيعات'), findsOneWidget);
    expect(find.text('المخزون'), findsOneWidget);

    // Strategic sections are reachable via the rail.
    await tester.tap(find.text('الإعدادات'));
    await tester.pumpAndSettle();
    expect(find.text('الإعدادات'), findsWidgets);

    // Admin can open the users section.
    await tester.tap(find.text('المستخدمون'));
    await tester.pumpAndSettle();
    expect(find.text('المستخدمون'), findsWidgets);
  });
}