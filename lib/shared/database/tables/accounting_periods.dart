import 'package:drift/drift.dart';
import 'users.dart';

/// Accounting period management (§17 Phase 10): open/close periods to
/// prevent financial postings into closed periods.
@DataClassName('AccountingPeriodRow')
@TableIndex(name: 'idx_accounting_periods_dates', columns: {#startDate, #endDate})
class AccountingPeriods extends Table {
  TextColumn get id => text()();
  TextColumn get name => text()();
  IntColumn get startDate => integer()();
  IntColumn get endDate => integer()();
  BoolColumn get isClosed => boolean().withDefault(const Constant(false))();
  TextColumn get closedBy => text().nullable().references(Users, #id)();
  IntColumn get closedAt => integer().nullable()();
  TextColumn get closeReason => text().nullable()();
  IntColumn get createdAt => integer()();
  IntColumn get updatedAt => integer()();

  @override
  Set<Column> get primaryKey => {id};
}
