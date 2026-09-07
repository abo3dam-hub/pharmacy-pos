import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/data_grid/page_request.dart';
import '../../../core/errors/exceptions.dart';
import '../../../core/errors/failures.dart';
import '../../../shared/database/app_database.dart';
import '../../../shared/models/enums.dart';
import '../domain/entities/expense_list_item.dart';
import '../domain/repositories/expense_repository.dart';
import '../domain/usecases/expenses_use_cases.dart';

enum ExpenseViewStatus { initial, loading, ready, error }

/// Expenses page state (§4.20): the paged journal grid plus category master for
/// filters/management and the per-page totals header.
class ExpenseViewState {
  const ExpenseViewState({
    this.status = ExpenseViewStatus.initial,
    this.expenses = const [],
    this.total = 0,
    this.request = const PageRequest(pageSize: 30),
    this.categories = const [],
    this.categoryFilter,
    this.paymentFilter,
    this.voidedFilter,
    this.fromDate,
    this.toDate,
    this.busy = false,
    this.error,
  });

  final ExpenseViewStatus status;
  final List<ExpenseListItem> expenses;
  final int total;
  final PageRequest request;
  final List<ExpenseCategoryRow> categories;
  final String? categoryFilter;
  final ExpensePaymentMethod? paymentFilter;
  final bool? voidedFilter;
  final int? fromDate;
  final int? toDate;
  final bool busy;
  final Failure? error;

  /// Sum of non-voided page amounts (header totals, current page only).
  int get pageTotalMicros =>
      expenses.where((e) => !e.isVoided).fold(0, (sum, e) => sum + e.amountMicros);

  ExpenseViewState copyWith({
    ExpenseViewStatus? status,
    List<ExpenseListItem>? expenses,
    int? total,
    PageRequest? request,
    List<ExpenseCategoryRow>? categories,
    String? categoryFilter,
    ExpensePaymentMethod? paymentFilter,
    bool? voidedFilter,
    int? fromDate,
    int? toDate,
    bool? busy,
    Failure? error,
    bool clearCategoryFilter = false,
    bool clearPaymentFilter = false,
    bool clearVoidedFilter = false,
    bool clearError = false,
  }) {
    return ExpenseViewState(
      status: status ?? this.status,
      expenses: expenses ?? this.expenses,
      total: total ?? this.total,
      request: request ?? this.request,
      categories: categories ?? this.categories,
      categoryFilter:
          clearCategoryFilter ? null : categoryFilter ?? this.categoryFilter,
      paymentFilter:
          clearPaymentFilter ? null : paymentFilter ?? this.paymentFilter,
      voidedFilter:
          clearVoidedFilter ? null : voidedFilter ?? this.voidedFilter,
      fromDate: fromDate ?? this.fromDate,
      toDate: toDate ?? this.toDate,
      busy: busy ?? this.busy,
      error: clearError ? null : error ?? this.error,
    );
  }
}

/// Expenses controller: drives the journal listing + filters, category master
/// and the record/edit/cancel/receipt flow (RBAC + audit live in the use cases).
class ExpenseController extends StateNotifier<ExpenseViewState> {
  ExpenseController(
    this._list,
    this._categories,
    this._create,
    this._update,
    this._cancel,
    this._attachReceipt,
    this._removeReceipt,
    this._createCategory,
    this._updateCategory,
    this._setCategoryActive,
  ) : super(const ExpenseViewState());

  final ListExpensesUseCase _list;
  final ListExpenseCategoriesUseCase _categories;
  final CreateExpenseUseCase _create;
  final UpdateExpenseUseCase _update;
  final CancelExpenseUseCase _cancel;
  final AttachReceiptUseCase _attachReceipt;
  final RemoveReceiptUseCase _removeReceipt;
  final CreateExpenseCategoryUseCase _createCategory;
  final UpdateExpenseCategoryUseCase _updateCategory;
  final SetExpenseCategoryActiveUseCase _setCategoryActive;

  /// Loads the category master (once) and the first journal page.
  Future<Failure?> load({String? actingRoleId}) async {
    state = state.copyWith(status: ExpenseViewStatus.loading, clearError: true);
    try {
      final categories = await _categories(actingRoleId: actingRoleId);
      final result = await _list(
        state.request,
        categoryCode: state.categoryFilter,
        paymentMethod: state.paymentFilter,
        isVoided: state.voidedFilter,
        actingRoleId: actingRoleId,
      );
      state = state.copyWith(
        status: ExpenseViewStatus.ready,
        categories: categories,
        expenses: result.items,
        total: result.total,
        request: result.request,
        clearError: true,
      );
      return null;
    } on AppException catch (e) {
      state = state.copyWith(status: ExpenseViewStatus.error, error: e.failure);
      return state.error;
    }
  }

  /// Re-applies the current filters to page 1.
  Future<Failure?> applyFilters({
    String? categoryFilter,
    ExpensePaymentMethod? paymentFilter,
    bool? voidedFilter,
    String? actingRoleId,
  }) async {
    final request = state.request.withSearch('');
    state = state.copyWith(
      status: ExpenseViewStatus.loading,
      request: request,
      categoryFilter: categoryFilter,
      paymentFilter: paymentFilter,
      voidedFilter: voidedFilter,
      clearError: true,
    );
    return _fetch(request, actingRoleId: actingRoleId);
  }

  Future<Failure?> search(String query, {String? actingRoleId}) async {
    final request = state.request.withSearch(query);
    state = state.copyWith(status: ExpenseViewStatus.loading, request: request, clearError: true);
    return _fetch(request, actingRoleId: actingRoleId);
  }

