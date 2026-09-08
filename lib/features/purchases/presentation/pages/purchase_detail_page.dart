import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/constants/permission_codes.dart';
import '../../../../core/di/providers.dart';
import '../../../../core/errors/exceptions.dart';
import '../../../../core/errors/failures.dart';
import '../../../../core/money/money.dart';
import '../../../../core/theme/app_dimensions.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/widgets/app_data_table.dart';
import '../../../../core/widgets/confirm_dialog.dart';
import '../../../../core/widgets/loading_overlay.dart';
import '../../../../data/daos/purchase_dao.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../../shared/models/enums.dart';
import '../widgets/purchase_return_dialog.dart';
import '../widgets/purchase_status_chip.dart';
import '../widgets/receive_dialog.dart';
import '../../../../core/widgets/app_rtl_icons.dart';

/// Purchase invoice detail page — header, lines (effective qty/cost), bonuses
/// and the receive / cancel / return actions. Routed at
/// `/purchases/detail/:id`.
class PurchaseDetailPage extends ConsumerStatefulWidget {
  const PurchaseDetailPage({super.key, required this.invoiceId});

  final String invoiceId;

  @override
  ConsumerState<PurchaseDetailPage> createState() =>
      _PurchaseDetailPageState();
}

class _PurchaseDetailPageState extends ConsumerState<PurchaseDetailPage> {
  PurchaseDetailView? _detail;
  bool _loading = true;

  String? get _actingUserId => ref.read(authControllerProvider).user?.id;
  String? get _actingRoleId => ref.read(authControllerProvider).actingRoleId;

  @override
  void initState() {
    super.initState();
    Future.microtask(_load);
  }

  Future<void> _load() async {
    final auth = ref.read(authControllerProvider);
    if (!auth.permissions.contains(Perm.purchasesView)) {
      setState(() => _loading = false);
      return;
    }
    try {
      final detail = await ref
          .read(getPurchaseDetailUseCaseProvider)
          .call(widget.invoiceId, actingRoleId: auth.actingRoleId);
      if (!mounted) return;
      setState(() {
        _detail = detail;
        _loading = false;
      });
    } on AppException catch (e) {
      if (mounted) {
        setState(() => _loading = false);
        _showFailure(e.failure);
      }
    }
  }

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

  bool _has(String perm) =>
      ref.read(authControllerProvider).permissions.contains(perm);

