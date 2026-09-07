import 'package:drift/drift.dart';

import '../../../core/data_grid/page_request.dart';
import '../../../core/errors/exceptions.dart';
import '../../../core/util/ids.dart';
import '../../../shared/database/app_database.dart';
import '../../../shared/models/enums.dart';

/// Simple data class for account statement lines.
class StatementLine {
  const StatementLine({
    required this.entryId,
    required this.entryNumber,
    required this.entryDate,
    required this.description,
    required this.debitMicros,
    required this.creditMicros,
    required this.refType,
    this.runningBalanceMicros,
  });

  final String entryId;
  final String entryNumber;
  final int entryDate;
  final String description;
  final int debitMicros;
  final int creditMicros;
  final JournalReferenceType refType;

  /// Running account balance after this line (Phase 11). Null until the
  /// reporting controller fills it from the opening balance.
  final int? runningBalanceMicros;
}

/// Chart of Accounts + Journal + Statement DAO (§4.22, §4.23).
class AccountingDao {
  const AccountingDao(this._db);

  final AppDatabase _db;

  // ── Chart of Accounts ───────────────────────────────────────────────────

  Future<List<AccountRow>> listAccounts({
    String? search,
    bool onlyActive = false,
  }) async {
    final query = _db.select(_db.accounts);
    if (onlyActive) {
      query.where((a) => a.isActive.equals(true));
    }
    if (search != null && search.isNotEmpty) {
      query.where((a) =>
          a.code.like('%$search%') | a.name.like('%$search%'));
    }
    query.orderBy([(a) => OrderingTerm.asc(a.code)]);
    return query.get();
  }

  Future<AccountRow?> getAccount(String id) async {
    return (_db.select(_db.accounts)..where((a) => a.id.equals(id)))
        .getSingleOrNull();
  }

  Future<String> createAccount({
    required AccountType type,
    required String code,
    required String name,
    String? nameEn,
    String? parentId,
    int openingBalanceMicros = 0,
    String? notes,
  }) async {
    final existing = await (_db.select(_db.accounts)
          ..where((a) => a.code.equals(code)))
        .getSingleOrNull();
    if (existing != null) {
      throw ValidationException('رمز الحساب مكرر: $code');
    }
    final now = DateTime.now().millisecondsSinceEpoch;
    final id = newId('acc');
    await _db.into(_db.accounts).insert(
          AccountsCompanion.insert(
            id: id,
            code: code,
            name: name,
            nameEn: Value(nameEn),
            accountType: type,
            parentId: Value(parentId),
            isSystem: const Value(false),
            openingBalanceMicros: Value(openingBalanceMicros),
            balanceMicros: Value(openingBalanceMicros),
            createdAt: now,
            updatedAt: now,
          ),
        );
    return id;
  }

  Future<void> updateAccount(
    String id, {
    String? name,
    String? nameEn,
    String? parentId,
    String? notes,
    bool? isActive,
  }) async {
    final existing = await getAccount(id);
    if (existing == null) throw NotFoundException('الحساب غير موجود');
    final now = DateTime.now().millisecondsSinceEpoch;
    await (_db.update(_db.accounts)..where((a) => a.id.equals(id))).write(
      AccountsCompanion(
        name: name != null ? Value(name) : const Value.absent(),
        nameEn: Value(nameEn),
        parentId: Value(parentId),
        notes: Value(notes),
        isActive: isActive != null ? Value(isActive) : const Value.absent(),
        updatedAt: Value(now),
      ),
    );
  }

  Future<void> toggleAccountActive(String id, bool active) async {
    final existing = await getAccount(id);
    if (existing == null) throw NotFoundException('الحساب غير موجود');
    final now = DateTime.now().millisecondsSinceEpoch;
    await (_db.update(_db.accounts)..where((a) => a.id.equals(id))).write(
      AccountsCompanion(
        isActive: Value(active),
        updatedAt: Value(now),
      ),
    );
  }

  Future<int> accountBalance(String accountId) async {
    final account = await getAccount(accountId);
    if (account == null) return 0;
    return account.balanceMicros;
  }

  // ── Journal ─────────────────────────────────────────────────────────────

