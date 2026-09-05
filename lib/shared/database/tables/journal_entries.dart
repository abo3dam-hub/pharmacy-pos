import 'package:drift/drift.dart';
import '../../models/enum_value_converter.dart';
import 'users.dart';

/// Double-entry journal header (§4.23, §18); lines must balance
/// (Σ debits == Σ credits), enforced by the accounting service.
/// `isPosted` is NOT NULL and defaults to `1` — entries are posted on create.
@DataClassName('JournalEntryRow')
@TableIndex(name: 'idx_journal_entries_date', columns: {#entryDate})
@TableIndex(name: 'idx_journal_entries_ref', columns: {#refType, #refId})
class JournalEntries extends Table {
  TextColumn get id => text()();
  TextColumn get entryNumber => text().unique()();

  /// Stored plan values: 'sale' | 'purchase' | 'return' | 'expense' |
  /// 'cashbox' | 'opening_balance' | 'adjustment' | 'manual' (§4.23).
  TextColumn get refType => text().map(journalReferenceTypeValues)();
  TextColumn get refId => text().nullable()();
  IntColumn get entryDate => integer()();
  TextColumn get description => text()();
  IntColumn get totalDebitMicros => integer().withDefault(const Constant(0))();
  IntColumn get totalCreditMicros => integer().withDefault(const Constant(0))();
  BoolColumn get isPosted =>
      boolean().withDefault(const Constant(true))();
  TextColumn get createdBy => text().references(Users, #id)();
  IntColumn get createdAt => integer()();
  IntColumn get updatedAt => integer()();

  @override
  Set<Column> get primaryKey => {id};
}