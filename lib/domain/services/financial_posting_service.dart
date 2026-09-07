import 'package:drift/drift.dart';

import '../../core/constants/account_codes.dart';
import '../../core/constants/permission_codes.dart';
import '../../core/errors/exceptions.dart';
import '../../core/util/ids.dart';
import '../../data/daos/customer_dao.dart';
import '../../shared/database/app_database.dart';
import '../../shared/models/enums.dart';
import 'audit_service.dart';
import 'permission_service.dart';

export '../../core/constants/account_codes.dart';

/// One balanced journal line draft (one of debit/credit, never both).
class JournalLineDraft {
  const JournalLineDraft({
    required this.accountCode,
    this.debitMicros = 0,
    this.creditMicros = 0,
    this.note,
  });

  final String accountCode;
  final int debitMicros;
  final int creditMicros;
  final String? note;
}

/// The double-entry financial posting engine (§11, §14, §18, §19, §21).
///
/// Methods in this service are *primitives*: they are called from inside a
/// caller-owned `db.transaction` (sale, return, payment, void, expense) so the
/// invoice/stock/cashbox/journal/audit changes are committed atomically or not
/// at all. [recordExpense] and [adjustCash] are standalone workflows and own
/// their transaction.
///
/// Every cashbox transaction and journal entry is auditable; every journal is
/// validated to satisfy Σ debits == Σ credits before it is persisted.
class FinancialPostingService {
  const FinancialPostingService({
    AuditService? audit,
    PermissionService? permissions,
  })  : _audit = audit ?? const AuditService(),
        _permissions = permissions ?? const PermissionService();
  final AuditService _audit;
  final PermissionService _permissions;

  // ── Cashbox primitives ─────────────────────────────────────────────────

  /// Appends one drawer movement with the running balance. [amountMicros]
  /// must be non-zero; positive adds to the drawer, negative removes.
  Future<int> postCashboxRow(
    AppDatabase db, {
    required CashboxTransactionType type,
    required int amountMicros,
    String? refType,
    String? refId,
    required String userId,
    String? note,
    required int atMillis,
  }) async {
    if (amountMicros == 0) {
      throw ValidationException('حركة الصندوق لا يمكن أن تكون صفرية');
    }
    final current = await _currentCashBalance(db);
    final running = current + amountMicros;
    await db.into(db.cashboxTransactions).insert(
          CashboxTransactionsCompanion.insert(
            id: newId('cbx'),
            type: type,
            amountMicros: amountMicros,
            remainingMicros: running,
            refType: refType != null ? Value(refType) : const Value(null),
            refId: refId != null ? Value(refId) : const Value(null),
            userId: userId,
            note: note != null ? Value(note) : const Value(null),
            createdAt: atMillis,
          ),
        );
    return running;
  }

  Future<int> _currentCashBalance(AppDatabase db) async {
    final row = await db
        .customSelect(
            'SELECT COALESCE(SUM(amount_micros), 0) AS s FROM cashbox_transactions')
        .getSingle();
    return row.read<int>('s');
  }

  // ── Journal primitives ─────────────────────────────────────────────────

  /// Persists a balanced journal entry and updates running account balances.
  int _normalSign(AccountType type) => switch (type) {
        AccountType.asset || AccountType.expense => 1,
        AccountType.liability || AccountType.equity || AccountType.revenue => -1,
      };

