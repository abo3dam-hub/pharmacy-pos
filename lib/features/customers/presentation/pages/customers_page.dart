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
import '../../application/customers_controller.dart';
import '../../../prescriptions/presentation/pages/prescriptions_page.dart';
import '../widgets/customer_dialog.dart';
import '../../../../core/widgets/app_rtl_icons.dart';

/// §16 customers section: the customer/patient registry (tab 1) and their
/// prescriptions (tab 2). Later phases add the POS/sales ledger (§11).
class CustomersPage extends ConsumerStatefulWidget {
  const CustomersPage({super.key});

  @override
  ConsumerState<CustomersPage> createState() => _CustomersPageState();
}

class _CustomersPageState extends ConsumerState<CustomersPage> {
  static const int _pageSize = 30;

  @override
  void initState() {
    super.initState();
    Future.microtask(() async {
      final auth = ref.read(authControllerProvider);
      if (auth.permissions.contains(Perm.customersView)) {
        await ref
            .read(customersControllerProvider.notifier)
            .load(actingRoleId: auth.actingRoleId);
      }
    });
  }

  bool get _canCreate =>
      ref.read(authControllerProvider).permissions.contains(Perm.customersCreate);
  bool get _canEdit =>
      ref.read(authControllerProvider).permissions.contains(Perm.customersEdit);
  bool get _canView =>
      ref.read(authControllerProvider).permissions.contains(Perm.customersView);
  String? get _actingUserId => ref.read(authControllerProvider).user?.id;
  String? get _actingRoleId => ref.read(authControllerProvider).actingRoleId;

  void _showFailure(Failure? failure) {
    showFailureSnack(context, failure);
  }

  Future<void> _load({String search = ''}) async {
    final failure = await ref
        .read(customersControllerProvider.notifier)
        .load(search: search, actingRoleId: _actingRoleId);
    _showFailure(failure);
  }

