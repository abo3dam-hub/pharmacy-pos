import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/constants/permission_codes.dart';
import '../../../../core/di/providers.dart';
import '../../../../core/errors/failures.dart';
import '../../../../core/money/money.dart';
import '../../../../core/theme/app_dimensions.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/widgets/app_data_table.dart';
import '../../../../core/widgets/loading_overlay.dart';
import '../../../../core/widgets/responsive_layout.dart';
import '../../../../core/widgets/search_field.dart';
import '../../../../data/daos/purchase_dao.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../../shared/models/enums.dart';
import '../../application/purchases_controller.dart';
import '../widgets/purchase_status_chip.dart';

/// §12 purchases section: searchable, filterable invoice grid with the new
/// invoice action. Create/edit/receive/cancel/return live in the form and
/// detail pages.
class PurchasesPage extends ConsumerStatefulWidget {
  const PurchasesPage({super.key});

  @override
  ConsumerState<PurchasesPage> createState() => _PurchasesPageState();
}

class _PurchasesPageState extends ConsumerState<PurchasesPage> {
  static const int _pageSize = 30;

  List<({String id, String name})> _suppliers = const [];
  String? _supplierId;
  PurchaseStatus? _statusFilter;
  int _page = 1;

  @override
  void initState() {
    super.initState();
    Future.microtask(() async {
      final auth = ref.read(authControllerProvider);
      if (auth.permissions.contains(Perm.purchasesView)) {
        await ref
            .read(allSuppliersUseCaseProvider)
            .call(actingRoleId: auth.actingRoleId)
            .then((rows) {
          if (mounted) {
            setState(() => _suppliers = [
                  for (final r in rows) (id: r.id, name: r.name),
                ]);
          }
        });
        await _load();
      }
    });
  }

  bool get _canCreate =>
      ref.read(authControllerProvider).permissions.contains(Perm.purchasesCreate);
  bool get _canEdit =>
      ref.read(authControllerProvider).permissions.contains(Perm.purchasesEdit);
  String? get _actingRoleId => ref.read(authControllerProvider).actingRoleId;

