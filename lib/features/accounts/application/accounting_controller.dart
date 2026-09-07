import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/data_grid/page_request.dart';
import '../../../core/errors/exceptions.dart';
import '../../../core/errors/failures.dart';
import '../../../domain/services/accounting_period_service.dart';
import '../../../shared/database/app_database.dart';
import '../../../shared/models/enums.dart';
import '../data/accounting_dao.dart';

// ── Accounts ───────────────────────────────────────────────────────────────

enum AccountsViewStatus { initial, loading, ready, error }

class AccountsViewState {
  const AccountsViewState({
    this.status = AccountsViewStatus.initial,
    this.accounts = const [],
    this.search = '',
    this.busy = false,
    this.error,
  });

  final AccountsViewStatus status;
  final List<AccountRow> accounts;
  final String search;
  final bool busy;
  final Failure? error;

  AccountsViewState copyWith({
    AccountsViewStatus? status,
    List<AccountRow>? accounts,
    String? search,
    bool? busy,
    Failure? Function()? error,
  }) {
    return AccountsViewState(
      status: status ?? this.status,
      accounts: accounts ?? this.accounts,
      search: search ?? this.search,
      busy: busy ?? this.busy,
      error: error != null ? error() : this.error,
    );
  }
}

class AccountsController extends StateNotifier<AccountsViewState> {
  AccountsController(this._dao) : super(const AccountsViewState());

  final AccountingDao _dao;

  Future<Failure?> load() async {
    state = state.copyWith(
        status: AccountsViewStatus.loading, error: () => null);
    try {
      final accounts = await _dao.listAccounts(search: state.search);
      state = state.copyWith(
        status: AccountsViewStatus.ready,
        accounts: accounts,
        error: () => null,
      );
      return null;
    } on AppException catch (e) {
      state = state.copyWith(
          status: AccountsViewStatus.error, error: () => e.failure);
      return state.error;
    }
  }

  Future<Failure?> search(String query) async {
    state = state.copyWith(search: query);
    return load();
  }

  Future<Failure?> create({
    required AccountType type,
    required String code,
    required String name,
    String? nameEn,
    String? parentId,
    int openingBalanceMicros = 0,
    String? notes,
  }) async {
    state = state.copyWith(busy: true, error: () => null);
    try {
      await _dao.createAccount(
        type: type,
        code: code,
        name: name,
        nameEn: nameEn,
        parentId: parentId,
        openingBalanceMicros: openingBalanceMicros,
        notes: notes,
      );
      state = state.copyWith(busy: false);
      return null;
    } on AppException catch (e) {
      state = state.copyWith(busy: false, error: () => e.failure);
      return state.error;
    }
  }

  Future<Failure?> update(
    String id, {
    String? name,
    String? nameEn,
    String? parentId,
    String? notes,
    bool? isActive,
  }) async {
    state = state.copyWith(busy: true, error: () => null);
    try {
      await _dao.updateAccount(
        id,
        name: name,
        nameEn: nameEn,
        parentId: parentId,
        notes: notes,
        isActive: isActive,
      );
      state = state.copyWith(busy: false);
      return null;
    } on AppException catch (e) {
      state = state.copyWith(busy: false, error: () => e.failure);
      return state.error;
    }
  }

  Future<Failure?> toggleActive(String id, bool active) async {
    state = state.copyWith(busy: true, error: () => null);
    try {
      await _dao.toggleAccountActive(id, active);
      state = state.copyWith(busy: false);
      return null;
    } on AppException catch (e) {
      state = state.copyWith(busy: false, error: () => e.failure);
      return state.error;
    }
  }
}

// ── Journal ────────────────────────────────────────────────────────────────

enum JournalViewStatus { initial, loading, ready, error }

class JournalViewState {
  const JournalViewState({
    this.status = JournalViewStatus.initial,
    this.entries,
    this.refTypeFilter,
    this.request = const PageRequest(pageSize: 25),
    this.busy = false,
    this.error,
  });

  final JournalViewStatus status;
  final PageResult<JournalEntryRow>? entries;
  final JournalReferenceType? refTypeFilter;
  final PageRequest request;
  final bool busy;
  final Failure? error;

  JournalViewState copyWith({
    JournalViewStatus? status,
    PageResult<JournalEntryRow>? entries,
    JournalReferenceType? Function()? refTypeFilter,
    PageRequest? request,
    bool? busy,
    Failure? Function()? error,
  }) {
    return JournalViewState(
      status: status ?? this.status,
      entries: entries ?? this.entries,
      refTypeFilter: refTypeFilter != null ? refTypeFilter() : this.refTypeFilter,
      request: request ?? this.request,
      busy: busy ?? this.busy,
      error: error != null ? error() : this.error,
    );
  }
}

class JournalController extends StateNotifier<JournalViewState> {
  JournalController(this._dao) : super(const JournalViewState());

  final AccountingDao _dao;

