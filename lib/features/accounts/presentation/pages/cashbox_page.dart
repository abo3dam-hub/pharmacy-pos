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
import '../../application/cashbox_controller.dart';
import '../../domain/entities/cashbox_session.dart';
import '../widgets/cashbox_dialogs.dart';

/// Phase 8 Cash Box (الصندوق): drawer dashboard — open/close sessions,
/// deposits/withdrawals, live reconciliation (`expected = opening + net moves`)
/// and the paged ledger history. Requires `cashbox.view` to open (router
/// redirect) and `cashbox.operate` for every mutation.
class CashboxPage extends ConsumerStatefulWidget {
  const CashboxPage({super.key});

  @override
  ConsumerState<CashboxPage> createState() => _CashboxPageState();
}

class _CashboxPageState extends ConsumerState<CashboxPage> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  Future<void> _load() async {
    final userId = ref.read(authControllerProvider).user?.id;
    if (userId == null) return;
    await ref.read(cashboxControllerProvider.notifier).load(userId: userId);
  }

  Future<void> _reload() async {
    await ref.read(cashboxControllerProvider.notifier).reload();
  }

  void _showFailure(Failure? failure) {
    if (failure == null || !mounted) return;
    final l10n = AppLocalizations.of(context);
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(
          content: Text(
              failure.message.isEmpty ? l10n.commonError : failure.message)));
  }

  void _runMutation(Future<Failure?> Function() action) async {
    final failure = await action();
    if (failure == null) {
      await _reload();
    } else {
      _showFailure(failure);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final state = ref.watch(cashboxControllerProvider);
    final auth = ref.watch(authControllerProvider);

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.cashboxTitle),
        actions: [
          IconButton(
            tooltip: l10n.commonRetry,
            onPressed: state.busy ? null : _reload,
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: SafeArea(
        child: switch (state.status) {
          CashboxViewStatus.initial ||
          CashboxViewStatus.loading =>
            const Center(child: CircularProgressIndicator()),
          CashboxViewStatus.error => _ErrorPane(
              message: state.error?.message ?? l10n.commonError,
              onRetry: _load,
            ),
          CashboxViewStatus.ready => _CashboxBody(
              view: state,
              canOperate: auth.permissions.contains(Perm.cashboxOperate),
              onMutate: _runMutation,
            ),
        },
      ),
    );
  }
}

class _CashboxBody extends StatelessWidget {
  const _CashboxBody({
    required this.view,
    required this.canOperate,
    required this.onMutate,
  });