  Future<void> postJournalEntry(
    AppDatabase db, {
    required JournalReferenceType refType,
    String? refId,
    required int entryDate,
    required String description,
    required List<JournalLineDraft> lines,
    required String createdBy,
    bool isReversal = false,
    String? reversalOfEntryId,
  }) async {
    // Double-posting protection: for event-linked journals (sale/return/
    // expense/customer_payment/adjustment/cashbox), refuse to post the same
    // refType+refId twice for the SAME kind of event. An original posting
    // (isReversal=false) is blocked when an original for the reference already
    // exists; a reversal (isReversal=true) is blocked when a reversal already
    // exists — while the legitimate pair (one original + one reversal) stays
    // allowed. Manual and opening-balance journals are exempt. Public posting
    // entry-points also call this before any side effect so a rejected event
    // never leaks drawer rows.
    await _assertNoDuplicate(db, refType, refId, isReversal);

    // Central closed-period enforcement (Phase 10.1): reject any posting whose
    // entry date falls inside a closed accounting period. Resolved here, in the
    // posting layer, so every financial path is protected — not just the UI.
    await _enforcePeriodOpen(db, entryDate);

    if (lines.isEmpty) {
      throw ValidationException('قيد محاسبي بدون بنود');
    }
    var totalDebitMicros = 0;
    var totalCreditMicros = 0;
    for (final line in lines) {
      if (line.debitMicros < 0 || line.creditMicros < 0) {
        throw ValidationException('لا يمكن أن تكون بنود القيد سالبة');
      }
      if (line.debitMicros > 0 && line.creditMicros > 0) {
        throw ValidationException('بند القيد لا يمكن أن يكون مديناً ودائناً معاً');
      }
      if (line.debitMicros == 0 && line.creditMicros == 0) {
        throw ValidationException('بند القيد بدون مبلغ');
      }
      totalDebitMicros += line.debitMicros;
      totalCreditMicros += line.creditMicros;
    }
    if (totalDebitMicros != totalCreditMicros) {
      throw ValidationException(
          'القيد غير متوازن: مدين ($totalDebitMicros) ≠ دائن ($totalCreditMicros)');
    }

    final codes = {for (final l in lines) l.accountCode};
    final accounts = await (db.select(db.accounts)
          ..where((a) => a.code.isIn(codes)))
        .get();
    final byCode = {for (final a in accounts) a.code: a};
    for (final code in codes) {
      if (!byCode.containsKey(code)) {
        throw ValidationException('حساب النظام غير موجود بالكود $code');
      }
    }

    final entryId = newId('je');
    await db.into(db.journalEntries).insert(
          JournalEntriesCompanion.insert(
            id: entryId,
            entryNumber: 'JE-$entryId',
            refType: refType,
            refId: refId != null ? Value(refId) : const Value(null),
            entryDate: entryDate,
            description: description,
            totalDebitMicros: Value(totalDebitMicros),
            totalCreditMicros: Value(totalCreditMicros),
            isPosted: const Value(true),
            isReversal: Value(isReversal),
            reversalOfEntryId: reversalOfEntryId != null
                ? Value(reversalOfEntryId)
                : const Value(null),
            createdBy: createdBy,
            createdAt: entryDate,
            updatedAt: entryDate,
          ),
        );

    final netByCode = <String, int>{};
    for (final line in lines) {
      await db.into(db.journalEntryLines).insert(
            JournalEntryLinesCompanion.insert(
              id: newId('jel'),
              journalEntryId: entryId,
              accountId: byCode[line.accountCode]!.id,
              debitMicros: Value(line.debitMicros),
              creditMicros: Value(line.creditMicros),
              note: line.note != null ? Value(line.note) : const Value(null),
              createdAt: entryDate,
            ),
          );
      netByCode.update(line.accountCode,
          (v) => v + line.debitMicros - line.creditMicros,
          ifAbsent: () => line.debitMicros - line.creditMicros);
    }

    for (final entry in netByCode.entries) {
      final account = byCode[entry.key]!;
      final newBalance =
          account.balanceMicros + (_normalSign(account.accountType) * entry.value);
      await (db.update(db.accounts)..where((a) => a.id.equals(account.id))).write(
            AccountsCompanion(
              balanceMicros: Value(newBalance),
              updatedAt: Value(entryDate),
            ),
          );
    }
  }

  /// Central closed-period enforcement (Phase 10.1). Every posting resolves its
  /// accounting period from [entryDate]; a closed matching period rejects the
  /// posting. If no period covers the date, the existing project policy applies
  /// (post freely — no period is auto-created). Periods are date-granular:
  /// a period stored as start-of-day/end-of-day spans through the end of its
  /// last day (`endDate + 1 day`), matching how the UI stores period bounds.
  /// Reversals are new entries dated "now", so their own (open) period governs;
  /// historical entries are never mutated.
  Future<void> _enforcePeriodOpen(AppDatabase db, int entryDate) async {
    const dayMs = 24 * 60 * 60 * 1000;
    final candidates = (await db.select(db.accountingPeriods).get())
        .where((p) => entryDate >= p.startDate && entryDate < p.endDate + dayMs)
        .toList()
      ..sort((a, b) => b.startDate.compareTo(a.startDate));
    if (candidates.isEmpty) {
      return;
    }
    if (candidates.first.isClosed) {
      throw InvalidOperationException(
          'الفترة المالية "${candidates.first.name}" مقفلة — لا يمكن '
          'ترحيل قيد بتاريخ ${_fmtEntryDate(entryDate)}. افتح فترة جديدة أو '
          'صحّح تاريخ القيد.');
    }
  }

  static String _fmtEntryDate(int millis) {
    final d = DateTime.fromMillisecondsSinceEpoch(millis);
    final hh = d.hour.toString().padLeft(2, '0');
    final mm = d.minute.toString().padLeft(2, '0');
    return '${d.year}-${d.month.toString().padLeft(2, '0')}-'
        '${d.day.toString().padLeft(2, '0')} $hh:$mm';
  }

