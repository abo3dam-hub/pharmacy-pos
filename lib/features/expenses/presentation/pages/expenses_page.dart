import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/constants/permission_codes.dart';
import '../../../../core/di/providers.dart';
import '../../../../core/errors/failures.dart';
import '../../../../core/money/money.dart';
import '../../../../core/theme/app_dimensions.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/widgets/app_data_table.dart';
import '../../../../core/widgets/confirm_dialog.dart';
import '../../../../core/widgets/loading_overlay.dart';
import '../../../../core/widgets/responsive_layout.dart';
import '../../../../core/widgets/search_field.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../../shared/database/app_database.dart';
import '../../../../shared/models/enums.dart';
import '../../application/expense_controller.dart';
import '../../domain/entities/expense_list_item.dart';
import '../widgets/expense_dialogs.dart';

String _formatDate(int millis) =>
    DateTime.fromMillisecondsSinceEpoch(millis)
        .toLocal()
        .toIso8601String()
        .split('T')
        .first;

/// §4.20 Phase 9 Expenses (المصروفات): paged journal with category / payment /
/// status filters, printable expense numbers, payment-method breakdown, receipt
/// scan attachment/preview and guarded cancel (reverse) + categories manager.
class ExpensesPage extends ConsumerStatefulWidget {
  const ExpensesPage({super.key});

  @override
  ConsumerState<ExpensesPage> createState() => _ExpensesPageState();
}

class _ExpensesPageState extends ConsumerState<ExpensesPage> {
  static const int _pageSize = 30;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  Future<void> _load() async {
    await ref
        .read(expenseControllerProvider.notifier)
        .load(actingRoleId: _actingRoleId);
  }

  String? get _actingUserId => ref.read(authControllerProvider).user?.id;
  String? get _actingRoleId => ref.read(authControllerProvider).actingRoleId;

  bool get _canCreate =>
      ref.read(authControllerProvider).permissions.contains(Perm.expensesCreate);
  bool get _canEdit =>
      ref.read(authControllerProvider).permissions.contains(Perm.expensesEdit);
  bool get _canVoid =>
      ref.read(authControllerProvider).permissions.contains(Perm.expensesVoid);
  bool get _canManageCategories => ref
      .read(authControllerProvider)
      .permissions
      .contains(Perm.expenseCategoriesManage);
  bool get _canViewCategories =>
      ref.read(authControllerProvider).permissions.contains(Perm.expenseCategoriesView);

  void _showFailure(Failure? failure) {
    if (failure == null || !mounted) return;
    final l10n = AppLocalizations.of(context);
    final message = failure.message.isEmpty ? l10n.commonError : failure.message;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _record() async {
    final l10n = AppLocalizations.of(context);
    final state = ref.read(expenseControllerProvider);
    var suppliers = <SupplierRow>[];
    try {
      suppliers = await ref
          .read(allSuppliersUseCaseProvider)
          .call(actingRoleId: _actingRoleId);
    } catch (_) {
      suppliers = const [];
    }
    if (!mounted) return;
    final draft = await showExpenseRecordDialog(
      context,
      categories: state.categories,
      suppliers: suppliers,
    );
    if (draft == null || !mounted) return;
    final outcome = await ref
        .read(expenseControllerProvider.notifier)
        .record(draft,
            actingUserId: _actingUserId, actingRoleId: _actingRoleId);
    if (outcome == null && mounted) {
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(content: Text(l10n.expenseCreatedMessage)));
    } else {
      _showFailure(outcome);
    }
  }

