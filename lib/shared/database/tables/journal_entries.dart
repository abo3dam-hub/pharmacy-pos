import 'package:drift/drift.dart';
import '../../models/enums.dart';
import 'users.dart';

/// Double-entry journal entries; every batch of lines must balance
/// (Σ debits == Σ credits). Enforced by the accounting service.
@DataClassName('JournalEntryRow')
@TableIndex(name: 'idx_journal_entries_date', columns: {#entryDate})
@TableIndex(name: 'idx_journal_entries_ref', columns: {#refType, #refId})
class JournalEntries extends Table {
  TextColumn get id => text()();
  TextColumn get entryNumber => text().unique()();
  TextColumn get refType => textEnum<JournalReferenceType>()();
  TextColumn get refId => text().nullable()();
  IntColumn get entryDate => integer()();
  TextColumn get description => text().nullable()();
  IntColumn get totalDebitMicros => integer().withDefault(const Constant(0))();
  IntColumn get totalCreditMicros => integer().withDefault(const Constant(0))();
  TextColumn get status => textEnum<JournalEntryStatus>()();
  TextColumn get createdById => text().nullable().references(Users, #id)();
  IntColumn get createdAt => integer()();
  IntColumn get updatedAt => integer()();

  @override
  Set<Column> get primaryKey => {id};
}