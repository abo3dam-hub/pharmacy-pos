import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:pharmacy_pos/core/widgets/app_rtl_icons.dart';

/// RTL QA (§24/§14): shared direction-aware icons must mirror under RTL.
void main() {
  late IconData back, prev, next, drillIn;

  Future<void> capture(WidgetTester tester,
      TextDirection direction) async {
    await tester.pumpWidget(MaterialApp(
      builder: (context, child) => Directionality(
        textDirection: direction,
        child: Builder(
          builder: (context) {
            back = AppDirectionalIcons.back(context);
            prev = AppDirectionalIcons.previous(context);
            next = AppDirectionalIcons.next(context);
            drillIn = AppDirectionalIcons.drillIn(context);
            return const SizedBox.shrink();
          },
        ),
      ),
    ));
  }

  testWidgets('back/previous/next/drillIn mirror between LTR and RTL',
      (tester) async {
    await capture(tester, TextDirection.ltr);
    final ltrBack = back, ltrPrev = prev, ltrNext = next, ltrDrill = drillIn;

    await capture(tester, TextDirection.rtl);
    final rtlBack = back, rtlPrev = prev, rtlNext = next, rtlDrill = drillIn;

    // Canonical LTR directions.
    expect(ltrBack, Icons.arrow_back);
    expect(ltrPrev, Icons.chevron_left);
    expect(ltrNext, Icons.chevron_right);
    expect(ltrDrill, Icons.chevron_right);

    // Mirrored in RTL.
    expect(rtlBack, Icons.arrow_forward);
    expect(rtlPrev, Icons.chevron_right);
    expect(rtlNext, Icons.chevron_left);
    expect(rtlDrill, Icons.chevron_left);

    // Every RTL glyph is the mirror counterpart of its LTR glyph.
    expect(rtlBack, isNot(ltrBack));
    expect(rtlPrev, isNot(ltrPrev));
    expect(rtlNext, isNot(ltrNext));
    expect(rtlDrill, isNot(ltrDrill));
  });
}