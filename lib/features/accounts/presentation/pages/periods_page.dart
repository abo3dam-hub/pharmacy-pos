import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/constants/permission_codes.dart';
import '../../../../core/di/providers.dart';
import '../../../../core/errors/exceptions.dart';
import '../../../../core/errors/failures.dart';
import '../../../../core/theme/app_dimensions.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/widgets/app_data_table.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../../shared/database/app_database.dart';
import '../../application/accounting_controller.dart';

/// Periods page (إقفال الفترة): list periods, create, close.
class PeriodsPage extends ConsumerStatefulWidget {
  const PeriodsPage({super.key});

  @override
  ConsumerState<PeriodsPage> createState() => _PeriodsPageState();
}

class _PeriodsPageState extends ConsumerState<PeriodsPage> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  bool get _canPost =>
      ref.read(authControllerProvider).permissions.contains(Perm.accountingPost);

  Future<void> _load() async {
    await ref.read(periodsControllerProvider.notifier).load();
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

  void _showSuccess(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _showCreateDialog() async {
    final l10n = AppLocalizations.of(context);
    final result = await showDialog<_PeriodFormResult>(
      context: context,
      builder: (_) => const _CreatePeriodDialog(),
    );
    if (result == null) return;
    try {
      await ref.read(periodsControllerProvider.notifier).create(
            name: result.name,
            startDate: result.startDate,
            endDate: result.endDate,
          );
      _showSuccess(l10n.periodCreatedMessage);
      await _load();
    } on AppException catch (e) {
      _showFailure(e.failure);
    }
  }

  Future<void> _confirmClose(AccountingPeriodRow period) async {
    final l10n = AppLocalizations.of(context);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: Text(l10n.periodCloseTitle),
        content: Text(
            '${l10n.periodCloseConfirmMessage}\n${period.name}'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(l10n.commonCancel),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: Text(l10n.commonConfirm),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    if (!mounted) return;

    final reasonCtrl = TextEditingController();
    final closeReason = await showDialog<String>(
      context: context,
      builder: (_) => AlertDialog(
        title: Text(l10n.periodCloseReason),
        content: TextField(
          controller: reasonCtrl,
          decoration: InputDecoration(
            border: const OutlineInputBorder(),
            isDense: true,
          ),
          maxLines: 2,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text(l10n.commonCancel),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(reasonCtrl.text),
            child: Text(l10n.commonConfirm),
          ),
        ],
      ),
    );

    try {
      final userId = ref.read(authControllerProvider).user?.id;
      if (userId == null) return;
      await ref.read(periodsControllerProvider.notifier).close(
            periodId: period.id,
            userId: userId,
            closeReason: closeReason,
          );
      _showSuccess(l10n.periodClosedMessage);
      await _load();
    } on AppException catch (e) {
      _showFailure(e.failure);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final state = ref.watch(periodsControllerProvider);

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.periodCloseTitle),
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
          PeriodsViewStatus.initial ||
          PeriodsViewStatus.loading =>
            const Center(child: CircularProgressIndicator()),
          PeriodsViewStatus.error => Center(
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
          PeriodsViewStatus.ready => _PeriodsBody(
              periods: state.periods,
              canPost: _canPost,
              onCreate: _showCreateDialog,
              onClose: _confirmClose,
            ),
        },
      ),
    );
  }
}

class _PeriodsBody extends StatelessWidget {
  const _PeriodsBody({
    required this.periods,
    required this.canPost,
    required this.onCreate,
    required this.onClose,
  });

