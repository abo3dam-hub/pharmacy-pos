import 'package:drift/drift.dart';

import '../../../core/data_grid/page_request.dart';
import '../../../core/errors/exceptions.dart';
import '../../../core/util/ids.dart';
import '../../../domain/services/financial_posting_service.dart';
import '../../../shared/database/app_database.dart';
import '../../../shared/models/enums.dart';
import '../domain/entities/expense_list_item.dart';
import '../domain/repositories/expense_repository.dart';
import '../domain/services/receipt_storage.dart';
import 'expense_dao.dart';

/// Phase 9 data layer: expenses over the existing posting engine (record /
/// cancel book GL + drawer atomically) plus the paged read DAO and the
/// category master. Money stays integer micro-units throughout.
class ExpenseRepositoryImpl implements ExpenseRepository {
  ExpenseRepositoryImpl(this._db, this._storage, this._posting);

  final AppDatabase _db;
  final ReceiptStorage _storage;
  final FinancialPostingService _posting;

  ExpenseDao get _dao => ExpenseDao(_db);

  @override
  AppDatabase get database => _db;

  @override
  Future<PageResult<ExpenseListItem>> listExpenses({
    required PageRequest page,
    String? categoryCode,
    ExpensePaymentMethod? paymentMethod,
    bool? isVoided,
    int? fromMillis,
    int? toMillis,
  }) =>
      _dao.listExpenses(
        page: page,
        categoryCode: categoryCode,
        paymentMethod: paymentMethod,
        isVoided: isVoided,
        fromMillis: fromMillis,
        toMillis: toMillis,
      );

  @override
  Future<List<ExpenseCategoryRow>> listCategories({bool activeOnly = true}) async {
    final query = _db.select(_db.expenseCategories)
      ..orderBy([(c) => OrderingTerm.asc(c.name)]);
    if (activeOnly) {
      query.where((c) => c.isActive.equals(true));
    }
    return query.get();
  }

  @override
  Future<ExpenseCategoryRow?> findCategory(String code) async =>
      (_db.select(_db.expenseCategories)..where((c) => c.code.equals(code)))
          .getSingleOrNull();

  @override
  Future<ExpenseRow> record(ExpenseDraft draft, {required String userId}) async {
    final String? receiptPath = draft.receiptSourcePath == null
        ? null
        : await _storage.save(draft.receiptSourcePath!);
    return _posting.recordExpenseByCode(
      _db,
      categoryCode: draft.categoryCode,
      description: draft.description,
      amountMicros: draft.amountMicros,
      userId: userId,
      expenseDate: draft.date,
      supplierId: draft.supplierId,
      notes: draft.notes,
      receiptPath: receiptPath,
      paymentMethod: draft.paymentMethod,
    );
  }

  @override
  Future<ExpenseRow> updateEditable(
    String expenseId,
    ExpenseEditDraft draft, {
    required String userId,
  }) async {
    final existing = await _rowOrThrow(expenseId);
    if (existing.isVoided) {
      throw InvalidOperationException('لا يمكن تعديل مصروف ملغي');
    }
    final now = DateTime.now().millisecondsSinceEpoch;
    await (_db.update(_db.expenses)..where((e) => e.id.equals(expenseId)))
        .write(ExpensesCompanion(
          description: draft.description == null
              ? const Value.absent()
              : Value(draft.description!.trim()),
          notes: draft.notes == null
              ? const Value.absent()
              : Value(draft.notes!.trim().isEmpty ? null : draft.notes!.trim()),
          updatedAt: Value(now),
        ));
    return _rowOrThrow(expenseId);
  }

  @override
  Future<ExpenseRow> cancel(
    String expenseId, {
    required String reason,
    required String userId,
  }) =>
      _posting.cancelExpense(_db, expenseId: expenseId, reason: reason, userId: userId);

