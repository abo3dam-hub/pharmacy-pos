import 'package:flutter/material.dart';

import '../../../../core/theme/app_dimensions.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/widgets/app_data_table.dart';
import '../../../../core/widgets/app_rtl_icons.dart';
import '../../../../core/widgets/search_field.dart';
import '../../../../l10n/app_localizations.dart';

/// Searchable, locally paged container for master-data grids (§4.1–4.5).
///
/// The controller keeps the whole registry in memory (the item form needs the
/// complete lists for its pickers), but grids must stay smooth with thousands
/// of rows: only [pageSize] [DataRow]s are materialised per frame and the rest
/// is reachable through the pager and the name search box.
class PagedMasterTable<T> extends StatefulWidget {
  const PagedMasterTable({
    super.key,
    required this.data,
    required this.columns,
    required this.rowBuilder,
    required this.searchText,
    required this.emptyMessage,
    this.pageSize = 50,
  });

  final List<T> data;
  final List<DataColumn> columns;
  final DataRow Function(T row) rowBuilder;

  /// Combined text used for filtering; already-normalized input of the name
  /// (Arabic + English) is matched with `contains`.
  final String Function(T row) searchText;
  final String emptyMessage;
  final int pageSize;

  @override
  State<PagedMasterTable<T>> createState() => _PagedMasterTableState<T>();
}

class _PagedMasterTableState<T> extends State<PagedMasterTable<T>> {
  String _query = '';
  int _page = 1;

  List<T> get _filtered {
    if (_query.isEmpty) return widget.data;
    final query = _query;
    return [
      for (final row in widget.data)
        if (widget.searchText(row).toLowerCase().contains(query)) row,
    ];
  }

  void _onSearch(String value) {
    setState(() {
      _query = value.trim().toLowerCase();
      _page = 1;
    });
  }

  void _clampPage(int pageCount) {
    if (_page > pageCount && pageCount >= 1) _page = pageCount;
  }

  void _toPage(int page, int pageCount) {
    if (page < 1 || page > (pageCount == 0 ? 1 : pageCount)) return;
    setState(() => _page = page);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final filtered = _filtered;
    final pageCount = (filtered.length / widget.pageSize).ceil();
    if (_query.isNotEmpty || filtered.length > widget.pageSize) {
      _clampPage(pageCount);
    }
    final start = (_page - 1) * widget.pageSize;
    final slice = filtered.skip(start).take(widget.pageSize).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.xl,
            AppSpacing.s,
            AppSpacing.xl,
            AppSpacing.s,
          ),
          child: SizedBox(
            width: 320,
            child: SearchField(
              hintText: l10n.masterDataSearchHint,
              onChanged: _onSearch,
            ),
          ),
        ),
        Expanded(
          child: AppDataTable(
            emptyMessage: widget.emptyMessage,
            columns: widget.columns,
            rows: [for (final row in slice) widget.rowBuilder(row)],
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.xl,
            AppSpacing.s,
            AppSpacing.xl,
            AppSpacing.l,
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              Text(
                l10n.masterDataCount(filtered.length),
                style: context.appTypography.bodySecondary,
              ),
              const SizedBox(width: AppSpacing.m),
              Text(
                '$_page / ${pageCount == 0 ? 1 : pageCount}',
                style: context.appTypography.bodySecondary,
              ),
              const SizedBox(width: AppSpacing.m),
              IconButton(
                onPressed: _page <= 1
                    ? null
                    : () => _toPage(_page - 1, pageCount),
                icon: Icon(AppDirectionalIcons.previous(context)),
                tooltip: l10n.commonPrevious,
              ),
              IconButton(
                onPressed: _page >= pageCount || pageCount == 0
                    ? null
                    : () => _toPage(_page + 1, pageCount),
                icon: Icon(AppDirectionalIcons.next(context)),
                tooltip: l10n.commonNext,
              ),
            ],
          ),
        ),
      ],
    );
  }
}