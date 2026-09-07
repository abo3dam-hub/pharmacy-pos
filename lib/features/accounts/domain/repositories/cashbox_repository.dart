import '../../../../core/data_grid/page_request.dart';
import '../../../../shared/models/enums.dart';
import '../entities/cashbox_session.dart';

/// Phase 8 Cash Box data contract (§4.21, §41). The domain layer defines the
/// types; the data layer implements the workflow over [CashboxService] and the
/// read-side [CashboxDao]. Presentation never touches Drift.
abstract interface class CashboxRepository {
  /// Derives the current drawer session (not opened / open / closed) with the
  /// full reconciliation summary.
  Future<CashboxSession> currentSession();

  /// Paged drawer ledger history, DB-side filtered by type and time window.
  Future<PageResult<CashboxHistoryEntry>> history({
    required PageRequest page,
    CashboxTransactionType? type,
    int? fromMillis,
    int? toMillis,
  });

  /// Opens the drawer with an opening float. Requires `cashbox.operate`.
  Future<void> openDrawer({
    required int openingMicros,
    required String userId,
    String? note,
  });

  /// Closes the drawer declaring the counted cash. Requires `cashbox.operate`.
  Future<void> closeDrawer({
    required int declaredCloseMicros,
    required String userId,
    required String reason,
  });

  /// Manual cash deposit. Requires `cashbox.operate` + an open session.
  Future<void> deposit({
    required int amountMicros,
    required String reason,
    required String userId,
  });

  /// Manual cash withdrawal. Requires `cashbox.operate` + an open session.
  Future<void> withdraw({
    required int amountMicros,
    required String reason,
    required String userId,
  });

  /// Authorized drawer adjustment (±). Requires `cashbox.operate`.
  Future<void> adjustCash({
    required int amountMicros,
    required String reason,
    required String userId,
  });
}