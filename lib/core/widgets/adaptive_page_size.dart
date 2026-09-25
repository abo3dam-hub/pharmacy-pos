/// Viewport-adaptive pagination: size each page so its rows exactly fill the
/// available vertical space instead of scrolling internally.
///
/// The pager stays pinned at the bottom of the screen while the page shows
/// precisely the rows that fit — no internal vertical scroll for
/// fixed-height rows (data tables), and a close fit for estimated card
/// heights (card lists keep their own scroll as a safety net).
library;

/// How many fixed-height rows fit in [availableHeight] after reserving
/// [headerHeight] for the table/card-list header, clamped to [minPage]…
/// [maxPage].
int rowsThatFit({
  required double availableHeight,
  required double rowHeight,
  required double headerHeight,
  int minPage = 4,
  int maxPage = 60,
}) {
  final fit = ((availableHeight - headerHeight) / rowHeight).floor();
  return fit.clamp(minPage, maxPage);
}
