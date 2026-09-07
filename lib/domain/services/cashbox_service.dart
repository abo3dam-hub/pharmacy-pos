import 'package:drift/drift.dart';

import '../../core/constants/permission_codes.dart';
import '../../core/errors/exceptions.dart';
import '../../core/util/ids.dart';
import '../../features/accounts/data/cashbox_dao.dart';
import '../../features/accounts/domain/entities/cashbox_session.dart';
import '../../shared/database/app_database.dart';
import '../../shared/models/enums.dart';
import 'audit_service.dart';
import 'financial_posting_service.dart';
import 'permission_service.dart';

/// Cash Box / drawer workflow (§4.21, §41 Phase 8): open, close, deposit,
/// withdraw and authorized adjustments.
///
/// The service is intentionally thin over the existing financial engine:
/// every movement is persisted through [FinancialPostingService.postCashboxRow]
/// so it carries the same running-balance and journal semantics as the
/// automatic sale/return/payment entries. Audit and RBAC follow the project's
/// established patterns (`cashbox.operate` for every mutation).
///
/// Reconciliation contract (shared with the Z-Report DAO):
///   expectedClosing = opening + netMoves
///   difference       = declaredClose − expectedClosing
/// `open` seeds the drawer; `close` is a *declaration* snapshot (amount =
/// counted cash) that never enters `netMoves`.
class CashboxService {
  const CashboxService({
    AuditService? audit,
    PermissionService? permissions,
    FinancialPostingService? financial,
  })  : _audit = audit ?? const AuditService(),
        _permissions = permissions ?? const PermissionService(),
        _financial = financial ?? const FinancialPostingService();

  final AuditService _audit;
  final PermissionService _permissions;
  final FinancialPostingService _financial;

  /// Opens the drawer with an opening float of [openingMicros] (micros).
  ///
  /// Requires `cashbox.operate`, a non-negative amount and **no currently open
  /// session**. Opening is allowed from the fresh state and after a completed
  /// close (a new shift), but rejected while the drawer is already open.
  Future<CashboxTransactionRow> openDrawer(
    AppDatabase db, {
    required int openingMicros,
    required String userId,
    String? note,
  }) async {
    await _permissions.requireUserPermission(db, userId, Perm.cashboxOperate);
    if (openingMicros <= 0) {
      // The ledger constraint `amount_micros != 0` (and a drawer with no float
      // being meaningless) forbid a zero opening.
      throw ValidationException('الرصيد الافتتاحي يجب أن يكون أكبر من صفر');
    }
    final dao = CashboxDao(db);
    final session = await dao.currentSession();
    if (session.status == CashboxStatus.open) {
      throw InvalidOperationException(
          'الصندوق مفتوح بالفعل — أغلق الجلسة الحالية أولاً');
    }
    return db.transaction(() async {
      final now = DateTime.now().millisecondsSinceEpoch;
      // The open row seeds the drawer: amount = opening float, remaining =
      // running cash (previous history + float). Inserted directly so a
      // zero float stays representable (postCashboxRow rejects 0 amounts).
      final id = newId('cbx');
      final running = await _cashBalance(db) + openingMicros;
      await db.into(db.cashboxTransactions).insert(
            CashboxTransactionsCompanion.insert(
              id: id,
              type: CashboxTransactionType.open,
              amountMicros: openingMicros,
              remainingMicros: running,
              refType: const Value('cashbox'),
              refId: const Value('open'),
              userId: userId,
              note: note != null && note.trim().isNotEmpty
                  ? Value<String?>(note.trim())
                  : const Value(null),
              createdAt: now,
            ),
          );
      // Phase 10 reconciliation: mirror the opening float into the GL so the
      // cash-box ledger (SUM of drawer moves) reconciles to the GL Cash
      // account. Dr Cash, Cr Capital — the float funds the drawer.
      await _financial.postJournalEntry(
        db,
        refType: JournalReferenceType.opening_balance,
        refId: 'cbx-open-$id',
        entryDate: now,
        description: 'فتح الصندوق برصيد افتتاحي',
        lines: [
          JournalLineDraft(
              accountCode: SystemAccountCode.cash,
              debitMicros: openingMicros),
          JournalLineDraft(
              accountCode: SystemAccountCode.capital,
              creditMicros: openingMicros),
        ],
        createdBy: userId,
      );
      final row = await (db.select(db.cashboxTransactions)
            ..where((t) => t.id.equals(id)))
          .getSingle();
      await _audit.write(
        db,
        userId: userId,
        action: AuditAction.create,
        entityType: 'cashbox',
        entityId: row.id,
        after: {
          'operation': 'open',
          'opening_micros': openingMicros,
          'note': note,
        },
      );
      return row;
    });
  }

