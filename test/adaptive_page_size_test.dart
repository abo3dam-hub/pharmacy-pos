import 'package:flutter_test/flutter_test.dart';
import 'package:pharmacy_pos/core/widgets/adaptive_page_size.dart';

/// Regression tests for viewport-adaptive pagination (Ali's "fit to screen"
/// request): page sizes are derived from the available height so a page of
/// rows fills the viewport instead of scrolling internally.
void main() {
  group('rowsThatFit', () {
    test('fills a standard desktop viewport with 64px rows', () {
      // 900px viewport, 56px table header, 64px rows (standard density):
      // (900 - 56) / 64 = 13.18 -> 13 rows.
      expect(
        rowsThatFit(
          availableHeight: 900,
          rowHeight: 64,
          headerHeight: 56,
        ),
        13,
      );
    });

    test('uses compact 48px rows when density is compact', () {
      // (900 - 56) / 48 = 17.58 -> 17 rows.
      expect(
        rowsThatFit(
          availableHeight: 900,
          rowHeight: 48,
          headerHeight: 56,
        ),
        17,
      );
    });

    test('shrinks the page on short viewports', () {
      // 500px viewport: (500 - 56) / 64 = 6.9 -> 6 rows.
      expect(
        rowsThatFit(
          availableHeight: 500,
          rowHeight: 64,
          headerHeight: 56,
        ),
        6,
      );
    });

    test('never drops below the minimum page size', () {
      expect(
        rowsThatFit(
          availableHeight: 200,
          rowHeight: 64,
          headerHeight: 56,
        ),
        4,
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

    test('estimates card pages on compact layouts', () {
      // 700px viewport, 152px estimated cards: (700 - 12) / 152 = 4.5 -> 4.
      expect(
        rowsThatFit(
          availableHeight: 700,
          rowHeight: 152,
          headerHeight: 12,
        ),
        4,
      );
    });
  });
}
