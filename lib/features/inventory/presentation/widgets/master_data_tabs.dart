import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/constants/permission_codes.dart';
import '../../../../core/di/providers.dart';
import '../../../../core/errors/failures.dart';
import '../../../../core/theme/app_dimensions.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/widgets/confirm_dialog.dart';
import '../../../../core/widgets/loading_overlay.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../../shared/database/app_database.dart';
import '../../application/master_data_controller.dart';
import '../../domain/repositories/inventory_repository.dart';
import '../widgets/master_data_dialog.dart';
import '../widgets/paged_master_table.dart';
import '../widgets/status_chips.dart';

/// §4.3 + §4.4 — main categories with expandable sub-categories.
class CategoriesTab extends ConsumerStatefulWidget {
  const CategoriesTab({super.key});

  @override
  ConsumerState<CategoriesTab> createState() => _CategoriesTabState();
}

class _CategoriesTabState extends ConsumerState<CategoriesTab> {
  bool get _canEdit =>
      ref.read(authControllerProvider).permissions.contains(Perm.inventoryEdit);
  bool get _canDelete =>
      ref.read(authControllerProvider).permissions.contains(Perm.inventoryDelete);
  String? get _actingUserId => ref.read(authControllerProvider).user?.id;
  String? get _actingRoleId => ref.read(authControllerProvider).actingRoleId;

  Future<void> _addCategory() async {
    final l10n = AppLocalizations.of(context);
    final result = await showMasterDataFormDialog(
      context,
      kind: MasterDataKind.category,
      title: l10n.categoriesAddTitle,
    );
    if (result == null || !mounted) return;
    final failure = await ref.read(masterDataControllerProvider.notifier)
        .createCategory(result.draft,
            actingUserId: _actingUserId, actingRoleId: _actingRoleId);
    if (failure == null && mounted) _saved();
    if (failure != null && mounted) _showFailure(context, failure);
  }

  Future<void> _editCategory(CategoryRow row) async {
    final l10n = AppLocalizations.of(context);
    final result = await showMasterDataFormDialog(
      context,
      kind: MasterDataKind.category,
      title: l10n.categoriesEditTitle,
      initial: MasterDataDraft(
        name: row.name,
        nameEn: row.nameEn,
        description: row.description,
      ),
    );
    if (result == null || !mounted) return;
    final failure = await ref.read(masterDataControllerProvider.notifier)
        .updateCategory(row.id, result.draft,
            actingUserId: _actingUserId, actingRoleId: _actingRoleId);
    if (failure == null && mounted) _saved();
    if (failure != null && mounted) _showFailure(context, failure);
  }

  Future<void> _toggleCategory(CategoryRow row) async {
    final l10n = AppLocalizations.of(context);
    final activating = !row.isActive;
    final confirmed = await showAppConfirmDialog(
      context,
      title: activating ? l10n.userActivate : l10n.userDeactivate,
      message: activating
          ? l10n.userActivateConfirmMessage(row.name)
          : l10n.userDeactivateConfirmMessage(row.name),
      confirmLabel: activating ? l10n.userActivate : l10n.userDeactivate,
      destructive: !activating,
    );
    if (!confirmed || !mounted) return;
    final failure = await ref.read(masterDataControllerProvider.notifier)
        .setCategoryActive(row.id, activating,
            actingUserId: _actingUserId, actingRoleId: _actingRoleId);
    if (failure == null && mounted) _saved();
    if (failure != null && mounted) _showFailure(context, failure);
  }

