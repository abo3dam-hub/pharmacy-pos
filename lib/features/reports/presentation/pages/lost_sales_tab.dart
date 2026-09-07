import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/constants/permission_codes.dart';
import '../../../../core/di/providers.dart';
import '../../../../core/errors/failures.dart';
import '../../../../core/theme/app_dimensions.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/widgets/app_data_table.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../../shared/models/enums.dart';
import '../../application/reports_controller.dart';
import '../../domain/services/report_export_service.dart';
import '../widgets/report_actions.dart';
import '../widgets/report_page.dart';

/// Lost-sales report tab (النواقص): items captured as missing from the POS,
/// with a status filter. Gated by [Perm.lostSalesView].
class LostSalesTab extends ConsumerStatefulWidget {
  const LostSalesTab({super.key});

  @override
  ConsumerState<LostSalesTab> createState() => _LostSalesTabState();
}

class _LostSalesTabState extends ConsumerState<LostSalesTab> {
  final DateTime _today = DateTime.now();
  late DateTime _from = DateTime(_today.year, 1, 1);
  late DateTime _to = _today;
  LostSalesStatusFilter? _status;

  @override
  void initState() {
    super.initState();
    Future.microtask(_load);
  }

  Future<void> _load() async {
    await ref.read(lostSalesReportControllerProvider.notifier).load(
          from: _from,
          to: _to,
          status: _status,
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
    final report = ref.read(lostSalesReportControllerProvider).data;
    if (report == null) return;
    final l10n = AppLocalizations.of(context);
    final request = ReportExportRequest(
      title: l10n.reportLostSales,
      subtitle:
          '${formatReportDate(report.fromMillis)} - ${formatReportDate(report.toMillis)}',
      sheetName: 'lost_sales',
      generatedAtMillis: DateTime.now().millisecondsSinceEpoch,
      columns: [
        l10n.reportDate,
        l10n.reportLostSalesItem,
        l10n.reportLostSalesBarcode,
        l10n.reportLostSalesQty,
        l10n.reportLostSalesCustomer,
        l10n.reportLostSalesStatus,
        l10n.reportLostSalesNote,
      ],
      rows: [
        for (final r in report.rows)
          [
            ReportCell.text(formatReportDate(r.createdAt)),
            ReportCell.text(r.requestedItemName),
            ReportCell.text(r.barcode ?? ''),
            ReportCell.integer(r.quantityRequested),
            ReportCell.text(r.customerName ?? ''),
            ReportCell.text(_statusLabel(r.status)),
            ReportCell.text(r.note ?? ''),
          ],
      ],
      totals: [
        ReportTotalRow(
            l10n.reportLostSalesCount, ReportCell.integer(report.requestCount)),
        ReportTotalRow(l10n.reportLostSalesQty,
            ReportCell.integer(report.totalQuantityRequested)),
      ],
    );
    const service = ReportExportService();
    if (asPdf) {
      await printReportPdf(context, service, request);
    } else {
      await saveReportExcel(context, service, request);
    }
  }

  String _statusLabel(LostSaleStatus status) {
    final l10n = AppLocalizations.of(context);
    return switch (status) {
      LostSaleStatus.open => l10n.reportLostStatusOpen,
      LostSaleStatus.ordered => l10n.reportLostStatusOrdered,
      LostSaleStatus.resolved => l10n.reportLostStatusResolved,
      LostSaleStatus.cancelled => l10n.reportLostStatusCancelled,
    };
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final typography = context.appTypography;
    final state = ref.watch(lostSalesReportControllerProvider);
    final report = state.data;
    final hasPermission = ref
        .watch(authControllerProvider)
        .permissions
        .contains(Perm.lostSalesView);

    return PermissionGate(
      hasPermission: hasPermission,
      child: ReportPage(
        title: l10n.reportLostSales,
        filters: ReportFilterBar(
          fromLabel: '${l10n.reportFromDate} ${formatReportDate(reportDayMillis(_from))}',
          toLabel: '${l10n.reportToDate} ${formatReportDate(reportDayMillis(_to))}',
          onPickFrom: () => _pickDate(from: true),
          onPickTo: () => _pickDate(from: false),
          onRefresh: _load,
          onPrint: () => _export(asPdf: true),
          onExportExcel: () => _export(asPdf: false),
          exportEnabled: report != null && report.rows.isNotEmpty,
          extra: [
            SizedBox(
              width: 200,
              child: DropdownButtonFormField<LostSalesStatusFilter?>(
                initialValue: _status,
                decoration: InputDecoration(
                  labelText: l10n.reportLostSalesStatus,
                  isDense: true,
                  border: const OutlineInputBorder(),
                ),
                items: [
                  DropdownMenuItem<LostSalesStatusFilter?>(
                    value: null,
                    child: Text(l10n.reportAllStatuses),
                  ),
                  for (final s in LostSalesStatusFilter.values)
                    DropdownMenuItem<LostSalesStatusFilter?>(
                      value: s,
                      child: Text(_filterLabel(s)),
                    ),
                ],
                onChanged: (value) {
                  setState(() => _status = value);
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
                      '${l10n.reportLostSalesCount}: ${report.requestCount}',
                      style: typography.label,
                    ),
                    Text(
                      '${l10n.reportLostSalesQty}: ${report.totalQuantityRequested}',
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
          child: report == null || report.rows.isEmpty
              ? null
              : AppDataTable(
                  columns: [
                    DataColumn(label: Text(l10n.reportDate)),
                    DataColumn(label: Text(l10n.reportLostSalesItem)),
                    DataColumn(label: Text(l10n.reportLostSalesBarcode)),
                    DataColumn(
                        numeric: true, label: Text(l10n.reportLostSalesQty)),
                    DataColumn(label: Text(l10n.reportLostSalesCustomer)),
                    DataColumn(label: Text(l10n.reportLostSalesStatus)),
                    DataColumn(label: Text(l10n.reportLostSalesNote)),
                  ],
                  rows: [
                    for (final r in report.rows)
                      DataRow(cells: [
                        DataCell(Text(formatReportDate(r.createdAt))),
                        DataCell(Text(r.requestedItemName)),
                        DataCell(Text(r.barcode ?? '')),
                        DataCell(Text('${r.quantityRequested}')),
                        DataCell(Text(r.customerName ?? '')),
                        DataCell(Text(_statusLabel(r.status))),
                        DataCell(Text(r.note ?? '')),
                      ]),
                  ],
                  emptyMessage: l10n.reportNoData,
                ),
        ),
      ),
    );
  }

  String _filterLabel(LostSalesStatusFilter s) {
    final l10n = AppLocalizations.of(context);
    return switch (s) {
      LostSalesStatusFilter.open => l10n.reportLostStatusOpen,
      LostSalesStatusFilter.ordered => l10n.reportLostStatusOrdered,
      LostSalesStatusFilter.resolved => l10n.reportLostStatusResolved,
      LostSalesStatusFilter.cancelled => l10n.reportLostStatusCancelled,
    };
  }

  String _message(Failure? failure) {
    final l10n = AppLocalizations.of(context);
    if (failure is UnauthorizedFailure) return l10n.reportNoPermission;
    return l10n.authSaveError;
  }
}