import 'package:flutter/material.dart';

import '../theme/app_dimensions.dart';
import '../theme/app_text_styles.dart';
import 'horizontal_scroll.dart';

/// Theme-styled `DataTable` wrapper (single row-density + typography source).
///
/// Renders [columns] / [rows] through the central `DataTableTheme`; supports
/// sorting state, optional multi-select checkbox column, and a shared empty
/// state (text provided by the caller, e.g. localized "no results").
/// This is the *styling* foundation — the full §22 data-grid feature
/// (column visibility/order, inline edit, bulk actions) lands in its phase.
///
/// Both scroll axes use explicit controllers wired to always-visible
/// scrollbars ([HorizontalScroll] + vertical [Scrollbar]): on desktop a
/// controller-less scrollbar shows no thumb and horizontal scrolling is
/// impossible with a mouse.
class AppDataTable extends StatefulWidget {
  const AppDataTable({
    super.key,
    required this.columns,
    required this.rows,
    this.emptyMessage,
    this.sortColumnIndex,
    this.sortAscending = true,
    this.onSortChanged,
    this.showCheckboxColumn = false,
    this.dataRowHeight,
  });

  final List<DataColumn> columns;
  final List<DataRow> rows;
  final String? emptyMessage;
  final int? sortColumnIndex;
  final bool sortAscending;
  final void Function(int columnIndex, bool ascending)? onSortChanged;
  final bool showCheckboxColumn;
  final double? dataRowHeight;

  @override
  State<AppDataTable> createState() => _AppDataTableState();
}

class _AppDataTableState extends State<AppDataTable> {
  late final ScrollController _verticalController;

  @override
  void initState() {
    super.initState();
    _verticalController = ScrollController();
  }

  @override
  void dispose() {
    _verticalController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.rows.isEmpty && widget.emptyMessage != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.xxl),
          child: Text(
            widget.emptyMessage!,
            style: context.appTypography.labelSmall,
          ),
        ),
      );
    }

    return Scrollbar(
      controller: _verticalController,
      thumbVisibility: true,
      notificationPredicate: (notification) =>
          notification.metrics.axis == Axis.vertical,
      child: HorizontalScroll(
        child: SingleChildScrollView(
          controller: _verticalController,
          child: DataTable(
            columns: widget.columns,
            rows: widget.rows,
            headingRowHeight: AppLayoutTokens.tableHeaderHeight,
            // Tight column spacing so tables fit the screen width without
            // horizontal scrolling (explicit user requirement); the
            // Flutter default of 56px wastes most of the row.
            columnSpacing: 20,
            horizontalMargin: 12,
            dataRowMaxHeight:
                widget.dataRowHeight ?? AppLayoutTokens.tableRowHeight,
            dataRowMinHeight:
                widget.dataRowHeight ?? AppLayoutTokens.tableRowHeight,
            sortColumnIndex: widget.sortColumnIndex,
            sortAscending: widget.sortAscending,
            showCheckboxColumn: widget.showCheckboxColumn,
            onSelectAll: widget.showCheckboxColumn ? (value) {} : null,
          ),
        ),
      ),
    );
  }
}
