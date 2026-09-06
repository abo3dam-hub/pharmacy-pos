import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/errors/exceptions.dart';
import '../../../core/errors/failures.dart';
import '../../../shared/database/app_database.dart';
import '../domain/repositories/inventory_repository.dart';
import '../domain/usecases/categories_use_cases.dart';
import '../domain/usecases/groups_use_cases.dart';
import '../domain/usecases/manufacturers_use_cases.dart';
import '../domain/usecases/units_use_cases.dart';

enum MasterDataStatus { initial, loading, ready, error }

/// Categories / sub-categories / manufacturers / therapeutic groups / units —
/// the item master-data registry (§4.1–4.5).
class MasterDataViewState {
  const MasterDataViewState({
    this.status = MasterDataStatus.initial,
    this.categories = const [],
    this.subCategories = const [],
    this.manufacturers = const [],
    this.groups = const [],
    this.units = const [],
    this.error,
    this.busy = false,
  });

  final MasterDataStatus status;
  final List<CategoryRow> categories;
  final List<SubCategoryRow> subCategories;
  final List<ManufacturerRow> manufacturers;
  final List<TherapeuticGroupRow> groups;
  final List<UnitRow> units;
  final Failure? error;
  final bool busy;

  List<SubCategoryRow> subsOf(String categoryId) =>
      subCategories.where((s) => s.categoryId == categoryId).toList();

  MasterDataViewState copyWith({
    MasterDataStatus? status,
    List<CategoryRow>? categories,
    List<SubCategoryRow>? subCategories,
    List<ManufacturerRow>? manufacturers,
    List<TherapeuticGroupRow>? groups,
    List<UnitRow>? units,
    Failure? Function()? error,
    bool? busy,
  }) {
    return MasterDataViewState(
      status: status ?? this.status,
      categories: categories ?? this.categories,
      subCategories: subCategories ?? this.subCategories,
      manufacturers: manufacturers ?? this.manufacturers,
      groups: groups ?? this.groups,
      units: units ?? this.units,
      error: error != null ? error() : this.error,
      busy: busy ?? this.busy,
    );
  }
}

/// Master-data tabs controller. All mutations go through audited use cases
/// (`inventory.edit`) and reload the in-memory lists afterwards.
class MasterDataController extends StateNotifier<MasterDataViewState> {
  MasterDataController(
    this._listCategories,
    this._saveCategory,
    this._saveSubCategory,
    this._setCategoryActive,
    this._saveManufacturer,
    this._setManufacturerActive,
    this._allManufacturers,
    this._listGroups,
    this._saveGroup,
    this._setGroupActive,
    this._listUnits,
    this._saveUnit,
  ) : super(const MasterDataViewState());

  final ListCategoriesUseCase _listCategories;
  final SaveCategoryUseCase _saveCategory;
  final SaveSubCategoryUseCase _saveSubCategory;
  final SetCategoryActiveUseCase _setCategoryActive;
  final SaveManufacturerUseCase _saveManufacturer;
  final SetManufacturerActiveUseCase _setManufacturerActive;
  final AllManufacturersUseCase _allManufacturers;
  final ListTherapeuticGroupsUseCase _listGroups;
  final SaveTherapeuticGroupUseCase _saveGroup;
  final SetTherapeuticGroupActiveUseCase _setGroupActive;
  final ListUnitsUseCase _listUnits;
  final SaveUnitUseCase _saveUnit;

  Future<Failure?> load({String? actingRoleId}) async {
    state = state.copyWith(status: MasterDataStatus.loading, error: () => null);
    try {
      final cats = await _listCategories.call(actingRoleId: actingRoleId);
      final manufacturers = await _allManufacturers.call(actingRoleId: actingRoleId);
      final groups = await _listGroups.call(actingRoleId: actingRoleId);
      final units = await _listUnits.call(actingRoleId: actingRoleId);
      state = MasterDataViewState(
        status: MasterDataStatus.ready,
        categories: cats.categories,
        subCategories: cats.allSubs,
        manufacturers: manufacturers,
        groups: groups,
        units: units,
      );
      return null;
    } on AppException catch (e) {
      state = state.copyWith(status: MasterDataStatus.error, error: () => e.failure);
      return e.failure;
    }
  }

  Future<Failure?> reload({String? actingRoleId}) => load(actingRoleId: actingRoleId);

  void clearError() => state = state.copyWith(error: () => null);

  // ----- categories -----

  Future<Failure?> createCategory(
    MasterDataDraft draft, {
    String? actingUserId,
    String? actingRoleId,
  }) =>
      _run(() => _saveCategory.create(draft,
          actingUserId: actingUserId, actingRoleId: actingRoleId),
          actingRoleId: actingRoleId);

