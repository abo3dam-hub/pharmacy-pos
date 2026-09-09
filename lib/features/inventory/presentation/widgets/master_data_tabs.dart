import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/constants/permission_codes.dart';
import '../../../../core/di/providers.dart';
import '../../../../core/errors/failures.dart';
import '../../../../core/theme/app_dimensions.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/widgets/app_data_table.dart';
import '../../../../core/widgets/confirm_dialog.dart';
import '../../../../core/widgets/loading_overlay.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../../shared/database/app_database.dart';
import '../../application/master_data_controller.dart';
import '../../domain/repositories/inventory_repository.dart';
import '../widgets/master_data_dialog.dart';
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
    if (failure != null) _showFailure(failure);
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
    if (failure != null) _showFailure(failure);
  }

  Future<void> _addSubCategory(CategoryRow parent) async {
    final l10n = AppLocalizations.of(context);
    final result = await showMasterDataFormDialog(
      context,
      kind: MasterDataKind.subCategory,
      title: l10n.subCategoriesAddTitle,
      initial: MasterDataDraft(name: '', categoryId: parent.id),
      categories: ref.read(masterDataControllerProvider).categories,
    );
    if (result == null || !mounted) return;
    final failure = await ref.read(masterDataControllerProvider.notifier)
        .createSubCategory(result.draft,
            actingUserId: _actingUserId, actingRoleId: _actingRoleId);
    if (failure == null && mounted) _saved();
    if (failure != null) _showFailure(failure);
  }

  Future<void> _editSubCategory(SubCategoryRow row) async {
    final l10n = AppLocalizations.of(context);
    final result = await showMasterDataFormDialog(
      context,
      kind: MasterDataKind.subCategory,
      title: l10n.subCategoriesEditTitle,
      initial: MasterDataDraft(
        name: row.name,
        nameEn: row.nameEn,
        description: row.description,
        categoryId: row.categoryId,
      ),
      categories: ref.read(masterDataControllerProvider).categories,
    );
    if (result == null || !mounted) return;
    final failure = await ref.read(masterDataControllerProvider.notifier)
        .updateSubCategory(row.id, result.draft,
            actingUserId: _actingUserId, actingRoleId: _actingRoleId);
    if (failure == null && mounted) _saved();
    if (failure != null) _showFailure(failure);
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
    if (failure != null) _showFailure(failure);
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
                : AppDataTable(
                    emptyMessage: l10n.categoriesEmpty,
                    columns: [
                      DataColumn(label: Text(l10n.categoryName)),
                      DataColumn(label: Text(l10n.categoryNameEn)),
                      DataColumn(label: Text(l10n.itemSubCategory)),
                      DataColumn(label: Text(l10n.userStatusActive)),
                      DataColumn(label: Text('')),
                    ],
                    rows: [
                      for (final c in state.categories)
                        DataRow(cells: [
                          DataCell(Text(c.name)),
                          DataCell(Text(c.nameEn ?? '')),
                          DataCell(
                            _subCategoryChips(
                              state.subsOf(c.id),
                              onEdit: _editSubCategory,
                            ),
                          ),
                          DataCell(_ActiveStatusChipBox(active: c.isActive)),
                          DataCell(_MasterActions(
                            canEdit: _canEdit,
                            onEdit: () => _editCategory(c),
                            onAddSub: () => _addSubCategory(c),
                            onToggle: () => _toggleCategory(c),
                            active: c.isActive,
                          )),
                        ]),
                    ],
                  ),
          ),
        ),
      ],
    );
  }

  Widget _subCategoryChips(
    List<SubCategoryRow> subs, {
    required Future<void> Function(SubCategoryRow) onEdit,
  }) {
    if (subs.isEmpty) {
      return const SizedBox.shrink();
    }
    return Wrap(
      spacing: AppSpacing.xs,
      runSpacing: AppSpacing.xs,
      children: [
        for (final s in subs)
          ActionChip(
            avatar: const Icon(Icons.folder_open_outlined, size: 14),
            label: Text(s.name),
            visualDensity: VisualDensity.compact,
            onPressed: _canEdit ? () => onEdit(s) : null,
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
    if (failure != null) return;
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
    if (failure != null) return;
    _snack(true);
  }

  Future<void> _toggle(ManufacturerRow row, bool active) async {
    final failure = await ref.read(masterDataControllerProvider.notifier)
        .setManufacturerActive(row.id, active,
            actingUserId: _actingUserId, actingRoleId: _actingRoleId);
    if (failure != null) return;
    _snack(true);
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
                : AppDataTable(
                    emptyMessage: l10n.manufacturersEmpty,
                    columns: [
                      DataColumn(label: Text(l10n.manufacturerName)),
                      DataColumn(label: Text(l10n.manufacturerCountry)),
                      DataColumn(label: Text(l10n.userPhone)),
                      DataColumn(label: Text(l10n.userStatusActive)),
                      DataColumn(label: Text('')),
                    ],
                    rows: [
                      for (final m in state.manufacturers)
                        DataRow(cells: [
                          DataCell(Text(m.name)),
                          DataCell(Text(m.country ?? '')),
                          DataCell(Text(m.phone ?? '')),
                          DataCell(_ActiveStatusChipBox(active: m.isActive)),
                          DataCell(_MasterActions(
                            canEdit: _canEdit,
                            onEdit: () => _edit(m),
                            onToggle: () => _toggle(m, !m.isActive),
                            active: m.isActive,
                          )),
                        ]),
                    ],
                  ),
          ),
        ),
      ],
    );
  }
}