  final List<AccountingPeriodRow> periods;
  final bool canPost;
  final VoidCallback onCreate;
  final void Function(AccountingPeriodRow) onClose;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final tp = context.appTypography;

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(
          AppSpacing.l, AppSpacing.s, AppSpacing.l, AppSpacing.l),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 900),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (canPost)
                Wrap(
                  spacing: AppSpacing.s,
                  children: [
                    FilledButton.icon(
                      onPressed: onCreate,
                      icon: const Icon(Icons.add),
                      label: Text(l10n.periodCreate),
                    ),
                  ],
                ),
              const SizedBox(height: AppSpacing.m),
              AppDataTable(
                emptyMessage: l10n.accountsNoData,
                columns: [
                  DataColumn(label: Text(l10n.periodName)),
                  DataColumn(label: Text(l10n.periodStartDate)),
                  DataColumn(label: Text(l10n.periodEndDate)),
                  DataColumn(label: Text(l10n.periodStatus)),
                  if (canPost) DataColumn(label: Text('')),
                ],
                rows: [
                  for (final period in periods)
                    DataRow(cells: [
                      DataCell(Text(period.name, style: tp.body)),
                      DataCell(Text(
                          _fmtDate(period.startDate), style: tp.body)),
                      DataCell(Text(
                          _fmtDate(period.endDate), style: tp.body)),
                      DataCell(
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(
                            color: period.isClosed
                                ? Colors.green.withValues(alpha: 0.1)
                                : Colors.orange.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            period.isClosed
                                ? l10n.periodClosed
                                : l10n.periodOpen,
                            style: tp.labelSmall.copyWith(
                              color: period.isClosed
                                  ? Colors.green.shade800
                                  : Colors.orange.shade800,
                            ),
                          ),
                        ),
                      ),
                      if (canPost)
                        DataCell(
                          !period.isClosed
                              ? OutlinedButton.icon(
                                  onPressed: () => onClose(period),
                                  icon: const Icon(Icons.lock_outline,
                                      size: 16),
                                  label: Text(l10n.periodCloseTitle),
                                )
                              : const SizedBox.shrink(),
                        ),
                    ]),
                ],
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
}

class _PeriodFormResult {
  const _PeriodFormResult({
    required this.name,
    required this.startDate,
    required this.endDate,
  });

  final String name;
  final int startDate;
  final int endDate;
}

class _CreatePeriodDialog extends StatefulWidget {
  const _CreatePeriodDialog();

  @override
  State<_CreatePeriodDialog> createState() => _CreatePeriodDialogState();
}

class _CreatePeriodDialogState extends State<_CreatePeriodDialog> {
  final _formKey = GlobalKey<FormState>();
  final _nameCtrl = TextEditingController();
  DateTime? _startDate;
  DateTime? _endDate;

  @override
  void dispose() {
    _nameCtrl.dispose();
    super.dispose();
  }

  void _submit() {
    if (!_formKey.currentState!.validate()) return;
    if (_startDate == null || _endDate == null) return;
    Navigator.of(context).pop(_PeriodFormResult(
      name: _nameCtrl.text.trim(),
      startDate: _startDate!.millisecondsSinceEpoch,
      endDate: _endDate!.millisecondsSinceEpoch,
    ));
  }

  Future<void> _pickDate({required bool isStart}) async {
    final picked = await showDatePicker(
      context: context,
      initialDate: isStart
          ? _startDate ?? DateTime.now()
          : _endDate ?? DateTime.now().add(const Duration(days: 90)),
      firstDate: DateTime(2020),
      lastDate: DateTime(2030),
    );
    if (picked == null) return;
    setState(() {
      if (isStart) {
        _startDate = picked;
      } else {
        _endDate = picked;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);

    return AlertDialog(
      title: Text(l10n.periodCreate),
      content: Form(
        key: _formKey,
        child: SizedBox(
          width: 380,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                controller: _nameCtrl,
                decoration: InputDecoration(
                  labelText: l10n.periodName,
                  border: const OutlineInputBorder(),
                  isDense: true,
                ),
                validator: (v) {
                  if (v == null || v.trim().isEmpty) {
                    return l10n.periodNameRequired;
                  }
                  return null;
                },
              ),
              const SizedBox(height: AppSpacing.m),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () => _pickDate(isStart: true),
                      icon: const Icon(Icons.calendar_today, size: 16),
                      label: Text(_startDate != null
                          ? _fmtDate(_startDate!.millisecondsSinceEpoch)
                          : l10n.periodStartDate),
                    ),
                  ),
                  const SizedBox(width: AppSpacing.s),
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () => _pickDate(isStart: false),
                      icon: const Icon(Icons.calendar_today, size: 16),
                      label: Text(_endDate != null
                          ? _fmtDate(_endDate!.millisecondsSinceEpoch)
                          : l10n.periodEndDate),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(l10n.commonCancel),
        ),
        FilledButton(
          onPressed: _submit,
          child: Text(l10n.commonSave),
        ),
      ],
    );
  }

  static String _fmtDate(int millis) {
    final d = DateTime.fromMillisecondsSinceEpoch(millis);
    return '${d.year}-${d.month.toString().padLeft(2, '0')}-'
        '${d.day.toString().padLeft(2, '0')}';
  }
}