  /// Double-posting protection, refactored so every public posting entry-point
  /// can refuse a duplicate event *before* writing any side effect (drawer rows,
  /// stock…) — not only when the journal row is about to be inserted. Manual and
  /// opening-balance journals are exempt.
  Future<void> _assertNoDuplicate(
    AppDatabase db,
    JournalReferenceType refType,
    String? refId,
    bool isReversal,
  ) async {
    if (refType == JournalReferenceType.manual ||
        refType == JournalReferenceType.opening_balance ||
        refId == null) {
      return;
    }
    final existing = await (db.select(db.journalEntries)
          ..where((je) =>
              je.refType.equalsValue(refType) & je.refId.equals(refId)))
        .get();
    if (isReversal
        ? existing.any((e) => e.isReversal)
        : existing.any((e) => !e.isReversal)) {
      throw InvalidOperationException(
          isReversal
              ? 'تم تسجيل قيد مرتجع/استرجاع لهذا الحدث بالفعل — '
                  'لا يمكن الترحيل مرتين (النوع: $refType، المرجع: $refId)'
              : 'تم ترحيل قيد لهذا الحدث بالفعل — لا يمكن الترحيل مرتين '
                  '(النوع: $refType، المرجع: $refId)');
    }
  }

  // ── Business postings (called inside caller transactions) ─────────────

  /// Sale posting (§11): cash/card/credit settlement + COGS/inventory.
  Future<void> postSale(
    AppDatabase db, {
    required String invoiceId,
    required String invoiceNumber,
    required int totalMicros,
    required int costMicros,
    required int cashMicros,
    required int cardMicros,
    required int creditMicros,
    required int changeMicros,
    required String userId,
    required int atMillis,
  }) async {
    final drawerNet = cashMicros - changeMicros;
    if (drawerNet < 0) {
      throw ValidationException(
          'تجاوز المبلغ المرتجع النقد المستلم (شبكة الصندوق سالبة)');
    }
    // Refuse a repeated invoice before touching the drawer.
    await _assertNoDuplicate(db, JournalReferenceType.sale, invoiceId, false);
    if (drawerNet > 0) {
      await postCashboxRow(
        db,
        type: CashboxTransactionType.sale,
        amountMicros: drawerNet,
        refType: 'sale',
        refId: invoiceId,
        userId: userId,
        note: 'فاتورة بيع $invoiceNumber',
        atMillis: atMillis,
      );
    }
    final lines = <JournalLineDraft>[
      if (drawerNet > 0)
        JournalLineDraft(
            accountCode: SystemAccountCode.cash, debitMicros: drawerNet),
      if (cardMicros > 0)
        JournalLineDraft(
            accountCode: SystemAccountCode.bank, debitMicros: cardMicros),
      if (creditMicros > 0)
        JournalLineDraft(
            accountCode: SystemAccountCode.accountsReceivable,
            debitMicros: creditMicros),
      JournalLineDraft(
          accountCode: SystemAccountCode.salesRevenue, creditMicros: totalMicros),
      JournalLineDraft(
          accountCode: SystemAccountCode.costOfGoodsSold, debitMicros: costMicros),
      JournalLineDraft(
          accountCode: SystemAccountCode.inventory, creditMicros: costMicros),
    ];
    await postJournalEntry(
      db,
      refType: JournalReferenceType.sale,
      refId: invoiceId,
      entryDate: atMillis,
      description: 'فاتورة بيع $invoiceNumber',
      lines: lines,
      createdBy: userId,
    );
  }

  /// Return reversal (§14): refunds the customer (AR-offset then cash) and
  /// restores inventory/cost. [reversalRevenueMicros] and [costMicros] are
  /// positive amounts; of the reversed revenue, any part not offset against
  /// accounts receivable is refunded as cash ([refundCashMicros]).
  Future<void> postReturn(
    AppDatabase db, {
    required String returnId,
    required String returnNumber,
    required String invoiceNumber,
    required int reversalRevenueMicros,
    required int costMicros,
    required int accountsReceivableOffsetMicros,
    required int refundCashMicros,
    required String userId,
    required int atMillis,
  }) async {
    if (refundCashMicros + accountsReceivableOffsetMicros !=
        reversalRevenueMicros) {
      throw ValidationException(
          'تسوية المرتجع غير متوازنة: الإرجاع النقدي + الحسابات لا يغطي المبلغ');
    }
    // Refuse a repeated return before touching the drawer.
    await _assertNoDuplicate(
        db, JournalReferenceType.return_invoice, returnId, false);
    if (refundCashMicros > 0) {
      await postCashboxRow(
        db,
        type: CashboxTransactionType.refund,
        amountMicros: -refundCashMicros,
        refType: 'return',
        refId: returnId,
        userId: userId,
        note: 'مرتجع بيع $returnNumber',
        atMillis: atMillis,
      );
    }
    await postJournalEntry(
      db,
      refType: JournalReferenceType.return_invoice,
      refId: returnId,
      entryDate: atMillis,
      description: 'مرتجع بيع $returnNumber على فاتورة $invoiceNumber',
      lines: [
        JournalLineDraft(
            accountCode: SystemAccountCode.salesReturns,
            debitMicros: reversalRevenueMicros),
        if (accountsReceivableOffsetMicros > 0)
          JournalLineDraft(
              accountCode: SystemAccountCode.accountsReceivable,
              creditMicros: accountsReceivableOffsetMicros),
        if (refundCashMicros > 0)
          JournalLineDraft(
              accountCode: SystemAccountCode.cash,
              creditMicros: refundCashMicros),
        JournalLineDraft(
            accountCode: SystemAccountCode.inventory, debitMicros: costMicros),
        JournalLineDraft(
            accountCode: SystemAccountCode.costOfGoodsSold, creditMicros: costMicros),
      ],
      createdBy: userId,
    );
  }

