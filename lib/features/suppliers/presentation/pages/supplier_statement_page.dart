import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/di/providers.dart';
import '../../../../core/errors/failures.dart';
import '../../../../core/money/money.dart';
import '../../../../core/theme/app_dimensions.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/widgets/app_data_table.dart';
import '../../../../core/widgets/loading_overlay.dart';
import '../../../../data/daos/supplier_dao.dart';
import '../../../../features/reports/domain/services/report_export_service.dart';
import '../../../../features/reports/domain/services/statement_export.dart';
import '../../../../features/reports/presentation/widgets/report_actions.dart';
import '../../../../l10n/app_localizations.dart';
import '../../application/suppliers_controller.dart';
import '../../../../core/widgets/app_rtl_icons.dart';

/// Supplier statement (كشف حساب) page — one supplier's document ledger in a
/// date range with keyset pagination and a summary footer. Routed at
/// `/suppliers/statement/:supplierId`.
class SupplierStatementView extends ConsumerStatefulWidget {
  const SupplierStatementView({super.key, required this.supplierId});

  final String supplierId;

  @override
  ConsumerState<SupplierStatementView> createState() =>
      _SupplierStatementPageState();
}

class _SupplierStatementPageState extends ConsumerState<SupplierStatementView> {
  static const int _pageSize = 30;

  final DateTime _today = DateTime.now();
  late DateTime _from = DateTime(_today.year, 1, 1);
  late DateTime _to = _today;
  int _page = 1;

  String? get _actingRoleId => ref.read(authControllerProvider).actingRoleId;

  @override
  void initState() {
    super.initState();
    Future.microtask(_load);
  }