  /// Closes the drawer declaring [declaredCloseMicros] as the counted cash.
  ///
  /// Requires `cashbox.operate`, an open session and a non-empty [reason].
  /// Inside one transaction it loads the opening balance, sums the session's
  /// cash moves, persists the close declaration (a snapshot, never a move) and
  /// writes the reconciliation details to the immutable audit trail.
  Future<CashboxTransactionRow> closeDrawer(
    AppDatabase db, {
    required int declaredCloseMicros,
    required String userId,
    required String reason,
  }) async {
    await _permissions.requireUserPermission(db, userId, Perm.cashboxOperate);
    if (declaredCloseMicros < 0) {
      throw ValidationException('الرصيد المعلن عند الإغلاق لا يمكن أن يكون سالباً');
    }
    if (reason.trim().isEmpty) {
      throw ValidationException('سبب إغلاق الصندوق مطلوب');
    }
    final dao = CashboxDao(db);
    final session = await dao.currentSession();
    if (session.status != CashboxStatus.open) {
      throw InvalidOperationException(session.status == CashboxStatus.notOpened
          ? 'الصندوق لم يُفتح بعد — لا يمكن إغلاق جلسة غير موجودة'
          : 'الصندوق مقفل بالفعل — لا يمكن إغلاقه مرتين');
    }
    return db.transaction(() async {
      final now = DateTime.now().millisecondsSinceEpoch;
      final id = newId('cbx');
      await db.into(db.cashboxTransactions).insert(
            CashboxTransactionsCompanion.insert(
              id: id,
              type: CashboxTransactionType.close,
              // The declared closing balance is a declaration (reconciliation
              // snapshot), not a cash move — it never joins `netMoves`, exactly
              // as the Z-Report DAO treats `close` rows.
              amountMicros: declaredCloseMicros,
              remainingMicros: declaredCloseMicros,
              refType: const Value('cashbox'),
              refId: const Value('close'),
              userId: userId,
              note: Value<String?>(reason.trim()),
              createdAt: now,
            ),
          );
      final expected = session.expectedClosingMicros;
      final diff = declaredCloseMicros - expected;
      await _audit.write(
        db,
        userId: userId,
        action: AuditAction.update,
        entityType: 'cashbox',
        entityId: id,
        after: {
          'operation': 'close',
          'reason': reason.trim(),
          'declared_close_micros': declaredCloseMicros,
          'expected_close_micros': expected,
          'difference_micros': diff,
        },
      );
      return (await (db.select(db.cashboxTransactions)
            ..where((t) => t.id.equals(id)))
            .getSingle());
    });
  }

  /// Books a manual cash deposit (إيداع نقدي) into the drawer. Requires
  /// `cashbox.operate`, an open session, a positive amount and a reason.
  Future<CashboxTransactionRow> deposit(
    AppDatabase db, {
    required int amountMicros,
    required String reason,
    required String userId,
  }) =>
      _manualMove(
        db,
        type: CashboxTransactionType.deposit,
        amountMicros: amountMicros,
        reason: reason,
        userId: userId,
      );

  /// Books a manual cash withdrawal (سحب نقدي) out of the drawer. Requires
  /// `cashbox.operate`, an open session, a positive amount and a reason.
  Future<CashboxTransactionRow> withdraw(
    AppDatabase db, {
    required int amountMicros,
    required String reason,
    required String userId,
  }) =>
      _manualMove(
        db,
        type: CashboxTransactionType.withdraw,
        amountMicros: amountMicros,
        reason: reason,
        userId: userId,
      );

  Future<CashboxTransactionRow> _manualMove(
    AppDatabase db, {
    required CashboxTransactionType type,
    required int amountMicros,
    required String reason,
    required String userId,
  }) async {
    await _permissions.requireUserPermission(db, userId, Perm.cashboxOperate);
    if (amountMicros <= 0) {
      throw ValidationException('المبلغ يجب أن يكون أكبر من صفر');
    }
    if (reason.trim().isEmpty) {
      throw ValidationException(
          type == CashboxTransactionType.deposit
              ? 'سبب الإيداع مطلوب'
              : 'سبب السحب مطلوب');
    }
    final dao = CashboxDao(db);
    final session = await dao.currentSession();
    if (session.status != CashboxStatus.open) {
      throw InvalidOperationException(session.status == CashboxStatus.notOpened
          ? 'الصندوق لم يُفتح بعد — افتح الصندوق أولاً'
          : 'الصندوق مقفل — افتح جلسة جديدة أولاً');
    }
    return db.transaction(() async {
      final now = DateTime.now().millisecondsSinceEpoch;
      final CashboxTransactionRow row;
      if (type == CashboxTransactionType.deposit) {
        row = await _financial.postCashboxDeposit(
          db,
          amountMicros: amountMicros,
          reason: reason,
          userId: userId,
          atMillis: now,
        );
      } else {
        row = await _financial.postCashboxWithdrawal(
          db,
          amountMicros: amountMicros,
          reason: reason,
          userId: userId,
          atMillis: now,
        );
      }
      await _audit.write(
        db,
        userId: userId,
        action: AuditAction.create,
        entityType: 'cashbox',
        entityId: row.id,
        after: {
          'operation': type.name,
          'amount_micros': type == CashboxTransactionType.withdraw
              ? -amountMicros
              : amountMicros,
          'reason': reason.trim(),
        },
      );
      return row;
    });
  }

  /// Authorized drawer adjustment (±) — reuses the existing financial engine,
  /// which owns its own transaction, RBAC check, journal and audit (§7.5).
  /// Requires an open session so changes are attributed to the active shift.
  Future<CashboxTransactionRow> adjustCash(
    AppDatabase db, {
    required int amountMicros,
    required String reason,
    required String userId,
  }) async {
    final dao = CashboxDao(db);
    final status = (await dao.currentSession()).status;
    if (status != CashboxStatus.open) {
      throw InvalidOperationException(status == CashboxStatus.notOpened
          ? 'الصندوق لم يُفتح بعد — افتح الصندوق أولاً'
          : 'الصندوق مقفل — افتح جلسة جديدة أولاً');
    }
    return _financial.adjustCash(
      db,
      amountMicros: amountMicros,
      reason: reason,
      userId: userId,
    );
  }

  /// Historic running cash sum of the ledger (ربطاً بالمحرك المالي): the
  /// baseline the next movement is posted against.
  Future<int> _cashBalance(AppDatabase db) async {
    final row = await db
        .customSelect(
            'SELECT COALESCE(SUM(amount_micros), 0) AS s FROM cashbox_transactions')
        .getSingle();
    return row.read<int>('s');
  }
}