  /// Customer payment on account (§18): Dr Cash/Bank, Cr AR.
  Future<void> postCustomerPayment(
    AppDatabase db, {
    required String paymentId,
    required String paymentNumber,
    required int amountMicros,
    required int cashMicros,
    required int cardMicros,
    required String userId,
    required int atMillis,
  }) async {
    // Refuse a repeated payment event before touching the drawer.
    await _assertNoDuplicate(
        db, JournalReferenceType.customer_payment, paymentId, false);
    if (cashMicros > 0) {
      await postCashboxRow(
        db,
        type: CashboxTransactionType.payment,
        amountMicros: cashMicros,
        refType: 'customer_payment',
        refId: paymentId,
        userId: userId,
        note: 'سداد عميل $paymentNumber',
        atMillis: atMillis,
      );
    }
    await postJournalEntry(
      db,
      refType: JournalReferenceType.customer_payment,
      refId: paymentId,
      entryDate: atMillis,
      description: 'سداد عميل $paymentNumber',
      lines: [
        if (cashMicros > 0)
          JournalLineDraft(
              accountCode: SystemAccountCode.cash, debitMicros: cashMicros),
        if (cardMicros > 0)
          JournalLineDraft(
              accountCode: SystemAccountCode.bank, debitMicros: cardMicros),
        JournalLineDraft(
            accountCode: SystemAccountCode.accountsReceivable,
            creditMicros: amountMicros),
      ],
      createdBy: userId,
    );
  }

  /// Customer refund: Dr AR, Cr Cash/Bank (reduces their credit balance).
  ///
  /// Phase 10.1: a refund is a distinct financial event with explicit reversal
  /// semantics — it keeps its own unique `paymentId` reference, is flagged
  /// `isReversal: true` and links back to the most recent original payment
  /// journal ([reversalOfEntryId]) so traceability and the double-posting guard
  /// both hold. Never mutates the original entry.
  Future<void> postCustomerRefund(
    AppDatabase db, {
    required String paymentId,
    required String paymentNumber,
    required int amountMicros,
    required int cashMicros,
    required int cardMicros,
    required String userId,
    required int atMillis,
    String? reversalOfEntryId,
  }) async {
    // Refuse a repeated refund event before touching the drawer.
    await _assertNoDuplicate(
        db, JournalReferenceType.customer_payment, paymentId, true);
    if (cashMicros > 0) {
      await postCashboxRow(
        db,
        type: CashboxTransactionType.refund,
        amountMicros: -cashMicros,
        refType: 'customer_payment',
        refId: paymentId,
        userId: userId,
        note: 'استرداد مبلغ $paymentNumber',
        atMillis: atMillis,
      );
    }
    await postJournalEntry(
      db,
      refType: JournalReferenceType.customer_payment,
      refId: paymentId,
      entryDate: atMillis,
      description: 'استرداد مبلغ عميل $paymentNumber',
      isReversal: true,
      reversalOfEntryId: reversalOfEntryId,
      lines: [
        JournalLineDraft(
            accountCode: SystemAccountCode.accountsReceivable,
            debitMicros: amountMicros),
        if (cashMicros > 0)
          JournalLineDraft(
              accountCode: SystemAccountCode.cash, creditMicros: cashMicros),
        if (cardMicros > 0)
          JournalLineDraft(
              accountCode: SystemAccountCode.bank, creditMicros: cardMicros),
      ],
      createdBy: userId,
    );
  }

