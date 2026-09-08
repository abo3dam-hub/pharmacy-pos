import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/data_grid/page_request.dart';
import '../../../core/errors/exceptions.dart';
import '../../../core/errors/failures.dart';
import '../../../shared/database/app_database.dart';
import '../domain/entities/audit_entry.dart';
import '../domain/usecases/audit_use_cases.dart';

enum AuditStatus { initial, loading, ready, error }

class AuditViewState {
  const AuditViewState({
    this.status = AuditStatus.initial,
    this.items = const [],
    this.total = 0,
    this.page = 1,
    this.filters = const AuditFilters(),
    this.actions = const [],
    this.actors = const [],
    this.error,
    this.busy = false,
  });

  final AuditStatus status;
  final List<AuditEntry> items;
  final int total;
  final int page;

  /// Active filter set (drives the query on load/page).
  final AuditFilters filters;

  /// Dropdown sources.
  final List<String> actions;
  final List<AuditActorOption> actors;

  final Failure? error;
  final bool busy;

  static const int pageSize = 25;

  int get pageCount =>
      total == 0 ? 0 : ((total + pageSize - 1) ~/ pageSize);

  AuditViewState copyWith({
    AuditStatus? status,
    List<AuditEntry>? items,
    int? total,
    int? page,
    AuditFilters? filters,
    List<String>? actions,
    List<AuditActorOption>? actors,
    Failure? Function()? error,
    bool? busy,
  }) {
    return AuditViewState(
      status: status ?? this.status,
      items: items ?? this.items,
      total: total ?? this.total,
      page: page ?? this.page,
      filters: filters ?? this.filters,
      actions: actions ?? this.actions,
      actors: actors ?? this.actors,
      error: error != null ? error() : this.error,
      busy: busy ?? this.busy,
    );
  }
}

/// Audit-log viewer controller (Phase 12): paginated, filterable, read-only.
class AuditController extends StateNotifier<AuditViewState> {
  AuditController(this._list, this._actions, this._actors, this._db)
      : super(const AuditViewState());

  final ListAuditLogsUseCase _list;
  final ListAuditActionsUseCase _actions;
  final ListAuditActorsUseCase _actors;
  final AppDatabase _db;

  String? _actingRoleId;

  /// Initial load + dropdown sources. Call once from initState.
  Future<void> load(String? actingRoleId) async {
    _actingRoleId = actingRoleId;
    state = state.copyWith(status: AuditStatus.loading, error: () => null);
    await _loadPage(1);
    try {
      final actions = await _actions.call(_db, actingRoleId);
      final actors = await _actors.call(_db, actingRoleId);
      state = state.copyWith(actions: actions, actors: actors);
    } on AppException {
      // Dropdown sources are optional; the grid still works.
    }
  }

  Future<void> setFilters(AuditFilters filters) async {
    state = state.copyWith(filters: filters, error: () => null);
    await _loadPage(1);
  }

  Future<void> applySearch(String query) =>
      setFilters(state.filters.copyWith(search: query));

  Future<void> toPage(int page) async {
    if (page < 1 || page == state.page) return;
    final result = await _fetch(page);
    if (result != null) {
      state = state.copyWith(
        status: AuditStatus.ready,
        items: result.items,
        total: result.total,
        page: page,
      );
    }
  }

  Future<void> _loadPage(int page) async {
    final result = await _fetch(page);
    if (result != null) {
      state = state.copyWith(
        status: AuditStatus.ready,
        items: result.items,
        total: result.total,
        page: page,
        busy: false,
      );
    }
  }

  Future<PageResult<AuditEntry>?> _fetch(int page) async {
    try {
      return await _list.call(
        _db,
        _actingRoleId,
        request: PageRequest(page: page, pageSize: AuditViewState.pageSize),
        filters: state.filters,
      );
    } on AppException catch (e) {
      state = state.copyWith(status: AuditStatus.error, error: () => e.failure);
      return null;
    } on Exception {
      state = state.copyWith(status: AuditStatus.error);
      return null;
    }
  }

  void clearError() => state = state.copyWith(error: () => null);
}