  Future<PageResult<JournalEntryRow>> listJournals({
    required PageRequest page,
    JournalReferenceType? refType,
    int? fromMillis,
    int? toMillis,
  }) async {
    final countQuery = _db.select(_db.journalEntries);
    if (refType != null) {
      countQuery.where((q) => q.refType.equalsValue(refType));
    }
    if (fromMillis != null) {
      countQuery.where((q) =>
          q.entryDate.isBiggerOrEqualValue(fromMillis));
    }
    if (toMillis != null) {
      countQuery.where((q) =>
          q.entryDate.isSmallerOrEqualValue(toMillis));
    }
    final allEntries = await countQuery.get();
    final total = allEntries.length;

    final query = _db.select(_db.journalEntries);
    if (refType != null) {
      query.where((q) => q.refType.equalsValue(refType));
    }
    if (fromMillis != null) {
      query.where((q) =>
          q.entryDate.isBiggerOrEqualValue(fromMillis));
    }
    if (toMillis != null) {
      query.where((q) =>
          q.entryDate.isSmallerOrEqualValue(toMillis));
    }
    query
      ..orderBy([(q) => OrderingTerm.desc(q.entryDate)])
      ..limit(page.pageSize, offset: page.offset);

    final items = await query.get();
    return PageResult(
      items: items,
      total: total,
      request: page,
    );
  }

  Future<JournalEntryRow?> getJournalEntry(String id) async {
    return (_db.select(_db.journalEntries)
          ..where((j) => j.id.equals(id)))
        .getSingleOrNull();
  }

  Future<List<JournalEntryLineRow>> listJournalLines(String entryId) async {
    return (_db.select(_db.journalEntryLines)
          ..where((l) => l.journalEntryId.equals(entryId)))
        .get();
  }

  Future<String> getAccountName(String accountId) async {
    final account = await getAccount(accountId);
    return account?.name ?? accountId;
  }

  // ── Account Statement ───────────────────────────────────────────────────

  Future<List<StatementLine>> accountStatement(
    String accountId, {
    DateTime? from,
    DateTime? to,
  }) async {
    final fromMillis = from?.millisecondsSinceEpoch ?? 0;
    final toMillis = to?.millisecondsSinceEpoch ?? 9999999999999;

    final query = _db.select(_db.journalEntryLines).join([
      innerJoin(
        _db.journalEntries,
        _db.journalEntries.id.equalsExp(
            _db.journalEntryLines.journalEntryId),
      ),
    ])
      ..where(
        _db.journalEntryLines.accountId.equals(accountId) &
            _db.journalEntries.entryDate
                .isBiggerOrEqualValue(fromMillis) &
            _db.journalEntries.entryDate
                .isSmallerOrEqualValue(toMillis),
      )
      ..orderBy([
        OrderingTerm.asc(_db.journalEntries.entryDate),
        OrderingTerm.asc(_db.journalEntries.entryNumber),
      ]);

    final rows = await query.get();
    return rows.map((row) {
      final line = row.readTable(_db.journalEntryLines);
      final entry = row.readTable(_db.journalEntries);
      return StatementLine(
        entryId: entry.id,
        entryNumber: entry.entryNumber,
        entryDate: entry.entryDate,
        description: entry.description,
        debitMicros: line.debitMicros,
        creditMicros: line.creditMicros,
        refType: entry.refType,
      );
    }).toList();
  }

  /// Signed balance of [accountId] immediately before [from] (null = the
  /// seeded opening). Formula matches the posting engine:
  /// `opening = openingBalanceMicros + normalSign * (Σ debit − Σ credit)`
  /// over entries strictly before `from`.
  Future<int> accountOpeningBalanceMicros(
    String accountId, {
    DateTime? from,
  }) async {
    final fromMillis = from?.millisecondsSinceEpoch ?? 0;
    final row = await _db.customSelect(
      '''
      SELECT
        a.opening_balance_micros AS opening_base,
        a.account_type AS account_type,
        COALESCE(SUM(CASE WHEN j.entry_date < ? THEN l.debit_micros ELSE 0 END), 0) AS pre_debit,
        COALESCE(SUM(CASE WHEN j.entry_date < ? THEN l.credit_micros ELSE 0 END), 0) AS pre_credit
      FROM accounts a
      LEFT JOIN journal_entry_lines l ON l.account_id = a.id
      LEFT JOIN journal_entries j ON j.id = l.journal_entry_id
      WHERE a.id = ?
      GROUP BY a.id
      ''',
      variables: [
        Variable<int>(fromMillis),
        Variable<int>(fromMillis),
        Variable.withString(accountId),
      ],
    ).getSingle();
    final type = _accountType(row.read<String>('account_type'));
    final sign = switch (type) {
      AccountType.asset || AccountType.expense => 1,
      AccountType.liability ||
      AccountType.equity ||
      AccountType.revenue =>
        -1,
    };
    return row.read<int>('opening_base') +
        sign * (row.read<int>('pre_debit') - row.read<int>('pre_credit'));
  }

  static AccountType _accountType(String value) =>
      AccountType.values.firstWhere((t) => t.name == value);
}
