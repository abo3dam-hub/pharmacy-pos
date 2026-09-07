import 'package:drift/drift.dart';

/// Expense categories master (§4.20, Phase 9).
///
/// `code` is the canonical stable code persisted in `expenses.category`. The
/// seeded codes match the legacy `ExpenseCategory` enum names (`rent`,
/// `utilities`, ...) so existing rows keep their meaning after the Phase 9
/// migration. `accountCode` is the GL expense account the posting engine
/// debits (`5100` operating expenses default; rent→`5101`, salaries→`5102`).
/// System categories can be deactivated but never edited/deleted.
@DataClassName('ExpenseCategoryRow')
@TableIndex(name: 'idx_expense_categories_code', columns: {#code})
class ExpenseCategories extends Table {
  TextColumn get id => text()();
  TextColumn get code => text().unique()();
  TextColumn get name => text()();
  TextColumn get nameEn => text().nullable()();
  TextColumn get accountCode => text()();
  BoolColumn get isActive => boolean().withDefault(const Constant(true))();
  BoolColumn get isSystem => boolean().withDefault(const Constant(false))();
  IntColumn get createdAt => integer()();
  IntColumn get updatedAt => integer()();

  @override
  Set<Column> get primaryKey => {id};
}