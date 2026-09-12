import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:pharmacy_pos/core/config/app_config.dart';
import 'package:pharmacy_pos/core/theme/app_theme.dart';
import 'package:pharmacy_pos/core/widgets/app_data_table.dart';
import 'package:pharmacy_pos/features/inventory/presentation/widgets/paged_master_table.dart';
import 'package:pharmacy_pos/l10n/app_localizations.dart';

class _Entry {
  const _Entry(this.name);
  final String name;
}

/// Localized harness matching the app's Arabic-first delegates.
Widget _harness(Widget home) {
  return MaterialApp(
    theme: AppTheme.light(),
    locale: const Locale(AppConfig.defaultLocale),
    supportedLocales: AppLocalizations.supportedLocales,
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    home: home,
  );
}

void main() {
  final entries = [
    for (var i = 0; i < 25; i++) _Entry('item ${i.toString().padLeft(2, '0')}'),
  ];

  Widget table({
    String query = '',
  }) =>
      _harness(
        Scaffold(
          body: PagedMasterTable<_Entry>(
            data: entries,
            pageSize: 10,
            emptyMessage: 'empty',
            searchText: (e) => e.name,
            columns: [DataColumn(label: Text('name'))],
            rowBuilder: (e) => DataRow(
              cells: [DataCell(Text(e.name))],
            ),
          ),
        ),
      );

  testWidgets('renders only the first page and paginates', (tester) async {
    await tester.pumpWidget(table());
    await tester.pumpAndSettle();

    final l10n = AppLocalizations.of(tester.element(find.byType(Scaffold)));
    expect(find.text('item 00'), findsOneWidget);
    expect(find.text('item 09'), findsOneWidget);
    expect(find.text('item 10'), findsNothing,
        reason: 'page 2 rows must not be materialised yet');
    expect(find.text(l10n.masterDataCount(25)), findsOneWidget);
    expect(find.textContaining('1 / 3'), findsOneWidget);

    await tester.tap(find.byTooltip(l10n.commonNext));
    await tester.pumpAndSettle();

    expect(find.text('item 10'), findsOneWidget);
    expect(find.text('item 19'), findsOneWidget);
    expect(find.text('item 20'), findsNothing);
    expect(find.textContaining('2 / 3'), findsOneWidget);

    await tester.tap(find.byTooltip(l10n.commonPrevious));
    await tester.pumpAndSettle();
    expect(find.text('item 00'), findsOneWidget);
  });

  testWidgets('search narrows results and resets to page one', (tester) async {
    await tester.pumpWidget(table());
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip(findL10n(tester).commonNext));
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField), 'item 03');
    await tester.pump(const Duration(milliseconds: 400));
    await tester.pumpAndSettle();

    expect(
        find.descendant(
            of: find.byType(AppDataTable), matching: find.text('item 03')),
        findsOneWidget);
    expect(find.text('item 04'), findsNothing);
    expect(find.text(AppLocalizations.of(tester.element(find.byType(Scaffold)))
        .masterDataCount(1)), findsOneWidget);
    expect(find.textContaining('1 / 1'), findsOneWidget);
  });

  testWidgets('thousands of rows stay bounded to a single page', (tester) async {
    // §28 perf guard: building one DataRow per registry row froze the master
    // tabs with large catalogues; the paged table must materialise only the
    // active page no matter how many entries the controller holds.
    final big = [
      for (var i = 0; i < 5000; i++)
        _Entry('bulk ${i.toString().padLeft(5, '0')}'),
    ];
    await tester.pumpWidget(_harness(
      Scaffold(
        body: PagedMasterTable<_Entry>(
          data: big,
          pageSize: 50,
          emptyMessage: 'empty',
          searchText: (e) => e.name,
          columns: [DataColumn(label: Text('name'))],
          rowBuilder: (e) => DataRow(cells: [DataCell(Text(e.name))]),
        ),
      ),
    ));
    await tester.pumpAndSettle();

    expect(find.text('bulk 00000'), findsOneWidget);
    expect(find.text('bulk 00050'), findsNothing,
        reason: 'only the active page may be materialised');
    final rendered = tester
        .widgetList(find.textContaining('bulk '))
        .length;
    expect(rendered, lessThanOrEqualTo(50),
        reason: 'data rows are bounded by the page size, never the dataset');

    final l10n = findL10n(tester);
    await tester.tap(find.byTooltip(l10n.commonNext));
    await tester.pumpAndSettle();
    expect(find.text('bulk 00050'), findsOneWidget);
  });
}

AppLocalizations findL10n(WidgetTester tester) {
  return AppLocalizations.of(tester.element(find.byType(Scaffold)));
}