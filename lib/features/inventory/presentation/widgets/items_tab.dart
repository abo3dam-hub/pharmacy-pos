import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
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
import '../../../../core/widgets/responsive_layout.dart';
import '../../../../core/widgets/search_field.dart';
import '../../../../l10n/app_localizations.dart';
import '../../application/inventory_controller.dart';
import '../../application/master_data_controller.dart';
import '../../domain/entities/inventory_item.dart';
import '../../domain/repositories/inventory_repository.dart';
import '../widgets/bulk_dialog.dart';
import '../widgets/item_dialog.dart';
import '../widgets/status_chips.dart';
import '../../../../core/widgets/app_rtl_icons.dart';

/// §22 items grid tab — search, active filter, selection, bulk actions,
/// create/edit/toggle, and Excel import/export.
class ItemsTab extends ConsumerStatefulWidget {
  const ItemsTab({super.key});

  @override
  ConsumerState<ItemsTab> createState() => _ItemsTabState();
}

class _ItemsTabState extends ConsumerState<ItemsTab> {
  @override
  void initState() {
    super.initState();
    Future.microtask(() async {
      final auth = ref.read(authControllerProvider);
      if (auth.permissions.contains(Perm.inventoryView)) {
        await ref
            .read(inventoryControllerProvider.notifier)
            .load(actingRoleId: auth.actingRoleId);
      }
      await ref
          .read(masterDataControllerProvider.notifier)
          .load(actingRoleId: auth.actingRoleId);
    });
  }

  bool get _canCreate =>
      ref.read(authControllerProvider).permissions.contains(Perm.inventoryCreate);
  bool get _canEdit =>
      ref.read(authControllerProvider).permissions.contains(Perm.inventoryEdit);
  bool get _canChangePrices =>
      ref.read(authControllerProvider).permissions.contains(Perm.changePrices);
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

  Future<void> _onSearch(String query) => _load(search: query);

  Future<void> _toggleActiveFilter(bool value) => _load(onlyActive: value);

  Future<void> _load({String search = '', bool? onlyActive}) async {
    final failure = await ref
        .read(inventoryControllerProvider.notifier)
        .load(search: search, onlyActive: onlyActive, actingRoleId: _actingRoleId);
    _showFailure(failure);
  }

