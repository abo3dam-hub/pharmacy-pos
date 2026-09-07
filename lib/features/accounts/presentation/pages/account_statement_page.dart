import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/di/providers.dart';
import '../../../../core/money/money.dart';
import '../../../../core/theme/app_dimensions.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/widgets/app_data_table.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../../shared/models/enums.dart';
import '../../../../features/reports/domain/services/report_export_service.dart';
import '../../../../features/reports/domain/services/statement_export.dart';
import '../../../../features/reports/presentation/widgets/report_actions.dart';
import '../../application/accounting_controller.dart';

/// Account Statement page (كشف حساب): select account, view statement lines.
class AccountStatementPage extends ConsumerStatefulWidget {
  const AccountStatementPage({super.key});

  @override
  ConsumerState<AccountStatementPage> createState() =>
      _AccountStatementPageState();
}

class _AccountStatementPageState extends ConsumerState<AccountStatementPage> {
  String? _selectedAccountId;
  DateTime? _from;
  DateTime? _to;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadAccounts());
  }

  Future<void> _loadAccounts() async {
    await ref.read(accountsControllerProvider.notifier).load();
  }

  Future<void> _loadStatement() async {
    if (_selectedAccountId == null) return;
    await ref
        .read(accountStatementControllerProvider.notifier)
        .loadForAccount(_selectedAccountId!);
  }

  Future<void> _pickDate({required bool isFrom}) async {
    final picked = await showDatePicker(
      context: context,
      initialDate: isFrom ? _from ?? DateTime.now() : _to ?? DateTime.now(),
      firstDate: DateTime(2020),
      lastDate: DateTime(2030),
    );
    if (picked == null) return;
    setState(() {
      if (isFrom) {
        _from = picked;
      } else {
        _to = picked.add(const Duration(days: 1));
      }
    });
    await _loadStatement();
  }

  Future<void> _export({required bool asPdf}) async {
    final state = ref.read(accountStatementControllerProvider);
    if (state.status != AccountStatementViewStatus.ready ||
        state.lines.isEmpty) {
      return;
    }
    final l10n = AppLocalizations.of(context);
    final request = StatementExport.account(
      title: '${state.accountName ?? state.accountId} - ${l10n.accountStatementTitle}',
      subtitle: '${_fmtDate(_from?.millisecondsSinceEpoch ?? 0)} - '
          '${_fmtDate(_to?.millisecondsSinceEpoch ?? DateTime.now().millisecondsSinceEpoch)}',
      generatedAtMillis: DateTime.now().millisecondsSinceEpoch,
      lines: state.lines,
      openingBalanceMicros: state.openingBalanceMicros,
      totalDebitMicros: state.totalDebitMicros,
      totalCreditMicros: state.totalCreditMicros,
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
    final accountsState = ref.watch(accountsControllerProvider);
    final statementState = ref.watch(accountStatementControllerProvider);

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.accountStatementTitle),
        actions: [
          IconButton(
            tooltip: l10n.commonRetry,
            onPressed: _loadStatement,
            icon: const Icon(Icons.refresh),
          ),
          IconButton(
            tooltip: l10n.commonPrint,
            onPressed: () => _export(asPdf: true),
            icon: const Icon(Icons.print_outlined),
          ),
          IconButton(
            tooltip: l10n.reportExportExcel,
            onPressed: () => _export(asPdf: false),
            icon: const Icon(Icons.download_outlined),
          ),
        ],
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(
              AppSpacing.l, AppSpacing.s, AppSpacing.l, AppSpacing.l),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 1000),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Account selector + date range
                  Card(
                    elevation: 0,
                    child: Padding(
                      padding: const EdgeInsets.all(AppSpacing.m),
                      child: Wrap(
                        spacing: AppSpacing.m,
                        runSpacing: AppSpacing.s,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: [
                          SizedBox(
                            width: 300,
                            child: DropdownButtonFormField<String>(
                              initialValue: _selectedAccountId,
                              decoration: InputDecoration(
                                labelText: l10n.accountsColName,
                                border: const OutlineInputBorder(),
                                isDense: true,
                              ),
                              items: accountsState.accounts
                                  .map((a) => DropdownMenuItem(
                                        value: a.id,
                                        child: Text('${a.code} - ${a.name}'),
                                      ))
                                  .toList(),
                              onChanged: (v) async {
                                setState(() => _selectedAccountId = v);
                                if (v != null) await _loadStatement();
                              },
                            ),
                          ),
                          OutlinedButton.icon(
                            onPressed: () => _pickDate(isFrom: true),
                            icon: const Icon(Icons.calendar_today, size: 16),
                            label: Text(_from != null
                                ? _fmtDate(_from!.millisecondsSinceEpoch)
                                : l10n.accountStatementFromDate),
                          ),
                          OutlinedButton.icon(
                            onPressed: () => _pickDate(isFrom: false),
                            icon: const Icon(Icons.calendar_today, size: 16),
                            label: Text(_to != null
                                ? _fmtDate(_to!.millisecondsSinceEpoch)
                                : l10n.accountStatementToDate),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: AppSpacing.m),

                  // Statement lines
                  if (statementState.status ==
                      AccountStatementViewStatus.loading)
                    const Center(child: CircularProgressIndicator())
                  else if (statementState.status ==
                      AccountStatementViewStatus.error)
                    Center(
                      child: Text(
                          statementState.error?.message ?? l10n.commonError),
                    )
                  else if (statementState.lines.isNotEmpty) ...[
                    // Account name header
                    if (statementState.accountName != null)
                      Padding(
                        padding: const EdgeInsets.only(bottom: AppSpacing.s),
                        child: Text(
                          statementState.accountName!,
                          style: context.appTypography.sectionTitle,
                        ),
                      ),
                    AppDataTable(
                      emptyMessage: l10n.accountsNoData,
                      columns: [
                        DataColumn(label: Text(l10n.journalColEntryNumber)),
                        DataColumn(label: Text(l10n.journalColDate)),
                        DataColumn(label: Text(l10n.journalColDescription)),
                        DataColumn(label: Text(l10n.journalColDebit)),
                        DataColumn(label: Text(l10n.journalColCredit)),
                        DataColumn(label: Text(l10n.statementBalance)),
                      ],
                      rows: [
                        for (final line in statementState.lines)
                          DataRow(cells: [
                            DataCell(Text(line.entryNumber,
                                style: context.appTypography.numeric)),
                            DataCell(Text(_fmtDate(line.entryDate),
                                style: context.appTypography.body)),
                            DataCell(Text(
                                '${_refTypeLabel(l10n, line.refType)} - ${line.description}',
                                style: context.appTypography.body)),
                            DataCell(Text(
                              line.debitMicros > 0
                                  ? Money.fromUnits(line.debitMicros)
                                      .formatArabicDigits()
                                  : '-',
                              style: context.appTypography.numeric,
                            )),
                            DataCell(Text(
                              line.creditMicros > 0
                                  ? Money.fromUnits(line.creditMicros)
                                      .formatArabicDigits()
                                  : '-',
                              style: context.appTypography.numeric,
                            )),
                            DataCell(Text(
                              Money.fromUnits(
                                      line.runningBalanceMicros ?? 0)
                                  .formatArabicDigits(),
                              style: context.appTypography.numeric,
                            )),
                          ]),
                      ],
                    ),
                    const SizedBox(height: AppSpacing.m),
                    // Totals and closing balance
                    Card(
                      elevation: 0,
                      child: Padding(
                        padding: const EdgeInsets.all(AppSpacing.m),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(l10n.statementOpening,
                                    style: context.appTypography.body),
                                Text(
                                  Money.fromUnits(
                                          statementState.openingBalanceMicros)
                                      .formatArabicDigits(),
                                  style: context.appTypography.numeric,
                                ),
                              ],
                            ),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(l10n.journalColDebit,
                                    style: context.appTypography.body),
                                Text(
                                  Money.fromUnits(
                                          statementState.totalDebitMicros)
                                      .formatArabicDigits(),
                                  style: context.appTypography.numericStrong,
                                ),
                              ],
                            ),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(l10n.journalColCredit,
                                    style: context.appTypography.body),
                                Text(
                                  Money.fromUnits(
                                          statementState.totalCreditMicros)
                                      .formatArabicDigits(),
                                  style: context.appTypography.numericStrong,
                                ),
                              ],
                            ),
                            const Divider(),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(l10n.accountStatementClosingBalance,
                                    style: context.appTypography.label),
                                Text(
                                  Money.fromUnits(
                                          statementState.closingBalanceMicros)
                                      .formatArabicDigits(),
                                  style: context.appTypography.numericStrong,
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                  ] else if (statementState.status ==
                      AccountStatementViewStatus.ready)
                    Center(
                      child: Padding(
                        padding: const EdgeInsets.all(AppSpacing.xxl),
                        child: Text(
                          _selectedAccountId == null
                              ? l10n.accountStatementSelectAccount
                              : l10n.accountsNoData,
                          style: context.appTypography.body,
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  static String _fmtDate(int millis) {
    final d = DateTime.fromMillisecondsSinceEpoch(millis);
    return '${d.year}-${d.month.toString().padLeft(2, '0')}-'
        '${d.day.toString().padLeft(2, '0')}';
  }

  static String _refTypeLabel(AppLocalizations l10n, JournalReferenceType type) =>
      switch (type) {
        JournalReferenceType.sale => l10n.refTypeSale,
        JournalReferenceType.purchase => l10n.refTypePurchase,
        JournalReferenceType.return_invoice => l10n.refTypeReturn,
        JournalReferenceType.expense => l10n.refTypeExpense,
        JournalReferenceType.cashbox => l10n.refTypeCashbox,
        JournalReferenceType.opening_balance => l10n.refTypeOpeningBalance,
        JournalReferenceType.adjustment => l10n.refTypeAdjustment,
        JournalReferenceType.manual => l10n.refTypeManual,
        JournalReferenceType.customer_payment => l10n.refTypeCustomerPayment,
      };
}