  Future<void> _load() async {
    final failure = await ref
        .read(suppliersControllerProvider.notifier)
        .loadStatement(
          widget.supplierId,
          fromDate: _toMillis(_from),
          toDate: _toMillis(_to),
          page: _page,
          pageSize: _pageSize,
          actingRoleId: _actingRoleId,
        );
    if (failure != null && mounted) {
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(content: Text(_message(failure))));
    }
  }

  Future<void> _pickDate({required bool from}) async {
    final picked = await showDatePicker(
      context: context,
      initialDate: from ? _from : _to,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );
    if (picked == null || !mounted) return;
    setState(() {
      _page = 1;
      if (from) {
        _from = picked;
        if (_to.isBefore(_from)) _to = _from;
      } else {
        _to = picked;
        if (_from.isAfter(_to)) _from = _to;
      }
    });
    await _load();
  }

  static int _toMillis(DateTime d) =>
      DateTime(d.year, d.month, d.day).millisecondsSinceEpoch;

  void _toPage(int page) {
    final statement = ref.read(suppliersControllerProvider).statement;
    if (statement == null) return;
    final pageCount = (statement.totals.totalDocs / _pageSize).ceil();
    if (page < 1 || page > (pageCount == 0 ? 1 : pageCount)) return;
    setState(() => _page = page);
    _load();
  }

  String _message(Failure failure) {
    final l10n = AppLocalizations.of(context);
    return switch (failure) {
      UnauthorizedFailure() => l10n.authPermissionDenied,
      _ => l10n.authSaveError,
    };
  }

  String _fmtDate(int millis) {
    final d = DateTime.fromMillisecondsSinceEpoch(millis);
    String two(int n) => n.toString().padLeft(2, '0');
    return '${d.year}-${two(d.month)}-${two(d.day)}';
  }

  String _docLabel(AppLocalizations l10n, SupplierStatementEntry e) {
    return switch (e.docType) {
      'opening' => l10n.statementOpening,
      'purchase_invoice' => l10n.statementRowInvoice(e.refNo),
      'purchase_return' => l10n.statementRowReturn(e.refNo),
      _ => e.refNo,
    };
  }

  Future<void> _export({required bool asPdf}) async {
    final l10n = AppLocalizations.of(context);
    final full = await ref
        .read(suppliersControllerProvider.notifier)
        .statementForExport(
          widget.supplierId,
          fromDate: _toMillis(_from),
          toDate: _toMillis(_to),
          actingRoleId: _actingRoleId,
        );
    if (full == null || !mounted) return;
    final request = StatementExport.supplier(
      title: '${full.supplierName} - ${l10n.supplierStatementTitle}',
      subtitle: '${_fmtDate(_toMillis(_from))} - ${_fmtDate(_toMillis(_to))}',
      generatedAtMillis: DateTime.now().millisecondsSinceEpoch,
      rows: full.entries,
      openingMicros: full.totals.openingMicros,
      debitTotalMicros: full.totals.debitTotalMicros,
      creditTotalMicros: full.totals.creditTotalMicros,
      closingMicros: full.totals.closingMicros,
    );
    const service = ReportExportService();
    if (asPdf) {
      await printReportPdf(context, service, request);
    } else {
      await saveReportExcel(context, service, request);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final state = ref.watch(suppliersControllerProvider);
    final typography = context.appTypography;
    final statement = state.statement;

    return LoadingOverlay(
      visible: state.statementLoading || state.busy,
      label: l10n.commonLoading,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.xl,
              AppSpacing.l,
              AppSpacing.xl,
              AppSpacing.s,
            ),
            child: Wrap(
              spacing: AppSpacing.m,
              runSpacing: AppSpacing.m,
              alignment: WrapAlignment.spaceBetween,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      icon: Icon(AppDirectionalIcons.back(context)),
                      tooltip: l10n.commonBack,
                      onPressed: () => context.go('/suppliers'),
                    ),
                    Text(
                      statement?.supplierName ?? '',
                      style: typography.pageTitle,
                    ),
                  ],
                ),
                Wrap(
                  spacing: AppSpacing.m,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    OutlinedButton.icon(
                      onPressed: () => _pickDate(from: true),
                      icon: const Icon(Icons.event_outlined),
                      label: Text(
                        '${l10n.supplierStatementDateFrom} ${_fmtDate(_toMillis(_from))}',
                      ),
                    ),
                    OutlinedButton.icon(
                      onPressed: () => _pickDate(from: false),
                      icon: const Icon(Icons.event_outlined),
                      label: Text(
                        '${l10n.supplierStatementDateTo} ${_fmtDate(_toMillis(_to))}',
                      ),
                    ),
                    const SizedBox(width: AppSpacing.s),
                    ReportExportBar(
                      enabled: statement != null && statement.entries.isNotEmpty,
                      onPrint: () => _export(asPdf: true),
                      onSaveExcel: () => _export(asPdf: false),
                    ),
                  ],
                ),
              ],
            ),
          ),
          Expanded(
            child: statement == null
                ? Center(
                    child: Text(l10n.statementNoData,
                        style: typography.labelSmall))
                : AppDataTable(
                    emptyMessage: l10n.statementNoData,
                    columns: [
                      DataColumn(label: Text(l10n.statementDate)),
                      DataColumn(label: Text(l10n.statementDescription)),
                      DataColumn(label: Text(l10n.statementDebit)),
                      DataColumn(label: Text(l10n.statementCredit)),
                      DataColumn(label: Text(l10n.statementBalance)),
                    ],
                    rows: [
                      for (final e in statement.entries)
                        DataRow(cells: [
                          DataCell(Text(
                              e.docType == 'opening' ? '' : _fmtDate(e.date))),
                          DataCell(Text(_docLabel(l10n, e))),
                          DataCell(
                              Text(e.debitMicros == 0 ? '' : Money.fromUnits(e.debitMicros).format())),
                          DataCell(
                              Text(e.creditMicros == 0 ? '' : Money.fromUnits(e.creditMicros).format())),
                          DataCell(
                            Text(
                              Money.fromUnits(e.balanceMicros).format(),
                              style: context.appTypography.numericStrong,
                            ),
                          ),
                        ]),
                    ],
                  ),
          ),
          _footer(l10n, state, typography),
        ],
      ),
    );
  }

  Widget _footer(
    AppLocalizations l10n,
    SuppliersViewState state,
    AppTypography typography,
  ) {
    final statement = state.statement;
    if (statement == null) return const SizedBox.shrink();
    final totals = statement.totals;
    final pageCount = (totals.totalDocs / _pageSize).ceil();

    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.xl,
        AppSpacing.s,
        AppSpacing.xl,
        AppSpacing.l,
      ),
      child: Wrap(
        spacing: AppSpacing.l,
        runSpacing: AppSpacing.s,
        alignment: WrapAlignment.spaceBetween,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          Wrap(
            spacing: AppSpacing.l,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              Text(
                '${l10n.statementOpening}: '
                '${Money.fromUnits(totals.openingMicros).format()}',
                style: typography.label,
              ),
              Text(
                '${l10n.statementDebit}: '
                '${Money.fromUnits(totals.debitTotalMicros).format()}',
                style: typography.label,
              ),
              Text(
                '${l10n.statementCredit}: '
                '${Money.fromUnits(totals.creditTotalMicros).format()}',
                style: typography.label,
              ),
              Text(
                '${l10n.statementClosing}: '
                '${Money.fromUnits(totals.closingMicros).format()}',
                style: typography.numericStrong,
              ),
            ],
          ),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                '${statement.page} / ${pageCount == 0 ? 1 : pageCount}',
                style: typography.bodySecondary,
              ),
              const SizedBox(width: AppSpacing.m),
              IconButton(
                onPressed: statement.page <= 1
                    ? null
                    : () => _toPage(statement.page - 1),
                icon: Icon(AppDirectionalIcons.previous(context)),
                tooltip: l10n.commonPrevious,
              ),
              IconButton(
                onPressed: statement.page >= pageCount || pageCount == 0
                    ? null
                    : () => _toPage(statement.page + 1),
                icon: Icon(AppDirectionalIcons.next(context)),
                tooltip: l10n.commonNext,
              ),
            ],
          ),
        ],
      ),
    );
  }
}