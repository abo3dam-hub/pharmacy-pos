import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/data_grid/page_request.dart';
import '../../../core/errors/exceptions.dart';
import '../../../core/errors/failures.dart';
import '../../../shared/models/enums.dart';
import '../domain/entities/cashbox_session.dart';
import '../domain/repositories/cashbox_repository.dart';

enum CashboxViewStatus { initial, loading, ready, error }

/// Cash Box page state (§41 Phase 8): drawer session summary + paged history.
class CashboxViewState {
  const CashboxViewState({
    this.status = CashboxViewStatus.initial,
    this.session,
    this.history,
    this.typeFilter,
    this.request = const PageRequest(pageSize: 25),
    this.busy = false,
    this.error,
  });

  final CashboxViewStatus status;
  final CashboxSession? session;
  final PageResult<CashboxHistoryEntry>? history;
  final CashboxTransactionType? typeFilter;
  final PageRequest request;
  final bool busy;
  final Failure? error;

  CashboxViewState copyWith({
    CashboxViewStatus? status,
    CashboxSession? Function()? session,
    PageResult<CashboxHistoryEntry>? history,
    CashboxTransactionType? Function()? typeFilter,
    PageRequest? request,
    bool? busy,
    Failure? Function()? error,
  }) {
    return CashboxViewState(
      status: status ?? this.status,
      session: session != null ? session() : this.session,
      history: history ?? this.history,
      typeFilter: typeFilter != null ? typeFilter() : this.typeFilter,
      request: request ?? this.request,
      busy: busy ?? this.busy,
      error: error != null ? error() : this.error,
    );
  }
}

/// Cash Box controller (§41 Phase 8): loads the drawer session + history and
/// drives the open/close/deposit/withdraw/adjust workflow through the
/// repository (RBAC and audit live in the service layer).
class CashboxController extends StateNotifier<CashboxViewState> {
  CashboxController(this._repository) : super(const CashboxViewState());

  final CashboxRepository _repository;

  /// Loads the drawer session and first history page.
  Future<Failure?> load({required String userId}) async {
    state = state.copyWith(status: CashboxViewStatus.loading, error: () => null);
    try {
      final session = await _repository.currentSession();
      final history = await _repository.history(page: state.request);
      state = state.copyWith(
        status: CashboxViewStatus.ready,
        session: () => session,
        history: history,
        error: () => null,
      );
      return null;
    } on AppException catch (e) {
      state = state.copyWith(status: CashboxViewStatus.error, error: () => e.failure);
      return state.error;
    }
  }

  /// Reloads with the currently applied type filter.
  Future<Failure?> reload() => _applyFilter(state.typeFilter, page: 1);

  /// Applies a ledger-type filter and reloads page 1.
  Future<Failure?> setTypeFilter(CashboxTransactionType? type) =>
      _applyFilter(type, page: 1);

  /// Loads the next history page (append).
  Future<Failure?> loadMore() => _applyFilter(state.typeFilter, page: state.request.page + 1, append: true);

  Future<Failure?> _applyFilter(
    CashboxTransactionType? type, {
    required int page,
    bool append = false,
  }) async {
    final request = PageRequest(page: page, pageSize: state.request.pageSize);
    state = state.copyWith(
      status: CashboxViewStatus.loading,
      typeFilter: () => type,
      error: () => null,
    );
    try {
      final history = await _repository.history(page: request, type: type);
      final existing = append ? state.history?.items ?? const <CashboxHistoryEntry>[] : const <CashboxHistoryEntry>[];
      final merged = append
          ? PageResult(
              items: [...existing, ...history.items],
              total: history.total,
              request: request,
            )
          : history;
      state = state.copyWith(
        status: CashboxViewStatus.ready,
        history: merged,
        request: request,
        error: () => null,
      );
      return null;
    } on AppException catch (e) {
      state = state.copyWith(status: CashboxViewStatus.error, error: () => e.failure);
      return state.error;
    }
  }

  Future<Failure?> open({
    required int openingMicros,
    required String userId,
    String? note,
  }) =>
      _mutate(() => _repository.openDrawer(openingMicros: openingMicros, userId: userId, note: note));

  Future<Failure?> close({
    required int declaredCloseMicros,
    required String userId,
    required String reason,
  }) =>
      _mutate(() => _repository.closeDrawer(declaredCloseMicros: declaredCloseMicros, userId: userId, reason: reason));

  Future<Failure?> deposit({
    required int amountMicros,
    required String reason,
    required String userId,
  }) =>
      _mutate(() => _repository.deposit(amountMicros: amountMicros, reason: reason, userId: userId));

  Future<Failure?> withdraw({
    required int amountMicros,
    required String reason,
    required String userId,
  }) =>
      _mutate(() => _repository.withdraw(amountMicros: amountMicros, reason: reason, userId: userId));

  Future<Failure?> adjust({
    required int amountMicros,
    required String reason,
    required String userId,
  }) =>
      _mutate(() => _repository.adjustCash(amountMicros: amountMicros, reason: reason, userId: userId));

  Future<Failure?> _mutate(Future<void> Function() action) async {
    state = state.copyWith(busy: true, error: () => null);
    try {
      await action();
      final session = await _repository.currentSession();
      state = state.copyWith(busy: false, session: () => session, error: () => null);
      return null;
    } on AppException catch (e) {
      state = state.copyWith(busy: false, error: () => e.failure);
      return state.error;
    }
  }
}