  Future<void> _receive() async {
    final l10n = AppLocalizations.of(context);
    final detail = _detail;
    if (detail == null) return;
    final inputs = await showReceiveDialog(context, lines: detail.lines);
    if (inputs == null || !mounted) return;
    final outcome = await ref
        .read(purchasesControllerProvider.notifier)
        .receive(detail.invoice.id,
            inputs: inputs,
            actingUserId: _actingUserId,
            actingRoleId: _actingRoleId);
    if (outcome == null && mounted) {
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(content: Text(l10n.purchaseReceivedMessage)));
      await _load();
    } else {
      _showFailure(outcome);
    }
  }

  Future<void> _cancel() async {
    final l10n = AppLocalizations.of(context);
    final detail = _detail;
    if (detail == null) return;
    final confirmed = await showAppConfirmDialog(
      context,
      title: l10n.purchaseCancel,
      message: l10n.purchaseCancelConfirm,
      confirmLabel: l10n.purchaseCancel,
      destructive: true,
    );
    if (!confirmed || !mounted) return;
    final outcome = await ref
        .read(purchasesControllerProvider.notifier)
        .cancel(detail.invoice.id,
            actingUserId: _actingUserId, actingRoleId: _actingRoleId);
    if (outcome == null && mounted) {
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(content: Text(l10n.purchaseCancelledMessage)));
      await _load();
    } else {
      _showFailure(outcome);
    }
  }

  Future<void> _return() async {
    final l10n = AppLocalizations.of(context);
    final detail = _detail;
    if (detail == null) return;
    final available = <String, int>{};
    for (final l in detail.lines) {
      final qty = await ref
          .read(getAvailableReturnQtyUseCaseProvider)
          .call(l.line.id, actingRoleId: _actingRoleId);
      available[l.line.id] = qty;
    }
    if (!mounted) return;
    final request = await showReturnDialog(
      context,
      lines: detail.lines,
      availableByLine: available,
      returnNumber: 'RET-${DateTime.now().millisecondsSinceEpoch}',
      invoiceId: detail.invoice.id,
      userId: _actingUserId ?? '',
    );
    if (request == null || !mounted) return;
    final outcome = await ref
        .read(purchasesControllerProvider.notifier)
        .recordReturn(request,
            actingUserId: _actingUserId, actingRoleId: _actingRoleId);
    if (outcome == null && mounted) {
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(content: Text(l10n.purchaseReturnSavedMessage)));
      await _load();
    } else {
      _showFailure(outcome);
    }
  }

  String _fmtDate(int millis) {
    final d = DateTime.fromMillisecondsSinceEpoch(millis);
    String two(int n) => n.toString().padLeft(2, '0');
    return '${d.year}-${two(d.month)}-${two(d.day)}';
  }

  String _bonusLabel(AppLocalizations l10n, PurchaseBonusType t) =>
      switch (t) {
        PurchaseBonusType.bonus_1 => l10n.purchaseBonus1,
        PurchaseBonusType.bonus_2 => l10n.purchaseBonus2,
        PurchaseBonusType.gift => l10n.purchaseBonusGift,
      };

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final typography = context.appTypography;
    final detail = _detail;

    final isPending = detail?.invoice.purchaseStatus == PurchaseStatus.pending;
    final canReceive = isPending && _has(Perm.purchasesEdit);
    final canCancel = isPending && _has(Perm.purchasesVoid);
    final canReturn =
        !isPending && _has(Perm.returnProducts) &&
        detail?.invoice.purchaseStatus == PurchaseStatus.received;

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
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              IconButton(
                icon: Icon(AppDirectionalIcons.back(context)),
                tooltip: l10n.commonBack,
                onPressed: () => context.go('/purchases'),
              ),
              Text(l10n.purchaseDetailTitle, style: typography.pageTitle),
            ],
          ),
          Wrap(
            spacing: AppSpacing.m,
            children: [
              if (canReceive)
                FilledButton.icon(
                  onPressed: _receive,
                  icon: const Icon(Icons.inventory_2_outlined),
                  label: Text(l10n.purchaseReceive),
                ),
              if (canReturn)
                FilledButton.icon(
                  onPressed: _return,
                  icon: const Icon(Icons.assignment_return_outlined),
                  label: Text(l10n.purchaseReturn),
                ),
              if (canCancel)
                OutlinedButton.icon(
                  onPressed: _cancel,
                  icon: const Icon(Icons.block),
                  label: Text(l10n.purchaseCancel),
                ),
            ],
          ),
        ],
      ),
    );

    return LoadingOverlay(
      visible: _loading,
      label: l10n.commonLoading,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          header,
          if (detail == null)
            Expanded(
              child: Center(
                child: Text(l10n.commonError, style: typography.labelSmall),
              ),
            )
          else ...[
            _invoiceSummary(l10n, detail),
            Padding(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.xl,
                AppSpacing.m,
                AppSpacing.xl,
                AppSpacing.s,
              ),
              child: Text(l10n.purchaseItemPlaceholder,
                  style: typography.sectionTitle),
            ),
            Expanded(
              child: AppDataTable(
                emptyMessage: l10n.purchaseNoLines,
                columns: [
                  DataColumn(label: Text(l10n.purchaseItemPlaceholder)),
                  DataColumn(label: Text(l10n.purchaseQty)),
                  DataColumn(label: Text(l10n.purchaseUnitCost)),
                  DataColumn(label: Text(l10n.purchaseDiscountPct)),
                  DataColumn(label: Text(l10n.purchaseBonus)),
                  DataColumn(label: Text(l10n.purchaseTotal)),
                ],
                rows: [
                  for (final l in detail.lines)
                    DataRow(cells: [
                      DataCell(Text(l.itemName)),
                      DataCell(Text('${l.line.quantityBase}')),
                      DataCell(Text(Money.fromUnits(l.line.unitCostMicros).format())),
                      DataCell(Text(_percent(l.line.discountBasisPoints))),
                      DataCell(Text(
                        l.line.bonusQuantityBase > 0
                            ? '+${l.line.bonusQuantityBase}'
                            : '',
                      )),
                      DataCell(Text(Money.fromUnits(l.line.lineTotalMicros).format())),
                    ]),
                ],
              ),
            ),
            if (detail.bonuses.isNotEmpty) ...[
              Padding(
                padding: const EdgeInsets.fromLTRB(
                    AppSpacing.xl, AppSpacing.m, AppSpacing.xl, AppSpacing.s),
                child: Text(l10n.purchaseBonusButton,
                    style: typography.sectionTitle),
              ),
              AppDataTable(
                emptyMessage: l10n.purchaseNoLines,
                columns: [
                  DataColumn(label: Text(l10n.purchaseItemPlaceholder)),
                  DataColumn(label: Text(l10n.purchaseBonus)),
                  DataColumn(label: Text(l10n.purchaseQty)),
                ],
                rows: [
                  for (final b in detail.bonuses)
                    DataRow(cells: [
                      DataCell(Text(b.itemName ?? '')),
                      DataCell(Text(_bonusLabel(l10n, b.bonus.bonusType))),
                      DataCell(Text('${b.bonus.bonusQuantityBase}')),
                    ]),
                ],
              ),
            ],
            Padding(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.xl,
                AppSpacing.l,
                AppSpacing.xl,
                AppSpacing.xxl,
              ),
              child: _summaryFooter(l10n, detail),
            ),
          ],
        ],
      ),
    );
  }

  Widget _invoiceSummary(AppLocalizations l10n, PurchaseDetailView detail) {
    final i = detail.invoice;
    final typography = context.appTypography;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xl),
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.l),
          child: Wrap(
            spacing: AppSpacing.l,
            runSpacing: AppSpacing.s,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              Text(i.invoiceNumber, style: typography.invoiceNumber),
              Text('${l10n.purchasesFilterSupplier}: ${detail.supplierName}',
                  style: typography.body),
              Text('${l10n.purchaseInvoiceDate}: ${_fmtDate(i.invoiceDate)}',
                  style: typography.bodySecondary),
              if (i.expectedDate != null)
                Text(
                    '${l10n.purchaseExpectedDate}: ${_fmtDate(i.expectedDate!)}',
                    style: typography.bodySecondary),
              if (i.notes != null && i.notes!.isNotEmpty)
                Text(i.notes!, style: typography.bodySecondary),
              PurchaseStatusChip(status: i.purchaseStatus, l10n: l10n),
            ],
          ),
        ),
      ),
    );
  }

  Widget _summaryFooter(AppLocalizations l10n, PurchaseDetailView detail) {
    final i = detail.invoice;
    final typography = context.appTypography;
    Row row(String label, int micros) => Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(label, style: typography.body),
            Text(Money.fromUnits(micros).format(),
                style: typography.numericStrong),
          ],
        );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        row(l10n.purchaseSubtotal, i.subtotalMicros),
        row(l10n.purchaseDiscount, i.discountTotalMicros),
        row(l10n.purchaseGrandTotal, i.totalMicros),
        const Divider(height: AppSpacing.xl),
        row(l10n.purchasePaid, i.paidMicros),
        row(l10n.purchaseRemaining, i.remainingMicros),
      ],
    );
  }

  String _percent(int basisPoints) {
    if (basisPoints == 0) return '';
    return '${(basisPoints / 100).toStringAsFixed(basisPoints % 100 == 0 ? 0 : 2)}%';
  }
}