  Future<Failure?> toPage(int page, {String? actingRoleId}) {
    final request = PageRequest(
      page: page,
      pageSize: state.request.pageSize,
      search: state.request.search,
    );
    state = state.copyWith(status: ExpenseViewStatus.loading, request: request, clearError: true);
    return _fetch(request, actingRoleId: actingRoleId);
  }

  Future<Failure?> _fetch(PageRequest request, {String? actingRoleId}) async {
    try {
      final result = await _list(
        request,
        categoryCode: state.categoryFilter,
        paymentMethod: state.paymentFilter,
        isVoided: state.voidedFilter,
        actingRoleId: actingRoleId,
      );
      state = state.copyWith(
        status: ExpenseViewStatus.ready,
        expenses: result.items,
        total: result.total,
        request: result.request,
        clearError: true,
      );
      return null;
    } on AppException catch (e) {
      state = state.copyWith(status: ExpenseViewStatus.error, error: e.failure);
      return state.error;
    }
  }

  Future<Failure?> record(
    ExpenseDraft draft, {
    String? actingUserId,
    String? actingRoleId,
  }) async {
    state = state.copyWith(busy: true, clearError: true);
    try {
      await _create(draft, actingUserId: actingUserId, actingRoleId: actingRoleId);
      await _reloadCategoriesAndFirst(actingRoleId);
      return null;
    } on AppException catch (e) {
      return e.failure;
    } finally {
      state = state.copyWith(busy: false);
    }
  }

  Future<Failure?> update(
    String expenseId,
    ExpenseEditDraft draft, {
    String? actingUserId,
    String? actingRoleId,
  }) async {
    state = state.copyWith(busy: true, clearError: true);
    try {
      await _update(expenseId, draft,
          actingUserId: actingUserId, actingRoleId: actingRoleId);
      return null;
    } on AppException catch (e) {
      return e.failure;
    } finally {
      state = state.copyWith(busy: false);
    }
  }

  Future<Failure?> cancel(
    String expenseId, {
    required String reason,
    String? actingUserId,
    String? actingRoleId,
  }) async {
    state = state.copyWith(busy: true, clearError: true);
    try {
      await _cancel(expenseId,
          reason: reason, actingUserId: actingUserId, actingRoleId: actingRoleId);
      return null;
    } on AppException catch (e) {
      return e.failure;
    } finally {
      state = state.copyWith(busy: false);
    }
  }

  Future<Failure?> attachReceipt(
    String expenseId, {
    required String sourcePath,
    String? actingUserId,
    String? actingRoleId,
  }) async {
    state = state.copyWith(busy: true, clearError: true);
    try {
      await _attachReceipt(expenseId,
          sourcePath: sourcePath,
          actingUserId: actingUserId,
          actingRoleId: actingRoleId);
      return null;
    } on AppException catch (e) {
      return e.failure;
    } finally {
      state = state.copyWith(busy: false);
    }
  }

  Future<Failure?> removeReceipt(
    String expenseId, {
    String? actingUserId,
    String? actingRoleId,
  }) async {
    state = state.copyWith(busy: true, clearError: true);
    try {
      await _removeReceipt(expenseId,
          actingUserId: actingUserId, actingRoleId: actingRoleId);
      return null;
    } on AppException catch (e) {
      return e.failure;
    } finally {
      state = state.copyWith(busy: false);
    }
  }

  Future<Failure?> createCategory(
    ExpenseCategoryDraft draft, {
    String? actingUserId,
    String? actingRoleId,
  }) async {
    state = state.copyWith(busy: true, clearError: true);
    try {
      await _createCategory(draft,
          actingUserId: actingUserId, actingRoleId: actingRoleId);
      await _reloadCategoriesAndFirst(actingRoleId);
      return null;
    } on AppException catch (e) {
      return e.failure;
    } finally {
      state = state.copyWith(busy: false);
    }
  }

  Future<Failure?> updateCategory(
    String categoryId,
    ExpenseCategoryDraft draft, {
    String? actingUserId,
    String? actingRoleId,
  }) async {
    state = state.copyWith(busy: true, clearError: true);
    try {
      await _updateCategory(categoryId, draft,
          actingUserId: actingUserId, actingRoleId: actingRoleId);
      await _reloadCategoriesAndFirst(actingRoleId);
      return null;
    } on AppException catch (e) {
      return e.failure;
    } finally {
      state = state.copyWith(busy: false);
    }
  }

  Future<Failure?> setCategoryActive(
    String categoryId,
    bool active, {
    String? actingUserId,
    String? actingRoleId,
  }) async {
    state = state.copyWith(busy: true, clearError: true);
    try {
      await _setCategoryActive(categoryId, active,
          actingUserId: actingUserId, actingRoleId: actingRoleId);
      await _reloadCategoriesAndFirst(actingRoleId);
      return null;
    } on AppException catch (e) {
      return e.failure;
    } finally {
      state = state.copyWith(busy: false);
    }
  }

  Future<void> _reloadCategoriesAndFirst(String? actingRoleId) async {
    try {
      final categories = await _categories(actingRoleId: actingRoleId);
      final result = await _list(
        state.request,
        categoryCode: state.categoryFilter,
        paymentMethod: state.paymentFilter,
        isVoided: state.voidedFilter,
        actingRoleId: actingRoleId,
      );
      state = state.copyWith(
        status: ExpenseViewStatus.ready,
        categories: categories,
        expenses: result.items,
        total: result.total,
        request: result.request,
        clearError: true,
      );
    } on AppException catch (e) {
      state = state.copyWith(status: ExpenseViewStatus.error, error: e.failure);
    }
  }
}