  final CashboxViewState view;
  final bool canOperate;
  final void Function(Future<Failure?> Function() action) onMutate;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final session = view.session;
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(
          AppSpacing.l, AppSpacing.s, AppSpacing.l, AppSpacing.l),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 900),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _ActionBar(
                session: session,
                canOperate: canOperate,
                onMutate: onMutate,
              ),
              const SizedBox(height: AppSpacing.m),
              if (session == null ||
                  session.status == CashboxStatus.notOpened)
                _NotOpenedCard(canOperate: canOperate)
              else
                _SessionCard(session: session),
              const SizedBox(height: AppSpacing.m),
              _HistoryCard(view: view),
              if (!canOperate)
                Padding(
                  padding: const EdgeInsets.only(top: AppSpacing.m),
                  child: Text(
                    l10n.cashboxReadOnly,
                    style: context.appTypography.body,
                    textAlign: TextAlign.center,
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Row of operational buttons: Open (غير مفتوح/مقفل) or Close / Deposit /
/// Withdraw / Adjust (جلسة مفتوحة). Mutations run through the shared
/// [onMutate] bridge so the page stays in control of refresh + error display.
class _ActionBar extends ConsumerWidget {
  const _ActionBar({
    required this.session,
    required this.canOperate,
    required this.onMutate,
  });

  final CashboxSession? session;
  final bool canOperate;
  final void Function(Future<Failure?> Function() action) onMutate;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final open = session?.status == CashboxStatus.open;

    return Wrap(
      spacing: AppSpacing.s,
      runSpacing: AppSpacing.s,
      children: [
        if (!open) ...[
          if (canOperate)
            FilledButton.icon(
              onPressed: () => onMutate(() => _open(ref, context)),
              icon: const Icon(Icons.lock_open_outlined),
              label: Text(l10n.cashboxActionOpen),
            ),
        ] else ...[
          if (canOperate)
            FilledButton.icon(
              onPressed: () => onMutate(() => _close(ref, context)),
              icon: const Icon(Icons.lock_outline),
              label: Text(l10n.cashboxActionClose),
            ),
          if (canOperate)
            OutlinedButton.icon(
              onPressed: () => onMutate(
                      () => _move(ref, context, isDeposit: true)),
              icon: const Icon(Icons.south_west),
              label: Text(l10n.cashboxActionDeposit),
            ),
          if (canOperate)
            OutlinedButton.icon(
              onPressed: () => onMutate(
                      () => _move(ref, context, isDeposit: false)),
              icon: const Icon(Icons.north_east),
              label: Text(l10n.cashboxActionWithdraw),
            ),
          if (canOperate)
            OutlinedButton.icon(
              onPressed: () => onMutate(() => _adjust(ref, context)),
              icon: const Icon(Icons.balance),
              label: Text(l10n.cashboxActionAdjust),
            ),
        ],
      ],
    );
  }

  Future<Failure?> _open(WidgetRef ref, BuildContext context) async {
    final result = await showCashboxOpenDialog(context);
    if (result == null) return null;
    final userId = _userId(ref);
    if (userId == null) return null;
    return ref.read(cashboxControllerProvider.notifier).open(
          openingMicros: result.openingMicros,
          userId: userId,
          note: result.note,
        );
  }

  Future<Failure?> _close(WidgetRef ref, BuildContext context) async {
    final expected = session?.expectedClosingMicros ?? 0;
    final result =
        await showCashboxCloseDialog(context, expectedClosingMicros: expected);
    if (result == null) return null;
    final userId = _userId(ref);
    if (userId == null) return null;
    return ref.read(cashboxControllerProvider.notifier).close(
          declaredCloseMicros: result.declaredCloseMicros,
          userId: userId,
          reason: result.reason,
        );
  }

  Future<Failure?> _move(
      WidgetRef ref, BuildContext context, {required bool isDeposit}) async {
    final result = await showCashboxMoveDialog(context, isDeposit: isDeposit);
    if (result == null) return null;
    final userId = _userId(ref);
    if (userId == null) return null;
    final controller = ref.read(cashboxControllerProvider.notifier);
    return isDeposit
        ? controller.deposit(
            amountMicros: result.amountMicros, userId: userId, reason: result.reason)
        : controller.withdraw(
            amountMicros: result.amountMicros, userId: userId, reason: result.reason);
  }

  Future<Failure?> _adjust(WidgetRef ref, BuildContext context) async {
    final expected = session?.expectedClosingMicros ?? 0;
    final result =
        await showCashboxAdjustDialog(context, expectedClosingMicros: expected);
    if (result == null) return null;
    final userId = _userId(ref);
    if (userId == null) return null;
    return ref.read(cashboxControllerProvider.notifier).adjust(
          amountMicros: result.signedMicros,
          userId: userId,
          reason: result.reason,
        );
  }

  static String? _userId(WidgetRef ref) =>
      ref.read(authControllerProvider).user?.id;
}

class _NotOpenedCard extends StatelessWidget {
  const _NotOpenedCard({required this.canOperate});

  final bool canOperate;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Card(
      elevation: 0,
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.m),
        child: Column(
          children: [
            Icon(Icons.lock_outline,
                size: 40, color: Theme.of(context).colorScheme.outline),
            const SizedBox(height: AppSpacing.s),
            Text(l10n.cashboxNotOpened, style: context.appTypography.sectionTitle),
            const SizedBox(height: AppSpacing.s),
            Text(
              canOperate
                  ? l10n.cashboxNotOpenedHint
                  : l10n.cashboxNotOpenedReadOnly,
              style: context.appTypography.body,
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}

class _SessionCard extends StatelessWidget {
  const _SessionCard({required this.session});

  final CashboxSession session;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final closed = session.status == CashboxStatus.closed;
    final tp = context.appTypography;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Card(
          elevation: 0,
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.m),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(
                      closed ? Icons.lock : Icons.lock_open,
                      color: closed
                          ? Theme.of(context).colorScheme.outline
                          : Theme.of(context).colorScheme.primary,
                    ),
                    const SizedBox(width: AppSpacing.s),
                    Text(
                      closed ? l10n.cashboxSessionClosed : l10n.cashboxSessionOpen,
                      style: tp.sectionTitle,
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.s),
                Text(
                  '${l10n.cashboxOpenedBy}: ${session.openedByUserName ?? session.openedByUserId ?? '-'} · '
                  '${l10n.cashboxOpenedAt}: ${_fmt(session.openedAtMillis)}',
                  style: tp.body,
                ),
                if (closed) ...[
                  const SizedBox(height: AppSpacing.xs),
                  Text(
                    '${l10n.cashboxClosedBy}: ${session.closedByUserName ?? session.closedByUserId ?? '-'} · '
                    '${l10n.cashboxClosedAt}: ${_fmt(session.closedAtMillis)}',
                    style: tp.body,
                  ),
                ],
                const Divider(),
                _RunningBalance(session: session),
                if (session.hasDifference) ...[
                  const SizedBox(height: AppSpacing.s),
                  _DifferenceBanner(session: session),
                ],
              ],
            ),
          ),
        ),
        const SizedBox(height: AppSpacing.m),
        _MovementsCard(session: session),
      ],
    );
  }
}