  /// Void reversal (§19): reverses the original sale journal + stock and pulls
  /// the money back out of the drawer. Creates a reversal journal linked to the
  /// original sale entry to preserve the correction relationship (§14).
  Future<void> postVoidReversal(
    AppDatabase db, {
    required String invoiceId,
    required String invoiceNumber,
    required int totalMicros,
    required int costMicros,
    required int drawerNetMicros,
    required int cardMicros,
    required int creditMicros,
    required String userId,
    required int atMillis,
  }) async {
    // Refuse a repeated void before pulling money back out of the drawer.
    await _assertNoDuplicate(db, JournalReferenceType.sale, invoiceId, true);
    if (drawerNetMicros > 0) {
      await postCashboxRow(
        db,
        type: CashboxTransactionType.refund,
        amountMicros: -drawerNetMicros,
        refType: 'sale',
        refId: invoiceId,
        userId: userId,
        note: 'إلغاء فاتورة $invoiceNumber',
        atMillis: atMillis,
      );
    }
    // Find the original sale journal for the reversal link.
    final original = await (db.select(db.journalEntries)
          ..where((je) =>
              je.refType.equalsValue(JournalReferenceType.sale) &
              je.refId.equals(invoiceId) &
              je.isReversal.equals(false))
          ..orderBy([(o) => OrderingTerm.asc(o.createdAt)])
          ..limit(1))
        .getSingleOrNull();
    await postJournalEntry(
      db,
      refType: JournalReferenceType.sale,
      refId: invoiceId,
      entryDate: atMillis,
      description: 'إلغاء فاتورة بيع $invoiceNumber',
      isReversal: true,
      reversalOfEntryId: original?.id,
      lines: [
        JournalLineDraft(
            accountCode: SystemAccountCode.salesRevenue, debitMicros: totalMicros),
        if (drawerNetMicros > 0)
          JournalLineDraft(
              accountCode: SystemAccountCode.cash,
              creditMicros: drawerNetMicros),
        if (cardMicros > 0)
          JournalLineDraft(
              accountCode: SystemAccountCode.bank, creditMicros: cardMicros),
        if (creditMicros > 0)
          JournalLineDraft(
              accountCode: SystemAccountCode.accountsReceivable,
              creditMicros: creditMicros),
        JournalLineDraft(
            accountCode: SystemAccountCode.inventory, debitMicros: costMicros),
        JournalLineDraft(
            accountCode: SystemAccountCode.costOfGoodsSold,
            creditMicros: costMicros),
      ],
      createdBy: userId,
    );
  }

  // ── Expense & cash-box workflows (own their transaction) ───────────────

  /// Books the expense row + drawer/bank settlement + GL posting (§19, §30).
  ///
  /// Phase 9 primitive: `categoryCode` is a stable `expense_categories.code`
  /// (the legacy enum names `rent`/`utilities`/… are the seeded codes, so the
  /// enum-based [recordExpense] delegate keeps its historical GL mapping). The
  /// journal account comes from the category master (`5100` operating expenses
  /// fallback when the mapped account is missing from the chart). Cash
  /// settlements move the drawer (type `expense`, outflow) and credit Cash;
  /// card settlements credit Bank and never touch the drawer.
  Future<ExpenseRow> recordExpenseByCode(
    AppDatabase db, {
    required String categoryCode,
    required String description,
    required int amountMicros,
    required String userId,
    int? expenseDate,
    String? supplierId,
    String? notes,
    String? receiptPath,
    ExpensePaymentMethod paymentMethod = ExpensePaymentMethod.cash,
  }) async {
    await _permissions.requireUserPermission(db, userId, Perm.expensesCreate);
    if (amountMicros <= 0) {
      throw ValidationException('مبلغ المصروف يجب أن يكون موجباً');
    }
    if (description.trim().isEmpty) {
      throw ValidationException('وصف المصروف مطلوب');
    }
    final accountCode = await _expenseAccountCodeFor(db, categoryCode);
    return db.transaction(() async {
      final now = expenseDate ?? DateTime.now().millisecondsSinceEpoch;
      final expenseId = newId('exp');
      final number = await _nextExpenseNumber(db, now);
      await db.into(db.expenses).insert(
            ExpensesCompanion.insert(
              id: expenseId,
              amountMicros: amountMicros,
              category: categoryCode,
              description: description.trim(),
              expenseDate: now,
              supplierId:
                  supplierId != null ? Value(supplierId) : const Value(null),
              userId: userId,
              notes: notes != null ? Value(notes) : const Value(null),
              receiptPath:
                  receiptPath != null ? Value(receiptPath) : const Value(null),
              paymentMethod: Value(paymentMethod.name),
              expenseNumber: Value(number),
              createdAt: now,
              updatedAt: now,
            ),
          );
      if (paymentMethod == ExpensePaymentMethod.cash) {
        await postCashboxRow(
          db,
          type: CashboxTransactionType.expense,
          amountMicros: -amountMicros,
          refType: 'expense',
          refId: expenseId,
          userId: userId,
          note: 'مصروف: $description',
          atMillis: now,
        );
      }
      await postJournalEntry(
        db,
        refType: JournalReferenceType.expense,
        refId: expenseId,
        entryDate: now,
        description: 'مصروف: $description',
        lines: [
          JournalLineDraft(
              accountCode: accountCode, debitMicros: amountMicros),
          JournalLineDraft(
              accountCode: paymentMethod == ExpensePaymentMethod.card
                  ? SystemAccountCode.bank
                  : SystemAccountCode.cash,
              creditMicros: amountMicros),
        ],
        createdBy: userId,
      );
      await _audit.write(
        db,
        userId: userId,
        action: AuditAction.create,
        entityType: 'expense',
        entityId: expenseId,
        after: {
          'expense_number': number,
          'amount_micros': amountMicros,
          'category_code': categoryCode,
          'account_code': accountCode,
          'payment_method': paymentMethod.name,
        },
      );
      return (await (db.select(db.expenses)
            ..where((e) => e.id.equals(expenseId)))
            .getSingle());
    });
  }

