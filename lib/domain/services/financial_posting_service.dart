import 'package:drift/drift.dart';

import '../../core/constants/permission_codes.dart';
import '../../core/errors/exceptions.dart';
import '../../core/util/ids.dart';
import '../../data/daos/customer_dao.dart';
import '../../shared/database/app_database.dart';
import '../../shared/models/enums.dart';
import 'audit_service.dart';
import 'permission_service.dart';

/// System chart-of-account codes (§4.22) addressed by the posting engine. The
/// engine maps business events to these seeded codes; UI code never addresses
/// accounts directly.
class SystemAccountCode {
  const SystemAccountCode._();

  static const String cash = '1000';
  static const String bank = '1001';
  static const String accountsReceivable = '1100';
  static const String inventory = '1200';
  static const String accountsPayable = '2000';
  static const String capital = '3000';
  static const String salesRevenue = '4000';
  static const String salesReturns = '4001';
  static const String costOfGoodsSold = '5000';
  static const String operatingExpenses = '5100';
  static const String rent = '5101';
  static const String salaries = '5102';
}

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
  }) async {
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
  Future<void> postCustomerRefund(
    AppDatabase db, {
    required String paymentId,
    required String paymentNumber,
    required int amountMicros,
    required int cashMicros,
    required int cardMicros,
    required String userId,
    required int atMillis,
  }) async {
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
  /// the money back out of the drawer.
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
    await postJournalEntry(
      db,
      refType: JournalReferenceType.sale,
      refId: invoiceId,
      entryDate: atMillis,
      description: 'إلغاء فاتورة بيع $invoiceNumber',
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

  /// Books the expense row + drawer outflow + GL posting (§19, §30).
  Future<ExpenseRow> recordExpense(
    AppDatabase db, {
    required ExpenseCategory category,
    required String description,
    required int amountMicros,
    required String userId,
    int? expenseDate,
    String? supplierId,
    String? notes,
  }) async {
    await _permissions.requireUserPermission(db, userId, Perm.expensesCreate);
    if (amountMicros <= 0) {
      throw ValidationException('مبلغ المصروف يجب أن يكون موجباً');
    }
    if (description.trim().isEmpty) {
      throw ValidationException('وصف المصروف مطلوب');
    }
    return db.transaction(() async {
      final now = expenseDate ?? DateTime.now().millisecondsSinceEpoch;
      final expenseId = newId('exp');
      await db.into(db.expenses).insert(
            ExpensesCompanion.insert(
              id: expenseId,
              amountMicros: amountMicros,
              category: category,
              description: description.trim(),
              expenseDate: now,
              supplierId:
                  supplierId != null ? Value(supplierId) : const Value(null),
              userId: userId,
              notes: notes != null ? Value(notes) : const Value(null),
              createdAt: now,
              updatedAt: now,
            ),
          );
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
      await postJournalEntry(
        db,
        refType: JournalReferenceType.expense,
        refId: expenseId,
        entryDate: now,
        description: 'مصروف: $description',
        lines: [
          JournalLineDraft(
              accountCode: _expenseAccountCode(category),
              debitMicros: amountMicros),
          JournalLineDraft(
              accountCode: SystemAccountCode.cash, creditMicros: amountMicros),
        ],
        createdBy: userId,
      );
      await _audit.write(
        db,
        userId: userId,
        action: AuditAction.create,
        entityType: 'expense',
        entityId: expenseId,
        after: {'amount_micros': amountMicros, 'category': category.name},
      );
      return (await (db.select(db.expenses)
            ..where((e) => e.id.equals(expenseId)))
            .getSingle());
    });
  }

  String _expenseAccountCode(ExpenseCategory category) => switch (category) {
        ExpenseCategory.rent => SystemAccountCode.rent,
        ExpenseCategory.salaries => SystemAccountCode.salaries,
        _ => SystemAccountCode.operatingExpenses,
      };

  /// Authorized drawer adjustment (±): requires `cashbox.operate` and a reason.
  /// The balancing GL side lands on Capital until a dedicated cash-difference
  /// account is added with the accounting UI (documented limitation).
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
        entryDate: now,
        description: 'تسوية الصندوق: ${reason.trim()}',
        lines: [
          if (amountMicros > 0)
            JournalLineDraft(
                accountCode: SystemAccountCode.cash, debitMicros: amountMicros),
          if (amountMicros > 0)
            JournalLineDraft(
                accountCode: SystemAccountCode.capital,
                creditMicros: amountMicros),
          if (amountMicros < 0)
            JournalLineDraft(
                accountCode: SystemAccountCode.capital,
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

  // ── Customer balance sync helper (used by sale/return/void) ────────────

  Future<void> syncCustomerBalance(AppDatabase db, String customerId,
      {required int at}) {
    return CustomerDao(db).syncBalance(customerId, at: at);
  }
}