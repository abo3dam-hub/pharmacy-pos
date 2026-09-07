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
import '../../../../shared/models/enums.dart';
import '../../application/accounting_controller.dart';
import '../widgets/account_form_dialog.dart';

/// Chart of Accounts page (دليل الحسابات): list, search, add, edit, toggle.
class ChartOfAccountsPage extends ConsumerStatefulWidget {
  const ChartOfAccountsPage({super.key});

  @override
  ConsumerState<ChartOfAccountsPage> createState() =>
      _ChartOfAccountsPageState();
}

class _ChartOfAccountsPageState extends ConsumerState<ChartOfAccountsPage> {
  final _searchCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    await ref.read(accountsControllerProvider.notifier).load();
  }

  bool get _canPost =>
      ref.read(authControllerProvider).permissions.contains(Perm.accountingPost);

  void _showFailure(Failure? failure) {
    if (failure == null || !mounted) return;
    final l10n = AppLocalizations.of(context);
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(
          content: Text(
              failure.message.isEmpty ? l10n.commonError : failure.message)));
  }

  Future<void> _addAccount() async {
    final result = await showAccountFormDialog(context);
    if (result == null) return;
    final failure = await ref.read(accountsControllerProvider.notifier).create(
          type: result.type,
          code: result.code,
          name: result.name,
          nameEn: result.nameEn,
          parentId: result.parentId,
          openingBalanceMicros: result.openingBalanceMicros,
          notes: result.notes,
        );
    _showFailure(failure);
    if (failure == null) await _load();
  }

  Future<void> _editAccount(AccountRow account) async {
    final result = await showAccountFormDialog(
      context,
      existing: account,
    );
    if (result == null) return;
    final failure = await ref.read(accountsControllerProvider.notifier).update(
          account.id,
          name: result.name,
          nameEn: result.nameEn,
          parentId: result.parentId,
          notes: result.notes,
        );
    _showFailure(failure);
    if (failure == null) await _load();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final state = ref.watch(accountsControllerProvider);

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.chartAccountsTitle),
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
          AccountsViewStatus.initial ||
          AccountsViewStatus.loading =>
            const Center(child: CircularProgressIndicator()),
          AccountsViewStatus.error => Center(
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
          AccountsViewStatus.ready => _AccountsBody(
              accounts: state.accounts,
              canPost: _canPost,
              searchController: _searchCtrl,
              onSearch: (q) =>
                  ref.read(accountsControllerProvider.notifier).search(q),
              onAdd: _canPost ? _addAccount : null,
              onEdit: _canPost ? _editAccount : null,
              onToggleActive: _canPost
                  ? (id, active) async {
                      final failure = await ref
                          .read(accountsControllerProvider.notifier)
                          .toggleActive(id, active);
                      _showFailure(failure);
                      if (failure == null) await _load();
                    }
                  : null,
            ),
        },
      ),
    );
  }
}

class _AccountsBody extends StatelessWidget {
  const _AccountsBody({
    required this.accounts,
    required this.canPost,
    required this.searchController,
    required this.onSearch,
    this.onAdd,
    this.onEdit,
    this.onToggleActive,
  });

  final List<AccountRow> accounts;
  final bool canPost;
  final TextEditingController searchController;
  final ValueChanged<String> onSearch;
  final VoidCallback? onAdd;
  final void Function(AccountRow)? onEdit;
  final void Function(String id, bool active)? onToggleActive;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final tp = context.appTypography;

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(
          AppSpacing.l, AppSpacing.s, AppSpacing.l, AppSpacing.l),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1000),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Action bar
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: searchController,
                      decoration: InputDecoration(
                        hintText: l10n.commonSearch,
                        prefixIcon: const Icon(Icons.search),
                        isDense: true,
                        border: const OutlineInputBorder(),
                      ),
                      onSubmitted: onSearch,
                    ),
                  ),
                  if (onAdd != null) ...[
                    const SizedBox(width: AppSpacing.s),
                    FilledButton.icon(
                      onPressed: onAdd,
                      icon: const Icon(Icons.add),
                      label: Text(l10n.commonAdd),
                    ),
                  ],
                ],
              ),
              const SizedBox(height: AppSpacing.m),

              // Table
              AppDataTable(
                emptyMessage: l10n.accountsNoData,
                columns: [
                  DataColumn(label: Text(l10n.accountsColCode)),
                  DataColumn(label: Text(l10n.accountsColName)),
                  DataColumn(label: Text(l10n.accountsColType)),
                  DataColumn(label: Text(l10n.accountsColBalance)),
                  DataColumn(label: Text(l10n.accountsColStatus)),
                  if (canPost) DataColumn(label: Text('')),
                ],
                rows: [
                  for (final account in accounts)
                    DataRow(cells: [
                      DataCell(Text(account.code, style: tp.numeric)),
                      DataCell(
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            if (account.isSystem)
                              const Icon(Icons.lock, size: 14, color: Colors.grey),
                            if (account.isSystem)
                              const SizedBox(width: 4),
                            Text(account.name, style: tp.body),
                          ],
                        ),
                      ),
                      DataCell(Text(
                          _typeLabel(l10n, account.accountType),
                          style: tp.body)),
                      DataCell(Text(
                        Money.fromUnits(account.balanceMicros)
                            .formatArabicDigits(),
                        style: tp.numericStrong,
                      )),
                      DataCell(
                        Switch(
                          value: account.isActive,
                          onChanged: onToggleActive != null
                              ? (v) => onToggleActive!(account.id, v)
                              : null,
                        ),
                      ),
                      if (canPost)
                        DataCell(
                          IconButton(
                            icon: const Icon(Icons.edit_outlined, size: 20),
                            tooltip: l10n.commonEdit,
                            onPressed: () => onEdit?.call(account),
                          ),
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

  static String _typeLabel(AppLocalizations l10n, AccountType type) =>
      switch (type) {
        AccountType.asset => l10n.accountTypeAsset,
        AccountType.liability => l10n.accountTypeLiability,
        AccountType.equity => l10n.accountTypeEquity,
        AccountType.revenue => l10n.accountTypeRevenue,
        AccountType.expense => l10n.accountTypeExpense,
      };
}