  Future<void> _edit(ExpenseListItem expense) async {
    final l10n = AppLocalizations.of(context);
    final draft = await showExpenseEditDialog(
      context,
      description: expense.description,
      notes: expense.notes,
    );
    if (draft == null || !mounted) return;
    final outcome = await ref
        .read(expenseControllerProvider.notifier)
        .update(expense.id, draft,
            actingUserId: _actingUserId, actingRoleId: _actingRoleId);
    if (outcome == null && mounted) {
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(content: Text(l10n.expenseUpdatedMessage)));
    } else {
      _showFailure(outcome);
    }
  }

  Future<void> _cancel(ExpenseListItem expense) async {
    final l10n = AppLocalizations.of(context);
    final reason = await showExpenseCancelDialog(
      context,
      expenseNumber: expense.expenseNumber,
    );
    if (reason == null || !mounted) return;
    final outcome = await ref
        .read(expenseControllerProvider.notifier)
        .cancel(expense.id,
            reason: reason,
            actingUserId: _actingUserId,
            actingRoleId: _actingRoleId);
    if (outcome == null && mounted) {
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(content: Text(l10n.expenseCancelledMessage)));
    } else {
      _showFailure(outcome);
    }
  }

  Future<void> _ensureReceipt(ExpenseListItem expense) async {
    final l10n = AppLocalizations.of(context);
    final picked = await FilePicker.pickFile(type: FileType.any);
    if (picked == null || picked.path == null || !mounted) return;
    final outcome = await ref
        .read(expenseControllerProvider.notifier)
        .attachReceipt(expense.id,
            sourcePath: picked.path!,
            actingUserId: _actingUserId,
            actingRoleId: _actingRoleId);
    if (outcome == null && mounted) {
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(content: Text(l10n.expenseReceiptAttached)));
    } else {
      _showFailure(outcome);
    }
  }

  Future<void> _showReceipt(ExpenseListItem expense) async {
    if (expense.receiptPath == null) return;
    await showExpenseReceiptDialog(context, path: expense.receiptPath!);
  }

  void _manageCategories() => _showManageCategoriesDialog(context);

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final state = ref.watch(expenseControllerProvider);
    final auth = ref.watch(authControllerProvider);

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.expensesTitle),
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
          ExpenseViewStatus.initial || ExpenseViewStatus.loading =>
            const Center(child: CircularProgressIndicator()),
          ExpenseViewStatus.error => _ErrorPane(
              message: state.error?.message ?? l10n.commonError,
              onRetry: _load,
            ),
          ExpenseViewStatus.ready => LoadingOverlay(
              visible: state.busy,
              label: l10n.commonLoading,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _SummaryStrip(state: state),
                  _FilterBar(
                    state: state,
                    canCreate: _canCreate,
                    canManageCategories: _canManageCategories,
                    onSearch: (q) => ref
                        .read(expenseControllerProvider.notifier)
                        .search(q, actingRoleId: _actingRoleId),
                    onRecord: _record,
                    onManageCategories: _manageCategories,
                  ),
                  Expanded(
                    child: AppResponsiveLayout(
                      desktop: _table(l10n, state, auth.permissions),
                      tablet: _table(l10n, state, auth.permissions),
                      compact:
                          _cards(l10n, state, auth.permissions),
                    ),
                  ),
                  _pager(l10n, state.request.page, state.total),
                  if (!_canCreate && !_canEdit && !_canVoid)
                    Padding(
                      padding: const EdgeInsets.only(top: AppSpacing.s),
                      child: Text(
                        l10n.expensesReadOnly,
                        style: context.appTypography.labelSmall,
                        textAlign: TextAlign.center,
                      ),
                    ),
                ],
              ),
            ),
        },
      ),
    );
  }

  Widget _pager(AppLocalizations l10n, int page, int total) {
    final pageCount = (total / _pageSize).ceil();
    return Padding(
      padding: const EdgeInsets.fromLTRB(
          AppSpacing.xl, AppSpacing.s, AppSpacing.xl, AppSpacing.l),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          Text('$page / ${pageCount == 0 ? 1 : pageCount}',
              style: context.appTypography.bodySecondary),
          const SizedBox(width: AppSpacing.m),
          IconButton(
            onPressed: page <= 1 ? null : () => _toPage(page - 1),
            icon: const Icon(Icons.chevron_left),
            tooltip: l10n.commonPrevious,
          ),
          IconButton(
            onPressed: page >= pageCount || pageCount == 0
                ? null
                : () => _toPage(page + 1),
            icon: const Icon(Icons.chevron_right),
            tooltip: l10n.commonNext,
          ),
        ],
      ),
    );
  }

  void _toPage(int page) {
    ref
        .read(expenseControllerProvider.notifier)
        .toPage(page, actingRoleId: _actingRoleId);
  }

  Widget _table(AppLocalizations l10n, ExpenseViewState state, Set<String> perms) {
    return AppDataTable(
      emptyMessage: l10n.expensesEmpty,
      columns: [
        DataColumn(label: Text(l10n.expensesColNumber)),
        DataColumn(label: Text(l10n.expensesColDate)),
        DataColumn(label: Text(l10n.expensesColDescription)),
        DataColumn(label: Text(l10n.expensesColCategory)),
        DataColumn(label: Text(l10n.expensesColPayment)),
        DataColumn(label: Text(l10n.expensesColAmount)),
        DataColumn(label: Text(l10n.expensesColOperator)),
        DataColumn(label: Text(l10n.expensesColStatus)),
        DataColumn(label: Text('')),
      ],
      rows: [
        for (final e in state.expenses)
          DataRow(cells: [
            DataCell(Text(e.expenseNumber)),
            DataCell(Text(_formatDate(e.expenseDate))),
            DataCell(Text(e.description)),
            DataCell(Text(e.categoryName)),
            DataCell(Text(e.paymentMethod == 'card'
                ? l10n.expensesCard
                : l10n.expensesCash)),
            DataCell(
              Text(
                Money.fromUnits(e.amountMicros).formatArabicDigits(),
                style: context.appTypography.numericStrong,
              ),
            ),
            DataCell(Text(e.userName ?? '')),
            DataCell(_StatusPill(voided: e.isVoided, l10n: l10n)),
            DataCell(_actions(l10n, e, perms)),
          ]),
      ],
    );
  }

  Widget _cards(
      AppLocalizations l10n, ExpenseViewState state, Set<String> perms) {
    if (state.expenses.isEmpty) {
      return Center(
        child: Text(l10n.expensesEmpty, style: context.appTypography.labelSmall),
      );
    }
    return ListView(
      padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.m, vertical: AppSpacing.s),
      children: [
        for (final e in state.expenses)
          Card(
            margin: const EdgeInsets.only(bottom: AppSpacing.m),
            child: Padding(
              padding: const EdgeInsets.all(AppSpacing.m),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          '${e.expenseNumber} · ${e.description}',
                          style: context.appTypography.sectionTitle,
                        ),
                      ),
                      _StatusPill(voided: e.isVoided, l10n: l10n),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.s),
                  Text(
                    '${e.categoryName} · ${e.paymentMethod == 'card' ? l10n.expensesCard : l10n.expensesCash} · '
                    '${Money.fromUnits(e.amountMicros).formatArabicDigits()} · '
                    '${_formatDate(e.expenseDate)}',
                    style: context.appTypography.bodySecondary,
                  ),
                  const SizedBox(height: AppSpacing.s),
                  Align(
                    alignment: AlignmentDirectional.centerEnd,
                    child: _actions(l10n, e, perms),
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }

  Widget _actions(AppLocalizations l10n, ExpenseListItem e, Set<String> perms) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (e.hasReceipt)
          IconButton(
            icon: const Icon(Icons.receipt_long_outlined),
            tooltip: l10n.expensesShowReceipt,
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints.tightFor(width: 32, height: 32),
            onPressed: () => _showReceipt(e),
          ),
        if (!e.isVoided && _canEdit) ...[
          if (!e.hasReceipt)
            IconButton(
              icon: const Icon(Icons.attach_file),
              tooltip: l10n.expensesAttachReceipt,
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints.tightFor(width: 32, height: 32),
              onPressed: () => _ensureReceipt(e),
            ),
          IconButton(
            icon: const Icon(Icons.edit_outlined),
            tooltip: l10n.commonEdit,
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints.tightFor(width: 32, height: 32),
            onPressed: () => _edit(e),
          ),
        ],
        if (!e.isVoided && _canVoid)
          IconButton(
            icon: const Icon(Icons.block),
            tooltip: l10n.expensesCancelAction,
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints.tightFor(width: 32, height: 32),
            onPressed: () => _cancel(e),
          ),
      ],
    );
  }

  Future<void> _showManageCategoriesDialog(BuildContext context) async {
    final l10n = AppLocalizations.of(context);
    final state = ref.read(expenseControllerProvider);
    final categories = state.categories;
    await showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(l10n.expenseCategoriesTitle),
        content: SizedBox(
          width: 480,
          height: 420,
          child: categories.isEmpty
              ? Center(
                  child:
                      Text(l10n.expenseNoCategories, style: context.appTypography.bodySecondary))
              : ListView.separated(
                  itemCount: categories.length,
                  separatorBuilder: (_, _) => const Divider(height: 1),
                  itemBuilder: (_, i) {
                    final c = categories[i];
                    return ListTile(
                      dense: true,
                      leading: _canViewCategories
                          ? const Icon(Icons.category_outlined)
                          : null,
                      title: Text(c.name),
                      subtitle: Text('${c.code} · ${c.accountCode}'),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (c.isSystem)
                            const Tooltip(
                              message: 'System',
                              child: Icon(Icons.lock_outline, size: 18),
                            ),
                          if (_canManageCategories && !c.isSystem)
                            IconButton(
                              icon: const Icon(Icons.edit_outlined),
                              tooltip: l10n.commonEdit,
                              constraints: const BoxConstraints.tightFor(
                                  width: 32, height: 32),
                              onPressed: () async {
                                Navigator.of(dialogContext).pop();
                                await _editCategory(c);
                              },
                            ),
                          if (_canManageCategories && !c.isSystem)
                            IconButton(
                              icon: Icon(c.isActive
                                  ? Icons.block
                                  : Icons.check_circle_outline),
                              tooltip:
                                  c.isActive ? l10n.userDeactivate : l10n.userActivate,
                              constraints: const BoxConstraints.tightFor(
                                  width: 32, height: 32),
                              onPressed: () async {
                                Navigator.of(dialogContext).pop();
                                await _setCategoryActive(c, !c.isActive);
                              },
                            ),
                        ],
                      ),
                    );
                  },
                ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: Text(l10n.commonClose),
          ),
          if (_canManageCategories)
            FilledButton.icon(
              onPressed: () async {
                Navigator.of(dialogContext).pop();
                await _addCategory();
              },
              icon: const Icon(Icons.add),
              label: Text(l10n.expenseCategoryAdd),
            ),
        ],
      ),
    );
  }

  Future<void> _addCategory() async {
    final l10n = AppLocalizations.of(context);
    final draft =
        await showExpenseCategoryDialog(context, isEdit: false);
    if (draft == null || !mounted) return;
    final outcome = await ref
        .read(expenseControllerProvider.notifier)
        .createCategory(draft,
            actingUserId: _actingUserId, actingRoleId: _actingRoleId);
    if (outcome == null && mounted) {
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(content: Text(l10n.expenseCategoryCreatedMessage)));
    } else {
      _showFailure(outcome);
    }
  }

  Future<void> _editCategory(ExpenseCategoryRow category) async {
    final l10n = AppLocalizations.of(context);
    final draft = await showExpenseCategoryDialog(context, isEdit: true, initial: category);
    if (draft == null || !mounted) return;
    final outcome = await ref
        .read(expenseControllerProvider.notifier)
        .updateCategory(category.id, draft,
            actingUserId: _actingUserId, actingRoleId: _actingRoleId);
    if (outcome == null && mounted) {
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(content: Text(l10n.expenseCategoryUpdatedMessage)));
    } else {
      _showFailure(outcome);
    }
  }

  Future<void> _setCategoryActive(
      ExpenseCategoryRow category, bool active) async {
    final l10n = AppLocalizations.of(context);
    final confirmed = await showAppConfirmDialog(
      context,
      title: active ? l10n.userActivate : l10n.userDeactivate,
      message: '${category.name} (${category.code})',
      confirmLabel: active ? l10n.userActivate : l10n.userDeactivate,
      destructive: !active,
    );
    if (!confirmed || !mounted) return;
    final outcome = await ref
        .read(expenseControllerProvider.notifier)
        .setCategoryActive(category.id, active,
            actingUserId: _actingUserId, actingRoleId: _actingRoleId);
    if (outcome == null && mounted) {
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(
            content: Text(active
                ? l10n.expenseCategoryActivated
                : l10n.expenseCategoryDeactivated)));
    } else {
      _showFailure(outcome);
    }
  }
}