  Future<void> _deleteCategory(CategoryRow row) async {
    final l10n = AppLocalizations.of(context);
    final confirmed = await showAppConfirmDialog(
      context,
      title: l10n.masterDataDeleteTitle,
      message: l10n.masterDataDeleteConfirm(row.name),
      confirmLabel: l10n.commonDelete,
      destructive: true,
    );
    if (!confirmed || !mounted) return;
    final failure = await ref.read(masterDataControllerProvider.notifier)
        .deleteCategory(row.id,
            actingUserId: _actingUserId, actingRoleId: _actingRoleId);
    if (failure == null && mounted) {
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(content: Text(l10n.masterDataDeletedMessage)));
    }
    if (failure != null && mounted) _showFailure(context, failure);
  }

  void _saved() {
    final l10n = AppLocalizations.of(context);
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(l10n.masterDataSavedMessage)));
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final state = ref.watch(masterDataControllerProvider);
    final header = _tabHeader(
      context: context,
      l10n: l10n,
      title: l10n.categoriesTitle,
      canEdit: _canEdit,
      onAdd: _addCategory,
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        header,
        Expanded(
          child: LoadingOverlay(
            visible: state.status == MasterDataStatus.loading,
            label: l10n.commonLoading,
            child: state.status == MasterDataStatus.error
                ? Center(
                    child: Text(l10n.commonError,
                        style: context.appTypography.labelSmall),
                  )
                : PagedMasterTable<CategoryRow>(
                    emptyMessage: l10n.categoriesEmpty,
                    data: state.categories,
                    searchText: (c) => '${c.name} ${c.nameEn ?? ''}',
                    columns: [
                      DataColumn(label: Text(l10n.categoryName)),
                      DataColumn(label: Text(l10n.categoryNameEn)),
                      DataColumn(label: Text(l10n.userStatusActive)),
                      DataColumn(label: Text('')),
                    ],
                    rowBuilder: (c) => DataRow(cells: [
                      DataCell(Text(c.name)),
                      DataCell(Text(c.nameEn ?? '')),
                      DataCell(_ActiveStatusChipBox(active: c.isActive)),
                      DataCell(_MasterActions(
                        canEdit: _canEdit,
                        canDelete: _canDelete,
                        onEdit: () => _editCategory(c),
                        onToggle: () => _toggleCategory(c),
                        onDelete: () => _deleteCategory(c),
                        active: c.isActive,
                      )),
                    ]),
                  ),
          ),
        ),
      ],
    );
  }
}

/// §4.1 — manufacturers registry.
class ManufacturersTab extends ConsumerStatefulWidget {
  const ManufacturersTab({super.key});

  @override
  ConsumerState<ManufacturersTab> createState() => _ManufacturersTabState();
}

class _ManufacturersTabState extends ConsumerState<ManufacturersTab> {
  bool get _canEdit =>
      ref.read(authControllerProvider).permissions.contains(Perm.inventoryEdit);
  bool get _canDelete =>
      ref.read(authControllerProvider).permissions.contains(Perm.inventoryDelete);
  String? get _actingUserId => ref.read(authControllerProvider).user?.id;
  String? get _actingRoleId => ref.read(authControllerProvider).actingRoleId;

