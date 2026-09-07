import 'package:drift/drift.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pharmacy_pos/core/errors/exceptions.dart';
import 'package:pharmacy_pos/domain/services/accounting_period_service.dart';
import 'package:pharmacy_pos/domain/services/financial_posting_service.dart';
import 'package:pharmacy_pos/domain/services/sale_service.dart';
import 'package:pharmacy_pos/shared/database/app_database.dart';
import 'package:pharmacy_pos/shared/models/enums.dart';

import 'helpers.dart';

/// Phase 10.1 — Item B (closed-period enforcement). The rule lives centrally
/// in the financial posting layer, so every path (sale, purchase, expense,
/// payment, reversal) is rejected atomically when the entry date falls inside
/// a closed accounting period. Reversals land in the currently-open period as
/// new linked events — history is never mutated.
void main() {
  late AppDatabase db;
  final periods = AccountingPeriodService();
  const financial = FinancialPostingService();

  setUp(() {
    db = newDatabase();
  });

  tearDown(() async {
    await db.close();
  });

  const dayMs = 24 * 60 * 60 * 1000;

  Future<int> runCount(String table) async {
    final row =
        await db.customSelect('SELECT COUNT(*) AS c FROM $table').getSingle();
    return row.read<int>('c');
  }

  Future<String> createTodayPeriod() async {
    final now = DateTime.now();
    final start = DateTime(now.year, now.month, now.day)
        .millisecondsSinceEpoch;
    return periods.createPeriod(db,
        name: 'اليوم',
        startDate: start,
        endDate: start + 2 * dayMs,
        userId: 'user_admin');
  }

  Future<String> closeTodayPeriod() async {
    final id = await createTodayPeriod();
    await periods.closePeriod(db,
        periodId: id, userId: 'user_admin', closeReason: 'إقفال للاختبار');
    return id;
  }

  Future<(String, String)> seedItem() async {
    final itemId = await insertItem(db);
    await insertBatch(db, itemId,
        quantityBase: 10, expiryDays: 90, unitCostMicros: 10000);
    return (itemId, itemId);
  }

  // ── Open/closed period postings ───────────────────────────────────────

  test('posting inside an open period succeeds', () async {
    final id = await createTodayPeriod();
    final entryDate = DateTime.now().millisecondsSinceEpoch;

    await financial.postJournalEntry(
      db,
      refType: JournalReferenceType.expense,
      refId: 'in-open',
      entryDate: entryDate,
      description: 'قيد داخل فترة مفتوحة',
      lines: const [
        JournalLineDraft(
            accountCode: SystemAccountCode.cash, debitMicros: 1000),
        JournalLineDraft(
            accountCode: SystemAccountCode.operatingExpenses,
            creditMicros: 1000),
      ],
      createdBy: 'user_admin',
    );

    final entry =
        (await (db.select(db.journalEntries)
              ..where((j) => j.refId.equals('in-open')))
            .getSingle());
    expect(entry.entryDate, entryDate);
    final period = (await (db.select(db.accountingPeriods)
          ..where((p) => p.id.equals(id)))
        .getSingle());
    expect(period.isClosed, isFalse);
  });

  test('closed period rejects a sale posting atomically', () async {
    final (itemId, _) = await seedItem();
    await closeTodayPeriod();

    final invoicesBefore = await runCount('sales_invoices');
    final itemsBefore = await runCount('sales_invoice_items');
    final journalsBefore = await runCount('journal_entries');
    final cashboxBefore = await runCount('cashbox_transactions');
    final auditBefore = await runCount('audit_logs');

    await expectLater(
      SaleService().recordSale(
        db,
        SaleRequest(
          invoiceNumber: 'SI-CLOSE',
          lines: [
            SaleLineRequest(
                itemId: itemId,
                quantityBase: 1,
                unitPriceMicros: 20000,
                unitTypeId: 'unit_strip'),
          ],
          paymentMethod: PaymentMethod.cash,
          userId: 'user_admin',
          paidMicros: 20000,
          cashMicros: 20000,
          cardMicros: 0,
        ),
      ),
      throwsA(isA<InvalidOperationException>()),
    );

    // Nothing financial may be partially persisted.
    expect(await runCount('sales_invoices'), invoicesBefore);
    expect(await runCount('sales_invoice_items'), itemsBefore);
    expect(await runCount('journal_entries'), journalsBefore);
    expect(await runCount('cashbox_transactions'), cashboxBefore);
    expect(await runCount('audit_logs'), auditBefore);
  });

  test('closed period rejects a purchase posting atomically', () async {
    await closeTodayPeriod();
    final journalsBefore = await runCount('journal_entries');

    await expectLater(
      financial.postPurchase(
        db,
        invoiceId: 'PI-CLOSE',
        invoiceNumber: 'P-1',
        inventoryMicros: 3000,
        paidCashMicros: 1000,
        paidCardMicros: 0,
        amountPayableMicros: 2000,
        userId: 'user_admin',
        atMillis: DateTime.now().millisecondsSinceEpoch,
      ),
      throwsA(isA<InvalidOperationException>()),
    );
    expect(await runCount('journal_entries'), journalsBefore);
  });

  test('closed period rejects an expense posting atomically', () async {
    await closeTodayPeriod();
    final expensesBefore = await runCount('expenses');
    final journalsBefore = await runCount('journal_entries');
    final cashboxBefore = await runCount('cashbox_transactions');
    final auditBefore = await runCount('audit_logs');

    await expectLater(
      financial.recordExpenseByCode(
        db,
        categoryCode: 'other',
        description: 'مصروف داخل فترة مقفلة',
        amountMicros: 1000,
        userId: 'user_admin',
      ),
      throwsA(isA<InvalidOperationException>()),
    );
    expect(await runCount('expenses'), expensesBefore);
    expect(await runCount('journal_entries'), journalsBefore);
    expect(await runCount('cashbox_transactions'), cashboxBefore);
    expect(await runCount('audit_logs'), auditBefore);
  });

  // ── Reversal policy ───────────────────────────────────────────────────

  test('reversal of a closed-period entry lands in the open period, linked',
      () async {
    final now = DateTime.now();
    final todayStart =
        DateTime(now.year, now.month, now.day).millisecondsSinceEpoch;
    final p1Start = todayStart - 3 * dayMs;
    final p1End = todayStart - dayMs; // window: [p1Start, todayStart)
    final p2Start = todayStart - dayMs;
    final p2End = todayStart; // window: [yesterday, tomorrow)

    final p1 = await periods.createPeriod(db,
        name: 'P1',
        startDate: p1Start,
        endDate: p1End,
        userId: 'user_admin');
    final p2 = await periods.createPeriod(db,
        name: 'P2',
        startDate: p2Start,
        endDate: p2End,
        userId: 'user_admin');

    // Original entry dated inside open P1.
    final pastDate = p1Start + 12 * 60 * 60 * 1000;
    await financial.postJournalEntry(
      db,
      refType: JournalReferenceType.sale,
      refId: 'X1',
      entryDate: pastDate,
      description: 'قيد أصلي في فترة قديمة',
      lines: const [
        JournalLineDraft(
            accountCode: SystemAccountCode.cash, debitMicros: 100),
        JournalLineDraft(
            accountCode: SystemAccountCode.salesRevenue, creditMicros: 100),
      ],
      createdBy: 'user_admin',
    );
    final original = (await (db.select(db.journalEntries)
          ..where((j) =>
              j.refId.equals('X1') & j.isReversal.equals(false)))
        .getSingle());

    // Close newest (P2) then oldest (P1) → both closed.
    await periods.closePeriod(db, periodId: p2, userId: 'user_admin');
    await periods.closePeriod(db, periodId: p1, userId: 'user_admin');

    // A fresh open period now exists.
    final p3 = await periods.createPeriod(db,
        name: 'P3',
        startDate: todayStart,
        endDate: todayStart + 2 * dayMs,
        userId: 'user_admin');

    // Reversal dated "now" resolves to P3 → allowed, explicitly linked.
    await financial.postJournalEntry(
      db,
      refType: JournalReferenceType.sale,
      refId: 'X1',
      entryDate: DateTime.now().millisecondsSinceEpoch,
      description: 'استرجاع قيد قديم',
      isReversal: true,
      reversalOfEntryId: original.id,
      lines: const [
        JournalLineDraft(
            accountCode: SystemAccountCode.salesRevenue, debitMicros: 100),
        JournalLineDraft(
            accountCode: SystemAccountCode.cash, creditMicros: 100),
      ],
      createdBy: 'user_admin',
    );

    final reversal = (await (db.select(db.journalEntries)
          ..where((j) =>
              j.refId.equals('X1') & j.isReversal.equals(true)))
        .getSingle());
    expect(reversal.reversalOfEntryId, original.id);
    expect(reversal.id, isNot(original.id));
    final p3row = (await (db.select(db.accountingPeriods)
          ..where((p) => p.id.equals(p3)))
        .getSingle());
    expect(reversal.entryDate >= p3row.startDate, isTrue);

    // The historical entry is untouched.
    final unchanged = (await (db.select(db.journalEntries)
          ..where((j) => j.id.equals(original.id)))
        .getSingle());
    expect(unchanged.isPosted, isTrue);
    expect(unchanged.isReversal, isFalse);
    expect(unchanged.totalDebitMicros, 100);
    expect(unchanged.totalCreditMicros, 100);
  });

  test('a reversal back-dated into a closed period is rejected', () async {
    final now = DateTime.now();
    final todayStart =
        DateTime(now.year, now.month, now.day).millisecondsSinceEpoch;
    final p1Start = todayStart - 3 * dayMs;
    final p1End = todayStart - dayMs;

    final p1 = await periods.createPeriod(db,
        name: 'P1',
        startDate: p1Start,
        endDate: p1End,
        userId: 'user_admin');
    final p2 = await periods.createPeriod(db,
        name: 'P2',
        startDate: p1End,
        endDate: todayStart,
        userId: 'user_admin');
    await periods.closePeriod(db, periodId: p2, userId: 'user_admin');
    await periods.closePeriod(db, periodId: p1, userId: 'user_admin');

    final pastDate = p1Start + 12 * 60 * 60 * 1000;
    await expectLater(
      financial.postJournalEntry(
        db,
        refType: JournalReferenceType.sale,
        refId: 'X2',
        entryDate: pastDate,
        description: 'قيد في فترة مقفلة',
        lines: const [
          JournalLineDraft(
              accountCode: SystemAccountCode.cash, debitMicros: 100),
          JournalLineDraft(
              accountCode: SystemAccountCode.salesRevenue,
              creditMicros: 100),
        ],
        createdBy: 'user_admin',
      ),
      throwsA(isA<InvalidOperationException>()),
    );
    expect(await runCount('journal_entries'), 0);
  });

  // ── RBAC & audit ──────────────────────────────────────────────────────

  test('createPeriod and closePeriod require accounting.post', () async {
    final now = DateTime.now().millisecondsSinceEpoch;
    await db.into(db.users).insert(UsersCompanion.insert(
          id: 'user_pharm',
          username: 'pharm',
          passwordHash: 'x',
          fullName: 'صيدلي',
          roleId: 'role_pharmacist',
          isActive: const Value(true),
          createdAt: now,
          updatedAt: now,
        ));

    final start = DateTime(now).millisecondsSinceEpoch;
    // Pharmacist (view only, no accounting.post) cannot create.
    await expectLater(
      periods.createPeriod(db,
          name: 'R1',
          startDate: start,
          endDate: start + dayMs,
          userId: 'user_pharm'),
      throwsA(isA<UnauthorizedException>()),
    );

    // Admin can create; pharmacist cannot close.
    final id = await periods.createPeriod(db,
        name: 'R2',
        startDate: start,
        endDate: start + dayMs,
        userId: 'user_admin');
    await expectLater(
      periods.closePeriod(db, periodId: id, userId: 'user_pharm'),
      throwsA(isA<UnauthorizedException>()),
    );
    await periods.closePeriod(db,
        periodId: id, userId: 'user_admin', closeReason: 'ربع سنوي');
  });

  test('period creation and closing are audited', () async {
    final now = DateTime.now().millisecondsSinceEpoch;
    final start = DateTime(now).millisecondsSinceEpoch;
    final id = await periods.createPeriod(db,
        name: 'A1',
        startDate: start,
        endDate: start + dayMs,
        userId: 'user_admin');
    await periods.closePeriod(db,
        periodId: id, userId: 'user_admin', closeReason: 'شهري');

    final audits =
        await (db.select(db.auditLogs)
              ..where((a) => a.entityType.equals('accounting_period')))
            .get();
    expect(audits, hasLength(2));
    final actions = audits.map((a) => a.action).toSet();
    expect(actions, containsAll({'create', 'update'}));
  });
}