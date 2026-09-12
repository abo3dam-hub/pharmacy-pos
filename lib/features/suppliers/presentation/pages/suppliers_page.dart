import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/constants/permission_codes.dart';
import '../../../../core/di/providers.dart';
import '../../../../core/errors/failure_messages.dart';
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
import '../../application/suppliers_controller.dart';
import '../widgets/supplier_dialog.dart';
import '../../../../core/widgets/app_rtl_icons.dart';

/// §16 suppliers section: master registry + derived balances ledger. Uses the
/// `suppliersControllerProvider` for search, CRUD and the statement generator.
class SuppliersPage extends ConsumerStatefulWidget {
  const SuppliersPage({super.key});

  @override
  ConsumerState<SuppliersPage> createState() => _SuppliersPageState();
}

class _SuppliersPageState extends ConsumerState<SuppliersPage> {
  static const int _pageSize = 30;

  @override
  void initState() {
    super.initState();
    Future.microtask(() async {
      final auth = ref.read(authControllerProvider);
      if (auth.permissions.contains(Perm.suppliersView)) {
        await ref
            .read(suppliersControllerProvider.notifier)
            .load(actingRoleId: auth.actingRoleId);
        await ref
            .read(suppliersControllerProvider.notifier)
            .loadBalances(actingRoleId: auth.actingRoleId);
      }
    });
  }

  bool get _canCreate =>
      ref.read(authControllerProvider).permissions.contains(Perm.suppliersCreate);
  bool get _canEdit =>
      ref.read(authControllerProvider).permissions.contains(Perm.suppliersEdit);
  bool get _canView =>
      ref.read(authControllerProvider).permissions.contains(Perm.suppliersView);
  String? get _actingUserId => ref.read(authControllerProvider).user?.id;
  String? get _actingRoleId => ref.read(authControllerProvider).actingRoleId;

  void _showFailure(Failure? failure) {
    showFailureSnack(context, failure);
  }

  Future<void> _load({String search = ''}) async {
    final failure = await ref
        .read(suppliersControllerProvider.notifier)
        .load(search: search, actingRoleId: _actingRoleId);
    _showFailure(failure);
  }

  Future<void> _loadBalances({String search = ''}) async {
    final failure = await ref
        .read(suppliersControllerProvider.notifier)
        .loadBalances(search: search, actingRoleId: _actingRoleId);
    _showFailure(failure);
  }

