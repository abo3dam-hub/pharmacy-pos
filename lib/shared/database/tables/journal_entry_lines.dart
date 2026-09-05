import 'package:drift/drift.dart';
import 'accounts.dart';
import 'journal_entries.dart';

/// Lines composing a balanced journal entry (§4.23).
@DataClassName('JournalEntryLineRow')
@TableIndex(name: 'idx_journal_lines_entry', columns: {#journalEntryId})
@TableIndex(name: 'idx_journal_lines_account', columns: {#accountId})
class JournalEntryLines extends Table {
  TextColumn get id => text()();
  TextColumn get journalEntryId =>
      text().references(JournalEntries, #id)();
  TextColumn get accountId => text().references(Accounts, #id)();
  IntColumn get debitMicros => integer().withDefault(const Constant(0))();
  IntColumn get creditMicros => integer().withDefault(const Constant(0))();
  TextColumn get note => text().nullable()();
  IntColumn get createdAt => integer()();

  @override
  Set<Column> get primaryKey => {id};

  @override
  List<String> get customConstraints => [
        'CHECK (NOT (debit_micros > 0 AND credit_micros > 0))',
        'CHECK (NOT (debit_micros == 0 AND credit_micros == 0))',
        'CHECK (debit_micros >= 0)',
        'CHECK (credit_micros >= 0)',
      ];
}