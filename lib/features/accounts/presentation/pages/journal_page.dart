import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/di/providers.dart';
import '../../../../core/money/money.dart';
import '../../../../core/theme/app_dimensions.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/widgets/app_data_table.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../../shared/database/app_database.dart';
import '../../../../shared/models/enums.dart';
import '../../application/accounting_controller.dart';

/// Journal page (دفتر اليومية): paged table of journal entries with refType filter.
class JournalPage extends ConsumerStatefulWidget {
  const JournalPage({super.key});

  @override
  ConsumerState<JournalPage> createState() => _JournalPageState();
}

class _JournalPageState extends ConsumerState<JournalPage> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  Future<void> _load() async {
    await ref.read(journalControllerProvider.notifier).load();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final state = ref.watch(journalControllerProvider);

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.journalTitle),
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
          JournalViewStatus.initial ||
          JournalViewStatus.loading =>
            const Center(child: CircularProgressIndicator()),
          JournalViewStatus.error => Center(
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
          JournalViewStatus.ready => _JournalBody(
              state: state,
              onFilterChanged: (t) => ref
                  .read(journalControllerProvider.notifier)
                  .setRefTypeFilter(t),
              onLoadMore: () =>
                  ref.read(journalControllerProvider.notifier).loadMore(),
              onEntryTap: (id) => context.push('/accounts/journal/detail/$id'),
            ),
        },
      ),
    );
  }
}

class _JournalBody extends StatelessWidget {
  const _JournalBody({
    required this.state,
    required this.onFilterChanged,
    required this.onLoadMore,
    required this.onEntryTap,
  });

  final JournalViewState state;
  final ValueChanged<JournalReferenceType?> onFilterChanged;
  final VoidCallback onLoadMore;
  final ValueChanged<String> onEntryTap;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final tp = context.appTypography;
    final items = state.entries?.items ?? const <JournalEntryRow>[];

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(
          AppSpacing.l, AppSpacing.s, AppSpacing.l, AppSpacing.l),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1000),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Filter
              Row(
                children: [
                  Text(l10n.journalFilterRefType, style: tp.body),
                  const SizedBox(width: AppSpacing.s),
                  DropdownButton<JournalReferenceType?>(
                    value: state.refTypeFilter,
                    hint: Text(l10n.journalFilterRefType),
                    items: [
                      DropdownMenuItem<JournalReferenceType?>(
                        value: null,
                        child: Text(l10n.accountsFilterAll),
                      ),
                      for (final type in JournalReferenceType.values)
                        DropdownMenuItem<JournalReferenceType?>(
                          value: type,
                          child: Text(_refTypeLabel(l10n, type)),
                        ),
                    ],
                    onChanged: onFilterChanged,
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.m),

              // Table
              AppDataTable(
                emptyMessage: l10n.accountsNoData,
                columns: [
                  DataColumn(label: Text(l10n.journalColEntryNumber)),
                  DataColumn(label: Text(l10n.journalColDate)),
                  DataColumn(label: Text(l10n.journalColDescription)),
                  DataColumn(label: Text(l10n.journalColRefType)),
                  DataColumn(label: Text(l10n.journalColDebit)),
                  DataColumn(label: Text(l10n.journalColCredit)),
                ],
                rows: [
                  for (final entry in items)
                    DataRow(
                      onSelectChanged: (_) => onEntryTap(entry.id),
                      cells: [
                        DataCell(Text(entry.entryNumber, style: tp.numeric)),
                        DataCell(Text(_fmtDate(entry.entryDate), style: tp.body)),
                        DataCell(
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              if (entry.isReversal) ...[
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 6, vertical: 2),
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
                                        color: Theme.of(context)
                                            .colorScheme
                                            .error),
                                  ),
                                ),
                                const SizedBox(width: AppSpacing.xs),
                              ],
                              Flexible(
                                child: Text(entry.description,
                                    style: tp.body,
                                    overflow: TextOverflow.ellipsis),
                              ),
                            ],
                          ),
                        ),
                        DataCell(Text(
                            _refTypeLabel(l10n, entry.refType),
                            style: tp.body)),
                        DataCell(Text(
                          entry.totalDebitMicros > 0
                              ? Money.fromUnits(entry.totalDebitMicros)
                                  .formatArabicDigits()
                              : '-',
                          style: tp.numeric,
                        )),
                        DataCell(Text(
                          entry.totalCreditMicros > 0
                              ? Money.fromUnits(entry.totalCreditMicros)
                                  .formatArabicDigits()
                              : '-',
                          style: tp.numeric,
                        )),
                      ],
                    ),
                ],
              ),

              if (state.entries != null && state.entries!.hasMore) ...[
                const SizedBox(height: AppSpacing.s),
                Center(
                  child: OutlinedButton.icon(
                    onPressed: onLoadMore,
                    icon: const Icon(Icons.more_horiz),
                    label: Text(l10n.commonNext),
                  ),
                ),
              ],
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