  /// Enum-based convenience alias kept for Phase 7.5 compatibility: the
  /// persisted enum names *are* the seeded category codes, so delegation is
  /// exact (rent→5101, salaries→5102, other→5100) and existing caller tests
  /// keep their contract.
  Future<ExpenseRow> recordExpense(
    AppDatabase db, {
    required ExpenseCategory category,
    required String description,
    required int amountMicros,
    required String userId,
    int? expenseDate,
    String? supplierId,
    String? notes,
  }) {
    return recordExpenseByCode(
      db,
      categoryCode: category.name,
      description: description,
      amountMicros: amountMicros,
      userId: userId,
      expenseDate: expenseDate,
      supplierId: supplierId,
      notes: notes,
    );
  }

  /// Cancels a booked expense (§19 Phase 9): reverses the drawer row (cash
  /// payments flow back in as a positive `expense` row, satisfying the
  /// "exactly once" contract enforced by the `is_voided` guard), posts the
  /// mirror journal (Dr Cash/Bank, Cr the expense account) and flags the row.
  /// Requires `expenses.void` and a reason; the audit action is the stored
  /// `'void'`.
  Future<ExpenseRow> cancelExpense(
    AppDatabase db, {
    required String expenseId,
    required String reason,
    required String userId,
  }) async {
    await _permissions.requireUserPermission(db, userId, Perm.expensesVoid);
    if (reason.trim().isEmpty) {
      throw ValidationException('سبب إلغاء المصروف مطلوب');
    }
    final expense = await (db.select(db.expenses)
          ..where((e) => e.id.equals(expenseId)))
        .getSingleOrNull();
    if (expense == null) {
      throw NotFoundException('المصروف غير موجود: $expenseId');
    }
    if (expense.isVoided) {
      throw InvalidOperationException('المصروف ملغي بالفعل — لا يمكن إلغاؤه مرتين');
    }
    final method = _expenseMethod(expense.paymentMethod);
    final accountCode = await _expenseAccountCodeFor(db, expense.category);
    return db.transaction(() async {
      final now = DateTime.now().millisecondsSinceEpoch;
      if (method == ExpensePaymentMethod.cash) {
        await postCashboxRow(
          db,
          type: CashboxTransactionType.expense,
          amountMicros: expense.amountMicros,
          refType: 'expense',
          refId: expenseId,
          userId: userId,
          note: 'إلغاء مصروف: ${expense.description}',
          atMillis: now,
        );
      }
      await postJournalEntry(
        db,
        refType: JournalReferenceType.expense,
        refId: expenseId,
        entryDate: now,
        description: 'إلغاء مصروف: ${expense.description}',
        isReversal: true,
        lines: [
          JournalLineDraft(
              accountCode: method == ExpensePaymentMethod.card
                  ? SystemAccountCode.bank
                  : SystemAccountCode.cash,
              debitMicros: expense.amountMicros),
          JournalLineDraft(
              accountCode: accountCode, creditMicros: expense.amountMicros),
        ],
        createdBy: userId,
      );
      await (db.update(db.expenses)..where((e) => e.id.equals(expenseId)))
          .write(const ExpensesCompanion(isVoided: Value(true)));
      await _audit.write(
        db,
        userId: userId,
        action: AuditAction.voidOrder,
        entityType: 'expense',
        entityId: expenseId,
        before: {'is_voided': false},
        after: {
          'is_voided': true,
          'reason': reason.trim(),
          'reversed_amount_micros': expense.amountMicros,
          'payment_method': method.name,
        },
        note: 'إلغاء مصروف: ${expense.description}',
      );
      return (await (db.select(db.expenses)
            ..where((e) => e.id.equals(expenseId)))
            .getSingle());
    });
  }

  /// Resolves the GL expense account for a category code: the master table is
  /// the source of truth; pre-v7 databases (and the enum convenience alias)
  /// carry only the legacy category names, so a missing master row falls back
  /// to the historical §19 mapping (`rent`→5101, `salaries`→5102, other→5100).
  /// If the mapped account is missing from the chart, operating expenses (5100)
  /// absorbs the line.
  Future<String> _expenseAccountCodeFor(AppDatabase db, String code) async {
    String accountCode;
    final category = await (db.select(db.expenseCategories)
          ..where((c) => c.code.equals(code)))
        .getSingleOrNull();
    if (category != null) {
      accountCode = category.accountCode;
    } else {
      accountCode = switch (code) {
        'rent' => SystemAccountCode.rent,
        'salaries' => SystemAccountCode.salaries,
        _ => SystemAccountCode.operatingExpenses,
      };
    }
    final chart = await (db.select(db.accounts)
          ..where((a) => a.code.equals(accountCode)))
        .get();
    if (chart.isEmpty) return SystemAccountCode.operatingExpenses;
    return accountCode;
  }