  void _snack(bool ok) {
    final l10n = AppLocalizations.of(context);
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(
        content: Text(ok ? l10n.masterDataSavedMessage : l10n.authSaveError),
      ));
  }

  Future<void> _add() async {
    final l10n = AppLocalizations.of(context);
    final result = await showMasterDataFormDialog(
      context,
      kind: MasterDataKind.manufacturer,
      title: l10n.manufacturersAdd,
    );
    if (result == null || !mounted) return;
    final failure = await ref.read(masterDataControllerProvider.notifier)
        .createManufacturer(result.draft,
            actingUserId: _actingUserId, actingRoleId: _actingRoleId);
    if (failure != null && mounted) {
      _showFailure(context, failure);
      return;
    }
    _snack(true);
  }

  Future<void> _edit(ManufacturerRow row) async {
    final l10n = AppLocalizations.of(context);
    final result = await showMasterDataFormDialog(
      context,
      kind: MasterDataKind.manufacturer,
      title: l10n.manufacturersEditTitle,
      initial: MasterDataDraft(
        name: row.name,
        country: row.country,
        phone: row.phone,
        website: row.website,
        description: row.notes,
      ),
    );
    if (result == null || !mounted) return;
    final failure = await ref.read(masterDataControllerProvider.notifier)
        .updateManufacturer(row.id, result.draft,
            actingUserId: _actingUserId, actingRoleId: _actingRoleId);
    if (failure != null && mounted) {
      _showFailure(context, failure);
      return;
    }
    _snack(true);
  }

  Future<void> _toggle(ManufacturerRow row, bool active) async {
    final failure = await ref.read(masterDataControllerProvider.notifier)
        .setManufacturerActive(row.id, active,
            actingUserId: _actingUserId, actingRoleId: _actingRoleId);
    if (failure != null && mounted) {
      _showFailure(context, failure);
      return;
    }
    _snack(true);
  }

  Future<void> _delete(ManufacturerRow row) async {
    final l10n = AppLocalizations.of(context);
    final confirmed = await showAppConfirmDialog(
      context,
      title: l10n.masterDataDeleteTitle,
      message: l10n.masterDataDeleteConfirm(row.name),
      confirmLabel: l10n.commonDelete,
      destructive: true,
    );
    if (!confirmed || !mounted) return;
    final failure = await ref.read(masterDataControllerProvider.notifier)
        .deleteManufacturer(row.id,
            actingUserId: _actingUserId, actingRoleId: _actingRoleId);
    if (failure == null && mounted) {
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(content: Text(l10n.masterDataDeletedMessage)));
    }
    if (failure != null && mounted) _showFailure(context, failure);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final state = ref.watch(masterDataControllerProvider);
    final header = _tabHeader(
      context: context,
      l10n: l10n,
      title: l10n.inventoryTabManufacturers,
      canEdit: _canEdit,
      onAdd: _add,
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        header,
        Expanded(
          child: LoadingOverlay(
            visible: state.status == MasterDataStatus.loading,
            label: l10n.commonLoading,
            child: state.status == MasterDataStatus.error
                ? Center(
                    child: Text(l10n.commonError,
                        style: context.appTypography.labelSmall),
                  )
                : PagedMasterTable<ManufacturerRow>(
                    emptyMessage: l10n.manufacturersEmpty,
                    data: state.manufacturers,
                    searchText: (m) => '${m.name} ${m.country ?? ''}',
                    columns: [
                      DataColumn(label: Text(l10n.manufacturerName)),
                      DataColumn(label: Text(l10n.manufacturerCountry)),
                      DataColumn(label: Text(l10n.userPhone)),
                      DataColumn(label: Text(l10n.userStatusActive)),
                      DataColumn(label: Text('')),
                    ],
                    rowBuilder: (m) => DataRow(cells: [
                      DataCell(Text(m.name)),
                      DataCell(Text(m.country ?? '')),
                      DataCell(Text(m.phone ?? '')),
                      DataCell(_ActiveStatusChipBox(active: m.isActive)),
                      DataCell(_MasterActions(
                        canEdit: _canEdit,
                        canDelete: _canDelete,
                        onEdit: () => _edit(m),
                        onToggle: () => _toggle(m, !m.isActive),
                        onDelete: () => _delete(m),
                        active: m.isActive,
                      )),
                    ]),
                  ),
          ),
        ),
      ],
    );
  }
}

/// §4.5 — measurement units registry.
class UnitsTab extends ConsumerStatefulWidget {
  const UnitsTab({super.key});

  @override
  ConsumerState<UnitsTab> createState() => _UnitsTabState();
}

class _UnitsTabState extends ConsumerState<UnitsTab> {
  bool get _canEdit =>
      ref.read(authControllerProvider).permissions.contains(Perm.inventoryEdit);
  bool get _canDelete =>
      ref.read(authControllerProvider).permissions.contains(Perm.inventoryDelete);
  String? get _actingUserId => ref.read(authControllerProvider).user?.id;
  String? get _actingRoleId => ref.read(authControllerProvider).actingRoleId;

