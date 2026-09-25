import 'package:flutter_test/flutter_test.dart';
import 'package:pharmacy_pos/core/widgets/adaptive_page_size.dart';

/// Viewport-adaptive pagination (Ali's "fit to screen" request, corrected
/// 2026-09-25): pages grow with the viewport but never shrink below the
/// app-wide conventional page size (25) — the old "exact fit, floor 4"
/// policy produced degenerate 4-5-row pages on ordinary windows.
void main() {
  group('rowsThatFit', () {
    test('never drops below the conventional page size on short viewports',
        () {
      // 500px viewport, 64px rows: (500 - 56) / 64 = 6.9 -> floored to 25.
      expect(
        rowsThatFit(
          availableHeight: 500,
          rowHeight: 64,
          headerHeight: 56,
        ),
        25,
      );
    });

    test('floors a standard desktop viewport at 25 rows', () {
      // 900px viewport, 56px table header, 64px rows: (900 - 56) / 64 =
      // 13.18 -> floored to the conventional 25.
      expect(
        rowsThatFit(
          availableHeight: 900,
          rowHeight: 64,
          headerHeight: 56,
        ),
        25,
      );
    });

    test('floors compact 48px rows at 25 as well', () {
      // (900 - 56) / 48 = 17.58 -> 25.
      expect(
        rowsThatFit(
          availableHeight: 900,
          rowHeight: 48,
          headerHeight: 56,
        ),
        25,
      );
    });

    test('grows past the floor on tall viewports', () {
      // (2000 - 56) / 64 = 30.37 -> 30 rows.
      expect(
        rowsThatFit(
          availableHeight: 2000,
          rowHeight: 64,
          headerHeight: 56,
        ),
        30,
      );
    });

    test('caps very tall viewports at the maximum page size', () {
      expect(
        rowsThatFit(
          availableHeight: 4000,
          rowHeight: 64,
          headerHeight: 56,
        ),
        60,
      );
    });

    test('honours an explicit minPage override', () {
      expect(
        rowsThatFit(
          availableHeight: 200,
          rowHeight: 64,
          headerHeight: 56,
          minPage: 10,
        ),
        10,
      );
    });

    test('floors estimated card pages on compact layouts', () {
      // 700px viewport, 152px estimated cards: (700 - 12) / 152 = 4.5 ->
      // floored to 25.
      expect(
        rowsThatFit(
          availableHeight: 700,
          rowHeight: 152,
          headerHeight: 12,
        ),
        25,
      );
    });
  });
}
