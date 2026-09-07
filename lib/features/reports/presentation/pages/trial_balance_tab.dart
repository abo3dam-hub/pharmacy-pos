import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/constants/permission_codes.dart';
import '../../../../core/di/providers.dart';
import '../../../../core/errors/failures.dart';
import '../../../../core/money/money.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/widgets/app_data_table.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../../shared/models/enums.dart';
import '../../application/reports_controller.dart';
import '../../domain/services/report_export_service.dart';
import '../widgets/report_actions.dart';
import '../widgets/report_page.dart';

/// Trial balance tab (ميزان المراجعة): every account with its opening,
/// period debit/credit activity and closing in the classic debit/credit
/// columns. Gated by [Perm.reportsViewProfit] (the financial-report family).
class TrialBalanceTab extends ConsumerStatefulWidget {
  const TrialBalanceTab({super.key});

  @override
  ConsumerState<TrialBalanceTab> createState() => _TrialBalanceTabState();
}

class _TrialBalanceTabState extends ConsumerState<TrialBalanceTab> {
  final DateTime _today = DateTime.now();
  late DateTime _from = DateTime(_today.year, 1, 1);
  late DateTime _to = _today;

  @override
  void initState() {
    super.initState();
    Future.microtask(_load);
  }

  Future<void> _load() async {
    await ref.read(trialBalanceControllerProvider.notifier).load(
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
    final state = ref.read(trialBalanceControllerProvider);
    final report = state.data;
    if (report == null) return;
    final l10n = AppLocalizations.of(context);
    final request = ReportExportRequest(
      title: l10n.reportTrialBalance,
      subtitle:
          '${formatReportDate(report.fromMillis)} - ${formatReportDate(report.toMillis)}',
      sheetName: 'trial_balance',
      generatedAtMillis: DateTime.now().millisecondsSinceEpoch,
      columns: [
        l10n.reportTrialBalanceAccount,
        l10n.reportTrialBalanceOpening,
        l10n.reportTrialBalanceDebit,
        l10n.reportTrialBalanceCredit,
        l10n.reportTrialBalanceClosing,
      ],
      rows: [
        for (final a in report.accounts)
          [
            ReportCell.text('${a.code} · ${a.name}'),
            ReportCell.money(switch (a.accountType) {
              AccountType.asset || AccountType.expense => a.openingBalanceMicros,
              _ => -a.openingBalanceMicros,
            }),
            ReportCell.money(a.periodDebitMicros),
            ReportCell.money(a.periodCreditMicros),
            ReportCell.money(a.closingBalanceMicros),
          ],
      ],
      totals: [
        ReportTotalRow(
            l10n.reportTrialBalanceDebit, ReportCell.money(report.totalDebitMicros)),
        ReportTotalRow(l10n.reportTrialBalanceCredit,
            ReportCell.money(report.totalCreditMicros)),
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
    final state = ref.watch(trialBalanceControllerProvider);
    final report = state.data;
    final hasPermission = ref
        .watch(authControllerProvider)
        .permissions
        .contains(Perm.reportsViewProfit);

    return PermissionGate(
      hasPermission: hasPermission,
      child: ReportPage(
        title: l10n.reportTrialBalance,
        filters: ReportFilterBar(
          fromLabel: '${l10n.reportFromDate} ${formatReportDate(reportDayMillis(_from))}',
          toLabel: '${l10n.reportToDate} ${formatReportDate(reportDayMillis(_to))}',
          onPickFrom: () => _pickDate(from: true),
          onPickTo: () => _pickDate(from: false),
          onRefresh: _load,
          onPrint: () => _export(asPdf: true),
          onExportExcel: () => _export(asPdf: false),
          exportEnabled: report != null && report.accounts.isNotEmpty,
        ),
        loading: state.status == ReportViewStatus.loading,
        footer: report == null
            ? null
            : Padding(
                padding: const EdgeInsets.fromLTRB(24, 4, 24, 16),
                child: Row(
                  children: [
                    Icon(
                      report.isBalanced
                          ? Icons.check_circle_outline
                          : Icons.error_outline,
                      size: 16,
                      color: report.isBalanced
                          ? Theme.of(context).colorScheme.primary
                          : Theme.of(context).colorScheme.error,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      report.isBalanced
                          ? l10n.reportBalanced
                          : l10n.reportNotBalanced,
                      style: context.appTypography.label,
                    ),
                  ],
                ),
              ),
        body: ReportBody(
          loading: state.status == ReportViewStatus.loading,
          error: state.error,
          errorMessage: _message(state.error),
          emptyMessage: l10n.reportNoData,
          child: report == null || report.accounts.isEmpty
              ? null
              : AppDataTable(
                  columns: [
                    DataColumn(label: Text(l10n.reportTrialBalanceAccount)),
                    DataColumn(label: Text(l10n.reportTrialBalanceOpening)),
                    DataColumn(
                        numeric: true, label: Text(l10n.reportTrialBalanceDebit)),
                    DataColumn(
                        numeric: true, label: Text(l10n.reportTrialBalanceCredit)),
                    DataColumn(
                        numeric: true, label: Text(l10n.reportTrialBalanceClosing)),
                  ],
                  rows: [
                    for (final a in report.accounts)
                      DataRow(cells: [
                        DataCell(Text('${a.code} · ${a.name}')),
                        DataCell(Text(Money.fromUnits(
                                a.openingBalanceMicros).format())),
                        DataCell(Text(Money.fromUnits(a.periodDebitMicros).format())),
                        DataCell(Text(Money.fromUnits(a.periodCreditMicros).format())),
                        DataCell(Text(
                          Money.fromUnits(a.closingBalanceMicros > 0
                                  ? a.closingBalanceMicros
                                  : -a.closingBalanceMicros)
                              .format(),
                          style: context.appTypography.numericStrong,
                        )),
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