/// Page totals strip: record count + sum of the current page (non-voided).
class _SummaryStrip extends StatelessWidget {
  const _SummaryStrip({required this.state});

  final ExpenseViewState state;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(
          AppSpacing.xl, AppSpacing.m, AppSpacing.xl, AppSpacing.s),
      child: Wrap(
        spacing: AppSpacing.l,
        runSpacing: AppSpacing.s,
        children: [
          Text(
            '${l10n.expensesTotalCount}: ${state.total}',
            style: context.appTypography.body,
          ),
          Text(
            '${l10n.expensesPageTotal}: '
            '${Money.fromUnits(state.pageTotalMicros).formatArabicDigits()}',
            style: context.appTypography.numericStrong,
          ),
        ],
      ),
    );
  }
}

class _FilterBar extends ConsumerWidget {
  const _FilterBar({
    required this.state,
    required this.canCreate,
    required this.canManageCategories,
    required this.onSearch,
    required this.onRecord,
    required this.onManageCategories,
  });

  final ExpenseViewState state;
  final bool canCreate;
  final bool canManageCategories;
  final ValueChanged<String> onSearch;
  final VoidCallback onRecord;
  final VoidCallback onManageCategories;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(
          AppSpacing.xl, AppSpacing.s, AppSpacing.xl, AppSpacing.s),
      child: Wrap(
        spacing: AppSpacing.m,
        runSpacing: AppSpacing.m,
        crossAxisAlignment: WrapCrossAlignment.center,
        alignment: WrapAlignment.spaceBetween,
        children: [
          SizedBox(
            width: 260,
            child: SearchField(
              hintText: l10n.expensesSearchHint,
              onChanged: onSearch,
            ),
          ),
          SizedBox(
            width: 180,
            child: DropdownButtonFormField<String?>(
              initialValue: state.categoryFilter,
              isExpanded: true,
              decoration: InputDecoration(
                labelText: l10n.expensesFilterAllCategories,
                border: const OutlineInputBorder(),
                isDense: true,
              ),
              items: [
                DropdownMenuItem(
                    value: null, child: Text(l10n.expensesFilterAllCategories)),
                for (final c in state.categories)
                  DropdownMenuItem(value: c.code, child: Text(c.name)),
              ],
              onChanged: (v) => ref
                  .read(expenseControllerProvider.notifier)
                  .applyFilters(categoryFilter: v, actingRoleId: null),
            ),
          ),
          SizedBox(
            width: 180,
            child: DropdownButtonFormField<ExpensePaymentMethod?>(
              initialValue: state.paymentFilter,
              isExpanded: true,
              decoration: InputDecoration(
                labelText: l10n.expensesFilterAllPayments,
                border: const OutlineInputBorder(),
                isDense: true,
              ),
              items: [
                DropdownMenuItem(
                    value: null,
                    child: Text(l10n.expensesFilterAllPayments)),
                DropdownMenuItem(
                    value: ExpensePaymentMethod.cash,
                    child: Text(l10n.expensesCash)),
                DropdownMenuItem(
                    value: ExpensePaymentMethod.card,
                    child: Text(l10n.expensesCard)),
              ],
              onChanged: (v) => ref
                  .read(expenseControllerProvider.notifier)
                  .applyFilters(paymentFilter: v, actingRoleId: null),
            ),
          ),
          SizedBox(
            width: 160,
            child: DropdownButtonFormField<bool?>(
              initialValue: state.voidedFilter,
              isExpanded: true,
              decoration: InputDecoration(
                labelText: l10n.expensesFilterAllStatus,
                border: const OutlineInputBorder(),
                isDense: true,
              ),
              items: [
                DropdownMenuItem(
                    value: null, child: Text(l10n.expensesFilterAllStatus)),
                DropdownMenuItem(
                    value: false,
                    child: Text(l10n.expensesFilterActiveOnly)),
                DropdownMenuItem(
                    value: true, child: Text(l10n.expensesFilterVoidedOnly)),
              ],
              onChanged: (v) =>
                  ref.read(expenseControllerProvider.notifier).applyFilters(
                      voidedFilter: v, actingRoleId: null),
            ),
          ),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (canCreate)
                FilledButton.icon(
                  onPressed: onRecord,
                  icon: const Icon(Icons.add),
                  label: Text(l10n.expensesAdd),
                ),
              if (canManageCategories) ...[
                const SizedBox(width: AppSpacing.s),
                OutlinedButton.icon(
                  onPressed: onManageCategories,
                  icon: const Icon(Icons.category_outlined),
                  label: Text(l10n.expenseCategoriesTitle),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }
}

class _StatusPill extends StatelessWidget {
  const _StatusPill({required this.voided, required this.l10n});

  final bool voided;
  final AppLocalizations l10n;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.s, vertical: 4),
      decoration: BoxDecoration(
        color: voided
            ? Theme.of(context).colorScheme.errorContainer
            : Theme.of(context).colorScheme.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(AppRadius.sm),
      ),
      child: Text(
        voided ? l10n.expensesStatusVoided : l10n.expensesStatusActive,
        style: context.appTypography.labelSmall,
      ),
    );
  }
}

class _ErrorPane extends StatelessWidget {
  const _ErrorPane({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(message, style: context.appTypography.bodySecondary),
          const SizedBox(height: AppSpacing.m),
          FilledButton.icon(
            onPressed: onRetry,
            icon: const Icon(Icons.refresh),
            label: Text(AppLocalizations.of(context).commonRetry),
          ),
        ],
      ),
    );
  }
}