/// §4.2 — therapeutic groups registry.
class GroupsTab extends ConsumerStatefulWidget {
  const GroupsTab({super.key});

  @override
  ConsumerState<GroupsTab> createState() => _GroupsTabState();
}

class _GroupsTabState extends ConsumerState<GroupsTab> {
  bool get _canEdit =>
      ref.read(authControllerProvider).permissions.contains(Perm.inventoryEdit);
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
      kind: MasterDataKind.group,
      title: l10n.groupsAdd,
    );
    if (result == null || !mounted) return;
    final failure = await ref.read(masterDataControllerProvider.notifier)
        .createGroup(result.draft,
            actingUserId: _actingUserId, actingRoleId: _actingRoleId);
    if (failure != null) return;
    _snack(true);
  }

  Future<void> _edit(TherapeuticGroupRow row) async {
    final l10n = AppLocalizations.of(context);
    final result = await showMasterDataFormDialog(
      context,
      kind: MasterDataKind.group,
      title: l10n.groupsEditTitle,
      initial: MasterDataDraft(
        name: row.name,
        description: row.description,
      ),
    );
    if (result == null || !mounted) return;
    final failure = await ref.read(masterDataControllerProvider.notifier)
        .updateGroup(row.id, result.draft,
            actingUserId: _actingUserId, actingRoleId: _actingRoleId);
    if (failure != null) return;
    _snack(true);
  }

  Future<void> _toggle(TherapeuticGroupRow row, bool active) async {
    final failure = await ref.read(masterDataControllerProvider.notifier)
        .setGroupActive(row.id, active,
            actingUserId: _actingUserId, actingRoleId: _actingRoleId);
    if (failure != null) return;
    _snack(true);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final state = ref.watch(masterDataControllerProvider);
    final header = _tabHeader(
      context: context,
      l10n: l10n,
      title: l10n.inventoryTabGroups,
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
                : AppDataTable(
                    emptyMessage: l10n.groupsEmpty,
                    columns: [
                      DataColumn(label: Text(l10n.groupName)),
                      DataColumn(label: Text(l10n.userNotes)),
                      DataColumn(label: Text(l10n.userStatusActive)),
                      DataColumn(label: Text('')),
                    ],
                    rows: [
                      for (final g in state.groups)
                        DataRow(cells: [
                          DataCell(Text(g.name)),
                          DataCell(Text(g.description ?? '')),
                          DataCell(_ActiveStatusChipBox(active: g.isActive)),
                          DataCell(_MasterActions(
                            canEdit: _canEdit,
                            onEdit: () => _edit(g),
                            onToggle: () => _toggle(g, !g.isActive),
                            active: g.isActive,
                          )),
                        ]),
                    ],
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
    if (failure != null) return;
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
    if (failure != null) return;
    _snack(true);
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
                : AppDataTable(
                    emptyMessage: l10n.unitsEmpty,
                    columns: [
                      DataColumn(label: Text(l10n.unitName)),
                      DataColumn(label: Text(l10n.unitAbbreviation)),
                      DataColumn(label: Text(l10n.userStatusActive)),
                      DataColumn(label: Text('')),
                    ],
                    rows: [
                      for (final u in state.units)
                        DataRow(cells: [
                          DataCell(Text(u.name)),
                          DataCell(Text(u.abbreviation ?? '')),
                          DataCell(_ActiveStatusChipBox(active: u.isActive)),
                          DataCell(_MasterActions(
                            canEdit: _canEdit,
                            onEdit: () => _edit(u),
                          )),
                        ]),
                    ],
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
    if (failure != null) return;
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
    if (failure != null) return;
    _snack(true);
  }

  Future<void> _toggle(ActiveIngredientRow row, bool active) async {
    final failure = await ref.read(masterDataControllerProvider.notifier)
        .setActiveIngredientActive(row.id, active,
            actingUserId: _actingUserId, actingRoleId: _actingRoleId);
    if (failure != null) return;
    _snack(true);
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
                : AppDataTable(
                    emptyMessage: l10n.activeIngredientsEmpty,
                    columns: [
                      DataColumn(label: Text(l10n.activeIngredientName)),
                      DataColumn(label: Text(l10n.masterDataNameEn)),
                      DataColumn(label: Text(l10n.userNotes)),
                      DataColumn(label: Text(l10n.userStatusActive)),
                      DataColumn(label: Text('')),
                    ],
                    rows: [
                      for (final a in state.activeIngredients)
                        DataRow(cells: [
                          DataCell(Text(a.name)),
                          DataCell(Text(a.nameEn ?? '')),
                          DataCell(Text(a.description ?? '')),
                          DataCell(_ActiveStatusChipBox(active: a.isActive)),
                          DataCell(_MasterActions(
                            canEdit: _canEdit,
                            onEdit: () => _edit(a),
                            onToggle: () => _toggle(a, !a.isActive),
                            active: a.isActive,
                          )),
                        ]),
                    ],
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
    if (failure != null) return;
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
    if (failure != null) return;
    _snack(true);
  }

  Future<void> _toggle(IndicationRow row, bool active) async {
    final failure = await ref.read(masterDataControllerProvider.notifier)
        .setIndicationActive(row.id, active,
            actingUserId: _actingUserId, actingRoleId: _actingRoleId);
    if (failure != null) return;
    _snack(true);
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
                : AppDataTable(
                    emptyMessage: l10n.indicationsEmpty,
                    columns: [
                      DataColumn(label: Text(l10n.indicationName)),
                      DataColumn(label: Text(l10n.masterDataNameEn)),
                      DataColumn(label: Text(l10n.userNotes)),
                      DataColumn(label: Text(l10n.userStatusActive)),
                      DataColumn(label: Text('')),
                    ],
                    rows: [
                      for (final i in state.indications)
                        DataRow(cells: [
                          DataCell(Text(i.name)),
                          DataCell(Text(i.nameEn ?? '')),
                          DataCell(Text(i.description ?? '')),
                          DataCell(_ActiveStatusChipBox(active: i.isActive)),
                          DataCell(_MasterActions(
                            canEdit: _canEdit,
                            onEdit: () => _edit(i),
                            onToggle: () => _toggle(i, !i.isActive),
                            active: i.isActive,
                          )),
                        ]),
                    ],
                  ),
          ),
        ),
      ],
    );
  }
}

/// Per-row action buttons for master-data grids.
class _MasterActions extends StatelessWidget {
const _MasterActions({
    required this.canEdit,
    required this.onEdit,
    this.onAddSub,
    this.onToggle,
    this.active = true,
  });

  final bool canEdit;
  final VoidCallback onEdit;
  final VoidCallback? onAddSub;
  final VoidCallback? onToggle;
  final bool active;

  @override
  Widget build(BuildContext context) {
    if (!canEdit) return const SizedBox.shrink();
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        IconButton(
          icon: const Icon(Icons.edit_outlined),
          tooltip: AppLocalizations.of(context).commonEdit,
          padding: EdgeInsets.zero,
          constraints: const BoxConstraints.tightFor(width: 32, height: 32),
          onPressed: onEdit,
        ),
        if (onAddSub != null)
          IconButton(
            icon: const Icon(Icons.create_new_folder_outlined),
            tooltip: AppLocalizations.of(context).addSubCategory,
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints.tightFor(width: 32, height: 32),
            onPressed: onAddSub,
          ),
        if (onToggle != null)
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