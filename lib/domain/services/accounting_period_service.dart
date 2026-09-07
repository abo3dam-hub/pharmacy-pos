import 'package:drift/drift.dart';

import '../../core/constants/permission_codes.dart';
import '../../core/errors/exceptions.dart';
import '../../core/util/ids.dart';
import '../../shared/database/app_database.dart';
import '../../shared/models/enums.dart';
import 'audit_service.dart';
import 'permission_service.dart';

/// Accounting period management service (§17 Phase 10).
///
/// Phase 10.1 hardening: period creation and closing are RBAC-gated on
/// `accounting.post` and audited, matching the UI gating (`canPost`).
class AccountingPeriodService {
  AccountingPeriodService({
    PermissionService? permissions,
    AuditService? audit,
  })  : _permissions = permissions ?? const PermissionService(),
        _audit = audit ?? const AuditService();

  final PermissionService _permissions;
  final AuditService _audit;

  /// Lists all periods, newest first.
  Future<List<AccountingPeriodRow>> listPeriods(AppDatabase db) async {
    return (db.select(db.accountingPeriods)
          ..orderBy([(p) => OrderingTerm.desc(p.startDate)]))
        .get();
  }

  /// Creates a new open accounting period. Requires `accounting.post`.
  Future<String> createPeriod(
    AppDatabase db, {
    required String name,
    required int startDate,
    required int endDate,
    required String userId,
  }) async {
    await _permissions.requireUserPermission(db, userId, Perm.accountingPost);
    if (endDate <= startDate) {
      throw ValidationException('تاريخ الانتهاء يجب أن يكون بعد تاريخ البدء');
    }
    if (name.trim().isEmpty) {
      throw ValidationException('اسم الفترة مطلوب');
    }
    final id = newId('period');
    final now = DateTime.now().millisecondsSinceEpoch;
    await db.into(db.accountingPeriods).insert(
          AccountingPeriodsCompanion.insert(
            id: id,
            name: name.trim(),
            startDate: startDate,
            endDate: endDate,
            createdAt: now,
            updatedAt: now,
          ),
        );
    await _audit.write(
      db,
      userId: userId,
      action: AuditAction.create,
      entityType: 'accounting_period',
      entityId: id,
      after: {
        'name': name.trim(),
        'start_date': startDate,
        'end_date': endDate,
      },
      note: 'إنشاء الفترة المالية "${name.trim()}"',
    );
    return id;
  }

  /// Validates and closes the given period. Requires `accounting.post`.
  ///
  /// Closing rules:
  /// 1. Period must not already be closed.
  /// 2. There must not be an open period with a start date after this one.
  Future<void> closePeriod(
    AppDatabase db, {
    required String periodId,
    required String userId,
    String? closeReason,
  }) async {
    await _permissions.requireUserPermission(db, userId, Perm.accountingPost);
    final period =
        await (db.select(db.accountingPeriods)
              ..where((p) => p.id.equals(periodId)))
            .getSingleOrNull();
    if (period == null) {
      throw NotFoundException('الفترة غير موجودة');
    }
    if (period.isClosed) {
      throw InvalidOperationException('الفترة مقفلة بالفعل');
    }

    final futureOpen = await (db.select(db.accountingPeriods)
          ..where((p) =>
              p.isClosed.equals(false) &
              p.id.equals(periodId).not() &
              p.startDate.isBiggerThanValue(period.startDate)))
        .get();
    if (futureOpen.isNotEmpty) {
      throw InvalidOperationException(
          'يوجد فترة مفتوحة أحدث — يجب إقفالها أولاً');
    }

    final now = DateTime.now().millisecondsSinceEpoch;
    await (db.update(db.accountingPeriods)
          ..where((p) => p.id.equals(periodId)))
        .write(
      AccountingPeriodsCompanion(
        isClosed: const Value(true),
        closedBy: Value(userId),
        closedAt: Value(now),
        closeReason: Value(closeReason),
        updatedAt: Value(now),
      ),
    );
    await _audit.write(
      db,
      userId: userId,
      action: AuditAction.update,
      entityType: 'accounting_period',
      entityId: periodId,
      before: {'is_closed': false},
      after: {
        'is_closed': true,
        'closed_by': userId,
        'closed_at': now,
        'close_reason': closeReason,
      },
      note: 'إقفال الفترة المالية "${period.name}"',
    );
  }
}
