import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/errors/failures.dart';
import '../../sales/data/z_report_dao.dart';
import '../data/dashboard_dao.dart';
import '../domain/entities/dashboard_snapshot.dart';

enum DashboardStatus { initial, loading, ready, error }

class DashboardViewState {
  const DashboardViewState({
    this.status = DashboardStatus.initial,
    this.snapshot,
    this.error,
    this.busy = false,
  });

  final DashboardStatus status;
  final DashboardSnapshot? snapshot;
  final Failure? error;
  final bool busy;

  DashboardViewState copyWith({
    DashboardStatus? status,
    DashboardSnapshot? snapshot,
    Failure? Function()? error,
    bool clearError = false,
    bool? busy,
  }) {
    return DashboardViewState(
      status: status ?? this.status,
      snapshot: snapshot ?? this.snapshot,
      error: clearError ? null : (error != null ? error() : this.error),
      busy: busy ?? this.busy,
    );
  }
}

/// Loads the real-data dashboard: a Z-Report window for today's sales plus the
/// inventory / activity read model behind it.
class DashboardController extends StateNotifier<DashboardViewState> {
  DashboardController(this._zReportDao, this._dashboardDao)
      : super(const DashboardViewState());

  final ZReportDao _zReportDao;
  final DashboardDao _dashboardDao;

  Future<Failure?> load({String? userId}) async {
    state = state.copyWith(
        status: DashboardStatus.loading, busy: true, clearError: true);
    try {
      final now = DateTime.now();
      final from = DateTime(now.year, now.month, now.day);
      final today = await _zReportDao.aggregate(
        fromMillis: from.millisecondsSinceEpoch,
        toMillis: now.millisecondsSinceEpoch,
        userId: userId,
      );
      final snapshot = await _dashboardDao.load(
        nowMillis: now.millisecondsSinceEpoch,
        fromMillis: from.millisecondsSinceEpoch,
        toMillis: now.millisecondsSinceEpoch,
        todayInvoiceCount: today.invoiceCount,
        todayUnitsSold: today.unitsSold,
        todayTotalMicros: today.totalMicros,
        todayPaidMicros: today.paidMicros,
      );
      state = DashboardViewState(
          status: DashboardStatus.ready, snapshot: snapshot);
      return null;
    } on Exception catch (e) {
      state = state.copyWith(
          status: DashboardStatus.error,
          busy: false,
          error: () => Failure('${e.runtimeType}: $e'));
    }
    return state.error;
  }

  Future<void> refresh() async {
    state = state.copyWith(busy: true);
    await load();
  }
}