  Future<void> _createItem() async {
    final l10n = AppLocalizations.of(context);
    final master = ref.read(masterDataControllerProvider);
    if (master.status != MasterDataStatus.ready) return;
    final result = await showItemFormDialog(
      context,
      title: l10n.inventoryItemAddTitle,
      categories: master.categories,
      subCategories: master.subCategories,
      manufacturers: master.manufacturers,
      groups: master.groups,
      units: master.units,
    );
    if (result == null || !mounted) return;
    final outcome = await ref
        .read(inventoryControllerProvider.notifier)
        .createItem(result.draft,
            actingUserId: _actingUserId, actingRoleId: _actingRoleId);
    if (outcome == null && mounted) {
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(content: Text(l10n.inventoryCreatedMessage)));
    } else {
      _showFailure(outcome);
    }
  }

  Future<void> _editItem(InventoryItemView view) async {
    final l10n = AppLocalizations.of(context);
    final master = ref.read(masterDataControllerProvider);
    if (master.status != MasterDataStatus.ready) return;
    final initial = ItemDraft.fromRow(
      view.item,
      units: view.units == null
          ? null
          : ItemUnitRelation(
              baseUnitId: view.units!.baseUnitId,
              largeUnitId: view.units!.largeUnitId,
              unitsPerLarge: view.units!.unitsPerLarge,
            ),
    );
    final result = await showItemFormDialog(
      context,
      title: l10n.inventoryItemEditTitle,
      initial: initial,
      categories: master.categories,
      subCategories: master.subCategories,
      manufacturers: master.manufacturers,
      groups: master.groups,
      units: master.units,
    );
    if (result == null || !mounted) return;
    final outcome = await ref
        .read(inventoryControllerProvider.notifier)
        .updateItem(view.item.id, result.draft,
            actingUserId: _actingUserId, actingRoleId: _actingRoleId);
    if (outcome == null && mounted) {
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(content: Text(l10n.inventoryUpdatedMessage)));
    } else {
      _showFailure(outcome);
    }
  }

  Future<void> _toggleActive(InventoryItemView view) async {
    final l10n = AppLocalizations.of(context);
    final activating = !view.item.isActive;
    final confirmed = await showAppConfirmDialog(
      context,
      title: activating ? l10n.userActivate : l10n.userDeactivate,
      message: activating
          ? l10n.userActivateConfirmMessage(view.primaryLabel)
          : l10n.userDeactivateConfirmMessage(view.primaryLabel),
      confirmLabel: activating ? l10n.userActivate : l10n.userDeactivate,
      destructive: !activating,
    );
    if (!confirmed || !mounted) return;
    final outcome = await ref
        .read(inventoryControllerProvider.notifier)
        .setActive(view.item.id, activating,
            actingUserId: _actingUserId, actingRoleId: _actingRoleId);
    if (outcome == null && mounted) {
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(
          content: Text(activating
              ? l10n.inventoryActivatedMessage
              : l10n.inventoryDeactivatedMessage),
        ));
    } else {
      _showFailure(outcome);
    }
  }

  Future<void> _bulk() async {
    final l10n = AppLocalizations.of(context);
    final master = ref.read(masterDataControllerProvider);
    if (master.status != MasterDataStatus.ready) return;
    final ids = ref.read(inventoryControllerProvider).selectedIds.toList();
    final result = await showBulkDialog(
      context,
      itemIds: ids,
      categories: master.categories,
      canChangePrices: _canChangePrices,
    );
    if (result == null || !mounted) return;
    final outcome = await ref.read(inventoryControllerProvider.notifier).bulk(
          result.input,
          actingUserId: _actingUserId,
          actingRoleId: _actingRoleId,
        );
    if (outcome == null && mounted) {
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(content: Text(l10n.bulkDone(ids.length))));
    } else {
      _showFailure(outcome);
    }
  }

  Future<void> _export() async {
    final l10n = AppLocalizations.of(context);
    final bytes = await ref
        .read(inventoryControllerProvider.notifier)
        .exportExcel(actingRoleId: _actingRoleId);
    if (bytes == null || !mounted) return;
    final file = await FilePicker.saveFile(
      dialogTitle: l10n.inventoryExport,
      fileName: 'inventory_${DateTime.now().millisecondsSinceEpoch}.xlsx',
      bytes: Uint8List.fromList(bytes),
      type: FileType.custom,
      allowedExtensions: ['xlsx'],
    );
    if (file != null && mounted) {
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(content: Text(l10n.inventoryExportDone)));
    }
  }

  Future<void> _import() async {
    final l10n = AppLocalizations.of(context);
    final picked = await FilePicker.pickFile(type: FileType.any);
    if (picked == null || mounted == false) return;
    final bytes = await picked.readAsBytes();
    final failure = await ref
        .read(inventoryControllerProvider.notifier)
        .importExcel(bytes,
            actingUserId: _actingUserId, actingRoleId: _actingRoleId);
    if (failure != null) {
      _showFailure(failure);
      return;
    }
    if (!mounted) return;
    final report = ref.read(inventoryControllerProvider).importReport;
    if (report != null) {
      final message = report.issues.isEmpty
          ? l10n.inventoryImportDone(report.created, report.updated)
          : '${l10n.inventoryImportDone(report.created, report.updated)} · '
              '${l10n.inventoryImportIssues(report.issues.length)}';
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(content: Text(message)));
    } else {
      _showFailure(const DatabaseFailure('inventoryImportFailed'));
    }
  }

  void _toPage(int page) {
    final state = ref.read(inventoryControllerProvider);
    final pageCount = (state.total / 30).ceil();
    if (page < 1 || page > (pageCount == 0 ? 1 : pageCount)) return;
    ref
        .read(inventoryControllerProvider.notifier)
        .load(search: state.search, page: page, actingRoleId: _actingRoleId);
  }

  void _openBatches(InventoryItemView view) =>
      context.go('/inventory/batches/${view.item.id}');

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final state = ref.watch(inventoryControllerProvider);
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
              hintText: l10n.inventorySearchHint,
              onChanged: _onSearch,
            ),
          ),
          Wrap(
            spacing: AppSpacing.m,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              FilterChip(
                label: Text(l10n.inventoryActiveFilter),
                selected: state.onlyActive ?? false,
                onSelected: _toggleActiveFilter,
              ),
              OutlinedButton.icon(
                onPressed: _export,
                icon: const Icon(Icons.upload_file_outlined),
                label: Text(l10n.inventoryExport),
              ),
              if (_canCreate) ...[
                OutlinedButton.icon(
                  onPressed: _import,
                  icon: const Icon(Icons.download_outlined),
                  label: Text(l10n.inventoryImport),
                ),
                FilledButton.icon(
                  onPressed: _createItem,
                  icon: const Icon(Icons.add),
                  label: Text(l10n.inventoryAddItem),
                ),
              ],
            ],
          ),
        ],
      ),
    );

    final bulkBar = state.hasSelection
        ? Padding(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.xl,
              AppSpacing.s,
              AppSpacing.xl,
              AppSpacing.s,
            ),
            child: Wrap(
              spacing: AppSpacing.m,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                Text(
                  l10n.bulkSelectedCount(state.selectedIds.length),
                  style: typography.label,
                ),
                if (_canEdit || _canChangePrices)
                  FilledButton.tonalIcon(
                    onPressed: _bulk,
                    icon: const Icon(Icons.edit_calendar_outlined),
                    label: Text(l10n.bulkTitle),
                  ),
                TextButton.icon(
                  onPressed: () => ref
                      .read(inventoryControllerProvider.notifier)
                      .clearSelection(),
                  icon: const Icon(Icons.close),
                  label: Text(l10n.commonClose),
                ),
              ],
            ),
          )
        : const SizedBox.shrink();

    final content = AppResponsiveLayout(
      desktop: _buildTable(l10n, state),
      tablet: _buildTable(l10n, state),
      compact: _buildCards(l10n, state, typography),
    );

    return LoadingOverlay(
      visible: state.status == InventoryStatus.loading || state.busy,
      label: l10n.commonLoading,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          header,
          if (_canEdit || _canCreate) bulkBar,
          Expanded(
            child: state.status == InventoryStatus.error
                ? Center(
                    child: Text(l10n.commonError, style: typography.labelSmall),
                  )
                : content,
          ),
          _buildPager(l10n, state),
        ],
      ),
    );
  }

  Widget _buildPager(AppLocalizations l10n, InventoryViewState state) {
    final pageCount = (state.total / 30).ceil();
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
            '${state.page} / ${pageCount == 0 ? 1 : pageCount}',
            style: context.appTypography.bodySecondary,
          ),
          const SizedBox(width: AppSpacing.m),
          IconButton(
            onPressed: state.page <= 1 ? null : () => _toPage(state.page - 1),
            icon: Icon(AppDirectionalIcons.previous(context)),
            tooltip: l10n.commonPrevious,
          ),
          IconButton(
            onPressed: state.page >= pageCount || pageCount == 0
                ? null
                : () => _toPage(state.page + 1),
            icon: Icon(AppDirectionalIcons.next(context)),
            tooltip: l10n.commonNext,
          ),
        ],
      ),
    );
  }

  Widget _buildTable(AppLocalizations l10n, InventoryViewState state) {
    return AppDataTable(
      emptyMessage: l10n.inventoryItemsEmpty,
      showCheckboxColumn: true,
      columns: [
        DataColumn(label: Text(l10n.itemTradeName)),
        DataColumn(label: Text(l10n.itemBarcode)),
        DataColumn(label: Text(l10n.itemCategory)),
        DataColumn(label: Text(l10n.itemCost)),
        DataColumn(label: Text(l10n.itemPrice)),
        DataColumn(label: Text(l10n.itemStock)),
        DataColumn(label: Text(l10n.userStatusActive)),
        DataColumn(label: Text('')),
      ],
      rows: [
        for (final row in state.items)
          DataRow(
            selected: state.selectedIds.contains(row.item.id),
            onSelectChanged: (_) => ref
                .read(inventoryControllerProvider.notifier)
                .toggleSelection(row.item.id),
            cells: [
              DataCell(Text(row.primaryLabel)),
              DataCell(Text(row.item.primaryBarcode ?? '')),
              DataCell(Text(row.categoryName ?? '')),
              DataCell(Text(Money.fromUnits(row.item.costMicros).format())),
              DataCell(
                  Text(Money.fromUnits(row.item.sellingPriceMicros).format())),
              DataCell(Text(_stockText(row))),
              DataCell(StockStatusChip(status: row.stockStatus)),
              DataCell(_actions(l10n, row)),
            ],
          ),
      ],
    );
  }

  String _stockText(InventoryItemView row) {
    final qty = row.onHand;
    if (qty.unitsPerLarge > 1 && qty.boxes > 0) {
      return '${row.onHand.boxes}×${row.onHand.unitsPerLarge}+${row.onHand.fractions}';
    }
    return '${row.item.currentStockBase}';
  }

  Widget _buildCards(
    AppLocalizations l10n,
    InventoryViewState state,
    AppTypography typography,
  ) {
    if (state.items.isEmpty) {
      return Center(
        child: Text(l10n.inventoryItemsEmpty, style: typography.labelSmall),
      );
    }
    return ListView(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.m,
        vertical: AppSpacing.s,
      ),
      children: [
        for (final row in state.items)
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
                            Text(row.primaryLabel,
                                style: typography.sectionTitle),
                            const SizedBox(height: AppSpacing.xs),
                            Text(
                              '${row.item.primaryBarcode ?? ''}'
                              '${row.categoryName == null ? '' : ' · ${row.categoryName}'}',
                              style: typography.bodySecondary,
                            ),
                          ],
                        ),
                      ),
                      StockStatusChip(status: row.stockStatus),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.s),
                  Text(
                    '${l10n.itemStock}: ${_stockText(row)} · '
                    '${l10n.itemCost}: ${Money.fromUnits(row.item.costMicros).format()} · '
                    '${l10n.itemPrice}: ${Money.fromUnits(row.item.sellingPriceMicros).format()}',
                    style: typography.label,
                  ),
                  if (_canEdit) ...[
                    const SizedBox(height: AppSpacing.s),
                    Align(
                      alignment: AlignmentDirectional.centerEnd,
                      child: _actions(l10n, row),
                    ),
                  ],
                ],
              ),
            ),
          ),
      ],
    );
  }

  Widget _actions(AppLocalizations l10n, InventoryItemView row) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        IconButton(
          icon: const Icon(Icons.inventory_2_outlined),
          tooltip: l10n.inventoryBatchView,
          padding: EdgeInsets.zero,
          constraints: const BoxConstraints.tightFor(width: 32, height: 32),
          onPressed: () => _openBatches(row),
        ),
        if (_canEdit) ...[
          IconButton(
            icon: const Icon(Icons.edit_outlined),
            tooltip: l10n.commonEdit,
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints.tightFor(width: 32, height: 32),
            onPressed: () => _editItem(row),
          ),
          IconButton(
            icon: Icon(
                row.item.isActive ? Icons.block : Icons.check_circle_outline),
            tooltip: row.item.isActive ? l10n.userDeactivate : l10n.userActivate,
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints.tightFor(width: 32, height: 32),
            onPressed: () => _toggleActive(row),
          ),
        ],
      ],
    );
  }
}