  Future<Failure?> load() async {
    state = state.copyWith(
        status: JournalViewStatus.loading, error: () => null);
    try {
      final entries = await _dao.listJournals(
        page: state.request,
        refType: state.refTypeFilter,
      );
      state = state.copyWith(
        status: JournalViewStatus.ready,
        entries: entries,
        error: () => null,
      );
      return null;
    } on AppException catch (e) {
      state = state.copyWith(
          status: JournalViewStatus.error, error: () => e.failure);
      return state.error;
    }
  }

  Future<Failure?> loadMore() async {
    final nextPage = state.request.next();
    state = state.copyWith(
        status: JournalViewStatus.loading, error: () => null);
    try {
      final result = await _dao.listJournals(
        page: nextPage,
        refType: state.refTypeFilter,
      );
      final existing = state.entries?.items ?? const <JournalEntryRow>[];
      final merged = PageResult(
        items: [...existing, ...result.items],
        total: result.total,
        request: nextPage,
      );
      state = state.copyWith(
        status: JournalViewStatus.ready,
        entries: merged,
        request: nextPage,
        error: () => null,
      );
      return null;
    } on AppException catch (e) {
      state = state.copyWith(
          status: JournalViewStatus.error, error: () => e.failure);
      return state.error;
    }
  }

  Future<Failure?> setRefTypeFilter(JournalReferenceType? refType) async {
    state = state.copyWith(
      refTypeFilter: () => refType,
      request: const PageRequest(pageSize: 25),
    );
    return load();
  }
}

// ── Journal Detail ─────────────────────────────────────────────────────────

enum JournalDetailViewStatus { initial, loading, ready, error }

class JournalDetailViewState {
  const JournalDetailViewState({
    this.status = JournalDetailViewStatus.initial,
    this.entry,
    this.lines = const [],
    this.accountNames = const {},
    this.busy = false,
    this.error,
  });

  final JournalDetailViewStatus status;
  final JournalEntryRow? entry;
  final List<JournalEntryLineRow> lines;
  final Map<String, String> accountNames;
  final bool busy;
  final Failure? error;

  JournalDetailViewState copyWith({
    JournalDetailViewStatus? status,
    JournalEntryRow? entry,
    List<JournalEntryLineRow>? lines,
    Map<String, String>? accountNames,
    bool? busy,
    Failure? Function()? error,
  }) {
    return JournalDetailViewState(
      status: status ?? this.status,
      entry: entry ?? this.entry,
      lines: lines ?? this.lines,
      accountNames: accountNames ?? this.accountNames,
      busy: busy ?? this.busy,
      error: error != null ? error() : this.error,
    );
  }
}

class JournalDetailController extends StateNotifier<JournalDetailViewState> {
  JournalDetailController(this._dao) : super(const JournalDetailViewState());

  final AccountingDao _dao;

  Future<Failure?> load(String entryId) async {
    state = state.copyWith(
        status: JournalDetailViewStatus.loading, error: () => null);
    try {
      final entry = await _dao.getJournalEntry(entryId);
      if (entry == null) {
        state = state.copyWith(
            status: JournalDetailViewStatus.error,
            error: () => const NotFoundFailure('القيد غير موجود'));
        return state.error;
      }
      final lines = await _dao.listJournalLines(entryId);
      final names = <String, String>{};
      for (final line in lines) {
        if (!names.containsKey(line.accountId)) {
          names[line.accountId] = await _dao.getAccountName(line.accountId);
        }
      }
      state = state.copyWith(
        status: JournalDetailViewStatus.ready,
        entry: entry,
        lines: lines,
        accountNames: names,
        error: () => null,
      );
      return null;
    } on AppException catch (e) {
      state = state.copyWith(
          status: JournalDetailViewStatus.error, error: () => e.failure);
      return state.error;
    }
  }
}

// ── Account Statement ──────────────────────────────────────────────────────

enum AccountStatementViewStatus { initial, loading, ready, error }

class AccountStatementViewState {
  const AccountStatementViewState({
    this.status = AccountStatementViewStatus.initial,
    this.accountId,
    this.accountName,
    this.lines = const [],
    this.from,
    this.to,
    this.openingBalanceMicros = 0,
    this.busy = false,
    this.error,
  });

  final AccountStatementViewStatus status;
  final String? accountId;
  final String? accountName;
  final List<StatementLine> lines;
  final DateTime? from;
  final DateTime? to;

  /// Signed balance before the statement range (Phase 11).
  final int openingBalanceMicros;
  final bool busy;
  final Failure? error;

  int get totalDebitMicros =>
      lines.fold(0, (sum, l) => sum + l.debitMicros);
  int get totalCreditMicros =>
      lines.fold(0, (sum, l) => sum + l.creditMicros);

  /// Statement net movement (debits − credits).
  int get netMovementMicros => totalDebitMicros - totalCreditMicros;

  /// Closing balance = opening + net movement (Phase 11).
  int get closingBalanceMicros => openingBalanceMicros + netMovementMicros;