  void _showFailure(Failure? failure) {
    if (failure == null || !mounted) return;
    final l10n = AppLocalizations.of(context);
    final message = switch (failure) {
      UnauthorizedFailure() => l10n.authPermissionDenied,
      _ => l10n.authSaveError,
    };
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _load({String search = ''}) async {
    final failure = await ref
        .read(purchasesControllerProvider.notifier)
        .load(
          search: search,
          page: _page,
          supplierId: _supplierId,
          status: _statusFilter,
          actingRoleId: _actingRoleId,
        );
    _showFailure(failure);
  }

  Future<void> _setSupplier(String? id) async {
    setState(() {
      _supplierId = id?.isEmpty ?? true ? null : id;
      _page = 1;
    });
    await _load();
  }

  Future<void> _setStatus(PurchaseStatus? status) async {
    setState(() {
      _statusFilter = status;
      _page = 1;
    });
    await _load();
  }

  void _toPage(int page) {
    final state = ref.read(purchasesControllerProvider);
    final pageCount = (state.total / _pageSize).ceil();
    if (page < 1 || page > (pageCount == 0 ? 1 : pageCount)) return;
    setState(() => _page = page);
    _load(search: state.request.search);
  }

  void _openDetail(String id) => context.go('/purchases/detail/$id');

  void _openEdit(String id) => context.go('/purchases/edit/$id');

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final state = ref.watch(purchasesControllerProvider);
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
              hintText: l10n.purchasesSearchHint,
              onChanged: (q) {
                setState(() => _page = 1);
                _load(search: q);
              },
            ),
          ),
          Wrap(
            spacing: AppSpacing.m,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              DropdownButtonHideUnderline(
                child: DropdownButton<String?>(
                  value: _supplierId,
                  hint: Text(l10n.purchasesFilterSupplier),
                  items: [
                    DropdownMenuItem(
                      value: null,
                      child: Text(l10n.purchasesFilterSupplier),
                    ),
                    for (final s in _suppliers)
                      DropdownMenuItem(value: s.id, child: Text(s.name)),
                  ],
                  onChanged: _setSupplier,
                ),
              ),
              DropdownButtonHideUnderline(
                child: DropdownButton<PurchaseStatus?>(
                  value: _statusFilter,
                  hint: Text(l10n.purchasesFilterStatus),
                  items: [
                    DropdownMenuItem(
                      value: null,
                      child: Text(l10n.purchasesFilterStatus),
                    ),
                    DropdownMenuItem(
                      value: PurchaseStatus.pending,
                      child: Text(l10n.purchaseStatusPending),
                    ),
                    DropdownMenuItem(
                      value: PurchaseStatus.received,
                      child: Text(l10n.purchaseStatusReceived),
                    ),
                    DropdownMenuItem(
                      value: PurchaseStatus.cancelled,
                      child: Text(l10n.purchaseStatusCancelled),
                    ),
                  ],
                  onChanged: _setStatus,
                ),
              ),
              if (_canCreate)
                FilledButton.icon(
                  onPressed: () => context.go('/purchases/new'),
                  icon: const Icon(Icons.add),
                  label: Text(l10n.purchaseAddInvoice),
                ),
            ],
          ),
        ],
      ),
    );

    return LoadingOverlay(
      visible: state.status == PurchasesStatus.loading || state.busy,
      label: l10n.commonLoading,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          header,
          Expanded(
            child: state.status == PurchasesStatus.error
                ? Center(
                    child: Text(l10n.commonError, style: typography.labelSmall),
                  )
                : AppResponsiveLayout(
                    desktop: _buildTable(l10n, state),
                    tablet: _buildTable(l10n, state),
                    compact: _buildCards(l10n, state, typography),
                  ),
          ),
          _buildPager(l10n, state),
        ],
      ),
    );
  }

  Widget _buildTable(AppLocalizations l10n, PurchasesViewState state) {
    return AppDataTable(
      emptyMessage: l10n.purchasesEmpty,
      columns: [
        DataColumn(label: Text(l10n.purchaseInvoiceNumber)),
        DataColumn(label: Text(l10n.purchasesFilterSupplier)),
        DataColumn(label: Text(l10n.purchaseInvoiceDate)),
        DataColumn(label: Text(l10n.purchaseStatusLabel)),
        DataColumn(label: Text(l10n.purchaseTotal)),
        DataColumn(label: Text(l10n.purchasePaid)),
        DataColumn(label: Text(l10n.purchaseRemaining)),
        DataColumn(label: Text('')),
      ],
      rows: [
        for (final view in state.invoices)
          DataRow(cells: [
            DataCell(Text(view.invoice.invoiceNumber)),
            DataCell(Text(view.supplierName)),
            DataCell(Text(_fmtDate(view.invoice.invoiceDate))),
            DataCell(PurchaseStatusChip(status: view.invoice.purchaseStatus, l10n: l10n)),
            DataCell(
                Text(Money.fromUnits(view.invoice.totalMicros).format())),
            DataCell(Text(Money.fromUnits(view.invoice.paidMicros).format())),
            DataCell(
              Text(
                Money.fromUnits(view.invoice.remainingMicros).format(),
                style: context.appTypography.numericStrong,
              ),
            ),
            DataCell(_actions(l10n, view)),
          ]),
      ],
    );
  }

  Widget _buildCards(
    AppLocalizations l10n,
    PurchasesViewState state,
    AppTypography typography,
  ) {
    if (state.invoices.isEmpty) {
      return Center(
        child: Text(l10n.purchasesEmpty, style: typography.labelSmall),
      );
    }
    return ListView(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.m,
        vertical: AppSpacing.s,
      ),
      children: [
        for (final view in state.invoices)
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
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(view.invoice.invoiceNumber,
                                style: typography.invoiceNumber),
                            const SizedBox(height: AppSpacing.xs),
                            Text(
                              '${view.supplierName} · ${_fmtDate(view.invoice.invoiceDate)}',
                              style: typography.bodySecondary,
                            ),
                          ],
                        ),
                      ),
                      PurchaseStatusChip(status: view.invoice.purchaseStatus, l10n: l10n),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.s),
                  Text(
                    '${l10n.purchaseTotal}: '
                    '${Money.fromUnits(view.invoice.totalMicros).format()} · '
                    '${l10n.purchaseRemaining}: '
                    '${Money.fromUnits(view.invoice.remainingMicros).format()}',
                    style: typography.label,
                  ),
                  const SizedBox(height: AppSpacing.s),
                  Align(
                    alignment: AlignmentDirectional.centerEnd,
                    child: _actions(l10n, view),
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }

  Widget _actions(AppLocalizations l10n, PurchaseInvoiceView view) {
    final invoice = view.invoice;
    final isPending = invoice.purchaseStatus == PurchaseStatus.pending;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        IconButton(
          icon: const Icon(Icons.receipt_long_outlined),
          tooltip: l10n.purchaseDetailTitle,
          padding: EdgeInsets.zero,
          constraints: const BoxConstraints.tightFor(width: 32, height: 32),
          onPressed: () => _openDetail(invoice.id),
        ),
        if (_canEdit && isPending)
          IconButton(
            icon: const Icon(Icons.edit_outlined),
            tooltip: l10n.commonEdit,
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints.tightFor(width: 32, height: 32),
            onPressed: () => _openEdit(invoice.id),
          ),
      ],
    );
  }

  Widget _buildPager(AppLocalizations l10n, PurchasesViewState state) {
    final pageCount = (state.total / _pageSize).ceil();
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
            '${state.request.page} / ${pageCount == 0 ? 1 : pageCount}',
            style: context.appTypography.bodySecondary,
          ),
          const SizedBox(width: AppSpacing.m),
          IconButton(
            onPressed: _page <= 1 ? null : () => _toPage(_page - 1),
            icon: const Icon(Icons.chevron_left),
            tooltip: l10n.commonPrevious,
          ),
          IconButton(
            onPressed: _page >= pageCount || pageCount == 0
                ? null
                : () => _toPage(_page + 1),
            icon: const Icon(Icons.chevron_right),
            tooltip: l10n.commonNext,
          ),
        ],
      ),
    );
  }

  String _fmtDate(int millis) {
    final d = DateTime.fromMillisecondsSinceEpoch(millis);
    String two(int n) => n.toString().padLeft(2, '0');
    return '${d.year}-${two(d.month)}-${two(d.day)}';
  }
}