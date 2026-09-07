import '../../../core/data_grid/page_request.dart';
import '../../../domain/services/cashbox_service.dart';
import '../../../shared/database/app_database.dart';
import '../../../shared/models/enums.dart';
import '../domain/entities/cashbox_session.dart';
import '../domain/repositories/cashbox_repository.dart';
import 'cashbox_dao.dart';

/// Phase 8 data layer: cash-box workflow over the existing financial engine
/// plus the read-side session/history DAO (§4.21, §41).
class CashboxRepositoryImpl implements CashboxRepository {
  CashboxRepositoryImpl(this._db, this._service);

  final AppDatabase _db;
  final CashboxService _service;

  CashboxDao get _dao => CashboxDao(_db);

  @override
  Future<CashboxSession> currentSession() => _dao.currentSession();

  @override
  Future<PageResult<CashboxHistoryEntry>> history({
    required PageRequest page,
    CashboxTransactionType? type,
    int? fromMillis,
    int? toMillis,
  }) =>
      _dao.history(page: page, type: type, fromMillis: fromMillis, toMillis: toMillis);

  @override
  Future<void> openDrawer({
    required int openingMicros,
    required String userId,
    String? note,
  }) async {
    await _service.openDrawer(
      _db,
      openingMicros: openingMicros,
      userId: userId,
      note: note,
    );
  }

  @override
  Future<void> closeDrawer({
    required int declaredCloseMicros,
    required String userId,
    required String reason,
  }) async {
    await _service.closeDrawer(
      _db,
      declaredCloseMicros: declaredCloseMicros,
      userId: userId,
      reason: reason,
    );
  }

  @override
  Future<void> deposit({
    required int amountMicros,
    required String reason,
    required String userId,
  }) =>
      _service.deposit(
        _db,
        amountMicros: amountMicros,
        reason: reason,
        userId: userId,
      );

  @override
  Future<void> withdraw({
    required int amountMicros,
    required String reason,
    required String userId,
  }) =>
      _service.withdraw(
        _db,
        amountMicros: amountMicros,
        reason: reason,
        userId: userId,
      );

  @override
  Future<void> adjustCash({
    required int amountMicros,
    required String reason,
    required String userId,
  }) =>
      _service.adjustCash(
        _db,
        amountMicros: amountMicros,
        reason: reason,
        userId: userId,
      );
}