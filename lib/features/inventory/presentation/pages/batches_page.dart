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
import '../../../../core/widgets/confirm_dialog.dart';
import '../../../../core/widgets/loading_overlay.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../../shared/database/app_database.dart';
import '../../../../shared/models/enums.dart';
import '../../application/inventory_controller.dart';
import '../../domain/entities/inventory_item.dart';
import '../widgets/batch_dialog.dart';
import '../widgets/status_chips.dart';
import '../widgets/stock_adjust_dialog.dart';

/// Batch ledger page for a single item (§4.8, §4.9): batches table + recent
/// stock movements. Routed at `/inventory/batches/:itemId`.
class BatchesPage extends ConsumerStatefulWidget {
  const BatchesPage({super.key, required this.itemId});

  final String itemId;

  @override
  ConsumerState<BatchesPage> createState() => _BatchesPageState();
}

class _BatchesPageState extends ConsumerState<BatchesPage> {
  ItemRow? _item;

  @override
  void initState() {
    super.initState();
    Future.microtask(() async {
      final item =
          await ref.read(inventoryRepositoryProvider).findItem(widget.itemId);
      if (mounted) setState(() => _item = item);
      await ref
          .read(inventoryControllerProvider.notifier)
          .loadBatches(widget.itemId,
              actingRoleId: ref.read(authControllerProvider).actingRoleId);
    });
  }

  bool get _canAdjust =>
      ref.read(authControllerProvider).permissions.contains(Perm.stockAdjust);
  String? get _actingUserId => ref.read(authControllerProvider).user?.id;
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

