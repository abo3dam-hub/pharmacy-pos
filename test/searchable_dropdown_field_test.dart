import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pharmacy_pos/core/widgets/searchable_dropdown_field.dart';

/// Regression tests for the combobox used by the product form's master-data
/// pickers. The core invariant: a tap on an option must always select it —
/// even when the platform moves focus while the pointer is still down (which
/// used to tear the list down before the tap-up completed, so the item you
/// tapped was never selected).
Widget harness(Widget child) {
  return MaterialApp(home: Scaffold(body: Center(child: child)));
}

SearchableDropdownField<String> _field({
  String? value,
  required ValueChanged<String?>? onChanged,
}) {
  return SearchableDropdownField<String>(
    value: value,
    items: const ['ألفا', 'بيتا', 'جاما'],
    idOf: (v) => v,
    nameOf: (v) => v,
    onChanged: onChanged,
  );
}

void main() {
  testWidgets('option tap survives a focus change that occurs during the tap',
      (tester) async {
    String? selected;
    await tester.pumpWidget(harness(_field(onChanged: (v) => selected = v)));

    // Open the list.
    await tester.tap(find.byType(TextField));
    await tester.pumpAndSettle();
    expect(find.text('بيتا'), findsOneWidget);

    final row = find.text('بيتا').last;
    final gesture = await tester.startGesture(tester.getCenter(row));
    await tester.pump();

    // Simulate the platform transferring focus away on pointer-down — the bug
    // precondition. Pre-fix this unmounted the list before the tap-up, so the
    // selection never happened.
    FocusManager.instance.primaryFocus?.unfocus();
    await tester.pump();

    expect(find.text('بيتا'), findsOneWidget,
        reason: 'the row must stay mounted while the pointer is still down');
    await gesture.up();
    await tester.pumpAndSettle();

    expect(selected, 'بيتا',
        reason: 'the tap must complete and select the row');
    expect(find.byType(ListTile), findsNothing,
        reason: 'the list closes after a successful selection');
  });

  testWidgets('typing filters the options and tapping selects the match',
      (tester) async {
    String? selected;
    await tester.pumpWidget(harness(_field(onChanged: (v) => selected = v)));

    await tester.enterText(find.byType(TextField), 'أل');
    await tester.pump();
    expect(find.text('ألفا'), findsOneWidget);
    expect(find.text('بيتا'), findsNothing,
        reason: 'typing narrows the option list');

    await tester.tap(find.text('ألفا').last);
    await tester.pumpAndSettle();

    expect(selected, 'ألفا');
    expect(find.byType(ListTile), findsNothing);
  });

  testWidgets('an external value change is reflected in the field text',
      (tester) async {
    final value = ValueNotifier<String>('ألفا');
    await tester.pumpWidget(harness(ValueListenableBuilder<String>(
      valueListenable: value,
      builder: (_, current, _) => SearchableDropdownField<String>(
        value: current,
        items: const ['ألفا', 'بيتا'],
        idOf: (v) => v,
        nameOf: (v) => v,
        onChanged: (_) {},
      ),
    )));
    expect(find.text('ألفا'), findsOneWidget,
        reason: 'the initial value is rendered');

    value.value = 'بيتا';
    await tester.pump();
    expect(find.text('بيتا'), findsOneWidget,
        reason: 'external changes propagate into the controlled field');
  });
}