  void _snack(bool ok) {
    final l10n = AppLocalizations.of(context);
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(
        content: Text(ok ? l10n.masterDataSavedMessage : l10n.authSaveError),
      ));
  }

  Future<void> _add() async {
    final l10n = AppLocalizations.of(context);
    final result = await showMasterDataFormDialog(
      context,
      kind: MasterDataKind.unit,
      title: l10n.unitsAdd,
    );
    if (result == null || !mounted) return;
    final failure = await ref.read(masterDataControllerProvider.notifier)
        .createUnit(result.draft,
            actingUserId: _actingUserId, actingRoleId: _actingRoleId);
    if (failure != null && mounted) {
      _showFailure(context, failure);
      return;
    }
    _snack(true);
  }

  Future<void> _edit(UnitRow row) async {
    final l10n = AppLocalizations.of(context);
    final result = await showMasterDataFormDialog(
      context,
      kind: MasterDataKind.unit,
      title: l10n.unitsEditTitle,
      initial: MasterDataDraft(
        name: row.name,
        nameEn: row.nameEn,
        abbreviation: row.abbreviation,
        description: row.description,
      ),
    );
    if (result == null || !mounted) return;
    final failure = await ref.read(masterDataControllerProvider.notifier)
        .updateUnit(row.id, result.draft,
            actingUserId: _actingUserId, actingRoleId: _actingRoleId);
    if (failure != null && mounted) {
      _showFailure(context, failure);
      return;
    }
    _snack(true);
  }

  Future<void> _delete(UnitRow row) async {
    final l10n = AppLocalizations.of(context);
    final confirmed = await showAppConfirmDialog(
      context,
      title: l10n.masterDataDeleteTitle,
      message: l10n.masterDataDeleteConfirm(row.name),
      confirmLabel: l10n.commonDelete,
      destructive: true,
    );
    if (!confirmed || !mounted) return;
    final failure = await ref.read(masterDataControllerProvider.notifier)
        .deleteUnit(row.id,
            actingUserId: _actingUserId, actingRoleId: _actingRoleId);
    if (failure == null && mounted) {
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(content: Text(l10n.masterDataDeletedMessage)));
    }
    if (failure != null && mounted) _showFailure(context, failure);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final state = ref.watch(masterDataControllerProvider);
    final header = _tabHeader(
      context: context,
      l10n: l10n,
      title: l10n.inventoryTabUnits,
      canEdit: _canEdit,
      onAdd: _add,
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        header,
        Expanded(
          child: LoadingOverlay(
            visible: state.status == MasterDataStatus.loading,
            label: l10n.commonLoading,
            child: state.status == MasterDataStatus.error
                ? Center(
                    child: Text(l10n.commonError,
                        style: context.appTypography.labelSmall),
                  )
                : PagedMasterTable<UnitRow>(
                    emptyMessage: l10n.unitsEmpty,
                    data: state.units,
                    searchText: (u) => '${u.name} ${u.nameEn ?? ''}',
                    columns: [
                      DataColumn(label: Text(l10n.unitName)),
                      DataColumn(label: Text(l10n.unitAbbreviation)),
                      DataColumn(label: Text(l10n.userStatusActive)),
                      DataColumn(label: Text('')),
                    ],
                    rowBuilder: (u) => DataRow(cells: [
                      DataCell(Text(u.name)),
                      DataCell(Text(u.abbreviation ?? '')),
                      DataCell(_ActiveStatusChipBox(active: u.isActive)),
                      DataCell(_MasterActions(
                        canEdit: _canEdit,
                        canDelete: _canDelete,
                        onEdit: () => _edit(u),
                        onDelete: () => _delete(u),
                      )),
                    ]),
                  ),
          ),
        ),
      ],
    );
  }
}

/// §4.2b — active ingredients registry.
class ActiveIngredientsTab extends ConsumerStatefulWidget {
  const ActiveIngredientsTab({super.key});

  @override
  ConsumerState<ActiveIngredientsTab> createState() =>
      _ActiveIngredientsTabState();
}

class _ActiveIngredientsTabState extends ConsumerState<ActiveIngredientsTab> {
  bool get _canEdit =>
      ref.read(authControllerProvider).permissions.contains(Perm.inventoryEdit);
  bool get _canDelete =>
      ref.read(authControllerProvider).permissions.contains(Perm.inventoryDelete);
  String? get _actingUserId => ref.read(authControllerProvider).user?.id;
  String? get _actingRoleId => ref.read(authControllerProvider).actingRoleId;

