import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/errors/exceptions.dart';
import '../../../core/errors/failures.dart';
import '../../../shared/models/enums.dart';
import '../data/reports_dao.dart';
import '../domain/entities/report_models.dart';

// ── shared base ────────────────────────────────────────────────────────────

enum ReportViewStatus { initial, loading, ready, error }

/// Read-only report state: the report data plus the applied window so pages
/// can render the period subtitle from the same source that produced rows.
class ReportViewState<T> {
  const ReportViewState({
    this.status = ReportViewStatus.initial,
    this.data,
    this.fromMillis,
    this.toMillis,
    this.error,
  });

  final ReportViewStatus status;
  final T? data;
  final int? fromMillis;
  final int? toMillis;
  final Failure? error;

  ReportViewState<T> copyWith({
    ReportViewStatus? status,
    T? data,
    int? fromMillis,
    int? toMillis,
    Failure? Function()? error,
  }) {
    return ReportViewState<T>(
      status: status ?? this.status,
      data: data ?? this.data,
      fromMillis: fromMillis ?? this.fromMillis,
      toMillis: toMillis ?? this.toMillis,
      error: error != null ? error() : this.error,
    );
  }
}

/// Base for all report controllers. Keeps the load contract uniform: every
/// controller runs read-only DAO queries and maps errors to [Failure].
abstract class ReportController<T> extends StateNotifier<ReportViewState<T>> {
  ReportController(super.initial);

  Future<Failure?> _run(
    Future<T> Function() query, {
    required DateTime? from,
    required DateTime? to,
  }) async {
    state = state.copyWith(
      status: ReportViewStatus.loading,
      fromMillis: from?.millisecondsSinceEpoch,
      toMillis: to?.millisecondsSinceEpoch,
      error: () => null,
    );
    try {
      final data = await query();
      state = state.copyWith(
        status: ReportViewStatus.ready,
        data: data,
        error: () => null,
      );
      return null;
    } on AppException catch (e) {
      state = state.copyWith(
          status: ReportViewStatus.error, error: () => e.failure);
      return state.error;
    }
  }
}

// ── Trial Balance ──────────────────────────────────────────────────────────

class TrialBalanceController extends ReportController<TrialBalanceReport> {
  TrialBalanceController(this._dao) : super(const ReportViewState());

  final ReportsDao _dao;

  Future<Failure?> load({DateTime? from, DateTime? to}) => _run(
      () => _dao.trialBalance(
        fromMillis: (from ?? DateTime.now()).millisecondsSinceEpoch,
        toMillis:
            (to ?? DateTime.now().add(const Duration(days: 1)))
                .millisecondsSinceEpoch,
      ),
      from: from,
      to: to);
}

// ── Income Statement ───────────────────────────────────────────────────────

class IncomeStatementController
    extends ReportController<IncomeStatementReport> {
  IncomeStatementController(this._dao) : super(const ReportViewState());

  final ReportsDao _dao;

  Future<Failure?> load({DateTime? from, DateTime? to}) => _run(
      () => _dao.incomeStatement(
        fromMillis: (from ?? DateTime.now()).millisecondsSinceEpoch,
        toMillis:
            (to ?? DateTime.now().add(const Duration(days: 1)))
                .millisecondsSinceEpoch,
      ),
      from: from,
      to: to);
}

// ── Balance Sheet ──────────────────────────────────────────────────────────

class BalanceSheetController extends ReportController<BalanceSheetReport> {
  BalanceSheetController(this._dao) : super(const ReportViewState());

  final ReportsDao _dao;

  Future<Failure?> load({DateTime? from, DateTime? to}) => _run(
      () => _dao.balanceSheet(
        asOfMillis:
            (to ?? DateTime.now().add(const Duration(days: 1)))
                .millisecondsSinceEpoch,
      ),
      from: from,
      to: to);
}

// ── Sales Report ───────────────────────────────────────────────────────────

class SalesReportController extends ReportController<SalesReport> {
  SalesReportController(this._dao) : super(const ReportViewState());

  final ReportsDao _dao;

  Future<Failure?> load({
    DateTime? from,
    DateTime? to,
    String? customerId,
    String? userId,
  }) {
    final start = (from ?? DateTime.now()).millisecondsSinceEpoch;
    final end =
        (to ?? DateTime.now().add(const Duration(days: 1)))
            .millisecondsSinceEpoch;
    return _run(
      () =>
          _dao.salesReport(
        fromMillis: start,
        toMillis: end,
        customerId: customerId,
        userId: userId,
      ),
      from: from,
      to: to,
    );
  }
}

// ── Purchase Report ────────────────────────────────────────────────────────

class PurchaseReportController extends ReportController<PurchaseReport> {
  PurchaseReportController(this._dao) : super(const ReportViewState());

  final ReportsDao _dao;

  Future<Failure?> load({
    DateTime? from,
    DateTime? to,
    String? supplierId,
  }) {
    final start = (from ?? DateTime.now()).millisecondsSinceEpoch;
    final end =
        (to ?? DateTime.now().add(const Duration(days: 1)))
            .millisecondsSinceEpoch;
    return _run(
      () => _dao.purchaseReport(
        fromMillis: start,
        toMillis: end,
        supplierId: supplierId,
      ),
      from: from,
      to: to,
    );
  }
}

// ── Inventory Report ───────────────────────────────────────────────────────

class InventoryReportController extends ReportController<InventoryReport> {
  InventoryReportController(this._dao) : super(const ReportViewState());

  final ReportsDao _dao;

  Future<Failure?> load({DateTime? from, DateTime? to}) => _run(
      () => _dao.inventoryReport(
        fromMillis: (from ?? DateTime.now()).millisecondsSinceEpoch,
        toMillis:
            (to ?? DateTime.now().add(const Duration(days: 1)))
                .millisecondsSinceEpoch,
      ),
      from: from,
      to: to);
}

// ── Lost Sales Report ──────────────────────────────────────────────────────

/// Lost-sales status filter option (null = all).
enum LostSalesStatusFilter {
  open(LostSaleStatus.open),
  ordered(LostSaleStatus.ordered),
  resolved(LostSaleStatus.resolved),
  cancelled(LostSaleStatus.cancelled);

  const LostSalesStatusFilter(this.status);

  final LostSaleStatus status;
}

class LostSalesReportController extends ReportController<LostSalesReport> {
  LostSalesReportController(this._dao) : super(const ReportViewState());

  final ReportsDao _dao;

  Future<Failure?> load({
    DateTime? from,
    DateTime? to,
    LostSalesStatusFilter? status,
  }) {
    final start = (from ?? DateTime.now()).millisecondsSinceEpoch;
    final end =
        (to ?? DateTime.now().add(const Duration(days: 1)))
            .millisecondsSinceEpoch;
    return _run(
      () => _dao.lostSalesReport(
        fromMillis: start,
        toMillis: end,
        status: status?.status,
      ),
      from: from,
      to: to,
    );
  }
}