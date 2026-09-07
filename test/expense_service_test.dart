
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
import 'package:pharmacy_pos/shared/models/enums.dart';

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
  late PermissionService perms;
  late AuditService audit;

  late ListExpensesUseCase listExpenses;
  late ListExpenseCategoriesUseCase listCategories;
  late CreateExpenseUseCase createExpense;
  late UpdateExpenseUseCase updateExpense;
  late CancelExpenseUseCase cancelExpense;
  late CreateExpenseCategoryUseCase createCategory;
  late UpdateExpenseCategoryUseCase updateCategory;

  setUp(() {
    db = newDatabase();
    repo = ExpenseRepositoryImpl(
        db, const _FakeReceiptStorage(), const FinancialPostingService());
    perms = const PermissionService();
    audit = const AuditService();

    listExpenses = ListExpensesUseCase(repo, perms);
    listCategories = ListExpenseCategoriesUseCase(repo, perms);
    createExpense = CreateExpenseUseCase(repo, perms);
    updateExpense = UpdateExpenseUseCase(repo, perms, audit);
    cancelExpense = CancelExpenseUseCase(repo, perms);
    createCategory = CreateExpenseCategoryUseCase(repo, perms, audit);
    updateCategory = UpdateExpenseCategoryUseCase(repo, perms, audit);
  });

  tearDown(() async => db.close());

  test('seeded categories include rent, utilities, salaries', () async {
    final cats = await listCategories(actingRoleId: 'role_admin');
    final codes = cats.map((c) => c.code).toSet();
    expect(codes, containsAll({'rent', 'utilities', 'salaries', 'other'}));
    expect(cats.every((c) => c.isSystem), isTrue);
  });

  test('admin records a cash expense (rent) successfully', () async {
    final row = await createExpense(
      ExpenseDraft(
          categoryCode: 'rent',
          description: 'rent',
          amountMicros: 50000,
          paymentMethod: ExpensePaymentMethod.cash),
      actingUserId: 'user_admin',
      actingRoleId: 'role_admin',
    );
    expect(row.category, 'rent');
    expect(row.amountMicros, 50000);
    expect(row.expenseNumber, startsWith('EXP-'));
    expect(row.isVoided, isFalse);
  });

  test('rejects expense with zero amount', () async {
    await expectLater(
      createExpense(
        ExpenseDraft(
            categoryCode: 'rent', description: 'test', amountMicros: 0),
        actingUserId: 'user_admin',
        actingRoleId: 'role_admin',
      ),
      throwsA(isA<ValidationException>()),
    );
  });

  test('rejects expense with missing description', () async {
    await expectLater(
      createExpense(
        ExpenseDraft(
            categoryCode: 'rent', description: '   ', amountMicros: 10000),
        actingUserId: 'user_admin',
        actingRoleId: 'role_admin',
      ),
      throwsA(isA<ValidationException>()),
    );
  });

  test('rejects expense with unknown category code', () async {
    await expectLater(
      createExpense(
        ExpenseDraft(
            categoryCode: 'nonexistent', description: 'x', amountMicros: 10000),
        actingUserId: 'user_admin',
        actingRoleId: 'role_admin',
      ),
      throwsA(isA<ValidationException>()),
    );
  });

  test('rejects expense without actingUserId', () async {
    await expectLater(
      createExpense(
        ExpenseDraft(
            categoryCode: 'rent', description: 'test', amountMicros: 10000),
        actingRoleId: 'role_admin',
      ),
      throwsA(isA<UnauthorizedException>()),
    );
  });

  test('admin edits description on a non-voided expense', () async {
    final created = await createExpense(
      ExpenseDraft(
          categoryCode: 'rent', description: 'old', amountMicros: 10000),
      actingUserId: 'user_admin',
      actingRoleId: 'role_admin',
    );
    final updated = await updateExpense(
      created.id,
      ExpenseEditDraft(description: 'new desc', notes: 'note'),
      actingUserId: 'user_admin',
      actingRoleId: 'role_admin',
    );
    expect(updated.description, 'new desc');
    expect(updated.notes, 'note');
  });

  test('cannot edit a voided expense', () async {
    final created = await createExpense(
      ExpenseDraft(
          categoryCode: 'rent', description: 'to void', amountMicros: 5000),
      actingUserId: 'user_admin',
      actingRoleId: 'role_admin',
    );
    await cancelExpense(created.id,
        reason: 'test void',
        actingUserId: 'user_admin',
        actingRoleId: 'role_admin');
    await expectLater(
      updateExpense(
        created.id,
        ExpenseEditDraft(description: 'tried'),
        actingUserId: 'user_admin',
        actingRoleId: 'role_admin',
      ),
      throwsA(isA<InvalidOperationException>()),
    );
  });

  test('void reverses the expense', () async {
    final created = await createExpense(
      ExpenseDraft(
          categoryCode: 'rent',
          description: 'cancel test',
          amountMicros: 8000),
      actingUserId: 'user_admin',
      actingRoleId: 'role_admin',
    );
    expect(created.isVoided, isFalse);
    final voided = await cancelExpense(created.id,
        reason: 'wrong entry',
        actingUserId: 'user_admin',
        actingRoleId: 'role_admin');
    expect(voided.isVoided, isTrue);
  });

  test('creates a user-defined category', () async {
    final cat = await createCategory(
      ExpenseCategoryDraft(
          code: 'training', name: 'training', accountCode: '5100'),
      actingUserId: 'user_admin',
      actingRoleId: 'role_admin',
    );
    expect(cat.code, 'training');
    expect(cat.isSystem, isFalse);
  });

  test('rejects duplicate category code', () async {
    await createCategory(
      ExpenseCategoryDraft(
          code: 'training', name: 'training', accountCode: '5100'),
      actingUserId: 'user_admin',
      actingRoleId: 'role_admin',
    );
    await expectLater(
      createCategory(
        ExpenseCategoryDraft(
            code: 'training', name: 'dup', accountCode: '5100'),
        actingUserId: 'user_admin',
        actingRoleId: 'role_admin',
      ),
      throwsA(isA<ValidationException>()),
    );
  });

  test('rejects invalid category code pattern', () async {
    await expectLater(
      createCategory(
        ExpenseCategoryDraft(
            code: 'UPPER_CASE', name: 'bad', accountCode: '5100'),
        actingUserId: 'user_admin',
        actingRoleId: 'role_admin',
      ),
      throwsA(isA<ValidationException>()),
    );
  });

  test('cannot edit a system category', () async {
    final systemCat = (await listCategories(actingRoleId: 'role_admin'))
        .firstWhere((c) => c.code == 'rent');
    await expectLater(
      updateCategory(
        systemCat.id,
        ExpenseCategoryDraft(
            code: 'rent', name: 'renamed', accountCode: '5101'),
        actingUserId: 'user_admin',
        actingRoleId: 'role_admin',
      ),
      throwsA(isA<InvalidOperationException>()),
    );
  });

  test('lists expenses with page 1', () async {
    for (var i = 0; i < 3; i++) {
      await createExpense(
        ExpenseDraft(
            categoryCode: 'rent',
            description: 'item $i',
            amountMicros: 1000 * (i + 1)),
        actingUserId: 'user_admin',
        actingRoleId: 'role_admin',
      );
    }
    final result = await listExpenses(
      const PageRequest(page: 1, pageSize: 10),
      actingRoleId: 'role_admin',
    );
    expect(result.items, hasLength(3));
    expect(result.total, 3);
  });

  test('viewer cannot record expense', () async {
    await expectLater(
      createExpense(
        ExpenseDraft(
            categoryCode: 'rent', description: 'nope', amountMicros: 1000),
        actingUserId: 'user_admin',
        actingRoleId: 'role_viewer',
      ),
      throwsA(isA<UnauthorizedException>()),
    );
  });
}
