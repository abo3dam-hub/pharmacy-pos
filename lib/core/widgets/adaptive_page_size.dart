/// Viewport-adaptive pagination: grow each page with the available vertical
/// space, but never shrink it below the app-wide conventional page size.
///
/// The page holds at least [minPage] rows (default 25 — the convention used
/// by the accounting, cashbox, audit and report lists); on tall viewports it
/// grows to exactly fill the space so page turns stay rare. When the
/// viewport fits fewer rows than the page holds, the table/card list keeps
/// its own internal scroll as a safety net and the pager stays pinned at
/// the bottom of the screen.
///
/// (2026-09-25: the previous "exact fit, floor 4" policy produced degenerate
/// 4-5-row pages on ordinary windows and — combined with the list UI
/// re-requesting a page size the controller had not published yet — an
/// infinite reload loop. The floor is now the conventional full page.)
library;

/// App-wide conventional page size: every list shows at least this many
/// rows per page.
const int kConventionalPageSize = 25;

/// How many fixed-height rows fit in [availableHeight] after reserving
/// [headerHeight] for the table/card-list header, clamped to [minPage]…
/// [maxPage].
int rowsThatFit({
  required double availableHeight,
  required double rowHeight,
  required double headerHeight,
  int minPage = kConventionalPageSize,
  int maxPage = 60,
}) {
  final fit = ((availableHeight - headerHeight) / rowHeight).floor();
  return fit.clamp(minPage, maxPage);
}
