import 'package:flutter/material.dart';

import '../theme/app_dimensions.dart';
import '../theme/app_text_styles.dart';

/// Theme-styled `DataTable` wrapper (single row-density + typography source).
///
/// Renders [columns] / [rows] through the central `DataTableTheme`; supports
/// sorting state, optional multi-select checkbox column, and a shared empty
/// state (text provided by the caller, e.g. localized "no results").
/// This is the *styling* foundation — the full §22 data-grid feature
/// (column visibility/order, inline edit, bulk actions) lands in its phase.
class AppDataTable extends StatelessWidget {
  const AppDataTable({
    super.key,
    required this.columns,
    required this.rows,
    this.emptyMessage,
    this.sortColumnIndex,
    this.sortAscending = true,
    this.onSortChanged,
    this.showCheckboxColumn = false,
  });

  final List<DataColumn> columns;
  final List<DataRow> rows;
  final String? emptyMessage;
  final int? sortColumnIndex;
  final bool sortAscending;
  final void Function(int columnIndex, bool ascending)? onSortChanged;
  final bool showCheckboxColumn;

  @override
  Widget build(BuildContext context) {
    if (rows.isEmpty && emptyMessage != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.xxl),
          child: Text(emptyMessage!, style: context.appTypography.labelSmall),
        ),
      );
    }

    return DataTable(
      columns: columns,
      rows: rows,
      headingRowHeight: AppLayoutTokens.tableHeaderHeight,
      dataRowMaxHeight: AppLayoutTokens.tableRowHeight,
      dataRowMinHeight: AppLayoutTokens.tableRowHeight,
      sortColumnIndex: sortColumnIndex,
      sortAscending: sortAscending,
      showCheckboxColumn: showCheckboxColumn,
      onSelectAll: showCheckboxColumn ? (value) {} : null,
    );
  }
}