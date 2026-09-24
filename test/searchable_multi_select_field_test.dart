import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pharmacy_pos/core/widgets/searchable_multi_select_field.dart';

class _Opt {
  _Opt(this.id, this.name);
  final String id;
  final String name;
}

void main() {
  List<_Opt> opts() => [
        _Opt('1', 'مسكن'),
        _Opt('2', 'خافض حرارة'),
        _Opt('3', 'مضاد التهاب'),
      ];

  testWidgets('search filters, checkbox toggles selection, chip removes',
      (tester) async {
    var selected = <String>{};
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SearchableMultiSelectField<_Opt>(
            selectedIds: selected,
            items: opts(),
            idOf: (o) => o.id,
            nameOf: (o) => o.name,
            onChanged: (next) => selected = next,
            label: 'الاستطبابات',
          ),
        ),
      ),
    );

    // Open the dropdown.
    await tester.tap(find.byType(TextField));
    await tester.pump();

    // All three options visible.
    expect(find.text('مسكن'), findsOneWidget);
    expect(find.text('خافض حرارة'), findsOneWidget);
    expect(find.text('مضاد التهاب'), findsOneWidget);

    // Filter by search.
    await tester.enterText(find.byType(TextField), 'حرارة');
    await tester.pump();
    expect(find.text('مسكن'), findsNothing);
    expect(find.text('خافض حرارة'), findsOneWidget);

    // Toggle via checkbox.
    await tester.tap(find.byType(CheckboxListTile));
    await tester.pump();
    expect(selected, {'2'});

    // Rebuild with the new selection: chip appears.
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SearchableMultiSelectField<_Opt>(
            selectedIds: selected,
            items: opts(),
            idOf: (o) => o.id,
            nameOf: (o) => o.name,
            onChanged: (next) => selected = next,
            label: 'الاستطبابات',
          ),
        ),
      ),
    );
    expect(find.byType(Chip), findsOneWidget);

    // Remove via chip delete icon.
    await tester.tap(find.byIcon(Icons.close));
    await tester.pump();
    expect(selected, isEmpty);
  });

  testWidgets('add-new row creates and auto-selects', (tester) async {
    var selected = <String>{};
    final created = <_Opt>[];
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SearchableMultiSelectField<_Opt>(
            selectedIds: selected,
            items: opts(),
            idOf: (o) => o.id,
            nameOf: (o) => o.name,
            onChanged: (next) => selected = next,
            onAddNew: (name) async {
              final o = _Opt('new', name);
              created.add(o);
              return o;
            },
            addNewLabel: 'إضافة جديد',
          ),
        ),
      ),
    );

    await tester.tap(find.byType(TextField));
    await tester.pump();
    await tester.enterText(find.byType(TextField), 'مضاد حساسية');
    await tester.pump();

    // Add-new row appears (no exact match).
    expect(find.textContaining('مضاد حساسية'), findsWidgets);
    await tester.tap(find.textContaining('"مضاد حساسية"'));
    await tester.pump();

    expect(created, hasLength(1));
    expect(selected, {'new'});
  });
}
