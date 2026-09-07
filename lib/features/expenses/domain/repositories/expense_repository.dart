import '../../../../core/data_grid/page_request.dart';
import '../../../../shared/database/app_database.dart';
import '../../../../shared/models/enums.dart';
import '../entities/expense_list_item.dart';

/// Input draft for recording a new expense (§4.20). The category is a stable
/// `expense_categories.code`; the engine resolves the GL account from the
/// master and books drawer (cash) / bank (card) + balanced journal atomically.
class ExpenseDraft {
  const ExpenseDraft({
    required this.categoryCode,
    required this.description,
    required this.amountMicros,
    this.paymentMethod = ExpensePaymentMethod.cash,
    this.date,
    this.supplierId,
    this.notes,
    this.receiptSourcePath,
  });

  final String categoryCode;
  final String description;
  final int amountMicros;
  final ExpensePaymentMethod paymentMethod;

  /// Booking date override (millis); defaults to now when null.
  final int? date;
  final String? supplierId;
  final String? notes;

  /// Absolute path of a picked receipt photo to copy into managed storage.
  final String? receiptSourcePath;
}

/// The only editable expense fields (§4.20): description and notes. Amount,
/// category, payment method and date are immutable after posting.
class ExpenseEditDraft {
  const ExpenseEditDraft({this.description, this.notes});

  final String? description;
  final String? notes;
}

/// Draft for creating/editing an expense category master row.
class ExpenseCategoryDraft {
  const ExpenseCategoryDraft({
    required this.code,
    required this.name,
    this.nameEn,
    required this.accountCode,
    this.isActive = true,
  });

  final String code;
  final String name;
  final String? nameEn;
  final String accountCode;
  final bool isActive;
}

/// Expense feature repository: read side is the paged DAO; the write side
/// delegates all financial posting to `FinancialPostingService` so the GL,
/// drawer and audit stay single-source (§19, §30).
abstract interface class ExpenseRepository {
  AppDatabase get database;

  /// Paged, DB-side-filtered expense journal (newest first) with joined
  /// category / operator / supplier display names (`expenses.view`).
  Future<PageResult<ExpenseListItem>> listExpenses({
    required PageRequest page,
    String? categoryCode,
    ExpensePaymentMethod? paymentMethod,
    bool? isVoided,
    int? fromMillis,
    int? toMillis,
  });

  /// Category master; system rows are immutable. `activeOnly` hides
  /// deactivated categories from the booking form.
  Future<List<ExpenseCategoryRow>> listCategories({bool activeOnly = true});

  Future<ExpenseCategoryRow?> findCategory(String code);

  /// Books the expense + settlement + GL atomically (`expenses.create`).
  Future<ExpenseRow> record(ExpenseDraft draft, {required String userId});

  /// Edits description/notes of a non-voided expense (`expenses.edit`).
  Future<ExpenseRow> updateEditable(
    String expenseId,
    ExpenseEditDraft draft, {
    required String userId,
  });

  /// Void-cancels an expense, reversing drawer + GL (`expenses.void`, exactly
  /// once — the `is_voided` flag guards against double reversal).
  Future<ExpenseRow> cancel(
    String expenseId, {
    required String reason,
    required String userId,
  });

  /// Copies a receipt file into managed storage and returns the stored path.
  Future<String> attachReceipt(
    String expenseId, {
    required String sourcePath,
    required String userId,
  });

  /// Deletes the stored receipt file and clears the reference.
  Future<void> removeReceipt(String expenseId, {required String userId});

  Future<ExpenseCategoryRow> createCategory(
    ExpenseCategoryDraft draft, {
    required String userId,
  });

  /// System categories are immutable (rejected by the use case / storage).
  Future<ExpenseCategoryRow> updateCategory(
    String categoryId,
    ExpenseCategoryDraft draft, {
    required String userId,
  });

  Future<void> setCategoryActive(
    String categoryId,
    bool active, {
    required String userId,
  });
}