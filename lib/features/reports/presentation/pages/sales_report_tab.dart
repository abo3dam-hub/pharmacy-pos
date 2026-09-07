import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/constants/permission_codes.dart';
import '../../../../core/data_grid/page_request.dart';
import '../../../../core/di/providers.dart';
import '../../../../core/errors/failures.dart';
import '../../../../core/money/money.dart';
import '../../../../core/theme/app_dimensions.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/widgets/app_data_table.dart';
import '../../../../features/auth/domain/entities/user.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../../shared/database/app_database.dart';
import '../../application/reports_controller.dart';
import '../../domain/services/report_export_service.dart';
import '../widgets/report_actions.dart';
import '../widgets/report_page.dart';

/// Sales report tab (تقارير المبيعات): per-day sales aggregates with optional
/// customer and user filters. Gated by [Perm.reportsViewSales].
class SalesReportTab extends ConsumerStatefulWidget {
  const SalesReportTab({super.key});

  @override
  ConsumerState<SalesReportTab> createState() => _SalesReportTabState();
}

class _SalesReportTabState extends ConsumerState<SalesReportTab> {
  final DateTime _today = DateTime.now();
  late DateTime _from = DateTime(_today.year, 1, 1);
  late DateTime _to = _today;

  List<CustomerRow> _customers = const [];
  List<AppUser> _users = const [];
  String? _customerId;
  String? _userId;

  @override
  void initState() {
    super.initState();
    Future.microtask(_preload);
    Future.microtask(_load);
  }

  Future<void> _preload() async {
    try {
      final customers =
          await ref.read(customerDaoProvider).all(activeOnly: true);
      final result = await ref.read(userDaoProvider).listUsers(
            const PageRequest(page: 1, pageSize: 1000),
          );
      if (!mounted) return;
      setState(() {
        _customers = customers;
        _users = result.items;
      });
    } catch (_) {
      // Filter lists are best-effort; the report itself still loads.
    }
  }