  void _snack(bool ok) {
    final l10n = AppLocalizations.of(context);
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(
        content: Text(ok ? l10n.masterDataSavedMessage : l10n.authSaveError),
      ));
  }

  Future<void> _add() async {
    final l10n = AppLocalizations.of(context);
    final result = await showMasterDataFormDialog(
      context,
      kind: MasterDataKind.activeIngredient,
      title: l10n.activeIngredientsAdd,
    );
    if (result == null || !mounted) return;
    final failure = await ref.read(masterDataControllerProvider.notifier)
        .createActiveIngredient(result.draft,
            actingUserId: _actingUserId, actingRoleId: _actingRoleId);
    if (failure != null && mounted) {
      _showFailure(context, failure);
      return;
    }
    _snack(true);
  }

  Future<void> _edit(ActiveIngredientRow row) async {
    final l10n = AppLocalizations.of(context);
    final result = await showMasterDataFormDialog(
      context,
      kind: MasterDataKind.activeIngredient,
      title: l10n.activeIngredientsEditTitle,
      initial: MasterDataDraft(
        name: row.name,
        nameEn: row.nameEn,
        description: row.description,
      ),
    );
    if (result == null || !mounted) return;
    final failure = await ref.read(masterDataControllerProvider.notifier)
        .updateActiveIngredient(row.id, result.draft,
            actingUserId: _actingUserId, actingRoleId: _actingRoleId);
    if (failure != null && mounted) {
      _showFailure(context, failure);
      return;
    }
    _snack(true);
  }

  Future<void> _toggle(ActiveIngredientRow row, bool active) async {
    final failure = await ref.read(masterDataControllerProvider.notifier)
        .setActiveIngredientActive(row.id, active,
            actingUserId: _actingUserId, actingRoleId: _actingRoleId);
    if (failure != null && mounted) {
      _showFailure(context, failure);
      return;
    }
    _snack(true);
  }

  Future<void> _delete(ActiveIngredientRow row) async {
    final l10n = AppLocalizations.of(context);
    final confirmed = await showAppConfirmDialog(
      context,
      title: l10n.masterDataDeleteTitle,
      message: l10n.masterDataDeleteConfirm(row.name),
      confirmLabel: l10n.commonDelete,
      destructive: true,
    );
    if (!confirmed || !mounted) return;
    final failure = await ref.read(masterDataControllerProvider.notifier)
        .deleteActiveIngredient(row.id,
            actingUserId: _actingUserId, actingRoleId: _actingRoleId);
    if (failure == null && mounted) {
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(content: Text(l10n.masterDataDeletedMessage)));
    }
    if (failure != null && mounted) _showFailure(context, failure);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final state = ref.watch(masterDataControllerProvider);
    final header = _tabHeader(
      context: context,
      l10n: l10n,
      title: l10n.inventoryTabActiveIngredients,
      canEdit: _canEdit,
      onAdd: _add,
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        header,
        Expanded(
          child: LoadingOverlay(
            visible: state.status == MasterDataStatus.loading,
            label: l10n.commonLoading,
            child: state.status == MasterDataStatus.error
                ? Center(
                    child: Text(l10n.commonError,
                        style: context.appTypography.labelSmall),
                  )
                : PagedMasterTable<ActiveIngredientRow>(
                    emptyMessage: l10n.activeIngredientsEmpty,
                    data: state.activeIngredients,
                    searchText: (a) => '${a.name} ${a.nameEn ?? ''}',
                    columns: [
                      DataColumn(label: Text(l10n.activeIngredientName)),
                      DataColumn(label: Text(l10n.masterDataNameEn)),
                      DataColumn(label: Text(l10n.userNotes)),
                      DataColumn(label: Text(l10n.userStatusActive)),
                      DataColumn(label: Text('')),
                    ],
                    rowBuilder: (a) => DataRow(cells: [
                      DataCell(Text(a.name)),
                      DataCell(Text(a.nameEn ?? '')),
                      DataCell(Text(a.description ?? '')),
                      DataCell(_ActiveStatusChipBox(active: a.isActive)),
                      DataCell(_MasterActions(
                        canEdit: _canEdit,
                        canDelete: _canDelete,
                        onEdit: () => _edit(a),
                        onToggle: () => _toggle(a, !a.isActive),
                        onDelete: () => _delete(a),
                        active: a.isActive,
                      )),
                    ]),
                  ),
          ),
        ),
      ],
    );
  }
}