  Future<void> _addSupplier() async {
    final l10n = AppLocalizations.of(context);
    final draft = await showSupplierFormDialog(
      context,
      title: l10n.supplierAddTitle,
    );
    if (draft == null || !mounted) return;
    final outcome = await ref
        .read(suppliersControllerProvider.notifier)
        .add(draft, actingUserId: _actingUserId, actingRoleId: _actingRoleId);
    if (outcome == null && mounted) {
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(content: Text(l10n.supplierCreatedMessage)));
    } else {
      _showFailure(outcome);
    }
  }

  Future<void> _editSupplier(SupplierRow supplier) async {
    final l10n = AppLocalizations.of(context);
    final draft = await showSupplierFormDialog(
      context,
      title: l10n.supplierEditTitle,
      initial: supplier,
    );
    if (draft == null || !mounted) return;
    final outcome = await ref
        .read(suppliersControllerProvider.notifier)
        .update(supplier.id, draft,
            actingUserId: _actingUserId, actingRoleId: _actingRoleId);
    if (outcome == null && mounted) {
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(content: Text(l10n.supplierUpdatedMessage)));
    } else {
      _showFailure(outcome);
    }
  }

  Future<void> _toggleActive(SupplierRow supplier) async {
    final l10n = AppLocalizations.of(context);
    final activating = !supplier.isActive;
    final confirmed = await showAppConfirmDialog(
      context,
      title: activating ? l10n.userActivate : l10n.userDeactivate,
      message: activating
          ? l10n.supplierActivateConfirmMessage(supplier.name)
          : l10n.supplierDeactivateConfirmMessage(supplier.name),
      confirmLabel: activating ? l10n.userActivate : l10n.userDeactivate,
      destructive: !activating,
    );
    if (!confirmed || !mounted) return;
    final outcome = await ref
        .read(suppliersControllerProvider.notifier)
        .toggleActive(supplier.id, activating,
            actingUserId: _actingUserId, actingRoleId: _actingRoleId);
    if (outcome == null && mounted) {
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(
          content: Text(activating
              ? l10n.supplierActivatedMessage
              : l10n.supplierDeactivatedMessage),
        ));
    } else {
      _showFailure(outcome);
    }
  }

  void _toPage(int page) {
    final state = ref.read(suppliersControllerProvider);
    final pageCount = (state.total / _pageSize).ceil();
    if (page < 1 || page > (pageCount == 0 ? 1 : pageCount)) return;
    ref
        .read(suppliersControllerProvider.notifier)
        .load(search: state.request.search, page: page, actingRoleId: _actingRoleId);
  }


  void _openStatement(String supplierId) =>
      context.go('/suppliers/statement/$supplierId');

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return DefaultTabController(
      length: 2,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Material(
            color: Theme.of(context).colorScheme.surface,
            child: TabBar(
              labelStyle: context.appTypography.label,
              tabs: [
                Tab(text: l10n.suppliersTab),
                Tab(text: l10n.suppliersBalancesTab),
              ],
            ),
          ),
          Expanded(
            child: TabBarView(
              children: [
                _buildMasterTab(l10n),
                _buildBalancesTab(l10n),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMasterTab(AppLocalizations l10n) {
    final state = ref.watch(suppliersControllerProvider);
    final typography = context.appTypography;

    final header = Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.xl,
        AppSpacing.l,
        AppSpacing.xl,
        AppSpacing.s,
      ),
      child: Wrap(
        spacing: AppSpacing.m,
        runSpacing: AppSpacing.m,
        alignment: WrapAlignment.spaceBetween,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          SizedBox(
            width: 320,
            child: SearchField(
              hintText: l10n.suppliersSearchHint,
              onChanged: (q) => _load(search: q),
            ),
          ),
          if (_canCreate)
            FilledButton.icon(
              onPressed: _addSupplier,
              icon: const Icon(Icons.add),
              label: Text(l10n.supplierAdd),
            ),
        ],
      ),
    );

    return LoadingOverlay(
      visible: state.status == SuppliersStatus.loading || state.busy,
      label: l10n.commonLoading,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          header,
          Expanded(
            child: state.status == SuppliersStatus.error
                ? Center(
                    child: Text(l10n.commonError, style: typography.labelSmall),
                  )
                : AppResponsiveLayout(
                    desktop: _masterTable(l10n, state),
                    tablet: _masterTable(l10n, state),
                    compact: _masterCards(l10n, state, typography),
                  ),
          ),
          _pager(l10n, state.request.page, state.total),
        ],
      ),
    );
  }

  Widget _buildBalancesTab(AppLocalizations l10n) {
    final state = ref.watch(suppliersControllerProvider);
    final typography = context.appTypography;

    final header = Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.xl,
        AppSpacing.l,
        AppSpacing.xl,
        AppSpacing.s,
      ),
      child: Wrap(
        spacing: AppSpacing.m,
        runSpacing: AppSpacing.m,
        alignment: WrapAlignment.spaceBetween,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          SizedBox(
            width: 320,
            child: SearchField(
              hintText: l10n.suppliersSearchHint,
              onChanged: (q) => _loadBalances(search: q),
            ),
          ),
        ],
      ),
    );

    return LoadingOverlay(
      visible: state.status == SuppliersStatus.loading || state.busy,
      label: l10n.commonLoading,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          header,
          Expanded(
            child: AppResponsiveLayout(
              desktop: _balancesTable(l10n, state),
              tablet: _balancesTable(l10n, state),
              compact: _balancesCards(l10n, state, typography),
            ),
          ),
          _pager(l10n, state.balancesRequest.page, state.balancesTotal),
        ],
      ),
    );
  }

  Widget _pager(AppLocalizations l10n, int page, int total) {
    final pageCount = (total / _pageSize).ceil();
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.xl,
        AppSpacing.s,
        AppSpacing.xl,
        AppSpacing.l,
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          Text(
            '$page / ${pageCount == 0 ? 1 : pageCount}',
            style: context.appTypography.bodySecondary,
          ),
          const SizedBox(width: AppSpacing.m),
          IconButton(
            onPressed: page <= 1 ? null : () => _toPage(page - 1),
            icon: Icon(AppDirectionalIcons.previous(context)),
            tooltip: l10n.commonPrevious,
          ),
          IconButton(
            onPressed: page >= pageCount || pageCount == 0
                ? null
                : () => _toPage(page + 1),
            icon: Icon(AppDirectionalIcons.next(context)),
            tooltip: l10n.commonNext,
          ),
        ],
      ),
    );
  }

  Widget _masterTable(AppLocalizations l10n, SuppliersViewState state) {
    return AppDataTable(
      emptyMessage: l10n.suppliersEmpty,
      columns: [
        DataColumn(label: Text(l10n.supplierName)),
        DataColumn(label: Text(l10n.supplierCode)),
        DataColumn(label: Text(l10n.supplierPhone)),
        DataColumn(label: Text(l10n.supplierContactPerson)),
        DataColumn(label: Text(l10n.supplierBalance)),
        DataColumn(label: Text(l10n.supplierCreditLimit)),
        DataColumn(label: Text(l10n.userStatusActive)),
        DataColumn(label: Text('')),
      ],
      rows: [
        for (final s in state.suppliers)
          DataRow(cells: [
            DataCell(Text(s.name)),
            DataCell(Text(s.code ?? '')),
            DataCell(Text(s.phone ?? '')),
            DataCell(Text(s.contactPerson ?? '')),
            DataCell(Text(Money.fromUnits(s.balanceMicros).format())),
            DataCell(Text(Money.fromUnits(s.creditLimitMicros).format())),
            DataCell(
              _ActivePill(active: s.isActive, l10n: l10n),
            ),
            DataCell(_actions(l10n, s)),
          ]),
      ],
    );
  }

  Widget _masterCards(
    AppLocalizations l10n,
    SuppliersViewState state,
    AppTypography typography,
  ) {
    if (state.suppliers.isEmpty) {
      return Center(
        child: Text(l10n.suppliersEmpty, style: typography.labelSmall),
      );
    }
    return ListView(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.m,
        vertical: AppSpacing.s,
      ),
      children: [
        for (final s in state.suppliers)
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
                        child: Text(s.name, style: typography.sectionTitle),
                      ),
                      _ActivePill(active: s.isActive, l10n: l10n),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.s),
                  Text(
                    '${l10n.supplierBalance}: '
                    '${Money.fromUnits(s.balanceMicros).format()} · '
                    '${l10n.supplierPhone}: ${s.phone ?? '-'}',
                    style: typography.bodySecondary,
                  ),
                  if (_canEdit) ...[
                    const SizedBox(height: AppSpacing.s),
                    Align(
                      alignment: AlignmentDirectional.centerEnd,
                      child: _actions(l10n, s),
                    ),
                  ],
                ],
              ),
            ),
          ),
      ],
    );
  }

  Widget _balancesTable(AppLocalizations l10n, SuppliersViewState state) {
    return AppDataTable(
      emptyMessage: l10n.suppliersEmpty,
      columns: [
        DataColumn(label: Text(l10n.supplierName)),
        DataColumn(label: Text(l10n.supplierCode)),
        DataColumn(label: Text(l10n.statementOpening)),
        DataColumn(label: Text(l10n.statementDebit)),
        DataColumn(label: Text(l10n.statementCredit)),
        DataColumn(label: Text(l10n.supplierBalance)),
        DataColumn(label: Text(l10n.supplierCreditLimit)),
        DataColumn(label: Text('')),
      ],
      rows: [
        for (final b in state.balances)
          DataRow(cells: [
            DataCell(Text(b.name)),
            DataCell(Text(b.code ?? '')),
            DataCell(Text(Money.fromUnits(b.openingMicros).format())),
            DataCell(Text(Money.fromUnits(b.invoicesNetMicros).format())),
            DataCell(Text(Money.fromUnits(b.returnsNetMicros).format())),
            DataCell(
              Text(
                Money.fromUnits(b.balanceMicros).format(),
                style: context.appTypography.numericStrong,
              ),
            ),
            DataCell(Text(Money.fromUnits(b.creditLimitMicros).format())),
            DataCell(
              IconButton(
                icon: const Icon(Icons.receipt_long_outlined),
                tooltip: l10n.supplierStatement,
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints.tightFor(
                    width: 32, height: 32),
                onPressed: () => _openStatement(b.supplierId),
              ),
            ),
          ]),
      ],
    );
  }

  Widget _balancesCards(
    AppLocalizations l10n,
    SuppliersViewState state,
    AppTypography typography,
  ) {
    if (state.balances.isEmpty) {
      return Center(
        child: Text(l10n.suppliersEmpty, style: typography.labelSmall),
      );
    }
    return ListView(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.m,
        vertical: AppSpacing.s,
      ),
      children: [
        for (final b in state.balances)
          Card(
            margin: const EdgeInsets.only(bottom: AppSpacing.m),
            child: Padding(
              padding: const EdgeInsets.all(AppSpacing.m),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(b.name, style: typography.sectionTitle),
                  const SizedBox(height: AppSpacing.s),
                  Text(
                    '${l10n.supplierBalance}: '
                    '${Money.fromUnits(b.balanceMicros).format()} · '
                    '${l10n.statementOpening}: '
                    '${Money.fromUnits(b.openingMicros).format()}',
                    style: typography.bodySecondary,
                  ),
                  const SizedBox(height: AppSpacing.s),
                  Align(
                    alignment: AlignmentDirectional.centerEnd,
                    child: OutlinedButton.icon(
                      onPressed: () => _openStatement(b.supplierId),
                      icon: const Icon(Icons.receipt_long_outlined),
                      label: Text(l10n.supplierStatement),
                    ),
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }

  Widget _actions(AppLocalizations l10n, SupplierRow s) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (_canView)
          IconButton(
            icon: const Icon(Icons.receipt_long_outlined),
            tooltip: l10n.supplierStatement,
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints.tightFor(width: 32, height: 32),
            onPressed: () => _openStatement(s.id),
          ),
        if (_canEdit) ...[
          IconButton(
            icon: const Icon(Icons.edit_outlined),
            tooltip: l10n.commonEdit,
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints.tightFor(width: 32, height: 32),
            onPressed: () => _editSupplier(s),
          ),
          IconButton(
            icon: Icon(s.isActive ? Icons.block : Icons.check_circle_outline),
            tooltip: s.isActive ? l10n.userDeactivate : l10n.userActivate,
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints.tightFor(width: 32, height: 32),
            onPressed: () => _toggleActive(s),
          ),
        ],
      ],
    );
  }
}

class _ActivePill extends StatelessWidget {
  const _ActivePill({required this.active, required this.l10n});

  final bool active;
  final AppLocalizations l10n;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.s, vertical: 4),
      decoration: BoxDecoration(
        color: active
            ? Theme.of(context).colorScheme.surfaceContainerHigh
            : Theme.of(context).colorScheme.errorContainer,
        borderRadius: BorderRadius.circular(AppRadius.sm),
      ),
      child: Text(
        active ? l10n.userStatusActive : l10n.userStatusInactive,
        style: context.appTypography.labelSmall,
      ),
    );
  }
}