import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/constants/permission_codes.dart';
import '../../../../core/di/providers.dart';
import '../../../../core/errors/failures.dart';
import '../../../../core/money/money.dart';
import '../../../../core/theme/app_dimensions.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/widgets/app_data_table.dart';
import '../../../../data/daos/supplier_dao.dart';
import '../../../../features/suppliers/domain/repositories/supplier_repository.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../../shared/database/app_database.dart';
import '../../domain/services/report_export_service.dart';
import '../../domain/services/statement_export.dart';
import '../widgets/report_actions.dart';
import '../widgets/report_page.dart';

/// Supplier statement tab inside the Reports hub (كشف حساب مورد). Reuses the
/// supplier repository's statement projection with the full-range export path
/// so the hub never touches the Suppliers page's own statement state.
/// Gated by [Perm.suppliersView] + [Perm.reportsViewPurchases].
class SupplierStatementTab extends ConsumerStatefulWidget {
  const SupplierStatementTab({super.key});

  @override
  ConsumerState<SupplierStatementTab> createState() =>
      _SupplierStatementTabState();
}

class _SupplierStatementTabState extends ConsumerState<SupplierStatementTab> {
  final DateTime _today = DateTime.now();
  late DateTime _from = DateTime(_today.year, 1, 1);
  late DateTime _to = _today;

  List<SupplierRow> _suppliers = const [];
  String? _supplierId;
  SupplierStatementPage? _statement;
  bool _loading = false;
  Failure? _error;

  String? get _actingRoleId => ref.read(authControllerProvider).actingRoleId;

  @override
  void initState() {
    super.initState();
    Future.microtask(_preload);
  }

  Future<void> _preload() async {
    try {
      final suppliers =
          await ref.read(supplierDaoProvider).all(activeOnly: true);
      if (!mounted) return;
      setState(() => _suppliers = suppliers);
    } catch (_) {
      // The picker is best-effort; a permission failure surfaces on load.
    }
  }

  Future<void> _load({String? supplierId}) async {
    final id = supplierId ?? _supplierId;
    if (id == null) return;
    setState(() {
      _loading = true;
      _error = null;
    });
    final page = await ref
        .read(suppliersControllerProvider.notifier)
        .statementForExport(
          id,
          fromDate: reportDayMillis(_from),
          toDate: reportDayMillis(_to),
          actingRoleId: _actingRoleId,
        );
    if (!mounted) return;
    setState(() {
      _statement = page;
      _loading = false;
      if (page == null) {
        _error = const UnauthorizedFailure();
      }
    });
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
    final statement = _statement;
    if (statement == null) return;
    final l10n = AppLocalizations.of(context);
    final request = StatementExport.supplier(
      title: '${statement.supplierName} - ${l10n.reportSupplierStatement}',
      subtitle:
          '${formatReportDate(reportDayMillis(_from))} - ${formatReportDate(reportDayMillis(_to))}',
      generatedAtMillis: DateTime.now().millisecondsSinceEpoch,
      rows: statement.entries,
      openingMicros: statement.totals.openingMicros,
      debitTotalMicros: statement.totals.debitTotalMicros,
      creditTotalMicros: statement.totals.creditTotalMicros,
      closingMicros: statement.totals.closingMicros,
    );
    const service = ReportExportService();
    if (asPdf) {
      await printReportPdf(context, service, request);
    } else {
      await saveReportExcel(context, service, request);
    }
  }

  String _docLabel(AppLocalizations l10n, SupplierStatementEntry e) {
    return switch (e.docType) {
      'opening' => l10n.statementOpening,
      'purchase_invoice' => l10n.statementRowInvoice(e.refNo),
      'purchase_return' => l10n.statementRowReturn(e.refNo),
      _ => e.refNo,
    };
  }

  String _message() {
    final l10n = AppLocalizations.of(context);
    if (_error is UnauthorizedFailure) return l10n.reportNoPermission;
    return l10n.authSaveError;
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final typography = context.appTypography;
    final permissions = ref.watch(authControllerProvider).permissions;
    final hasPermission = permissions.contains(Perm.suppliersView) &&
        permissions.contains(Perm.reportsViewPurchases);
    final statement = _statement;
    final totals = statement?.totals;

    return PermissionGate(
      hasPermission: hasPermission,
      child: ReportPage(
        title: l10n.reportSupplierStatement,
        filters: ReportFilterBar(
          fromLabel: '${l10n.reportFromDate} ${formatReportDate(reportDayMillis(_from))}',
          toLabel: '${l10n.reportToDate} ${formatReportDate(reportDayMillis(_to))}',
          onPickFrom: () => _pickDate(from: true),
          onPickTo: () => _pickDate(from: false),
          onRefresh: () => _load(),
          onPrint: () => _export(asPdf: true),
          onExportExcel: () => _export(asPdf: false),
          exportEnabled: statement != null && statement.entries.isNotEmpty,
          extra: [
            SizedBox(
              width: 220,
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
                    child: Text(l10n.reportSelectEntity),
                  ),
                  for (final s in _suppliers)
                    DropdownMenuItem<String?>(
                      value: s.id,
                      child: Text(s.name, overflow: TextOverflow.ellipsis),
                    ),
                ],
                onChanged: (value) {
                  setState(() => _supplierId = value);
                  _load(supplierId: value);
                },
              ),
            ),
          ],
        ),
        loading: _loading,
        footer: totals == null
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
              ),
        body: ReportBody(
          loading: _loading,
          error: _error,
          errorMessage: _error == null ? null : _message(),
          emptyMessage: _supplierId == null
              ? l10n.reportSelectEntity
              : l10n.reportNoData,
          child: statement == null || statement.entries.isEmpty
              ? null
              : AppDataTable(
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
                        DataCell(Text(e.docType == 'opening'
                            ? ''
                            : formatReportDate(e.date))),
                        DataCell(Text(_docLabel(l10n, e))),
                        DataCell(Text(e.debitMicros == 0
                            ? ''
                            : Money.fromUnits(e.debitMicros).format())),
                        DataCell(Text(e.creditMicros == 0
                            ? ''
                            : Money.fromUnits(e.creditMicros).format())),
                        DataCell(Text(
                          Money.fromUnits(e.balanceMicros).format(),
                          style: typography.numericStrong,
                        )),
                      ]),
                  ],
                  emptyMessage: l10n.reportNoData,
                ),
        ),
      ),
    );
  }
}