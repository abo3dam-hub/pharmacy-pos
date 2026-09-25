/// Horizontal-scroll regression: a wide [AppDataTable] inside a narrow
/// viewport must actually scroll horizontally (previously the
/// controller-less `Scrollbar` showed no thumb, leaving mouse users with no
/// way to reach off-screen columns at all).
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pharmacy_pos/core/theme/app_theme.dart';
import 'package:pharmacy_pos/core/widgets/app_data_table.dart';
import 'package:pharmacy_pos/core/widgets/horizontal_scroll.dart';

Widget _wideTable() {
  const colWidth = 200.0;
  return AppDataTable(
    columns: [
      for (var i = 0; i < 8; i++)
        DataColumn(
          label: SizedBox(
            width: colWidth,
            child: Text('COL-$i', textDirection: TextDirection.ltr),
          ),
        ),
    ],
    rows: [
      for (var r = 0; r < 3; r++)
        DataRow(
          cells: [
            for (var i = 0; i < 8; i++)
              DataCell(
                SizedBox(
                  width: colWidth,
                  child: Text(
                    'R${r}C$i',
                    textDirection: TextDirection.ltr,
                  ),
                ),
              ),
          ],
        ),
    ],
  );
}

void main() {
  testWidgets('wide AppDataTable scrolls horizontally in a narrow viewport',
      (tester) async {
    tester.view.physicalSize = const Size(400, 800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      MaterialApp(theme: AppTheme.light(), home: Scaffold(body: _wideTable())),
    );
    await tester.pumpAndSettle();

    final hScroll = tester.widget<SingleChildScrollView>(
      find.byWidgetPredicate(
        (w) => w is SingleChildScrollView && w.scrollDirection == Axis.horizontal,
      ),
    );
    final controller = hScroll.controller!;
    // 8 × 200px columns in a 400px viewport: must be scrollable.
    expect(controller.position.maxScrollExtent, greaterThan(0));

    // The far-right column starts off-screen (beyond the 400px viewport).
    expect(tester.getTopLeft(find.text('COL-7')).dx, greaterThan(400));

    // Drag left like a mouse/trackpad user would via the scrollbar.
    for (var i = 0; i < 3; i++) {
      await tester.drag(find.byType(AppDataTable), const Offset(-600, 0));
      await tester.pumpAndSettle();
    }

    expect(controller.offset, greaterThan(0));
    // Hidden content is now reachable inside the viewport.
    final col7Left = tester.getTopLeft(find.text('COL-7')).dx;
    expect(col7Left, lessThan(400));
  });

  testWidgets('HorizontalScroll exposes a visible, wired scrollbar', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(400, 800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light(),
        home: Scaffold(
          body: HorizontalScroll(
            child: Container(width: 1200, height: 50, color: Colors.red),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final scrollbar = tester.widget<Scrollbar>(find.byType(Scrollbar));
    // The scrollbar must own a real controller (not the detached primary
    // one) and keep its thumb visible for mouse users.
    expect(scrollbar.controller, isNotNull);
    expect(scrollbar.thumbVisibility, isTrue);
    expect(
      scrollbar.controller!.position.maxScrollExtent,
      greaterThan(0),
    );
  });
}
