import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/di/providers.dart';
import '../../../../core/money/money.dart';
import '../../../../core/theme/app_dimensions.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/widgets/app_data_table.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../../shared/models/enums.dart';
import '../../application/accounting_controller.dart';

/// Journal detail page (تفاصيل القيد): header + lines + totals.
class JournalDetailPage extends ConsumerStatefulWidget {
  const JournalDetailPage({super.key, required this.entryId});

  final String entryId;

  @override
  ConsumerState<JournalDetailPage> createState() => _JournalDetailPageState();
}

class _JournalDetailPageState extends ConsumerState<JournalDetailPage> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  Future<void> _load() async {
    await ref
        .read(journalDetailControllerProvider.notifier)
        .load(widget.entryId);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final state = ref.watch(journalDetailControllerProvider);

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.journalDetailTitle),
        actions: [
          IconButton(
            tooltip: l10n.commonRetry,
            onPressed: state.busy ? null : _load,
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: SafeArea(
        child: switch (state.status) {
          JournalDetailViewStatus.initial ||
          JournalDetailViewStatus.loading =>
            const Center(child: CircularProgressIndicator()),
          JournalDetailViewStatus.error => Center(
              child: Padding(
                padding: const EdgeInsets.all(AppSpacing.m),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.error_outline,
                        size: 48,
                        color: Theme.of(context).colorScheme.error),
                    const SizedBox(height: AppSpacing.m),
                    Text(state.error?.message ?? l10n.commonError,
                        textAlign: TextAlign.center),
                    const SizedBox(height: AppSpacing.m),
                    FilledButton.icon(
                      onPressed: _load,
                      icon: const Icon(Icons.refresh),
                      label: Text(l10n.commonRetry),
                    ),
                  ],
                ),
              ),
            ),
          JournalDetailViewStatus.ready => _DetailBody(state: state),
        },
      ),
    );
  }
}

class _DetailBody extends StatelessWidget {
  const _DetailBody({required this.state});

  final JournalDetailViewState state;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final tp = context.appTypography;
    final entry = state.entry!;
    final lines = state.lines;
    final totalDebit = lines.fold<int>(0, (s, l) => s + l.debitMicros);
    final totalCredit = lines.fold<int>(0, (s, l) => s + l.creditMicros);

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(
          AppSpacing.l, AppSpacing.s, AppSpacing.l, AppSpacing.l),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 900),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Header info
              Card(
                elevation: 0,
                child: Padding(
                  padding: const EdgeInsets.all(AppSpacing.m),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Text(
                              '${l10n.journalColEntryNumber}: ${entry.entryNumber}',
                              style: tp.sectionTitle),
                          if (entry.isReversal) ...[
                            const SizedBox(width: AppSpacing.s),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 8, vertical: 2),
                              decoration: BoxDecoration(
                                color: Theme.of(context)
                                    .colorScheme
                                    .error
                                    .withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Text(
                                l10n.journalReversalBadge,
                                style: tp.labelSmall.copyWith(
                                    color:
                                        Theme.of(context).colorScheme.error),
                              ),
                            ),
                          ],
                        ],
                      ),
                      const SizedBox(height: AppSpacing.s),
                      Text(
                        '${l10n.journalColDate}: ${_fmtDate(entry.entryDate)}',
                        style: tp.body,
                      ),
                      const SizedBox(height: AppSpacing.xs),
                      Text(
                        '${l10n.journalColDescription}: ${entry.description}',
                        style: tp.body,
                      ),
                      const SizedBox(height: AppSpacing.xs),
                      Text(
                        '${l10n.journalColRefType}: ${_refTypeLabel(l10n, entry.refType)}',
                        style: tp.body,
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: AppSpacing.m),

              // Lines table
              Card(
                elevation: 0,
                child: Padding(
                  padding: const EdgeInsets.all(AppSpacing.m),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text(l10n.journalDetailLines, style: tp.sectionTitle),
                      const SizedBox(height: AppSpacing.xs),
                      AppDataTable(
                        emptyMessage: l10n.accountsNoData,
                        columns: [
                          DataColumn(label: Text(l10n.accountsColName)),
                          DataColumn(label: Text(l10n.journalColDebit)),
                          DataColumn(label: Text(l10n.journalColCredit)),
                        ],
                        rows: [
                          for (final line in lines)
                            DataRow(cells: [
                              DataCell(Text(
                                  state.accountNames[line.accountId] ??
                                      line.accountId,
                                  style: tp.body)),
                              DataCell(Text(
                                line.debitMicros > 0
                                    ? Money.fromUnits(line.debitMicros)
                                        .formatArabicDigits()
                                    : '-',
                                style: tp.numeric,
                              )),
                              DataCell(Text(
                                line.creditMicros > 0
                                    ? Money.fromUnits(line.creditMicros)
                                        .formatArabicDigits()
                                    : '-',
                                style: tp.numeric,
                              )),
                            ]),
                          // Totals row
                          DataRow(cells: [
                            DataCell(Text(l10n.commonTotal,
                                style: tp.label)),
                            DataCell(Text(
                              Money.fromUnits(totalDebit).formatArabicDigits(),
                              style: tp.numericStrong,
                            )),
                            DataCell(Text(
                              Money.fromUnits(totalCredit).formatArabicDigits(),
                              style: tp.numericStrong,
                            )),
                          ]),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ],
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
