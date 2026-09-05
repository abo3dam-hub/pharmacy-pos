import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:pharmacy_pos/main.dart';

void main() {
  testWidgets('app shell renders Arabic RTL workspace', (tester) async {
    await tester.pumpWidget(const PharmacyApp());
    await tester.pumpAndSettle();

    // Arabic default locale.
    expect(find.text('الرئيسية'), findsWidgets);
    expect(find.text('مبيعات'), findsWidgets);
    expect(find.text('المخزون'), findsOneWidget);

    // App title is the Arabic product name.
    expect(
      tester.widget<MaterialApp>(find.byType(MaterialApp)).title,
      'نظام الصيدلية',
    );

    // Strategic sections are reachable via the rail.
    await tester.tap(find.text('الإعدادات'));
    await tester.pump();
    expect(find.text('الإعدادات'), findsWidgets);
  });
}