  Future<void> _load() async {
    await ref.read(salesReportControllerProvider.notifier).load(
          from: _from,
          to: _to,
          customerId: _customerId,
          userId: _userId,
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
    final report = ref.read(salesReportControllerProvider).data;
    if (report == null) return;
    final l10n = AppLocalizations.of(context);
    final request = ReportExportRequest(
      title: l10n.reportSales,
      subtitle:
          '${formatReportDate(report.fromMillis)} - ${formatReportDate(report.toMillis)}',
      sheetName: 'sales',
      generatedAtMillis: DateTime.now().millisecondsSinceEpoch,
      columns: [
        l10n.reportDate,
        l10n.reportSalesCount,
        l10n.reportSalesUnits,
        l10n.reportSalesSubtotal,
        l10n.reportSalesDiscount,
        l10n.reportSalesVat,
        l10n.reportSalesTotal,
        l10n.reportSalesPaid,
        l10n.reportSalesProfit,
        l10n.reportSalesReturns,
        l10n.reportSalesVoided,
      ],
      rows: [
        for (final d in report.days)
          [
            ReportCell.text(formatReportDate(d.dayMillis)),
            ReportCell.integer(d.invoiceCount),
            ReportCell.integer(d.unitsSold),
            ReportCell.money(d.subtotalMicros),
            ReportCell.money(d.discountMicros),
            ReportCell.money(d.vatMicros),
            ReportCell.money(d.totalMicros),
            ReportCell.money(d.paidMicros),
            ReportCell.money(d.profitMicros),
            ReportCell.money(d.returnTotalMicros),
            ReportCell.money(d.voidTotalMicros),
          ],
      ],
      totals: [
        ReportTotalRow(l10n.reportSalesCount, ReportCell.integer(report.invoiceCount)),
        ReportTotalRow(l10n.reportSalesTotal, ReportCell.money(report.totalMicros)),
        ReportTotalRow(l10n.reportSalesProfit, ReportCell.money(report.grossProfitMicros)),
        ReportTotalRow(l10n.reportSalesNet, ReportCell.money(report.netSalesMicros)),
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
    final state = ref.watch(salesReportControllerProvider);
    final report = state.data;
    final hasPermission = ref
        .watch(authControllerProvider)
        .permissions
        .contains(Perm.reportsViewSales);

    return PermissionGate(
      hasPermission: hasPermission,
      child: ReportPage(
        title: l10n.reportSales,
        filters: ReportFilterBar(
          fromLabel: '${l10n.reportFromDate} ${formatReportDate(reportDayMillis(_from))}',
          toLabel: '${l10n.reportToDate} ${formatReportDate(reportDayMillis(_to))}',
          onPickFrom: () => _pickDate(from: true),
          onPickTo: () => _pickDate(from: false),
          onRefresh: _load,
          onPrint: () => _export(asPdf: true),
          onExportExcel: () => _export(asPdf: false),
          exportEnabled: report != null && report.days.isNotEmpty,
          extra: [
            SizedBox(
              width: 200,
              child: DropdownButtonFormField<String?>(
                initialValue: _customerId,
                decoration: InputDecoration(
                  labelText: l10n.reportCustomer,
                  isDense: true,
                  border: const OutlineInputBorder(),
                ),
                items: [
                  DropdownMenuItem<String?>(
                    value: null,
                    child: Text(l10n.reportAllCustomers),
                  ),
                  for (final c in _customers)
                    DropdownMenuItem<String?>(
                      value: c.id,
                      child: Text(c.name, overflow: TextOverflow.ellipsis),
                    ),
                ],
                onChanged: (value) {
                  setState(() => _customerId = value);
                  _load();
                },
              ),
            ),
            SizedBox(
              width: 200,
              child: DropdownButtonFormField<String?>(
                initialValue: _userId,
                decoration: InputDecoration(
                  labelText: l10n.reportUser,
                  isDense: true,
                  border: const OutlineInputBorder(),
                ),
                items: [
                  DropdownMenuItem<String?>(
                    value: null,
                    child: Text(l10n.reportAllUsers),
                  ),
                  for (final u in _users)
                    DropdownMenuItem<String?>(
                      value: u.id,
                      child: Text(u.displayName, overflow: TextOverflow.ellipsis),
                    ),
                ],
                onChanged: (value) {
                  setState(() => _userId = value);
                  _load();
                },
              ),
            ),
          ],
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
                      '${l10n.reportSalesCount}: ${report.invoiceCount} · '
                      '${l10n.reportSalesUnits}: ${report.unitsSold}',
                      style: typography.label,
                    ),
                    Text(
                      '${l10n.reportSalesTotal}: '
                      '${Money.fromUnits(report.totalMicros).format()}',
                      style: typography.label,
                    ),
                    Text(
                      '${l10n.reportSalesNet}: '
                      '${Money.fromUnits(report.netSalesMicros).format()}',
                      style: typography.label,
                    ),
                    Text(
                      '${l10n.reportSalesProfit}: '
                      '${Money.fromUnits(report.grossProfitMicros).format()}',
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
          child: report == null || report.days.isEmpty
              ? null
              : AppDataTable(
                  columns: [
                    DataColumn(label: Text(l10n.reportDate)),
                    DataColumn(numeric: true, label: Text(l10n.reportSalesCount)),
                    DataColumn(numeric: true, label: Text(l10n.reportSalesUnits)),
                    DataColumn(
                        numeric: true, label: Text(l10n.reportSalesSubtotal)),
                    DataColumn(
                        numeric: true, label: Text(l10n.reportSalesDiscount)),
                    DataColumn(numeric: true, label: Text(l10n.reportSalesVat)),
                    DataColumn(numeric: true, label: Text(l10n.reportSalesTotal)),
                    DataColumn(numeric: true, label: Text(l10n.reportSalesPaid)),
                    DataColumn(numeric: true, label: Text(l10n.reportSalesProfit)),
                    DataColumn(numeric: true, label: Text(l10n.reportSalesReturns)),
                    DataColumn(numeric: true, label: Text(l10n.reportSalesVoided)),
                  ],
                  rows: [
                    for (final d in report.days)
                      DataRow(cells: [
                        DataCell(Text(formatReportDate(d.dayMillis))),
                        DataCell(Text('${d.invoiceCount}')),
                        DataCell(Text('${d.unitsSold}')),
                        DataCell(Text(Money.fromUnits(d.subtotalMicros).format())),
                        DataCell(Text(Money.fromUnits(d.discountMicros).format())),
                        DataCell(Text(Money.fromUnits(d.vatMicros).format())),
                        DataCell(Text(Money.fromUnits(d.totalMicros).format())),
                        DataCell(Text(Money.fromUnits(d.paidMicros).format())),
                        DataCell(Text(Money.fromUnits(d.profitMicros).format())),
                        DataCell(Text(Money.fromUnits(d.returnTotalMicros).format())),
                        DataCell(Text(Money.fromUnits(d.voidTotalMicros).format())),
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