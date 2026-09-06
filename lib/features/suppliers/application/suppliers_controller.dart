import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/data_grid/page_request.dart';
import '../../../core/errors/exceptions.dart';
import '../../../core/errors/failures.dart';
import '../../../data/daos/supplier_dao.dart';
import '../../../shared/database/app_database.dart';
import '../domain/repositories/supplier_repository.dart';
import '../domain/usecases/suppliers_use_cases.dart';

enum SuppliersStatus { initial, loading, ready, error }

/// Suppliers page state: master grid + derived balances tab + statement view.
class SuppliersViewState {
  const SuppliersViewState({
    this.status = SuppliersStatus.initial,
    this.suppliers = const [],
    this.total = 0,
    this.request = const PageRequest(),
    this.balances = const [],
    this.balancesTotal = 0,
    this.balancesRequest = const PageRequest(),
    this.statement,
    this.statementLoading = false,
    this.error,
    this.busy = false,
  });

  final SuppliersStatus status;
  final List<SupplierRow> suppliers;
  final int total;
  final PageRequest request;

  final List<SupplierBalanceRow> balances;
  final int balancesTotal;
  final PageRequest balancesRequest;

  final SupplierStatementPage? statement;
  final bool statementLoading;

  final Failure? error;
  final bool busy;

  SuppliersViewState copyWith({
    SuppliersStatus? status,
    List<SupplierRow>? suppliers,
    int? total,
    PageRequest? request,
    List<SupplierBalanceRow>? balances,
    int? balancesTotal,
    PageRequest? balancesRequest,
    SupplierStatementPage? Function()? statement,
    bool? statementLoading,
    Failure? Function()? error,
    bool? busy,
  }) {
    return SuppliersViewState(
      status: status ?? this.status,
      suppliers: suppliers ?? this.suppliers,
      total: total ?? this.total,
      request: request ?? this.request,
      balances: balances ?? this.balances,
      balancesTotal: balancesTotal ?? this.balancesTotal,
      balancesRequest: balancesRequest ?? this.balancesRequest,
      statement: statement != null ? statement() : this.statement,
      statementLoading: statementLoading ?? this.statementLoading,
      error: error != null ? error() : this.error,
      busy: busy ?? this.busy,
    );
  }
}

/// Suppliers controller: master CRUD, derived balances and the statement
/// (كشف حساب). Runs permissions in the use cases; failures are surfaced as
/// [Failure] objects for the UI.
class SuppliersController extends StateNotifier<SuppliersViewState> {
  SuppliersController(
    this._list,
    this._create,
    this._update,
    this._setActive,
    this._balances,
    this._statement,
  ) : super(const SuppliersViewState());

  final ListSuppliersUseCase _list;
  final CreateSupplierUseCase _create;
  final UpdateSupplierUseCase _update;
  final SetSupplierActiveUseCase _setActive;
  final SupplierBalancesUseCase _balances;
  final SupplierStatementUseCase _statement;

  Future<Failure?> load({
    String search = '',
    int page = 1,
    String? actingRoleId,
  }) async {
    final request = PageRequest(
        page: page, pageSize: state.request.pageSize, search: search);
    state = state.copyWith(status: SuppliersStatus.loading, error: null);
    try {
      final result = await _list(request, actingRoleId: actingRoleId);
      state = state.copyWith(
        status: SuppliersStatus.ready,
        suppliers: result.items,
        total: result.total,
        request: result.request,
      );
      return null;
    } on AppException catch (e) {
      state = state.copyWith(
          status: SuppliersStatus.error, error: () => e.failure);
      return state.error;
    }
  }

  Future<Failure?> add(
    SupplierDraft draft, {
    String? actingUserId,
    String? actingRoleId,
  }) async {
    state = state.copyWith(busy: true, error: null);
    try {
      await _create(draft, actingUserId: actingUserId, actingRoleId: actingRoleId);
      return null;
    } on AppException catch (e) {
      return e.failure;
    } finally {
      state = state.copyWith(busy: false);
    }
  }

  Future<Failure?> update(
    String id,
    SupplierDraft draft, {
    String? actingUserId,
    String? actingRoleId,
  }) async {
    state = state.copyWith(busy: true, error: null);
    try {
      await _update(id, draft, actingUserId: actingUserId, actingRoleId: actingRoleId);
      return null;
    } on AppException catch (e) {
      return e.failure;
    } finally {
      state = state.copyWith(busy: false);
    }
  }

  Future<Failure?> toggleActive(
    String id,
    bool active, {
    String? actingUserId,
    String? actingRoleId,
  }) async {
    state = state.copyWith(busy: true, error: null);
    try {
      await _setActive(id, active,
          actingUserId: actingUserId, actingRoleId: actingRoleId);
      return null;
    } on AppException catch (e) {
      return e.failure;
    } finally {
      state = state.copyWith(busy: false);
    }
  }

  Future<Failure?> loadBalances({
    String search = '',
    int page = 1,
    String? actingRoleId,
  }) async {
    final request = PageRequest(
        page: page, pageSize: state.balancesRequest.pageSize, search: search);
    state = state.copyWith(error: null);
    try {
      final result = await _balances(request, actingRoleId: actingRoleId);
      state = state.copyWith(
        balances: result.items,
        balancesTotal: result.total,
        balancesRequest: result.request,
      );
      return null;
    } on AppException catch (e) {
      return e.failure;
    }
  }

  Future<Failure?> loadStatement(
    String supplierId, {
    required int fromDate,
    required int toDate,
    required int page,
    required int pageSize,
    String? actingRoleId,
  }) async {
    state = state.copyWith(statementLoading: true, error: null);
    try {
      final result = await _statement(
        supplierId,
        fromDate: fromDate,
        toDate: toDate,
        page: page,
        pageSize: pageSize,
        actingRoleId: actingRoleId,
      );
      state = state.copyWith(
          statement: () => result, statementLoading: false, error: null);
      return null;
    } on AppException catch (e) {
      state = state.copyWith(statementLoading: false, error: () => e.failure);
      return state.error;
    }
  }
}