  Future<void> _addCustomer() async {
    final l10n = AppLocalizations.of(context);
    final draft = await showCustomerFormDialog(
      context,
      title: l10n.customerAddTitle,
    );
    if (draft == null || !mounted) return;
    final outcome = await ref
        .read(customersControllerProvider.notifier)
        .add(draft, actingUserId: _actingUserId, actingRoleId: _actingRoleId);
    if (outcome == null && mounted) {
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(content: Text(l10n.customerCreatedMessage)));
    } else {
      _showFailure(outcome);
    }
    if (mounted) await _load();
  }

  Future<void> _editCustomer(CustomerRow customer) async {
    final l10n = AppLocalizations.of(context);
    final draft = await showCustomerFormDialog(
      context,
      title: l10n.customerEditTitle,
      initial: customer,
    );
    if (draft == null || !mounted) return;
    final outcome = await ref
        .read(customersControllerProvider.notifier)
        .update(customer.id, draft,
            actingUserId: _actingUserId, actingRoleId: _actingRoleId);
    if (outcome == null && mounted) {
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(content: Text(l10n.customerUpdatedMessage)));
    } else {
      _showFailure(outcome);
    }
    if (mounted) await _load();
  }

  Future<void> _toggleActive(CustomerRow customer) async {
    final l10n = AppLocalizations.of(context);
    final activating = !customer.isActive;
    final confirmed = await showAppConfirmDialog(
      context,
      title: activating ? l10n.userActivate : l10n.userDeactivate,
      message: activating
          ? l10n.customerActivateConfirmMessage(customer.name)
          : l10n.customerDeactivateConfirmMessage(customer.name),
      confirmLabel: activating ? l10n.userActivate : l10n.userDeactivate,
      destructive: !activating,
    );
    if (!confirmed || !mounted) return;
    final outcome = await ref
        .read(customersControllerProvider.notifier)
        .toggleActive(customer.id, activating,
            actingUserId: _actingUserId, actingRoleId: _actingRoleId);
    if (outcome == null && mounted) {
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(
          content: Text(activating
              ? l10n.customerActivatedMessage
              : l10n.customerDeactivatedMessage),
        ));
    } else {
      _showFailure(outcome);
    }
    if (mounted) await _load();
  }

  Future<void> _toggleAccount(CustomerRow customer) async {
    final l10n = AppLocalizations.of(context);
    final enabling = !customer.hasAccount;
    final confirmed = await showAppConfirmDialog(
      context,
      title: enabling ? l10n.customerAccountEnabled : l10n.customerAccountDisabled,
      message: enabling
          ? l10n.customerAccountEnableConfirmMessage(customer.name)
          : l10n.customerAccountDisableConfirmMessage(customer.name),
      confirmLabel: enabling
          ? l10n.customerAccountEnabled
          : l10n.customerAccountDisabled,
    );
    if (!confirmed || !mounted) return;
    final outcome = await ref
        .read(customersControllerProvider.notifier)
        .setAccount(customer.id, enabling,
            actingUserId: _actingUserId, actingRoleId: _actingRoleId);
    if (outcome == null && mounted) {
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(
          content: Text(enabling
              ? l10n.customerAccountEnabledMessage
              : l10n.customerAccountDisabledMessage),
        ));
    } else {
      _showFailure(outcome);
    }
    if (mounted) await _load();
  }

  void _toPage(int page) {
    final state = ref.read(customersControllerProvider);
    final pageCount = (state.total / _pageSize).ceil();
    if (page < 1 || page > (pageCount == 0 ? 1 : pageCount)) return;
    ref
        .read(customersControllerProvider.notifier)
        .load(search: state.request.search, page: page, actingRoleId: _actingRoleId);
  }

  void _openStatement(String customerId) =>
      context.go('/customers/statement/$customerId');

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
                Tab(text: l10n.customersTab),
                Tab(text: l10n.prescriptionsTab),
              ],
            ),
          ),
          Expanded(
            child: TabBarView(
              children: [
                _buildCustomersTab(l10n),
                const PrescriptionsList(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCustomersTab(AppLocalizations l10n) {
    final state = ref.watch(customersControllerProvider);
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
              hintText: l10n.customersSearchHint,
              onChanged: (q) => _load(search: q),
            ),
          ),
          if (_canCreate)
            FilledButton.icon(
              onPressed: _addCustomer,
              icon: const Icon(Icons.person_add_alt),
              label: Text(l10n.customerAdd),
            ),
        ],
      ),
    );

    return LoadingOverlay(
      visible: state.status == CustomersStatus.loading || state.busy,
      label: l10n.commonLoading,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          header,
          Expanded(
            child: state.status == CustomersStatus.error
                ? Center(
                    child: Text(l10n.commonError, style: typography.labelSmall),
                  )
                : AppResponsiveLayout(
                    desktop: _customersTable(l10n, state),
                    tablet: _customersTable(l10n, state),
                    compact: _customersCards(l10n, state, typography),
                  ),
          ),
          _pager(l10n, state.request.page, state.total),
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

  Widget _customersTable(AppLocalizations l10n, CustomersViewState state) {
    return AppDataTable(
      emptyMessage: l10n.customersEmpty,
      columns: [
        DataColumn(label: Text(l10n.customerName)),
        DataColumn(label: Text(l10n.customerPhone)),
        DataColumn(label: Text(l10n.customerEmail)),
        DataColumn(label: Text(l10n.customerBalance)),
        DataColumn(label: Text(l10n.customerAccount)),
        DataColumn(label: Text(l10n.userStatusActive)),
        DataColumn(label: Text('')),
      ],
      rows: [
        for (final c in state.customers)
          DataRow(cells: [
            DataCell(Text(c.name)),
            DataCell(Text(c.phone ?? '')),
            DataCell(Text(c.email ?? '')),
            DataCell(
              Text(
                Money.fromUnits(c.balanceMicros).format(),
                style: context.appTypography.numeric,
              ),
            ),
            DataCell(_AccountPill(enabled: c.hasAccount, l10n: l10n)),
            DataCell(_ActivePill(active: c.isActive, l10n: l10n)),
            DataCell(_actions(l10n, c)),
          ]),
      ],
    );
  }

  Widget _customersCards(
    AppLocalizations l10n,
    CustomersViewState state,
    AppTypography typography,
  ) {
    if (state.customers.isEmpty) {
      return Center(
        child: Text(l10n.customersEmpty, style: typography.labelSmall),
      );
    }
    return ListView(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.m,
        vertical: AppSpacing.s,
      ),
      children: [
        for (final c in state.customers)
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
                        child: Text(c.name, style: typography.sectionTitle),
                      ),
                      _ActivePill(active: c.isActive, l10n: l10n),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.s),
                  Text(
                    '${l10n.customerBalance}: '
                    '${Money.fromUnits(c.balanceMicros).format()} · '
                    '${l10n.customerPhone}: ${c.phone ?? '-'}',
                    style: typography.bodySecondary,
                  ),
                  if (_canEdit) ...[
                    const SizedBox(height: AppSpacing.s),
                    Align(
                      alignment: AlignmentDirectional.centerEnd,
                      child: _actions(l10n, c),
                    ),
                  ],
                ],
              ),
            ),
          ),
      ],
    );
  }

  Widget _actions(AppLocalizations l10n, CustomerRow c) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (_canView && c.hasAccount)
          IconButton(
            icon: const Icon(Icons.receipt_long_outlined),
            tooltip: l10n.customerStatement,
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints.tightFor(width: 32, height: 32),
            onPressed: () => _openStatement(c.id),
          ),
        if (_canEdit) ...[
          IconButton(
            icon: const Icon(Icons.account_balance_wallet_outlined),
            tooltip: c.hasAccount
                ? l10n.customerAccountDisabled
                : l10n.customerAccountEnabled,
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints.tightFor(width: 32, height: 32),
            onPressed: () => _toggleAccount(c),
          ),
          IconButton(
            icon: const Icon(Icons.edit_outlined),
            tooltip: l10n.commonEdit,
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints.tightFor(width: 32, height: 32),
            onPressed: () => _editCustomer(c),
          ),
          IconButton(
            icon: Icon(c.isActive ? Icons.block : Icons.check_circle_outline),
            tooltip: c.isActive ? l10n.userDeactivate : l10n.userActivate,
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints.tightFor(width: 32, height: 32),
            onPressed: () => _toggleActive(c),
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

class _AccountPill extends StatelessWidget {
  const _AccountPill({required this.enabled, required this.l10n});

  final bool enabled;
  final AppLocalizations l10n;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.s, vertical: 4),
      decoration: BoxDecoration(
        color: enabled
            ? Theme.of(context).colorScheme.primaryContainer
            : Theme.of(context).colorScheme.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(AppRadius.sm),
      ),
      child: Text(
        enabled ? l10n.customerAccountEnabled : l10n.customerAccountDisabled,
        style: context.appTypography.labelSmall,
      ),
    );
  }
}