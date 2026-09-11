import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/errors/exceptions.dart';
import '../../../core/errors/failures.dart';
import '../../../shared/database/app_database.dart';
import '../domain/repositories/inventory_repository.dart';
import '../domain/usecases/active_ingredients_use_cases.dart';
import '../domain/usecases/categories_use_cases.dart';
import '../domain/usecases/indications_use_cases.dart';
import '../domain/usecases/manufacturers_use_cases.dart';
import '../domain/usecases/units_use_cases.dart';

enum MasterDataStatus { initial, loading, ready, error }

/// Categories / manufacturers / units / active ingredients / indications —
/// the item master-data registry (§4.1–4.5).
class MasterDataViewState {
  const MasterDataViewState({
    this.status = MasterDataStatus.initial,
    this.categories = const [],
    this.manufacturers = const [],
    this.units = const [],
    this.activeIngredients = const [],
    this.indications = const [],
    this.error,
    this.busy = false,
  });

  final MasterDataStatus status;
  final List<CategoryRow> categories;
  final List<ManufacturerRow> manufacturers;
  final List<UnitRow> units;
  final List<ActiveIngredientRow> activeIngredients;
  final List<IndicationRow> indications;
  final Failure? error;
  final bool busy;

  MasterDataViewState copyWith({
    MasterDataStatus? status,
    List<CategoryRow>? categories,
    List<ManufacturerRow>? manufacturers,
    List<UnitRow>? units,
    List<ActiveIngredientRow>? activeIngredients,
    List<IndicationRow>? indications,
    Failure? Function()? error,
    bool? busy,
  }) {
    return MasterDataViewState(
      status: status ?? this.status,
      categories: categories ?? this.categories,
      manufacturers: manufacturers ?? this.manufacturers,
      units: units ?? this.units,
      activeIngredients: activeIngredients ?? this.activeIngredients,
      indications: indications ?? this.indications,
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
    this._setCategoryActive,
    this._saveManufacturer,
    this._setManufacturerActive,
    this._allManufacturers,
    this._listUnits,
    this._saveUnit,
    this._listActiveIngredients,
    this._saveActiveIngredient,
    this._setActiveIngredientActive,
    this._listIndications,
    this._saveIndication,
    this._setIndicationActive,
  ) : super(const MasterDataViewState());

  final ListCategoriesUseCase _listCategories;
  final SaveCategoryUseCase _saveCategory;
  final SetCategoryActiveUseCase _setCategoryActive;
  final SaveManufacturerUseCase _saveManufacturer;
  final SetManufacturerActiveUseCase _setManufacturerActive;
  final AllManufacturersUseCase _allManufacturers;
  final ListUnitsUseCase _listUnits;
  final SaveUnitUseCase _saveUnit;
  final ListActiveIngredientsUseCase _listActiveIngredients;
  final SaveActiveIngredientUseCase _saveActiveIngredient;
  final SetActiveIngredientActiveUseCase _setActiveIngredientActive;
  final ListIndicationsUseCase _listIndications;
  final SaveIndicationUseCase _saveIndication;
  final SetIndicationActiveUseCase _setIndicationActive;

  Future<Failure?> load({String? actingRoleId}) async {
    state = state.copyWith(status: MasterDataStatus.loading, error: () => null);
    try {
      final cats = await _listCategories.call(actingRoleId: actingRoleId);
      final manufacturers = await _allManufacturers.call(actingRoleId: actingRoleId);
      final units = await _listUnits.call(actingRoleId: actingRoleId);
      final ingredients =
          await _listActiveIngredients.call(actingRoleId: actingRoleId);
      final indications = await _listIndications.call(actingRoleId: actingRoleId);
      state = MasterDataViewState(
        status: MasterDataStatus.ready,
        categories: cats.categories,
        manufacturers: manufacturers,
        units: units,
        activeIngredients: ingredients,
        indications: indications,
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

  // ----- active ingredients -----

  Future<Failure?> createActiveIngredient(
    MasterDataDraft draft, {
    String? actingUserId,
    String? actingRoleId,
  }) =>
      _run(() => _saveActiveIngredient.create(draft,
          actingUserId: actingUserId, actingRoleId: actingRoleId),
          actingRoleId: actingRoleId);

  Future<Failure?> updateActiveIngredient(
    String id,
    MasterDataDraft draft, {
    String? actingUserId,
    String? actingRoleId,
  }) =>
      _run(() => _saveActiveIngredient.update(id, draft,
          actingUserId: actingUserId, actingRoleId: actingRoleId),
          actingRoleId: actingRoleId);

  Future<Failure?> setActiveIngredientActive(
    String id,
    bool active, {
    String? actingUserId,
    String? actingRoleId,
  }) =>
      _run(() => _setActiveIngredientActive.call(id, active,
          actingUserId: actingUserId, actingRoleId: actingRoleId),
          actingRoleId: actingRoleId);

  // ----- indications -----

  Future<Failure?> createIndication(
    MasterDataDraft draft, {
    String? actingUserId,
    String? actingRoleId,
  }) =>
      _run(() => _saveIndication.create(draft,
          actingUserId: actingUserId, actingRoleId: actingRoleId),
          actingRoleId: actingRoleId);

  Future<Failure?> updateIndication(
    String id,
    MasterDataDraft draft, {
    String? actingUserId,
    String? actingRoleId,
  }) =>
      _run(() => _saveIndication.update(id, draft,
          actingUserId: actingUserId, actingRoleId: actingRoleId),
          actingRoleId: actingRoleId);

  Future<Failure?> setIndicationActive(
    String id,
    bool active, {
    String? actingUserId,
    String? actingRoleId,
  }) =>
      _run(() => _setIndicationActive.call(id, active,
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