  /// Printable expense reference `EXP-<seq>` where seq follows the table
  /// rowid (never reused: expenses are only ever voided, never deleted).
  Future<String> _nextExpenseNumber(AppDatabase db, int dateMillis) async {
    final row = await db
        .customSelect(
            'SELECT COALESCE(MAX(rowid), 0) + 1 AS n FROM expenses')
        .getSingle();
    final seq = row.read<int>('n');
    final year = DateTime.fromMillisecondsSinceEpoch(dateMillis).year;
    return 'EXP-$year-${seq.toString().padLeft(4, '0')}';
  }

  static ExpensePaymentMethod _expenseMethod(String? value) =>
      value == 'card' ? ExpensePaymentMethod.card : ExpensePaymentMethod.cash;

  /// Authorized drawer adjustment (±): requires `cashbox.operate` and a reason.
  /// The balancing GL side lands on the dedicated cash over/short expense
  /// account (1099) — the historical Capital stand-in is resolved (§18 audit).
  Future<CashboxTransactionRow> adjustCash(
    AppDatabase db, {
    required int amountMicros,
    required String reason,
    required String userId,
  }) async {
    await _permissions.requireUserPermission(db, userId, Perm.cashboxOperate);
    if (amountMicros == 0) {
      throw ValidationException('تسوية الصندوق لا يمكن أن تكون صفرية');
    }
    if (reason.trim().isEmpty) {
      throw ValidationException('سبب تسوية الصندوق مطلوب');
    }
    return db.transaction(() async {
      final now = DateTime.now().millisecondsSinceEpoch;
      await postCashboxRow(
        db,
        type: CashboxTransactionType.adjustment,
        amountMicros: amountMicros,
        refType: 'cashbox',
        userId: userId,
        note: 'تسوية الصندوق: ${reason.trim()}',
        atMillis: now,
      );
      await postJournalEntry(
        db,
        refType: JournalReferenceType.adjustment,
        refId: 'cash-adjust-${newId('adj')}',
        entryDate: now,
        description: 'تسوية الصندوق: ${reason.trim()}',
        lines: [
          if (amountMicros > 0)
            JournalLineDraft(
                accountCode: SystemAccountCode.cash, debitMicros: amountMicros),
          if (amountMicros > 0)
            JournalLineDraft(
                accountCode: SystemAccountCode.cashOverShort,
                creditMicros: amountMicros),
          if (amountMicros < 0)
            JournalLineDraft(
                accountCode: SystemAccountCode.cashOverShort,
                debitMicros: -amountMicros),
          if (amountMicros < 0)
            JournalLineDraft(
                accountCode: SystemAccountCode.cash,
                creditMicros: -amountMicros),
        ],
        createdBy: userId,
      );
      await _audit.write(
        db,
        userId: userId,
        action: AuditAction.update,
        entityType: 'cashbox',
        entityId: 'adjustment',
        after: {
          'amount_micros': amountMicros,
          'reason': reason.trim(),
        },
      );
      final row = await (db.select(db.cashboxTransactions)
            ..orderBy([(t) => OrderingTerm.desc(t.createdAt)])
            ..limit(1))
          .getSingle();
      return row;
    });
  }

  /// Customer balance sync helper (used by sale/return/void) ────────────

  Future<void> syncCustomerBalance(AppDatabase db, String customerId,
      {required int at}) {
    return CustomerDao(db).syncBalance(customerId, at: at);
  }

  // ── Purchase accounting (Phase 10) ─────────────────────────────────────

  /// Purchase posting: Dr Inventory, Cr Cash/Bank/AR per the settlement.
  /// Called from the purchase `receive` workflow inside its own transaction.
  Future<void> postPurchase(
    AppDatabase db, {
    required String invoiceId,
    required String invoiceNumber,
    required int inventoryMicros,
    required int paidCashMicros,
    required int paidCardMicros,
    required int amountPayableMicros,
    required String userId,
    required int atMillis,
  }) async {
    if (paidCashMicros + paidCardMicros + amountPayableMicros !=
        inventoryMicros) {
      throw ValidationException(
          'تسوية الشراء غير متوازنة: المدفوع + الآجل لا يغطي إجمالي الشراء');
    }
    await postJournalEntry(
      db,
      refType: JournalReferenceType.purchase,
      refId: invoiceId,
      entryDate: atMillis,
      description: 'فاتورة شراء $invoiceNumber',
      lines: [
        JournalLineDraft(
            accountCode: SystemAccountCode.inventory,
            debitMicros: inventoryMicros),
        if (paidCashMicros > 0)
          JournalLineDraft(
              accountCode: SystemAccountCode.cash,
              creditMicros: paidCashMicros),
        if (paidCardMicros > 0)
          JournalLineDraft(
              accountCode: SystemAccountCode.bank,
              creditMicros: paidCardMicros),
        if (amountPayableMicros > 0)
          JournalLineDraft(
              accountCode: SystemAccountCode.accountsPayable,
              creditMicros: amountPayableMicros),
      ],
      createdBy: userId,
    );
  }

