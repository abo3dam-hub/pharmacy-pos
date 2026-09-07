import 'package:drift/drift.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pharmacy_pos/core/errors/exceptions.dart';
import 'package:pharmacy_pos/domain/services/cashbox_service.dart';
import 'package:pharmacy_pos/domain/services/financial_posting_service.dart';
import 'package:pharmacy_pos/shared/database/app_database.dart';
import 'package:pharmacy_pos/shared/models/enums.dart';

import 'helpers.dart';

/// Phase 10.1 — Item E (double-posting / idempotency) plus the Item C cashbox
/// deposit/withdraw semantic decision and the Item D purchase-return
/// regression. Rapid repeated calls must never collapse into one event or
/// silently produce duplicates with colliding references.
void main() {
  late AppDatabase db;
  const financial = FinancialPostingService();
  const cashbox = CashboxService();

  setUp(() {
    db = newDatabase();
  });

  tearDown(() async {
    await db.close();
  });

  Future<int> runCount(String table) async {
    final row =
        await db.customSelect('SELECT COUNT(*) AS c FROM $table').getSingle();
    return row.read<int>('c');
  }

  Future<int> accountBalance(String code) async {
    final row = await (db.select(db.accounts)
          ..where((a) => a.code.equals(code)))
        .getSingle();
    return row.balanceMicros;
  }

  Future<int> cashboxTotal() async {
    final row = await db.customSelect(
        'SELECT COALESCE(SUM(amount_micros), 0) AS s FROM cashbox_transactions').getSingle();
    return row.read<int>('s');
  }

  Future<List<String>> journalRefIds() async {
    final rows = await db.select(db.journalEntries).get();
    return [for (final r in rows) '${r.refType.name}:${r.refId}'];
  }

  Future<bool> journalTouchesAccount(String accountCode) async {
    final row = await db.customSelect(
      'SELECT COUNT(*) AS c FROM journal_entry_lines jl '
      'JOIN accounts a ON a.id = jl.account_id '
      'WHERE a.code = ?1',
      variables: [Variable.withString(accountCode)],
    ).getSingle();
    return row.read<int>('c') > 0;
  }

  // ── Item E: guard precision ────────────────────────────────────────────

  test('duplicate original posting is still rejected', () async {
    const lines = [
      JournalLineDraft(
          accountCode: SystemAccountCode.cash, debitMicros: 100),
      JournalLineDraft(
          accountCode: SystemAccountCode.salesRevenue, creditMicros: 100),
    ];
    await financial.postJournalEntry(db,
        refType: JournalReferenceType.sale,
        refId: 'X0',
        entryDate: DateTime.now().millisecondsSinceEpoch,
        description: 'أصلي',
        lines: lines,
        createdBy: 'user_admin');
    await expectLater(
      financial.postJournalEntry(db,
          refType: JournalReferenceType.sale,
          refId: 'X0',
          entryDate: DateTime.now().millisecondsSinceEpoch,
          description: 'أصلي تكرار',
          lines: lines,
          createdBy: 'user_admin'),
      throwsA(isA<InvalidOperationException>()),
    );
    expect(await runCount('journal_entries'), 1);
  });

  test('original + reversal pair allowed; duplicate reversal is rejected',
      () async {
    const originalLines = [
      JournalLineDraft(
          accountCode: SystemAccountCode.cash, debitMicros: 500),
      JournalLineDraft(
          accountCode: SystemAccountCode.salesRevenue, creditMicros: 500),
    ];
    const reversalLines = [
      JournalLineDraft(
          accountCode: SystemAccountCode.salesRevenue, debitMicros: 500),
      JournalLineDraft(
          accountCode: SystemAccountCode.cash, creditMicros: 500),
    ];
    final now = DateTime.now().millisecondsSinceEpoch;

    await financial.postJournalEntry(db,
        refType: JournalReferenceType.sale,
        refId: 'R1',
        entryDate: now,
        description: 'أصلي',
        lines: originalLines,
        createdBy: 'user_admin');
    final original = (await (db.select(db.journalEntries)
          ..where((j) =>
              j.refId.equals('R1') & j.isReversal.equals(false)))
        .getSingle());

    // The legitimate pair (original + one reversal) is allowed.
    await financial.postJournalEntry(db,
        refType: JournalReferenceType.sale,
        refId: 'R1',
        entryDate: now,
        description: 'استرجاع',
        isReversal: true,
        reversalOfEntryId: original.id,
        lines: reversalLines,
        createdBy: 'user_admin');

    // A second reversal of the same reference is a duplicate → rejected.
    await expectLater(
      financial.postJournalEntry(db,
          refType: JournalReferenceType.sale,
          refId: 'R1',
          entryDate: now,
          description: 'استرجاع تكرار',
          isReversal: true,
          reversalOfEntryId: original.id,
          lines: reversalLines,
          createdBy: 'user_admin'),
      throwsA(isA<InvalidOperationException>()),
    );
    expect(await runCount('journal_entries'), 2);
  });

  test('manual and opening_balance references stay exempt', () async {
    const lines = [
      JournalLineDraft(
          accountCode: SystemAccountCode.cash, debitMicros: 25),
      JournalLineDraft(
          accountCode: SystemAccountCode.salesRevenue, creditMicros: 25),
    ];
    final now = DateTime.now().millisecondsSinceEpoch;
    for (final refType in [
      JournalReferenceType.manual,
      JournalReferenceType.opening_balance,
    ]) {
      await financial.postJournalEntry(db,
          refType: refType,
          refId: 'same-ref',
          entryDate: now,
          description: 'مستثنى من الحماية',
          lines: lines,
          createdBy: 'user_admin');
      await financial.postJournalEntry(db,
          refType: refType,
          refId: 'same-ref',
          entryDate: now,
          description: 'مستثنى من الحماية (مرة أخرى)',
          lines: lines,
          createdBy: 'user_admin');
    }
    expect(await runCount('journal_entries'), 4);
  });

  test('rapid repeated adjustCash calls keep unique references', () async {
    await cashbox.openDrawer(db,
        openingMicros: 10000,
        userId: 'user_admin',
        note: 'فتح الجلسة');

    // Two adjustments back-to-back (same millisecond window in practice).
    await cashbox.adjustCash(db, amountMicros: 500, reason: 'تسوية 1', userId: 'user_admin');
    await cashbox.adjustCash(db, amountMicros: 500, reason: 'تسوية 2', userId: 'user_admin');

    final adjustments = await (db.select(db.journalEntries)
          ..where((j) =>
              j.refType.equalsValue(JournalReferenceType.adjustment)))
        .get();
    expect(adjustments, hasLength(2));
    expect(adjustments.map((j) => j.refId).toSet(), hasLength(2));
    final allRefs = await journalRefIds();
    expect(allRefs.where((r) => r.startsWith('adjustment:cash-adjust-')),
        hasLength(2));

    // Drawer and GL mirror both adjustments.
    expect(await cashboxTotal(), 11000);
    expect(await accountBalance(SystemAccountCode.cash), 11000);
  });

  // ── Item C: deposit / withdrawal semantics ─────────────────────────────

  test('deposits/withdrawals are drawer movements against Cash Over/Short, '
      'never bank transfers', () async {
    await cashbox.openDrawer(db,
        openingMicros: 10000,
        userId: 'user_admin',
        note: 'فتح الجلسة');
    await cashbox.deposit(db, amountMicros: 2500, reason: 'إيداع رصيد', userId: 'user_admin');
    await cashbox.withdraw(db, amountMicros: 1000, reason: 'سحب لتسليم', userId: 'user_admin');

    // Drawer: 10000 + 2500 − 1000 = 11500; the GL mirrors it.
    expect(await cashboxTotal(), 11500);
    expect(await accountBalance(SystemAccountCode.cash), 11500);

    // Bank is untouched — this is not a cash↔bank transfer.
    expect(await accountBalance(SystemAccountCode.bank), 0);

    // The offset always lands on Cash Over/Short (deposit Cr 2500, withdraw
    // Dr 1000 → net −1500), never on Bank.
    expect(await accountBalance(SystemAccountCode.cashOverShort), -1500);

    // Exactly two distinct cashbox journal events.
    final cashboxJournals = await (db.select(db.journalEntries)
          ..where((j) =>
              j.refType.equalsValue(JournalReferenceType.cashbox)))
        .get();
    expect(cashboxJournals, hasLength(2));
    expect(cashboxJournals.map((j) => j.refId).toSet(), hasLength(2));
  });

  // ── Item D: purchase / purchase-return regression ──────────────────────

  test('purchase + purchase-return stay balanced, non-duplicated, no 4002',
      () async {
    final now = DateTime.now().millisecondsSinceEpoch;
    await financial.postPurchase(
      db,
      invoiceId: 'PI-R1',
      invoiceNumber: 'P-100',
      inventoryMicros: 10000,
      paidCashMicros: 4000,
      paidCardMicros: 0,
      amountPayableMicros: 6000,
      userId: 'user_admin',
      atMillis: now,
    );
    await financial.postPurchaseReturn(
      db,
      returnId: 'PR-1',
      returnNumber: 'PR-1',
      invoiceNumber: 'P-100',
      inventoryMicros: 3000,
      refundCashMicros: 0,
      refundCardMicros: 0,
      apOffsetMicros: 3000,
      userId: 'user_admin',
      atMillis: now,
    );

    // Balanced totals per reference.
    final purchase = (await (db.select(db.journalEntries)
          ..where((j) => j.refId.equals('PI-R1')))
        .getSingle());
    expect(purchase.totalDebitMicros, purchase.totalCreditMicros);
    final ret = (await (db.select(db.journalEntries)
          ..where((j) => j.refId.equals('PR-1')))
        .getSingle());
    expect(ret.totalDebitMicros, ret.totalCreditMicros);

    // Exactly one of each; the engine reverses inventory directly and never
    // uses the seeded 4002 account.
    expect(await runCount('journal_entries'), 2);
    expect(await journalTouchesAccount(SystemAccountCode.purchaseReturns),
        isFalse);

    // Net balances: inventory +7000, cash −4000, AP +3000 (6000 accrued,
    // 3000 reversed — 3000 liability remains).
    expect(await accountBalance(SystemAccountCode.inventory), 7000);
    expect(await accountBalance(SystemAccountCode.cash), -4000);
    expect(await accountBalance(SystemAccountCode.accountsPayable), 3000);
  });
}