/// §4.2c — indications registry.
class IndicationsTab extends ConsumerStatefulWidget {
  const IndicationsTab({super.key});

  @override
  ConsumerState<IndicationsTab> createState() => _IndicationsTabState();
}

class _IndicationsTabState extends ConsumerState<IndicationsTab> {
  bool get _canEdit =>
      ref.read(authControllerProvider).permissions.contains(Perm.inventoryEdit);
  bool get _canDelete =>
      ref.read(authControllerProvider).permissions.contains(Perm.inventoryDelete);
  String? get _actingUserId => ref.read(authControllerProvider).user?.id;
  String? get _actingRoleId => ref.read(authControllerProvider).actingRoleId;

  void _snack(bool ok) {
    final l10n = AppLocalizations.of(context);
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(
        content: Text(ok ? l10n.masterDataSavedMessage : l10n.authSaveError),
      ));
  }

  Future<void> _add() async {
    final l10n = AppLocalizations.of(context);
    final result = await showMasterDataFormDialog(
      context,
      kind: MasterDataKind.indication,
      title: l10n.indicationsAdd,
    );
    if (result == null || !mounted) return;
    final failure = await ref.read(masterDataControllerProvider.notifier)
        .createIndication(result.draft,
            actingUserId: _actingUserId, actingRoleId: _actingRoleId);
    if (failure != null && mounted) {
      _showFailure(context, failure);
      return;
    }
    _snack(true);
  }

  Future<void> _edit(IndicationRow row) async {
    final l10n = AppLocalizations.of(context);
    final result = await showMasterDataFormDialog(
      context,
      kind: MasterDataKind.indication,
      title: l10n.indicationsEditTitle,
      initial: MasterDataDraft(
        name: row.name,
        nameEn: row.nameEn,
        description: row.description,
      ),
    );
    if (result == null || !mounted) return;
    final failure = await ref.read(masterDataControllerProvider.notifier)
        .updateIndication(row.id, result.draft,
            actingUserId: _actingUserId, actingRoleId: _actingRoleId);
    if (failure != null && mounted) {
      _showFailure(context, failure);
      return;
    }
    _snack(true);
  }

  Future<void> _toggle(IndicationRow row, bool active) async {
    final failure = await ref.read(masterDataControllerProvider.notifier)
        .setIndicationActive(row.id, active,
            actingUserId: _actingUserId, actingRoleId: _actingRoleId);
    if (failure != null && mounted) {
      _showFailure(context, failure);
      return;
    }
    _snack(true);
  }

  Future<void> _delete(IndicationRow row) async {
    final l10n = AppLocalizations.of(context);
    final confirmed = await showAppConfirmDialog(
      context,
      title: l10n.masterDataDeleteTitle,
      message: l10n.masterDataDeleteConfirm(row.name),
      confirmLabel: l10n.commonDelete,
      destructive: true,
    );
    if (!confirmed || !mounted) return;
    final failure = await ref.read(masterDataControllerProvider.notifier)
        .deleteIndication(row.id,
            actingUserId: _actingUserId, actingRoleId: _actingRoleId);
    if (failure == null && mounted) {
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(content: Text(l10n.masterDataDeletedMessage)));
    }
    if (failure != null && mounted) _showFailure(context, failure);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final state = ref.watch(masterDataControllerProvider);
    final header = _tabHeader(
      context: context,
      l10n: l10n,
      title: l10n.inventoryTabIndications,
      canEdit: _canEdit,
      onAdd: _add,
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        header,
        Expanded(
          child: LoadingOverlay(
            visible: state.status == MasterDataStatus.loading,
            label: l10n.commonLoading,
            child: state.status == MasterDataStatus.error
                ? Center(
                    child: Text(l10n.commonError,
                        style: context.appTypography.labelSmall),
                  )
                : PagedMasterTable<IndicationRow>(
                    emptyMessage: l10n.indicationsEmpty,
                    data: state.indications,
                    searchText: (i) => '${i.name} ${i.nameEn ?? ''}',
                    columns: [
                      DataColumn(label: Text(l10n.indicationName)),
                      DataColumn(label: Text(l10n.masterDataNameEn)),
                      DataColumn(label: Text(l10n.userNotes)),
                      DataColumn(label: Text(l10n.userStatusActive)),
                      DataColumn(label: Text('')),
                    ],
                    rowBuilder: (i) => DataRow(cells: [
                      DataCell(Text(i.name)),
                      DataCell(Text(i.nameEn ?? '')),
                      DataCell(Text(i.description ?? '')),
                      DataCell(_ActiveStatusChipBox(active: i.isActive)),
                      DataCell(_MasterActions(
                        canEdit: _canEdit,
                        canDelete: _canDelete,
                        onEdit: () => _edit(i),
                        onToggle: () => _toggle(i, !i.isActive),
                        onDelete: () => _delete(i),
                        active: i.isActive,
                      )),
                    ]),
                  ),
          ),
        ),
      ],
    );
  }
}

