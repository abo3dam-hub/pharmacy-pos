import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/constants/permission_codes.dart';
import '../../../../core/di/providers.dart';
import '../../../../core/errors/failures.dart';
import '../../../../core/money/money.dart';
import '../../../../core/theme/app_dimensions.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/widgets/app_data_table.dart';
import '../../../../l10n/app_localizations.dart';
import '../../application/reports_controller.dart';
import '../../domain/entities/report_models.dart';
import '../../domain/services/report_export_service.dart';
import '../widgets/report_actions.dart';
import '../widgets/report_page.dart';

/// Balance sheet tab (الميزانية العمومية): assets, liabilities and equity
/// sections as of a date, including computed retained earnings so the equation
/// always balances. Gated by [Perm.reportsViewProfit].
class BalanceSheetTab extends ConsumerStatefulWidget {
  const BalanceSheetTab({super.key});

  @override
  ConsumerState<BalanceSheetTab> createState() => _BalanceSheetTabState();
}

class _BalanceSheetTabState extends ConsumerState<BalanceSheetTab> {
  final DateTime _today = DateTime.now();
  late DateTime _asOf = _today;

  @override
  void initState() {
    super.initState();
    Future.microtask(_load);
  }

  Future<void> _load() async {
    await ref.read(balanceSheetControllerProvider.notifier).load(
          from: null,
          to: _asOf,
        );
  }

  Future<void> _pickAsOf() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _asOf,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );
    if (picked == null || !mounted) return;
    setState(() => _asOf = picked);
    await _load();
  }

  Future<void> _export({required bool asPdf}) async {
    final report = ref.read(balanceSheetControllerProvider).data;
    if (report == null) return;
    final l10n = AppLocalizations.of(context);
    final rows = <List<ReportCell>>[
      ..._sectionRows(report.assets, l10n),
      ..._sectionRows(report.liabilities, l10n),
      ..._sectionRows(report.equity, l10n),
    ];
    final request = ReportExportRequest(
      title: l10n.reportBalanceSheet,
      subtitle:
          '${l10n.reportToDate} ${formatReportDate(report.asOfMillis)}',
      sheetName: 'balance_sheet',
      generatedAtMillis: DateTime.now().millisecondsSinceEpoch,
      columns: [l10n.reportInventoryItemName, l10n.reportBalanceTotal],
      rows: rows,
      totals: [
        ReportTotalRow(
            l10n.reportBalanceAssets, ReportCell.money(report.totalAssetsMicros)),
        ReportTotalRow(l10n.reportBalanceLiabilities,
            ReportCell.money(report.totalLiabilitiesMicros)),
        ReportTotalRow(
            l10n.reportBalanceEquity, ReportCell.money(report.totalEquityMicros)),
      ],
    );
    const service = ReportExportService();
    if (asPdf) {
      await printReportPdf(context, service, request);
    } else {
      await saveReportExcel(context, service, request);
    }
  }

  List<List<ReportCell>> _sectionRows(
      BalanceSheetSection section, AppLocalizations l10n) {
    return [
      [ReportCell.text(section.title), ReportCell.money(section.totalMicros)],
      for (final item in section.items)
        [
          ReportCell.text('${item.code} · ${item.name}'),
          ReportCell.money(item.amountMicros),
        ],
    ];
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final typography = context.appTypography;
    final state = ref.watch(balanceSheetControllerProvider);
    final report = state.data;
    final hasPermission = ref
        .watch(authControllerProvider)
        .permissions
        .contains(Perm.reportsViewProfit);

    return PermissionGate(
      hasPermission: hasPermission,
      child: ReportPage(
        title: l10n.reportBalanceSheet,
        filters: ReportFilterBar(
          fromLabel: '${l10n.reportToDate} ${formatReportDate(reportDayMillis(_asOf))}',
          toLabel: null,
          onPickFrom: _pickAsOf,
          onPickTo: null,
          onRefresh: _load,
          onPrint: () => _export(asPdf: true),
          onExportExcel: () => _export(asPdf: false),
          exportEnabled: report != null,
        ),
        loading: state.status == ReportViewStatus.loading,
        footer: report == null
            ? null
            : Padding(
                padding: const EdgeInsets.fromLTRB(
                    AppSpacing.xl, AppSpacing.s, AppSpacing.xl, AppSpacing.l),
                child: Wrap(
                  spacing: AppSpacing.l,
                  runSpacing: AppSpacing.s,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    Text(
                      '${l10n.reportBalanceAssets}: '
                      '${Money.fromUnits(report.totalAssetsMicros).format()}',
                      style: typography.label,
                    ),
                    Text(
                      '${l10n.reportBalanceLiabilities}: '
                      '${Money.fromUnits(report.totalLiabilitiesMicros).format()}',
                      style: typography.label,
                    ),
                    Text(
                      '${l10n.reportBalanceEquity}: '
                      '${Money.fromUnits(report.totalEquityMicros).format()}',
                      style: typography.numericStrong,
                    ),
                    Icon(
                      report.isBalanced
                          ? Icons.check_circle_outline
                          : Icons.error_outline,
                      size: 16,
                      color: report.isBalanced
                          ? Theme.of(context).colorScheme.primary
                          : Theme.of(context).colorScheme.error,
                    ),
                    Text(
                      report.isBalanced
                          ? l10n.reportBalanced
                          : l10n.reportNotBalanced,
                      style: typography.label,
                    ),
                  ],
                ),
              ),
        body: ReportBody(
          loading: state.status == ReportViewStatus.loading,
          error: state.error,
          errorMessage: _message(state.error),
          emptyMessage: l10n.reportNoData,
          child: report == null
              ? null
              : AppDataTable(
                  columns: [
                    DataColumn(label: Text(l10n.reportInventoryItemName)),
                    DataColumn(
                        numeric: true, label: Text(l10n.reportBalanceTotal)),
                  ],
                  rows: [
                    ..._sectionDataRows(report.assets, l10n),
                    ..._sectionDataRows(report.liabilities, l10n),
                    ..._sectionDataRows(report.equity, l10n),
                  ],
                  emptyMessage: l10n.reportNoData,
                ),
        ),
      ),
    );
  }

  List<DataRow> _sectionDataRows(
      BalanceSheetSection section, AppLocalizations l10n) {
    return [
      DataRow(cells: [
        DataCell(Text(section.title, style: context.appTypography.label)),
        DataCell(Text(Money.fromUnits(section.totalMicros).format(),
            style: context.appTypography.label)),
      ]),
      for (final item in section.items)
        DataRow(cells: [
          DataCell(Text('${item.code} · ${item.name}')),
          DataCell(Text(Money.fromUnits(item.amountMicros).format())),
        ]),
    ];
  }

  String _message(Failure? failure) {
    final l10n = AppLocalizations.of(context);
    if (failure is UnauthorizedFailure) return l10n.reportNoPermission;
    return l10n.authSaveError;
  }
}