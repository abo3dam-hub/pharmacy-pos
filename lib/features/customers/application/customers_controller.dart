import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/data_grid/page_request.dart';
import '../../../core/errors/exceptions.dart';
import '../../../core/errors/failures.dart';
import '../../../shared/database/app_database.dart';
import '../domain/repositories/customer_repository.dart';
import '../domain/usecases/customers_use_cases.dart';

enum CustomersStatus { initial, loading, ready, error }

/// Customers page state: master grid + statement view (كشف حساب العميل).
class CustomersViewState {
  const CustomersViewState({
    this.status = CustomersStatus.initial,
    this.customers = const [],
    this.total = 0,
    this.request = const PageRequest(),
    this.statement,
    this.statementLoading = false,
    this.error,
    this.busy = false,
  });

  final CustomersStatus status;
  final List<CustomerRow> customers;
  final int total;
  final PageRequest request;

  final CustomerStatementPage? statement;
  final bool statementLoading;

  final Failure? error;
  final bool busy;

  CustomersViewState copyWith({
    CustomersStatus? status,
    List<CustomerRow>? customers,
    int? total,
    PageRequest? request,
    CustomerStatementPage? Function()? statement,
    bool? statementLoading,
    Failure? Function()? error,
    bool? busy,
  }) {
    return CustomersViewState(
      status: status ?? this.status,
      customers: customers ?? this.customers,
      total: total ?? this.total,
      request: request ?? this.request,
      statement: statement != null ? statement() : this.statement,
      statementLoading: statementLoading ?? this.statementLoading,
      error: error != null ? error() : this.error,
      busy: busy ?? this.busy,
    );
  }
}

/// Customers controller: master CRUD, account enable/disable and the statement.
/// Permissions run in the use cases; failures surface as [Failure] objects.
class CustomersController extends StateNotifier<CustomersViewState> {
  CustomersController(
    this._list,
    this._create,
    this._update,
    this._setActive,
    this._setAccount,
    this._statement,
  ) : super(const CustomersViewState());

  final ListCustomersUseCase _list;
  final CreateCustomerUseCase _create;
  final UpdateCustomerUseCase _update;
  final SetCustomerActiveUseCase _setActive;
  final SetCustomerAccountUseCase _setAccount;
  final CustomerStatementUseCase _statement;

  Future<Failure?> load({
    String search = '',
    int page = 1,
    String? actingRoleId,
  }) async {
    final request = PageRequest(
        page: page, pageSize: state.request.pageSize, search: search);
    state = state.copyWith(status: CustomersStatus.loading, error: null);
    try {
      final result = await _list(request, actingRoleId: actingRoleId);
      state = state.copyWith(
        status: CustomersStatus.ready,
        customers: result.items,
        total: result.total,
        request: result.request,
      );
      return null;
    } on AppException catch (e) {
      state = state.copyWith(
          status: CustomersStatus.error, error: () => e.failure);
      return state.error;
    }
  }

  Future<Failure?> add(
    CustomerDraft draft, {
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
    CustomerDraft draft, {
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

  Future<Failure?> setAccount(
    String id,
    bool enabled, {
    String? actingUserId,
    String? actingRoleId,
  }) async {
    state = state.copyWith(busy: true, error: null);
    try {
      await _setAccount(id, enabled,
          actingUserId: actingUserId, actingRoleId: actingRoleId);
      return null;
    } on AppException catch (e) {
      return e.failure;
    } finally {
      state = state.copyWith(busy: false);
    }
  }

  Future<Failure?> loadStatement(
    String customerId, {
    required int fromDate,
    required int toDate,
    required int page,
    required int pageSize,
    String? actingRoleId,
  }) async {
    state = state.copyWith(statementLoading: true, error: null);
    try {
      final result = await _statement(
        customerId,
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