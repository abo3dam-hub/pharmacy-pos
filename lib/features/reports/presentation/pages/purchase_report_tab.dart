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
import '../../../../shared/database/app_database.dart';
import '../../application/reports_controller.dart';
import '../../domain/services/report_export_service.dart';
import '../widgets/report_actions.dart';
import '../widgets/report_page.dart';

/// Purchases report tab (تقارير المشتريات): per-day purchase aggregates with
/// an optional supplier filter. Gated by [Perm.reportsViewPurchases].
class PurchaseReportTab extends ConsumerStatefulWidget {
  const PurchaseReportTab({super.key});

  @override
  ConsumerState<PurchaseReportTab> createState() => _PurchaseReportTabState();
}

class _PurchaseReportTabState extends ConsumerState<PurchaseReportTab> {
  final DateTime _today = DateTime.now();
  late DateTime _from = DateTime(_today.year, 1, 1);
  late DateTime _to = _today;

  List<SupplierRow> _suppliers = const [];
  String? _supplierId;

  @override
  void initState() {
    super.initState();
    Future.microtask(_preload);
    Future.microtask(_load);
  }

  Future<void> _preload() async {
    try {
      final suppliers = await ref.read(supplierDaoProvider).all(activeOnly: true);
      if (!mounted) return;
      setState(() => _suppliers = suppliers);
    } catch (_) {
      // Filter list is best-effort; the report itself still loads.
    }
  }

  Future<void> _load() async {
    await ref.read(purchaseReportControllerProvider.notifier).load(
          from: _from,
          to: _to,
          supplierId: _supplierId,
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
    final report = ref.read(purchaseReportControllerProvider).data;
    if (report == null) return;
    final l10n = AppLocalizations.of(context);
    final request = ReportExportRequest(
      title: l10n.reportPurchases,
      subtitle:
          '${formatReportDate(report.fromMillis)} - ${formatReportDate(report.toMillis)}',
      sheetName: 'purchases',
      generatedAtMillis: DateTime.now().millisecondsSinceEpoch,
      columns: [
        l10n.reportDate,
        l10n.reportPurchasesCount,
        l10n.reportPurchasesSubtotal,
        l10n.reportPurchasesDiscount,
        l10n.reportPurchasesTax,
        l10n.reportPurchasesShipping,
        l10n.reportPurchasesTotal,
        l10n.reportPurchasesPaid,
        l10n.reportPurchasesRemaining,
        l10n.reportPurchasesReturns,
      ],
      rows: [
        for (final d in report.days)
          [
            ReportCell.text(formatReportDate(d.dayMillis)),
            ReportCell.integer(d.invoiceCount),
            ReportCell.money(d.subtotalMicros),
            ReportCell.money(d.discountMicros),
            ReportCell.money(d.taxMicros),
            ReportCell.money(d.shippingMicros),
            ReportCell.money(d.totalMicros),
            ReportCell.money(d.paidMicros),
            ReportCell.money(d.remainingMicros),
            ReportCell.money(d.returnTotalMicros),
          ],
      ],
      totals: [
        ReportTotalRow(
            l10n.reportPurchasesCount, ReportCell.integer(report.invoiceCount)),
        ReportTotalRow(l10n.reportPurchasesTotal, ReportCell.money(report.totalMicros)),
        ReportTotalRow(l10n.reportPurchasesNet, ReportCell.money(report.netTotalMicros)),
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
    final state = ref.watch(purchaseReportControllerProvider);
    final report = state.data;
    final hasPermission = ref
        .watch(authControllerProvider)
        .permissions
        .contains(Perm.reportsViewPurchases);

    return PermissionGate(
      hasPermission: hasPermission,
      child: ReportPage(
        title: l10n.reportPurchases,
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
                initialValue: _supplierId,
                decoration: InputDecoration(
                  labelText: l10n.reportSupplier,
                  isDense: true,
                  border: const OutlineInputBorder(),
                ),
                items: [
                  DropdownMenuItem<String?>(
                    value: null,
                    child: Text(l10n.reportAllSuppliers),
                  ),
                  for (final s in _suppliers)
                    DropdownMenuItem<String?>(
                      value: s.id,
                      child: Text(s.name, overflow: TextOverflow.ellipsis),
                    ),
                ],
                onChanged: (value) {
                  setState(() => _supplierId = value);
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
                      '${l10n.reportPurchasesCount}: ${report.invoiceCount}',
                      style: typography.label,
                    ),
                    Text(
                      '${l10n.reportPurchasesTotal}: '
                      '${Money.fromUnits(report.totalMicros).format()}',
                      style: typography.label,
                    ),
                    Text(
                      '${l10n.reportPurchasesNet}: '
                      '${Money.fromUnits(report.netTotalMicros).format()}',
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
                    DataColumn(
                        numeric: true, label: Text(l10n.reportPurchasesCount)),
                    DataColumn(
                        numeric: true, label: Text(l10n.reportPurchasesSubtotal)),
                    DataColumn(
                        numeric: true, label: Text(l10n.reportPurchasesDiscount)),
                    DataColumn(
                        numeric: true, label: Text(l10n.reportPurchasesTax)),
                    DataColumn(
                        numeric: true, label: Text(l10n.reportPurchasesShipping)),
                    DataColumn(
                        numeric: true, label: Text(l10n.reportPurchasesTotal)),
                    DataColumn(
                        numeric: true, label: Text(l10n.reportPurchasesPaid)),
                    DataColumn(
                        numeric: true, label: Text(l10n.reportPurchasesRemaining)),
                    DataColumn(
                        numeric: true, label: Text(l10n.reportPurchasesReturns)),
                  ],
                  rows: [
                    for (final d in report.days)
                      DataRow(cells: [
                        DataCell(Text(formatReportDate(d.dayMillis))),
                        DataCell(Text('${d.invoiceCount}')),
                        DataCell(Text(Money.fromUnits(d.subtotalMicros).format())),
                        DataCell(Text(Money.fromUnits(d.discountMicros).format())),
                        DataCell(Text(Money.fromUnits(d.taxMicros).format())),
                        DataCell(Text(Money.fromUnits(d.shippingMicros).format())),
                        DataCell(Text(Money.fromUnits(d.totalMicros).format())),
                        DataCell(Text(Money.fromUnits(d.paidMicros).format())),
                        DataCell(Text(Money.fromUnits(d.remainingMicros).format())),
                        DataCell(Text(Money.fromUnits(d.returnTotalMicros).format())),
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