class _RunningBalance extends StatelessWidget {
  const _RunningBalance({required this.session});

  final CashboxSession session;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final running = session.runningBalanceMicros;
    final label = session.status == CashboxStatus.closed
        ? l10n.cashboxDeclared
        : l10n.cashboxRunning;
    return Row(
      children: [
        Text(label, style: context.appTypography.body),
        const Spacer(),
        Text(
          Money.fromUnits(running).formatArabicDigits(),
          style: context.appTypography.numericStrong,
        ),
        if (session.status == CashboxStatus.open) ...[
          const SizedBox(width: AppSpacing.l),
          Text(
            l10n.cashboxExpected,
            style: context.appTypography.body,
          ),
          const SizedBox(width: AppSpacing.xs),
          Text(
            Money.fromUnits(session.expectedClosingMicros).formatArabicDigits(),
            style: context.appTypography.numeric,
          ),
        ],
      ],
    );
  }
}

class _DifferenceBanner extends StatelessWidget {
  const _DifferenceBanner({required this.session});

  final CashboxSession session;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final diff = session.differenceMicros ?? 0;
    final surplus = diff > 0;
    return Container(
      padding: const EdgeInsets.all(AppSpacing.s),
      decoration: BoxDecoration(
        color: (surplus ? Colors.amber : Theme.of(context).colorScheme.error)
            .withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          Icon(surplus ? Icons.trending_up : Icons.trending_down,
              color: surplus ? Colors.amber.shade800 : Theme.of(context).colorScheme.error),
          const SizedBox(width: AppSpacing.s),
          Expanded(
            child: Text(
              '${surplus ? l10n.cashboxSurplus : l10n.cashboxShortage}: '
              '${Money.fromUnits(diff.abs()).formatArabicDigits()}',
              style: context.appTypography.body,
            ),
          ),
        ],
      ),
    );
  }
}

class _MovementsCard extends StatelessWidget {
  const _MovementsCard({required this.session});

  final CashboxSession session;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final tp = context.appTypography;
    return Card(
      elevation: 0,
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.m),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(l10n.cashboxMovementsTitle, style: tp.sectionTitle),
            const SizedBox(height: AppSpacing.xs),
            _row(context, l10n.cashboxTypeSale, session.salesCashMicros,
                isOutflow: false),
            _row(context, l10n.cashboxTypeRefund, session.refundMicros.abs(),
                isOutflow: true),
            _row(context, l10n.cashboxTypePayment, session.paymentsMicros,
                isOutflow: false),
            _row(context, l10n.cashboxTypeDeposit, session.depositsMicros,
                isOutflow: false),
            _row(context, l10n.cashboxTypeWithdraw, session.withdrawalsMicros.abs(),
                isOutflow: true),
            _row(context, l10n.cashboxTypeExpense, session.expensesMicros.abs(),
                isOutflow: true),
            _row(context, l10n.cashboxTypeAdjustment, session.adjustmentsMicros,
                isOutflow: session.adjustmentsMicros < 0),
            const Divider(),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(l10n.cashboxInflows, style: tp.body),
                Text(Money.fromUnits(session.inflowsMicros).formatArabicDigits(),
                    style: tp.numeric),
              ],
            ),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(l10n.cashboxOutflows, style: tp.body),
                Text(
                    '-${Money.fromUnits(session.outflowsMicros).formatArabicDigits()}',
                    style: tp.numeric),
              ],
            ),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(l10n.cashboxNetMoves, style: tp.body),
                Text(Money.fromUnits(session.netMovesMicros).formatArabicDigits(),
                    style: tp.numeric),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _row(BuildContext context, String label, int micros,
      {required bool isOutflow}) {
    final sign = isOutflow && micros != 0 ? '-' : '';
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: context.appTypography.body),
          Text('$sign${Money.fromUnits(micros).formatArabicDigits()}',
              style: context.appTypography.numeric),
        ],
      ),
    );
  }
}