  @override
  Future<String> attachReceipt(
    String expenseId, {
    required String sourcePath,
    required String userId,
  }) async {
    final existing = await _rowOrThrow(expenseId);
    if (existing.isVoided) {
      throw InvalidOperationException('لا يمكن إرفاق مقبوض لمصروف ملغي');
    }
    final stored = await _storage.save(sourcePath);
    final now = DateTime.now().millisecondsSinceEpoch;
    await (_db.update(_db.expenses)..where((e) => e.id.equals(expenseId)))
        .write(ExpensesCompanion(
          receiptPath: Value(stored),
          updatedAt: Value(now),
        ));
    return stored;
  }

  @override
  Future<void> removeReceipt(String expenseId, {required String userId}) async {
    final existing = await _rowOrThrow(expenseId);
    if (existing.receiptPath != null) {
      await _storage.delete(existing.receiptPath!);
    }
    final now = DateTime.now().millisecondsSinceEpoch;
    await (_db.update(_db.expenses)..where((e) => e.id.equals(expenseId)))
        .write(ExpensesCompanion(
          receiptPath: const Value(null),
          updatedAt: Value(now),
        ));
  }

  @override
  Future<ExpenseCategoryRow> createCategory(
    ExpenseCategoryDraft draft, {
    required String userId,
  }) async {
    final now = DateTime.now().millisecondsSinceEpoch;
    await _db.into(_db.expenseCategories).insert(
          ExpenseCategoriesCompanion.insert(
            id: newId('expcat'),
            code: draft.code,
            name: draft.name,
            nameEn: draft.nameEn != null ? Value(draft.nameEn) : const Value(null),
            accountCode: draft.accountCode,
            isActive: Value(draft.isActive),
            isSystem: const Value(false),
            createdAt: now,
            updatedAt: now,
          ),
        );
    return (await _findCategoryByIdOrThrow(draft.code));
  }

  @override
  Future<ExpenseCategoryRow> updateCategory(
    String categoryId,
    ExpenseCategoryDraft draft, {
    required String userId,
  }) async {
    final existing = await _categoryOrThrow(categoryId);
    if (existing.isSystem) {
      throw InvalidOperationException('فئة النظام لا يمكن تعديلها');
    }
    final now = DateTime.now().millisecondsSinceEpoch;
    await (_db.update(_db.expenseCategories)
          ..where((c) => c.id.equals(categoryId)))
        .write(ExpenseCategoriesCompanion(
          name: Value(draft.name),
          nameEn: Value(draft.nameEn),
          accountCode: Value(draft.accountCode),
          isActive: Value(draft.isActive),
          updatedAt: Value(now),
        ));
    return _categoryOrThrow(categoryId);
  }

  @override
  Future<void> setCategoryActive(
    String categoryId,
    bool active, {
    required String userId,
  }) async {
    final existing = await _categoryOrThrow(categoryId);
    if (existing.isSystem) {
      throw InvalidOperationException('فئة النظام لا يمكن تعطيلها');
    }
    final now = DateTime.now().millisecondsSinceEpoch;
    await (_db.update(_db.expenseCategories)
          ..where((c) => c.id.equals(categoryId)))
        .write(ExpenseCategoriesCompanion(isActive: Value(active), updatedAt: Value(now)));
  }

  Future<ExpenseRow> _rowOrThrow(String id) async {
    final row = await (_db.select(_db.expenses)..where((e) => e.id.equals(id)))
        .getSingleOrNull();
    if (row == null) {
      throw NotFoundException('المصروف غير موجود: $id');
    }
    return row;
  }

  Future<ExpenseCategoryRow> _findCategoryByIdOrThrow(String code) async {
    final row = await findCategory(code);
    if (row == null) {
      throw NotFoundException('فئة المصروف غير موجودة: $code');
    }
    return row;
  }

  Future<ExpenseCategoryRow> _categoryOrThrow(String id) async {
    final row = await (_db.select(_db.expenseCategories)
          ..where((c) => c.id.equals(id)))
        .getSingleOrNull();
    if (row == null) {
      throw NotFoundException('فئة المصروف غير موجودة: $id');
    }
    return row;
  }
}