import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:pharmacy_pos/main.dart';

void main() {
  testWidgets('app shell renders Arabic RTL workspace on desktop',
      (tester) async {
    tester.view.physicalSize = const Size(1280, 800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(const PharmacyApp());
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
  });
}