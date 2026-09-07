
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:pharmacy_pos/core/data_grid/page_request.dart';
import 'package:pharmacy_pos/core/errors/exceptions.dart';
import 'package:pharmacy_pos/domain/services/audit_service.dart';
import 'package:pharmacy_pos/domain/services/financial_posting_service.dart';
import 'package:pharmacy_pos/domain/services/permission_service.dart';
import 'package:pharmacy_pos/features/expenses/data/expense_repository_impl.dart';
import 'package:pharmacy_pos/features/expenses/domain/repositories/expense_repository.dart';
import 'package:pharmacy_pos/features/expenses/domain/services/receipt_storage.dart';
import 'package:pharmacy_pos/features/expenses/domain/usecases/expenses_use_cases.dart';
import 'package:pharmacy_pos/shared/database/app_database.dart';

import 'helpers.dart';

class _FakeReceiptStorage implements ReceiptStorage {
  const _FakeReceiptStorage();
  @override
  Future<String> save(String sourcePath) async => '/fake/$sourcePath';
  @override
  Future<void> delete(String storedPath) async {}
}

void main() {
  late AppDatabase db;
  late ExpenseRepository repo;
  late ListExpensesUseCase listExpenses;
  late ListExpenseCategoriesUseCase listCategories;
  late CreateExpenseUseCase createExpense;
  late UpdateExpenseUseCase updateExpense;
  late CancelExpenseUseCase cancelExpense;
  late CreateExpenseCategoryUseCase createCategory;
  late UpdateExpenseCategoryUseCase updateCategory;
  late SetExpenseCategoryActiveUseCase setCategoryActive;

  setUp(() {
    db = newDatabase();
    repo = ExpenseRepositoryImpl(
        db, const _FakeReceiptStorage(), const FinancialPostingService());
    final perms = const PermissionService();
    final audit = const AuditService();
    listExpenses = ListExpensesUseCase(repo, perms);
    listCategories = ListExpenseCategoriesUseCase(repo, perms);
    createExpense = CreateExpenseUseCase(repo, perms);
    updateExpense = UpdateExpenseUseCase(repo, perms, audit);
    cancelExpense = CancelExpenseUseCase(repo, perms);
    createCategory = CreateExpenseCategoryUseCase(repo, perms, audit);
    updateCategory = UpdateExpenseCategoryUseCase(repo, perms, audit);
    setCategoryActive =
        SetExpenseCategoryActiveUseCase(repo, perms, audit);
  });

  tearDown(() async => db.close());

  test('viewer can list expenses and categories', () async {
    final expenses =
        await listExpenses(const PageRequest(page: 1, pageSize: 10), actingRoleId: 'role_viewer');
    expect(expenses.items, isEmpty);
    final cats = await listCategories(actingRoleId: 'role_viewer');
    expect(cats, isNotEmpty);
  });

  test('viewer cannot record expense', () async {
    await expectLater(
      createExpense(
        ExpenseDraft(categoryCode: 'rent', description: 'no', amountMicros: 1000),
        actingUserId: 'user_admin',
        actingRoleId: 'role_viewer',
      ),
      throwsA(isA<UnauthorizedException>()),
    );
  });

  test('viewer cannot edit expense', () async {
    await expectLater(
      updateExpense('fake_id', ExpenseEditDraft(description: 'no'),
          actingUserId: 'user_admin', actingRoleId: 'role_viewer'),
      throwsA(isA<UnauthorizedException>()),
    );
  });

  test('viewer cannot void expense', () async {
    await expectLater(
      cancelExpense('fake_id', reason: 'no',
          actingUserId: 'user_admin', actingRoleId: 'role_viewer'),
      throwsA(isA<UnauthorizedException>()),
    );
  });

  test('viewer cannot create category', () async {
    await expectLater(
      createCategory(
        ExpenseCategoryDraft(code: 'new', name: 'new', accountCode: '5100'),
        actingUserId: 'user_admin',
        actingRoleId: 'role_viewer',
      ),
      throwsA(isA<UnauthorizedException>()),
    );
  });

  test('missing actingRoleId is rejected', () async {
    await expectLater(
      createExpense(
        ExpenseDraft(categoryCode: 'rent', description: 'no role', amountMicros: 1000),
        actingUserId: 'user_admin',
      ),
      throwsA(isA<UnauthorizedException>()),
    );
  });

  test('admin can do all operations', () async {
    final row = await createExpense(
      ExpenseDraft(categoryCode: 'rent', description: 'admin', amountMicros: 1000),
      actingUserId: 'user_admin',
      actingRoleId: 'role_admin',
    );
    await updateExpense(row.id, ExpenseEditDraft(description: 'updated'),
        actingUserId: 'user_admin', actingRoleId: 'role_admin');
    await cancelExpense(row.id, reason: 'test',
        actingUserId: 'user_admin', actingRoleId: 'role_admin');
    final cat = await createCategory(
      ExpenseCategoryDraft(code: 'admin_cat', name: 'Admin cat', accountCode: '5100'),
      actingUserId: 'user_admin',
      actingRoleId: 'role_admin',
    );
    await updateCategory(
        cat.id,
        ExpenseCategoryDraft(
            code: 'admin_cat', name: 'renamed', accountCode: '5100'),
        actingUserId: 'user_admin',
        actingRoleId: 'role_admin');
    await setCategoryActive(cat.id, false,
        actingUserId: 'user_admin', actingRoleId: 'role_admin');
  });
}
