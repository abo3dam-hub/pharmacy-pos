import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/constants/permission_codes.dart';
import '../../../../core/di/providers.dart';
import '../../../../core/errors/failure_messages.dart';
import '../../../../core/errors/exceptions.dart';
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
import '../../../suppliers/domain/repositories/supplier_repository.dart';
import '../../application/inventory_controller.dart';
import '../../application/master_data_controller.dart';
import '../../domain/entities/inventory_item.dart';
import '../../domain/repositories/inventory_repository.dart';
import '../../domain/services/compound_stock_text.dart';
import '../../domain/usecases/excel_use_cases.dart';
import '../widgets/bulk_dialog.dart';
import '../widgets/import_progress_view.dart';
import '../widgets/item_dialog.dart';
import '../widgets/master_data_dialog.dart';
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
  List<SupplierRow> _suppliers = const [];

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
      // Preferred suppliers for the product form (`suppliers.view`); roles
      // without that permission simply see an empty supplier picker.
      try {
        final suppliers = await ref
            .read(allSuppliersUseCaseProvider)
            .call(actingRoleId: auth.actingRoleId);
        if (mounted) {
          setState(() => _suppliers = suppliers);
        }
      } on AppException {
        if (mounted) setState(() => _suppliers = const []);
      }
    });
  }

  bool get _canCreate =>
      ref.read(authControllerProvider).permissions.contains(Perm.inventoryCreate);
  bool get _canEdit =>
      ref.read(authControllerProvider).permissions.contains(Perm.inventoryEdit);
  bool get _canChangePrices =>
      ref.read(authControllerProvider).permissions.contains(Perm.changePrices);
  bool get _canDelete =>
      ref.read(authControllerProvider).permissions.contains(Perm.inventoryDelete);
  String? get _actingUserId => ref.read(authControllerProvider).user?.id;
  String? get _actingRoleId => ref.read(authControllerProvider).actingRoleId;

  void _showFailure(Failure? failure) {
    showFailureSnack(context, failure);
  }

  Future<void> _onSearch(String query) => _load(search: query);

  Future<void> _toggleActiveFilter(bool value) => _load(onlyActive: value);

  Future<void> _toggleInStock(bool value) => _load(inStockOnly: value);

  Future<void> _load({
    String search = '',
    bool? onlyActive,
    bool? inStockOnly,
  }) async {
    final failure = await ref
        .read(inventoryControllerProvider.notifier)
        .load(search: search,
            onlyActive: onlyActive,
            inStockOnly: inStockOnly,
            actingRoleId: _actingRoleId);
    _showFailure(failure);
  }

  Future<void> _createItem() async {
    final l10n = AppLocalizations.of(context);
    final master = ref.read(masterDataControllerProvider);
    if (master.status != MasterDataStatus.ready) return;
    final defaultMarkup = await _partialSaleMarkupDefault();
    if (!mounted) return;
    final result = await showItemFormDialog(
      context,
      title: l10n.inventoryItemAddTitle,
      categories: master.categories,
      manufacturers: master.manufacturers,
      units: master.units,
      suppliers: _suppliers,
      activeIngredients: master.activeIngredients,
      indications: master.indications,
      onCreateMasterData: _createMasterData,
      onCreateSupplier: _createSupplier,
      defaultPartialSaleMarkupBasisPoints: defaultMarkup,
      showContinueAction: true,
    );
    if (result == null || !mounted) return;
    final outcome = await ref
        .read(inventoryControllerProvider.notifier)
        .createItem(result.draft,
            actingUserId: _actingUserId, actingRoleId: _actingRoleId);
    if (outcome == null && mounted) {
      if (result.action == ItemFormAction.saveContinue) {
        final newId =
            ref.read(inventoryControllerProvider.notifier).lastCreatedItemId;
        if (newId != null) {
          context.go('/inventory/batches/$newId?add=1');
          return;
        }
      }
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
    List<String> supplierIds = const [];
    List<String> activeIngredientIds = const [];
    Map<String, String> activeIngredientStrengths = const {};
    List<String> indicationIds = const [];
    try {
      supplierIds = await ref
          .read(inventoryRepositoryProvider)
          .supplierIdsForItem(view.item.id);
      final ingredientRelations = await ref
          .read(inventoryRepositoryProvider)
          .activeIngredientRelationsForItem(view.item.id);
      activeIngredientIds = [
        for (final r in ingredientRelations) r.activeIngredientId,
      ];
      activeIngredientStrengths = {
        for (final r in ingredientRelations)
          if (r.strength != null && r.strength!.trim().isNotEmpty)
            r.activeIngredientId: r.strength!,
      };
      indicationIds = await ref
          .read(inventoryRepositoryProvider)
          .indicationIdsForItem(view.item.id);
    } on AppException {
      // Empty relations fall back to the free-text / no links.
    }
    final initial = ItemDraft.fromRow(
      view.item,
      units: view.units == null
          ? null
          : ItemUnitRelation(
              baseUnitId: view.units!.baseUnitId,
              largeUnitId: view.units!.largeUnitId,
              unitsPerLarge: view.units!.unitsPerLarge,
            ),
      supplierIds: supplierIds,
      activeIngredientIds: activeIngredientIds,
      activeIngredientStrengths: activeIngredientStrengths,
      indicationIds: indicationIds,
    );
    final defaultMarkup = await _partialSaleMarkupDefault();
    if (!mounted) return;
    final result = await showItemFormDialog(
      context,
      title: l10n.inventoryItemEditTitle,
      initial: initial,
      categories: master.categories,
      manufacturers: master.manufacturers,
      units: master.units,
      suppliers: _suppliers,
      activeIngredients: master.activeIngredients,
      indications: master.indications,
      onCreateMasterData: _createMasterData,
      onCreateSupplier: _createSupplier,
      defaultPartialSaleMarkupBasisPoints: defaultMarkup,
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

  Future<int> _partialSaleMarkupDefault() async {
    final value = await ref
        .read(settingsDaoProvider)
        .getInt('partial_sale_markup_basis_points');
    return value ?? 2000;
  }

  /// Inline master-data creation used by the product form: persists via the
  /// audited [MasterDataController] then returns the freshly loaded row so the
  /// form can select it immediately.
  Future<Object?> _createMasterData(
      MasterDataKind kind, MasterDataDraft draft) async {
    final mc = ref.read(masterDataControllerProvider.notifier);
    final failure = switch (kind) {
      MasterDataKind.category => await mc.createCategory(draft,
          actingUserId: _actingUserId, actingRoleId: _actingRoleId),
      MasterDataKind.manufacturer => await mc.createManufacturer(draft,
          actingUserId: _actingUserId, actingRoleId: _actingRoleId),
      MasterDataKind.unit => await mc.createUnit(draft,
          actingUserId: _actingUserId, actingRoleId: _actingRoleId),
      MasterDataKind.activeIngredient => await mc.createActiveIngredient(draft,
          actingUserId: _actingUserId, actingRoleId: _actingRoleId),
      MasterDataKind.indication => await mc.createIndication(draft,
          actingUserId: _actingUserId, actingRoleId: _actingRoleId),
    };
    if (failure != null) {
      _showFailure(failure);
      return null;
    }
    final state = ref.read(masterDataControllerProvider);
    final name = draft.name.trim();
    switch (kind) {
      case MasterDataKind.category:
        return _firstByName(state.categories, name);
      case MasterDataKind.manufacturer:
        return _firstByName(state.manufacturers, name);
      case MasterDataKind.unit:
        return _firstByName(state.units, name);
      case MasterDataKind.activeIngredient:
        return _firstByName(state.activeIngredients, name);
      case MasterDataKind.indication:
        return _firstByName(state.indications, name);
    }
  }

  T? _firstByName<T extends Object>(List<T> rows, String name) {
    for (final row in rows) {
      if ((row as dynamic).name?.trim() == name) return row;
    }
    return null;
  }

  Future<SupplierRow?> _createSupplier(SupplierDraft draft) async {
    try {
      return await ref.read(createSupplierUseCaseProvider).call(
            draft,
            actingUserId: _actingUserId,
            actingRoleId: _actingRoleId,
          );
    } on AppException catch (e) {
      _showFailure(e.failure);
      return null;
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

  Future<void> _deleteItem(InventoryItemView view) async {
    final l10n = AppLocalizations.of(context);
    final confirmed = await showAppConfirmDialog(
      context,
      title: l10n.inventoryDeleteTitle,
      message: l10n.inventoryDeleteConfirm(view.primaryLabel),
      confirmLabel: l10n.commonDelete,
      destructive: true,
    );
    if (!confirmed || !mounted) return;
    final failure = await ref
        .read(inventoryControllerProvider.notifier)
        .deleteItem(view.item.id,
            actingUserId: _actingUserId, actingRoleId: _actingRoleId);
    if (failure == null && mounted) {
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(content: Text(l10n.inventoryDeleteMessage)));
    } else {
      _showFailure(failure);
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
      manufacturers: master.manufacturers,
      suppliers: _suppliers,
      canChangePrices: _canChangePrices,
    );
    if (result == null || !mounted) return;
    final outcome = await ref.read(inventoryControllerProvider.notifier).bulk(
          result.input,
          actingUserId: _actingUserId,
          actingRoleId: _actingRoleId,
        );
    if (outcome == null && mounted) {
      final controller = ref.read(inventoryControllerProvider.notifier);
      final count = controller.lastBulkUpdatedCount;
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(content: Text(l10n.bulkDone(count))));
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
      if (failure is ImportCancelledFailure) {
        if (!mounted) return;
        ScaffoldMessenger.of(context)
          ..hideCurrentSnackBar()
          ..showSnackBar(SnackBar(content: Text(l10n.inventoryImportCancelled)));
        return;
      }
      _showFailure(failure);
      return;
    }
    if (!mounted) return;
    final report = ref.read(inventoryControllerProvider).importReport;
    if (report != null) {
      final parts = <String>[
        l10n.inventoryImportDone(report.created, report.updated),
        if (report.createdMaster > 0)
          l10n.inventoryImportMaster(report.createdMaster),
        if (report.issues.isNotEmpty)
          l10n.inventoryImportIssues(report.issues.length),
      ];
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(content: Text(parts.join(' · '))));
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
        .load(search: state.search,
            page: page,
            inStockOnly: state.inStockOnly,
            actingRoleId: _actingRoleId);
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
              SegmentedButton<bool>(
                segments: [
                  ButtonSegment(
                    value: true,
                    label: Text(l10n.inventoryInStock),
                  ),
                  ButtonSegment(
                    value: false,
                    label: Text(l10n.inventoryProductTree),
                  ),
                ],
                selected: {state.inStockOnly ?? true},
                showSelectedIcon: false,
                onSelectionChanged: (selection) =>
                    _toggleInStock(selection.first),
              ),
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

    final importProgress = state.importProgress;
    return LoadingOverlay(
      visible: state.status == InventoryStatus.loading || state.busy,
      label: l10n.commonLoading,
      progress: importProgress == null
          ? null
          : ImportProgressView(
              progress: importProgress,
              stageLabel: importProgress.stage == ImportStage.parsing
                  ? l10n.inventoryImportParsing
                  : l10n.inventoryImportApplying,
              progressLabel: l10n
                  .inventoryImportProgress(importProgress.processed,
                      importProgress.total == 0
                          ? 0
                          : importProgress.total),
              cancelLabel: l10n.inventoryImportCancel,
              onCancel: () => ref
                  .read(inventoryControllerProvider.notifier)
                  .cancelImport(),
            ),
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
              DataCell(Text(row.displayName)),
              DataCell(Text(row.item.primaryBarcode ?? '')),
              DataCell(Text(row.categoryName ?? '')),
              DataCell(Text(Money.fromUnits(row.item.costMicros).format())),
              DataCell(
                  Text(Money.fromUnits(row.item.sellingPriceMicros).format())),
              DataCell(
                Tooltip(
                  message: l10n.inventoryStockTooltip(
                    _stockText(row),
                    Money.fromUnits(row.item.sellingPriceMicros).format(),
                  ),
                  child: Text(_stockText(row)),
                ),
              ),
              DataCell(StockStatusChip(status: row.stockStatus)),
              DataCell(_actions(l10n, row)),
            ],
          ),
      ],
    );
  }

  String _stockText(InventoryItemView row) {
    return compoundStockText(
      baseUnits: row.item.currentStockBase,
      quantity: row.onHand,
      largeUnitName: row.largeUnitName,
      partUnitName: row.baseUnitName,
      unitsPerLarge: row.units?.unitsPerLarge,
      partsPerFullProduct: row.item.partialSaleEnabled
          ? row.item.partsPerFullProduct
          : null,
      sellablePartBaseQuantity: row.item.sellablePartBaseQuantity,
    );
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
                            Text(row.displayName, style: typography.sectionTitle),
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
                  Tooltip(
                    message: l10n.inventoryStockTooltip(
                      _stockText(row),
                      Money.fromUnits(row.item.sellingPriceMicros).format(),
                    ),
                    child: Text(
                      '${l10n.itemStock}: ${_stockText(row)} · '
                      '${l10n.itemCost}: ${Money.fromUnits(row.item.costMicros).format()} · '
                      '${l10n.itemPrice}: ${Money.fromUnits(row.item.sellingPriceMicros).format()}',
                      style: typography.label,
                    ),
                  ),
if (_canDelete)
          IconButton(
            icon: const Icon(Icons.delete_outline),
            tooltip: l10n.commonDelete,
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints.tightFor(width: 32, height: 32),
            onPressed: () => _deleteItem(row),
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