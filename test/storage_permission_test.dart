import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pharmacy_pos/core/permissions/storage_permission.dart';

void main() {
  testWidgets('ensureStoragePermission returns true without prompting '
      'on non-Android platforms', (tester) async {
    var contextSeen = false;
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) {
            contextSeen = true;
            return FutureBuilder<bool>(
              future: ensureStoragePermission(context),
              builder: (context, snapshot) {
                if (!snapshot.hasData) {
                  return const CircularProgressIndicator();
                }
                return Text('granted=${snapshot.data}');
              },
            );
          },
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(contextSeen, isTrue);
    // Tests run on Linux/macOS/Windows — no permission flow, immediate true.
    expect(find.text('granted=true'), findsOneWidget);
  });
}