  /// Purchase return: Dr AP/Cash/Bank, Cr Inventory. Called from the purchase
  /// return workflow inside its own transaction.
  Future<void> postPurchaseReturn(
    AppDatabase db, {
    required String returnId,
    required String returnNumber,
    required String invoiceNumber,
    required int inventoryMicros,
    required int refundCashMicros,
    required int refundCardMicros,
    required int apOffsetMicros,
    required String userId,
    required int atMillis,
  }) async {
    if (refundCashMicros + refundCardMicros + apOffsetMicros !=
        inventoryMicros) {
      throw ValidationException(
          'تسوية مرتجع الشراء غير متوازنة: المسترد + الدائن لا يغطي إجمالي الإرجاع');
    }
    await postJournalEntry(
      db,
      refType: JournalReferenceType.return_invoice,
      refId: returnId,
      entryDate: atMillis,
      description: 'مرتجع مشتريات $returnNumber على فاتورة $invoiceNumber',
      lines: [
        if (apOffsetMicros > 0)
          JournalLineDraft(
              accountCode: SystemAccountCode.accountsPayable,
              debitMicros: apOffsetMicros),
        if (refundCashMicros > 0)
          JournalLineDraft(
              accountCode: SystemAccountCode.cash,
              debitMicros: refundCashMicros),
        if (refundCardMicros > 0)
          JournalLineDraft(
              accountCode: SystemAccountCode.bank,
              debitMicros: refundCardMicros),
        JournalLineDraft(
            accountCode: SystemAccountCode.inventory,
            creditMicros: inventoryMicros),
      ],
      createdBy: userId,
    );
  }

  /// Cashbox manual deposit: Dr Cash (drawer) with a matching Cash-in/Cash-out
  /// offset. Deposits increase the drawer and mirror in the GL.
  Future<CashboxTransactionRow> postCashboxDeposit(
    AppDatabase db, {
    required int amountMicros,
    required String reason,
    required String userId,
    required int atMillis,
  }) =>
      _postCashboxManual(
        db,
        type: CashboxTransactionType.deposit,
        amountMicros: amountMicros,
        reason: reason,
        userId: userId,
        atMillis: atMillis,
        journalLines: [
          JournalLineDraft(
              accountCode: SystemAccountCode.cash,
              debitMicros: amountMicros),
          JournalLineDraft(
              accountCode: SystemAccountCode.cashOverShort,
              creditMicros: amountMicros),
        ],
        description: 'إيداع في الصندوق: $reason',
        refType: JournalReferenceType.cashbox,
      );

  /// Cashbox manual withdrawal: Cr Cash (drawer), offset against
  /// cash over/short (a cash-outgoing movement into the safe/bank).
  Future<CashboxTransactionRow> postCashboxWithdrawal(
    AppDatabase db, {
    required int amountMicros,
    required String reason,
    required String userId,
    required int atMillis,
  }) =>
      _postCashboxManual(
        db,
        type: CashboxTransactionType.withdraw,
        amountMicros: amountMicros,
        reason: reason,
        userId: userId,
        atMillis: atMillis,
        journalLines: [
          JournalLineDraft(
              accountCode: SystemAccountCode.cashOverShort,
              debitMicros: amountMicros),
          JournalLineDraft(
              accountCode: SystemAccountCode.cash,
              creditMicros: amountMicros),
        ],
        description: 'سحب من الصندوق: $reason',
        refType: JournalReferenceType.cashbox,
      );

  Future<CashboxTransactionRow> _postCashboxManual(
    AppDatabase db, {
    required CashboxTransactionType type,
    required int amountMicros,
    required String reason,
    required String userId,
    required int atMillis,
    required List<JournalLineDraft> journalLines,
    required String description,
    required JournalReferenceType refType,
  }) async {
    final signed = type == CashboxTransactionType.withdraw
        ? -amountMicros
        : amountMicros;
    final refId = '${type.name}-$atMillis-${newId('cbx')}';
    return db.transaction(() async {
      await postCashboxRow(
        db,
        type: type,
        amountMicros: signed,
        refType: 'cashbox',
        refId: refId,
        userId: userId,
        note: reason.trim(),
        atMillis: atMillis,
      );
      await postJournalEntry(
        db,
        refType: refType,
        refId: refId,
        entryDate: atMillis,
        description: description,
        lines: journalLines,
        createdBy: userId,
      );
      final row = await (db.select(db.cashboxTransactions)
            ..orderBy([(t) => OrderingTerm.desc(t.createdAt)])
            ..limit(1))
          .getSingle();
      return row;
    });
  }
}