  Future<Failure?> updateCategory(
    String id,
    MasterDataDraft draft, {
    String? actingUserId,
    String? actingRoleId,
  }) =>
      _run(() => _saveCategory.update(id, draft,
          actingUserId: actingUserId, actingRoleId: actingRoleId),
          actingRoleId: actingRoleId);

  Future<Failure?> setCategoryActive(
    String id,
    bool active, {
    String? actingUserId,
    String? actingRoleId,
  }) =>
      _run(() => _setCategoryActive.category(id, active,
          actingUserId: actingUserId, actingRoleId: actingRoleId),
          actingRoleId: actingRoleId);

  Future<Failure?> createSubCategory(
    MasterDataDraft draft, {
    String? actingUserId,
    String? actingRoleId,
  }) =>
      _run(() => _saveSubCategory.create(draft,
          actingUserId: actingUserId, actingRoleId: actingRoleId),
          actingRoleId: actingRoleId);

  Future<Failure?> updateSubCategory(
    String id,
    MasterDataDraft draft, {
    String? actingUserId,
    String? actingRoleId,
  }) =>
      _run(() => _saveSubCategory.update(id, draft,
          actingUserId: actingUserId, actingRoleId: actingRoleId),
          actingRoleId: actingRoleId);

  Future<Failure?> setSubCategoryActive(
    String id,
    bool active, {
    String? actingUserId,
    String? actingRoleId,
  }) =>
      _run(() => _setCategoryActive.subCategory(id, active,
          actingUserId: actingUserId, actingRoleId: actingRoleId),
          actingRoleId: actingRoleId);

  // ----- manufacturers -----

  Future<Failure?> createManufacturer(
    MasterDataDraft draft, {
    String? actingUserId,
    String? actingRoleId,
  }) =>
      _run(() => _saveManufacturer.create(draft,
          actingUserId: actingUserId, actingRoleId: actingRoleId),
          actingRoleId: actingRoleId);

  Future<Failure?> updateManufacturer(
    String id,
    MasterDataDraft draft, {
    String? actingUserId,
    String? actingRoleId,
  }) =>
      _run(() => _saveManufacturer.update(id, draft,
          actingUserId: actingUserId, actingRoleId: actingRoleId),
          actingRoleId: actingRoleId);

  Future<Failure?> setManufacturerActive(
    String id,
    bool active, {
    String? actingUserId,
    String? actingRoleId,
  }) =>
      _run(() => _setManufacturerActive.call(id, active,
          actingUserId: actingUserId, actingRoleId: actingRoleId),
          actingRoleId: actingRoleId);

  // ----- therapeutic groups -----

  Future<Failure?> createGroup(
    MasterDataDraft draft, {
    String? actingUserId,
    String? actingRoleId,
  }) =>
      _run(() => _saveGroup.create(draft,
          actingUserId: actingUserId, actingRoleId: actingRoleId),
          actingRoleId: actingRoleId);

  Future<Failure?> updateGroup(
    String id,
    MasterDataDraft draft, {
    String? actingUserId,
    String? actingRoleId,
  }) =>
      _run(() => _saveGroup.update(id, draft,
          actingUserId: actingUserId, actingRoleId: actingRoleId),
          actingRoleId: actingRoleId);

  Future<Failure?> setGroupActive(
    String id,
    bool active, {
    String? actingUserId,
    String? actingRoleId,
  }) =>
      _run(() => _setGroupActive.call(id, active,
          actingUserId: actingUserId, actingRoleId: actingRoleId),
          actingRoleId: actingRoleId);

  // ----- units -----

  Future<Failure?> createUnit(
    MasterDataDraft draft, {
    String? actingUserId,
    String? actingRoleId,
  }) =>
      _run(() => _saveUnit.create(draft,
          actingUserId: actingUserId, actingRoleId: actingRoleId),
          actingRoleId: actingRoleId);

  Future<Failure?> updateUnit(
    String id,
    MasterDataDraft draft, {
    String? actingUserId,
    String? actingRoleId,
  }) =>
      _run(() => _saveUnit.update(id, draft,
          actingUserId: actingUserId, actingRoleId: actingRoleId),
          actingRoleId: actingRoleId);

  Future<Failure?> _run(
    Future<Object?> Function() action, {
    String? actingRoleId,
  }) async {
    state = state.copyWith(busy: true, error: () => null);
    try {
      await action();
      await reload(actingRoleId: actingRoleId);
      return null;
    } on AppException catch (e) {
      state = state.copyWith(busy: false, error: () => e.failure);
      return e.failure;
    } on Exception {
      state = state.copyWith(busy: false);
      return const DatabaseFailure('حدث خطأ غير متوقع أثناء العملية');
    }
  }
}