class _HistoryCard extends ConsumerWidget {
  const _HistoryCard({required this.view});

  final CashboxViewState view;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final tp = context.appTypography;
    final history = view.history;
    final items = history?.items ?? const <CashboxHistoryEntry>[];

    return Card(
      elevation: 0,
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.m),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Text(l10n.cashboxHistoryTitle, style: tp.sectionTitle),
                const Spacer(),
                DropdownButton<CashboxTransactionType?>(
                  value: view.typeFilter,
                  hint: Text(l10n.cashboxFilterAll),
                  items: [
                    DropdownMenuItem<CashboxTransactionType?>(
                      value: null,
                      child: Text(l10n.cashboxFilterAll),
                    ),
                    for (final type in CashboxTransactionType.values)
                      DropdownMenuItem<CashboxTransactionType?>(
                        value: type,
                        child: Text(_typeLabel(l10n, type)),
                      ),
                  ],
                  onChanged: (t) async {
                    await ref
                        .read(cashboxControllerProvider.notifier)
                        .setTypeFilter(t);
                  },
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.xs),
            AppDataTable(
              emptyMessage: l10n.cashboxHistoryEmpty,
              columns: [
                DataColumn(label: Text(l10n.cashboxColTime)),
                DataColumn(label: Text(l10n.cashboxColType)),
                DataColumn(label: Text(l10n.cashboxColAmount)),
                DataColumn(label: Text(l10n.cashboxColRemaining)),
                DataColumn(label: Text(l10n.cashboxColOperator)),
                DataColumn(label: Text(l10n.cashboxColNote)),
              ],
              rows: [
                for (final entry in items)
                  DataRow(
                    cells: [
                      DataCell(Text(_fmt(entry.createdAt), style: tp.body)),
                      DataCell(Text(
                          entry.type == null
                              ? '-'
                              : _typeLabel(l10n, entry.type!),
                          style: tp.body)),
                      DataCell(Text(_amountText(entry), style: tp.numeric)),
                      DataCell(Text(
                        Money.fromUnits(entry.remainingMicros).formatArabicDigits(),
                        style: tp.numeric,
                      )),
                      DataCell(Text(entry.userName, style: tp.body)),
                      DataCell(Text(entry.note ?? '', style: tp.body)),
                    ],
                  ),
              ],
            ),
            if (history != null && history.hasMore) ...[
              const SizedBox(height: AppSpacing.s),
              Center(
                child: OutlinedButton.icon(
                  onPressed: () async {
                    await ref
                        .read(cashboxControllerProvider.notifier)
                        .loadMore();
                  },
                  icon: const Icon(Icons.more_horiz),
                  label: Text(l10n.commonNext),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  static String _amountText(CashboxHistoryEntry entry) {
    final sign = entry.amountMicros < 0 ? '-' : '';
    return '$sign${Money.fromUnits(entry.amountMicros.abs()).formatArabicDigits()}';
  }

  static String _typeLabel(AppLocalizations l10n, CashboxTransactionType type) =>
      switch (type) {
        CashboxTransactionType.open => l10n.cashboxTypeOpen,
        CashboxTransactionType.close => l10n.cashboxTypeClose,
        CashboxTransactionType.sale => l10n.cashboxTypeSale,
        CashboxTransactionType.refund => l10n.cashboxTypeRefund,
        CashboxTransactionType.payment => l10n.cashboxTypePayment,
        CashboxTransactionType.deposit => l10n.cashboxTypeDeposit,
        CashboxTransactionType.withdraw => l10n.cashboxTypeWithdraw,
        CashboxTransactionType.expense => l10n.cashboxTypeExpense,
        CashboxTransactionType.adjustment => l10n.cashboxTypeAdjustment,
      };
}

class _ErrorPane extends StatelessWidget {
  const _ErrorPane({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.m),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.error_outline,
                size: 48, color: Theme.of(context).colorScheme.error),
            const SizedBox(height: AppSpacing.m),
            Text(message,
                style: context.appTypography.body, textAlign: TextAlign.center),
            const SizedBox(height: AppSpacing.m),
            FilledButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh),
              label: Text(l10n.commonRetry),
            ),
          ],
        ),
      ),
    );
  }
}

String _fmt(int? millis) {
  if (millis == null) return '-';
  final d = DateTime.fromMillisecondsSinceEpoch(millis);
  return '${d.year}-${d.month.toString().padLeft(2, '0')}-'
      '${d.day.toString().padLeft(2, '0')} '
      '${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';
}