  AccountStatementViewState copyWith({
    AccountStatementViewStatus? status,
    String? accountId,
    String? accountName,
    List<StatementLine>? lines,
    DateTime? from,
    DateTime? to,
    int? openingBalanceMicros,
    bool? busy,
    Failure? Function()? error,
  }) {
    return AccountStatementViewState(
      status: status ?? this.status,
      accountId: accountId ?? this.accountId,
      accountName: accountName ?? this.accountName,
      lines: lines ?? this.lines,
      from: from ?? this.from,
      to: to ?? this.to,
      openingBalanceMicros: openingBalanceMicros ?? this.openingBalanceMicros,
      busy: busy ?? this.busy,
      error: error != null ? error() : this.error,
    );
  }
}

class AccountStatementController
    extends StateNotifier<AccountStatementViewState> {
  AccountStatementController(this._dao) : super(const AccountStatementViewState());

  final AccountingDao _dao;

  Future<Failure?> loadForAccount(String accountId) async {
    state = state.copyWith(
        status: AccountStatementViewStatus.loading,
        accountId: accountId,
        error: () => null);
    try {
      final account = await _dao.getAccount(accountId);
      final rawLines = await _dao.accountStatement(
        accountId,
        from: state.from,
        to: state.to,
      );
      final opening = await _dao.accountOpeningBalanceMicros(
        accountId,
        from: state.from,
      );
      var running = opening;
      final lines = <StatementLine>[];
      for (final line in rawLines) {
        running += line.debitMicros - line.creditMicros;
        lines.add(StatementLine(
          entryId: line.entryId,
          entryNumber: line.entryNumber,
          entryDate: line.entryDate,
          description: line.description,
          debitMicros: line.debitMicros,
          creditMicros: line.creditMicros,
          refType: line.refType,
          runningBalanceMicros: running,
        ));
      }
      state = state.copyWith(
        status: AccountStatementViewStatus.ready,
        accountName: account?.name,
        lines: lines,
        openingBalanceMicros: opening,
        error: () => null,
      );
      return null;
    } on AppException catch (e) {
      state = state.copyWith(
          status: AccountStatementViewStatus.error, error: () => e.failure);
      return state.error;
    }
  }

  Future<Failure?> setDateRange(DateTime? from, DateTime? to) async {
    state = state.copyWith(from: from, to: to);
    if (state.accountId != null) {
      return loadForAccount(state.accountId!);
    }
    return null;
  }
}

// ── Periods ────────────────────────────────────────────────────────────────

enum PeriodsViewStatus { initial, loading, ready, error }

class PeriodsViewState {
  const PeriodsViewState({
    this.status = PeriodsViewStatus.initial,
    this.periods = const [],
    this.busy = false,
    this.error,
  });

  final PeriodsViewStatus status;
  final List<AccountingPeriodRow> periods;
  final bool busy;
  final Failure? error;

  PeriodsViewState copyWith({
    PeriodsViewStatus? status,
    List<AccountingPeriodRow>? periods,
    bool? busy,
    Failure? Function()? error,
  }) {
    return PeriodsViewState(
      status: status ?? this.status,
      periods: periods ?? this.periods,
      busy: busy ?? this.busy,
      error: error != null ? error() : this.error,
    );
  }
}

class PeriodsController extends StateNotifier<PeriodsViewState> {
  PeriodsController(this._db, this._service) : super(const PeriodsViewState());

  final AppDatabase _db;
  final AccountingPeriodService _service;

  Future<Failure?> load() async {
    state = state.copyWith(
        status: PeriodsViewStatus.loading, error: () => null);
    try {
      final periods = await _service.listPeriods(_db);
      state = state.copyWith(
        status: PeriodsViewStatus.ready,
        periods: periods,
        error: () => null,
      );
      return null;
    } on AppException catch (e) {
      state = state.copyWith(
          status: PeriodsViewStatus.error, error: () => e.failure);
      return state.error;
    }
  }

  Future<Failure?> create({
    required String name,
    required int startDate,
    required int endDate,
    required String userId,
  }) async {
    state = state.copyWith(busy: true, error: () => null);
    try {
      await _service.createPeriod(
        _db,
        name: name,
        startDate: startDate,
        endDate: endDate,
        userId: userId,
      );
      state = state.copyWith(busy: false);
      return null;
    } on AppException catch (e) {
      state = state.copyWith(busy: false, error: () => e.failure);
      return state.error;
    }
  }

  Future<Failure?> close({
    required String periodId,
    required String userId,
    String? closeReason,
  }) async {
    state = state.copyWith(busy: true, error: () => null);
    try {
      await _service.closePeriod(
        _db,
        periodId: periodId,
        userId: userId,
        closeReason: closeReason,
      );
      state = state.copyWith(busy: false);
      return null;
    } on AppException catch (e) {
      state = state.copyWith(busy: false, error: () => e.failure);
      return state.error;
    }
  }
}
