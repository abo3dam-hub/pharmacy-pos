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
import '../../../../shared/models/enums.dart';
import '../../application/reports_controller.dart';
import '../../domain/services/report_export_service.dart';
import '../widgets/report_actions.dart';
import '../widgets/report_page.dart';

/// Inventory report tab (تقارير المخزون): current stock valuation plus a
/// movement-type summary for the selected window. Gated by
/// [Perm.reportsViewInventory].
class InventoryReportTab extends ConsumerStatefulWidget {
  const InventoryReportTab({super.key});

  @override
  ConsumerState<InventoryReportTab> createState() => _InventoryReportTabState();
}

class _InventoryReportTabState extends ConsumerState<InventoryReportTab> {
  final DateTime _today = DateTime.now();
  late DateTime _from = DateTime(_today.year, 1, 1);
  late DateTime _to = _today;

  @override
  void initState() {
    super.initState();
    Future.microtask(_load);
  }

  Future<void> _load() async {
    await ref.read(inventoryReportControllerProvider.notifier).load(
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
    final report = ref.read(inventoryReportControllerProvider).data;
    if (report == null) return;
    final l10n = AppLocalizations.of(context);
    final request = ReportExportRequest(
      title: l10n.reportInventory,
      subtitle:
          '${formatReportDate(report.fromMillis)} - ${formatReportDate(report.toMillis)}',
      sheetName: 'inventory',
      generatedAtMillis: DateTime.now().millisecondsSinceEpoch,
      columns: [
        l10n.reportInventoryItemCode,
        l10n.reportInventoryItemName,
        l10n.reportInventoryCurrentStock,
        l10n.reportInventoryMin,
        l10n.reportInventoryMax,
        l10n.reportInventoryUnitCost,
        l10n.reportInventoryValue,
      ],
      rows: [
        for (final i in report.items)
          [
            ReportCell.text(i.barcode ?? ''),
            ReportCell.text(i.name),
            ReportCell.integer(i.currentStockBase),
            ReportCell.integer(i.minimumStockBase),
            ReportCell.integer(i.maximumStockBase),
            ReportCell.money(i.unitCostMicros),
            ReportCell.money(i.stockValueMicros),
          ],
      ],
      totals: [
        ReportTotalRow(l10n.reportInventoryTotalStock,
            ReportCell.integer(report.totalStockBase)),
        ReportTotalRow(
            l10n.reportInventoryValue, ReportCell.money(report.stockValueMicros)),
        ReportTotalRow(
            l10n.reportInventoryLowStock, ReportCell.integer(report.lowStockCount)),
        ReportTotalRow(l10n.reportInventoryOutOfStock,
            ReportCell.integer(report.outOfStockCount)),
      ],
    );
    const service = ReportExportService();
    if (asPdf) {
      await printReportPdf(context, service, request);
    } else {
      await saveReportExcel(context, service, request);
    }
  }

  String _movementLabel(MovementType type) {
    final l10n = AppLocalizations.of(context);
    return switch (type) {
      MovementType.opening_balance => l10n.moveOpening,
      MovementType.purchase => l10n.movePurchase,
      MovementType.sale => l10n.moveSale,
      MovementType.sale_return => l10n.moveSaleReturn,
      MovementType.purchase_return => l10n.movePurchaseReturn,
      MovementType.stock_adjustment => l10n.moveAdjustment,
      MovementType.damaged => l10n.moveDamaged,
      MovementType.expired => l10n.moveExpired,
      MovementType.transfer => l10n.moveTransfer,
      MovementType.manual_correction => l10n.moveCorrection,
    };
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final typography = context.appTypography;
    final state = ref.watch(inventoryReportControllerProvider);
    final report = state.data;
    final hasPermission = ref
        .watch(authControllerProvider)
        .permissions
        .contains(Perm.reportsViewInventory);

    return PermissionGate(
      hasPermission: hasPermission,
      child: ReportPage(
        title: l10n.reportInventory,
        filters: ReportFilterBar(
          fromLabel: '${l10n.reportFromDate} ${formatReportDate(reportDayMillis(_from))}',
          toLabel: '${l10n.reportToDate} ${formatReportDate(reportDayMillis(_to))}',
          onPickFrom: () => _pickDate(from: true),
          onPickTo: () => _pickDate(from: false),
          onRefresh: _load,
          onPrint: () => _export(asPdf: true),
          onExportExcel: () => _export(asPdf: false),
          exportEnabled: report != null && report.items.isNotEmpty,
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
                      '${l10n.reportInventoryCount}: ${report.itemCount} · '
                      '${l10n.reportInventoryTotalStock}: ${report.totalStockBase}',
                      style: typography.label,
                    ),
                    Text(
                      '${l10n.reportInventoryValue}: '
                      '${Money.fromUnits(report.stockValueMicros).format()}',
                      style: typography.numericStrong,
                    ),
                    Text(
                      '${l10n.reportInventoryLowStock}: ${report.lowStockCount}',
                      style: typography.label,
                    ),
                    Text(
                      '${l10n.reportInventoryOutOfStock}: ${report.outOfStockCount}',
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
              : SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Padding(
                        padding: const EdgeInsets.fromLTRB(
                            AppSpacing.xxl, AppSpacing.s, AppSpacing.xxl, AppSpacing.s),
                        child: Text(l10n.reportInventoryItemName,
                            style: typography.label),
                      ),
                      AppDataTable(
                        columns: [
                          DataColumn(
                              label: Text(l10n.reportInventoryItemCode)),
                          DataColumn(
                              label: Text(l10n.reportInventoryItemName)),
                          DataColumn(
                              numeric: true,
                              label: Text(l10n.reportInventoryCurrentStock)),
                          DataColumn(
                              numeric: true,
                              label: Text(l10n.reportInventoryMin)),
                          DataColumn(
                              numeric: true,
                              label: Text(l10n.reportInventoryMax)),
                          DataColumn(
                              numeric: true,
                              label: Text(l10n.reportInventoryUnitCost)),
                          DataColumn(
                              numeric: true,
                              label: Text(l10n.reportInventoryValue)),
                        ],
                        rows: [
                          for (final i in report.items)
                            DataRow(cells: [
                              DataCell(Text(i.barcode ?? '')),
                              DataCell(Text(i.name)),
                              DataCell(Text('${i.currentStockBase}')),
                              DataCell(Text('${i.minimumStockBase}')),
                              DataCell(Text('${i.maximumStockBase}')),
                              DataCell(Text(Money.fromUnits(i.unitCostMicros).format())),
                              DataCell(Text(
                                Money.fromUnits(i.stockValueMicros).format(),
                                style: typography.numericStrong,
                              )),
                            ]),
                        ],
                        emptyMessage: l10n.reportNoData,
                      ),
                      Padding(
                        padding: const EdgeInsets.fromLTRB(AppSpacing.xxl,
                            AppSpacing.l, AppSpacing.xxl, AppSpacing.s),
                        child: Text(l10n.reportInventoryMovement,
                            style: typography.label),
                      ),
                      if (report.movements.isEmpty)
                        Padding(
                          padding: const EdgeInsets.all(AppSpacing.xl),
                          child: Text(l10n.reportNoData,
                              style: typography.labelSmall),
                        )
                      else
                        AppDataTable(
                          columns: [
                            DataColumn(label: Text(l10n.reportMovementType)),
                            DataColumn(
                                numeric: true,
                                label: Text(l10n.reportMovementCount)),
                            DataColumn(
                                numeric: true, label: Text(l10n.reportMovementQty)),
                            DataColumn(
                                numeric: true, label: Text(l10n.reportMovementTotal)),
                          ],
                          rows: [
                            for (final m in report.movements)
                              DataRow(cells: [
                                DataCell(Text(_movementLabel(m.movementType))),
                                DataCell(Text('${m.movementCount}')),
                                DataCell(Text('${m.quantityBaseSigned}')),
                                DataCell(Text(Money.fromUnits(m.totalMicros).format())),
                              ]),
                          ],
                          emptyMessage: l10n.reportNoData,
                        ),
                    ],
                  ),
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