/// Per-row action buttons for master-data grids. Edit + toggle sit behind
/// `inventory.edit`; the destructive delete behind `inventory.delete`.
class _MasterActions extends StatelessWidget {
  const _MasterActions({
    required this.canEdit,
    required this.canDelete,
    required this.onEdit,
    this.onToggle,
    this.onDelete,
    this.active = true,
  });

  final bool canEdit;
  final bool canDelete;
  final VoidCallback onEdit;
  final VoidCallback? onToggle;
  final VoidCallback? onDelete;
  final bool active;

  @override
  Widget build(BuildContext context) {
    if (!canEdit && !canDelete) return const SizedBox.shrink();
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (canEdit)
          IconButton(
            icon: const Icon(Icons.edit_outlined),
            tooltip: AppLocalizations.of(context).commonEdit,
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints.tightFor(width: 32, height: 32),
            onPressed: onEdit,
          ),
        if (canDelete && onDelete != null)
          IconButton(
            icon: const Icon(Icons.delete_outline),
            tooltip: AppLocalizations.of(context).commonDelete,
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints.tightFor(width: 32, height: 32),
            onPressed: onDelete,
          ),
        if (canEdit && onToggle != null)
          IconButton(
            icon: Icon(active ? Icons.block : Icons.check_circle_outline),
            tooltip: active
                ? AppLocalizations.of(context).userDeactivate
                : AppLocalizations.of(context).userActivate,
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints.tightFor(width: 32, height: 32),
            onPressed: onToggle,
          ),
      ],
    );
  }
}

/// Shorthand wrapper to keep master-data tables terse.
class _ActiveStatusChipBox extends StatelessWidget {
  const _ActiveStatusChipBox({required this.active});

  final bool active;

  @override
  Widget build(BuildContext context) {
    return ActiveStatusChip(active: active);
  }
}

/// Shared error presentation for master-data mutations. Callers guard for
/// `mounted` before invoking.
void _showFailure(BuildContext context, Failure? failure) {
  if (failure == null) return;
  final l10n = AppLocalizations.of(context);
  final message = switch (failure) {
    UnauthorizedFailure() => l10n.authPermissionDenied,
    InvalidOperationFailure(message: final m) => m,
    ValidationFailure(message: final m) => m,
    DuplicateFailure(message: final m) => m,
    NotFoundFailure(message: final m) => m,
    DatabaseFailure(message: final m) when (m).trim().isNotEmpty => m,
    _ => l10n.authSaveError,
  };
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(content: Text(message)));
}

/// Shared master-data tab header: title + add button (edit permission only).
Widget _tabHeader({
  required BuildContext context,
  required AppLocalizations l10n,
  required String title,
  required bool canEdit,
  required VoidCallback onAdd,
}) {
  return Padding(
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
        Text(title, style: context.appTypography.sectionTitle),
        if (canEdit)
          FilledButton.icon(
            onPressed: onAdd,
            icon: const Icon(Icons.add),
            label: Text(l10n.commonAdd),
          ),
      ],
    ),
  );
}