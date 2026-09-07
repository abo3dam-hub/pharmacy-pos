import 'package:drift/drift.dart';

import '../../core/errors/exceptions.dart';
import '../../core/util/ids.dart';
import '../../shared/database/app_database.dart';

/// Accounting period management service (§17 Phase 10).
class AccountingPeriodService {
  const AccountingPeriodService();

  /// Lists all periods, newest first.
  Future<List<AccountingPeriodRow>> listPeriods(AppDatabase db) async {
    return (db.select(db.accountingPeriods)
          ..orderBy([(p) => OrderingTerm.desc(p.startDate)]))
        .get();
  }

  /// Creates a new open accounting period.
  Future<String> createPeriod(
    AppDatabase db, {
    required String name,
    required int startDate,
    required int endDate,
  }) async {
    if (endDate <= startDate) {
      throw ValidationException('تاريخ الانتهاء يجب أن يكون بعد تاريخ البدء');
    }
    final id = newId('period');
    final now = DateTime.now().millisecondsSinceEpoch;
    await db.into(db.accountingPeriods).insert(
          AccountingPeriodsCompanion.insert(
            id: id,
            name: name,
            startDate: startDate,
            endDate: endDate,
            createdAt: now,
            updatedAt: now,
          ),
        );
    return id;
  }

  /// Validates and closes the given period.
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
  }
}