  Future<void> _addBatch() async {
    final l10n = AppLocalizations.of(context);
    final result = await showBatchFormDialog(
      context,
      itemId: widget.itemId,
      hasExpiry: _item?.hasExpiry ?? false,
    );
    if (result == null || !mounted) return;
    final failure = await ref
        .read(inventoryControllerProvider.notifier)
        .addBatch(result.input,
            actingUserId: _actingUserId, actingRoleId: _actingRoleId);
    if (failure == null && mounted) {
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(content: Text(l10n.batchesAddedMessage)));
    } else {
      _showFailure(failure);
    }
  }

  Future<void> _adjustStock() async {
    final l10n = AppLocalizations.of(context);
    final batches = ref.read(inventoryControllerProvider).batches;
    final result = await showStockAdjustDialog(
      context,
      itemId: widget.itemId,
      batches: batches,
    );
    if (result == null || !mounted) return;
    final failure = await ref
        .read(inventoryControllerProvider.notifier)
        .adjustStock(result.input,
            actingUserId: _actingUserId, actingRoleId: _actingRoleId);
    if (failure == null && mounted) {
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(content: Text(l10n.adjustStockDone)));
    } else {
      _showFailure(failure);
    }
  }

  Future<void> _voidBatch(BatchRow batch) async {
    final l10n = AppLocalizations.of(context);
    final confirmed = await showAppConfirmDialog(
      context,
      title: l10n.batchesVoidTitle,
      message: l10n.batchesVoidConfirm,
      confirmLabel: l10n.userDeactivate,
      destructive: true,
    );
    if (!confirmed || !mounted) return;
    final failure = await ref
        .read(inventoryControllerProvider.notifier)
        .voidBatch(batch.id,
            itemId: widget.itemId,
            actingUserId: _actingUserId,
            actingRoleId: _actingRoleId);
    if (failure == null && mounted) {
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(content: Text(l10n.batchesVoidedMessage)));
    } else {
      _showFailure(failure);
    }
  }

  String _fmtDate(int? millis) {
    if (millis == null) return '-';
    final d = DateTime.fromMillisecondsSinceEpoch(millis);
    String two(int n) => n.toString().padLeft(2, '0');
    return '${d.year}-${two(d.month)}-${two(d.day)}';
  }

  String _movementLabel(MovementType type) {
    final l10n = AppLocalizations.of(context);
    return switch (type) {
      MovementType.opening_balance => l10n.moveOpening,
      MovementType.purchase => l10n.movePurchase,
      MovementType.sale => l10n.moveSale,
      MovementType.sale_return => l10n.moveSaleReturn,
      MovementType.purchase_return => l10n.movePurchaseReturn,
      MovementType.stock_adjustment => l10n.moveAdjustment,
      MovementType.damaged => l10n.moveDamaged,
      MovementType.expired => l10n.moveExpired,
      MovementType.transfer => l10n.moveTransfer,
      MovementType.manual_correction => l10n.moveCorrection,
    };
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final state = ref.watch(inventoryControllerProvider);
    final typography = context.appTypography;
    final name = _item == null
        ? ''
        : (_item!.tradeName.isNotEmpty
            ? _item!.tradeName
            : (_item!.primaryBarcode ?? _item!.id));

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
                icon: const Icon(Icons.arrow_back),
                tooltip: l10n.commonBack,
                onPressed: () => context.go('/inventory'),
              ),
              Text(name, style: typography.pageTitle),
            ],
          ),
          Wrap(
            spacing: AppSpacing.m,
            children: [
              if (_canAdjust) ...[
                OutlinedButton.icon(
                  onPressed: _adjustStock,
                  icon: const Icon(Icons.tune),
                  label: Text(l10n.inventoryAdjustStock),
                ),
                FilledButton.icon(
                  onPressed: _addBatch,
                  icon: const Icon(Icons.add),
                  label: Text(l10n.batchesAdd),
                ),
              ],
            ],
          ),
        ],
      ),
    );

    return LoadingOverlay(
      visible: state.status == InventoryStatus.loading || state.busy,
      label: l10n.commonLoading,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          header,
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xl),
            child: Text(l10n.batchesTitle, style: typography.sectionTitle),
          ),
          Expanded(
            child: AppDataTable(
              emptyMessage: l10n.batchesEmpty,
              columns: [
                DataColumn(label: Text(l10n.batchNo)),
                DataColumn(label: Text(l10n.quantity)),
                DataColumn(label: Text(l10n.batchRemaining)),
                DataColumn(label: Text(l10n.batchUnitCost)),
                DataColumn(label: Text(l10n.expiryDate)),
                DataColumn(label: Text(l10n.batchReceivedDate)),
                DataColumn(label: Text(l10n.userStatusActive)),
                if (_canAdjust) DataColumn(label: Text('')),
              ],
              rows: [
                for (final b in state.batches)
                  DataRow(cells: [
                    DataCell(Text(b.batchNumber)),
                    DataCell(Text('${b.originalQuantityBase}')),
                    DataCell(Text('${b.quantityBase}')),
                    DataCell(Text(Money.fromUnits(b.unitCostMicros).format())),
                    DataCell(Text(_fmtDate(b.expiryDate))),
                    DataCell(Text(_fmtDate(b.receivedDate))),
                    DataCell(b.isVoided
                        ? _chip(l10n.batchVoided)
                        : BatchStatusChip(status: batchStatusFor(b))),
                    if (_canAdjust)
                      DataCell(
                        b.isVoided
                            ? const SizedBox.shrink()
                            : IconButton(
                                icon: const Icon(Icons.block),
                                tooltip: l10n.batchesVoidTitle,
                                padding: EdgeInsets.zero,
                                constraints: const BoxConstraints.tightFor(
                                    width: 32, height: 32),
                                onPressed: () => _voidBatch(b),
                              ),
                      ),
                  ]),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.xl,
              AppSpacing.xl,
              AppSpacing.xl,
              AppSpacing.s,
            ),
            child: Text(l10n.movementsList, style: typography.sectionTitle),
          ),
          Expanded(
            child: AppDataTable(
              emptyMessage: l10n.movementsList,
              columns: [
                DataColumn(label: Text(l10n.movementType)),
                DataColumn(label: Text(l10n.movementsDate)),
                DataColumn(label: Text(l10n.movementsDelta)),
                DataColumn(label: Text(l10n.batchNo)),
                DataColumn(label: Text(l10n.movementsBalance)),
              ],
              rows: [
                for (final m in state.movements.take(100))
                  DataRow(cells: [
                    DataCell(Text(_movementLabel(m.movementType))),
                    DataCell(Text(_fmtDate(m.createdAt))),
                    DataCell(Text(
                        '${m.quantityBaseSigned >= 0 ? '+' : ''}${m.quantityBaseSigned}')),
                    DataCell(Text(m.batchId ?? '-')),
                    DataCell(Text('${m.quantityBaseAfter}')),
                  ]),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _chip(String label) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.s,
        vertical: 4,
      ),
      child: Text(label),
    );
  }
}