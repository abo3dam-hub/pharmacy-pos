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
import '../../domain/services/report_export_service.dart';
import '../widgets/report_actions.dart';
import '../widgets/report_page.dart';

/// Income statement tab (قائمة الدخل): net revenue, COGS, gross profit,
/// operating expenses and net income for a [from, to) range.
class IncomeStatementTab extends ConsumerStatefulWidget {
  const IncomeStatementTab({super.key});

  @override
  ConsumerState<IncomeStatementTab> createState() => _IncomeStatementTabState();
}

class _IncomeStatementTabState extends ConsumerState<IncomeStatementTab> {
  final DateTime _today = DateTime.now();
  late DateTime _from = DateTime(_today.year, 1, 1);
  late DateTime _to = _today;

  @override
  void initState() {
    super.initState();
    Future.microtask(_load);
  }

  Future<void> _load() async {
    await ref.read(incomeStatementControllerProvider.notifier).load(
          from: _from,
          to: _to,
        );
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

  Future<void> _export({required bool asPdf}) async {
    final report = ref.read(incomeStatementControllerProvider).data;
    if (report == null) return;
    final l10n = AppLocalizations.of(context);
    final request = ReportExportRequest(
      title: l10n.reportIncomeStatement,
      subtitle:
          '${formatReportDate(report.fromMillis)} - ${formatReportDate(report.toMillis)}',
      sheetName: 'income_statement',
      generatedAtMillis: DateTime.now().millisecondsSinceEpoch,
      columns: [l10n.reportIncomeStatement, l10n.reportIncomeNetIncome],
      rows: [
        [
          ReportCell.text(l10n.reportIncomeSalesRevenue),
          ReportCell.money(report.salesRevenueMicros),
        ],
        [
          ReportCell.text(l10n.reportIncomeSalesReturns),
          ReportCell.money(-report.salesReturnsMicros),
        ],
        [
          ReportCell.text(l10n.reportIncomeNetRevenue),
          ReportCell.money(report.netRevenueMicros),
        ],
        [
          ReportCell.text(l10n.reportIncomeCogs),
          ReportCell.money(report.costOfGoodsSoldMicros),
        ],
        [
          ReportCell.text(l10n.reportIncomeGrossProfit),
          ReportCell.money(report.grossProfitMicros),
        ],
        for (final e in report.operatingExpenses) ...[
          [
            ReportCell.text('${e.code} · ${e.name}'),
            ReportCell.money(e.amountMicros),
          ],
        ],
        [
          ReportCell.text(l10n.reportIncomeNetIncome),
          ReportCell.money(report.netIncomeMicros),
        ],
      ],
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
    final typography = context.appTypography;
    final state = ref.watch(incomeStatementControllerProvider);
    final report = state.data;
    final hasPermission = ref
        .watch(authControllerProvider)
        .permissions
        .contains(Perm.reportsViewProfit);

    return PermissionGate(
      hasPermission: hasPermission,
      child: ReportPage(
        title: l10n.reportIncomeStatement,
        filters: ReportFilterBar(
          fromLabel: '${l10n.reportFromDate} ${formatReportDate(reportDayMillis(_from))}',
          toLabel: '${l10n.reportToDate} ${formatReportDate(reportDayMillis(_to))}',
          onPickFrom: () => _pickDate(from: true),
          onPickTo: () => _pickDate(from: false),
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
                      '${l10n.reportIncomeNetRevenue}: '
                      '${Money.fromUnits(report.netRevenueMicros).format()}',
                      style: typography.label,
                    ),
                    Text(
                      '${l10n.reportIncomeGrossProfit}: '
                      '${Money.fromUnits(report.grossProfitMicros).format()}',
                      style: typography.numericStrong,
                    ),
                    Text(
                      '${l10n.reportIncomeNetIncome}: '
                      '${Money.fromUnits(report.netIncomeMicros).format()}',
                      style: typography.numericStrong,
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
                    DataColumn(label: Text(l10n.reportIncomeStatement)),
                    DataColumn(
                        numeric: true, label: Text(l10n.reportIncomeNetIncome)),
                  ],
                  rows: [
                    DataRow(cells: [
                      DataCell(Text(l10n.reportIncomeSalesRevenue,
                          style: typography.label)),
                      DataCell(Text(
                          Money.fromUnits(report.salesRevenueMicros).format())),
                    ]),
                    DataRow(cells: [
                      DataCell(Text(l10n.reportIncomeSalesReturns)),
                      DataCell(Text('-${Money.fromUnits(report.salesReturnsMicros).format()}')),
                    ]),
                    DataRow(cells: [
                      DataCell(Text(l10n.reportIncomeNetRevenue,
                          style: typography.label)),
                      DataCell(Text(
                          Money.fromUnits(report.netRevenueMicros).format())),
                    ]),
                    DataRow(cells: [
                      DataCell(Text(l10n.reportIncomeCogs)),
                      DataCell(Text(
                          Money.fromUnits(report.costOfGoodsSoldMicros).format())),
                    ]),
                    DataRow(cells: [
                      DataCell(Text(l10n.reportIncomeGrossProfit,
                          style: typography.label)),
                      DataCell(Text(
                          Money.fromUnits(report.grossProfitMicros).format(),
                          style: typography.numericStrong)),
                    ]),
                    for (final e in report.operatingExpenses)
                      DataRow(cells: [
                        DataCell(Text('${e.code} · ${e.name}')),
                        DataCell(Text(Money.fromUnits(e.amountMicros).format())),
                      ]),
                    DataRow(cells: [
                      DataCell(Text(l10n.reportIncomeNetIncome,
                          style: typography.label)),
                      DataCell(Text(
                          Money.fromUnits(report.netIncomeMicros).format(),
                          style: typography.numericStrong)),
                    ]),
                  ],
                  emptyMessage: l10n.reportNoData,
                ),
        ),
      ),
    );
  }

  String _message(Failure? failure) {
    final l10n = AppLocalizations.of(context);
    if (failure is UnauthorizedFailure) return l10n.reportNoPermission;
    return l10n.authSaveError;
  }
}