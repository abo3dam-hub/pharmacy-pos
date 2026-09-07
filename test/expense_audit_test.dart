
library;

import 'package:flutter_test/flutter_test.dart';
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
  late CreateExpenseUseCase createUseCase;
  late UpdateExpenseUseCase updateUseCase;
  late CancelExpenseUseCase cancelUseCase;
  late AttachReceiptUseCase attachUseCase;
  late CreateExpenseCategoryUseCase createCatUseCase;
  late SetExpenseCategoryActiveUseCase setCatActive;

  Future<int> expenseAuditCount() async {
    final rows = await (db.select(db.auditLogs)).get();
    return rows
        .where((a) =>
            a.entityType == 'expense' ||
            a.entityType == 'expense_category')
        .length;
  }

  setUp(() {
    db = newDatabase();
    repo = ExpenseRepositoryImpl(
        db, const _FakeReceiptStorage(), const FinancialPostingService());
    final perms = const PermissionService();
    final audit = const AuditService();
    createUseCase = CreateExpenseUseCase(repo, perms);
    updateUseCase = UpdateExpenseUseCase(repo, perms, audit);
    cancelUseCase = CancelExpenseUseCase(repo, perms);
    attachUseCase = AttachReceiptUseCase(repo, perms, audit);
    createCatUseCase = CreateExpenseCategoryUseCase(repo, perms, audit);
    setCatActive = SetExpenseCategoryActiveUseCase(repo, perms, audit);
  });

  tearDown(() async => db.close());

  test('create expense is audited', () async {
    final row = await createUseCase(
      ExpenseDraft(
          categoryCode: 'rent', description: 'audit', amountMicros: 5000),
      actingUserId: 'user_admin',
      actingRoleId: 'role_admin',
    );
    final logs = await (db.select(db.auditLogs)
          ..where((a) => a.entityId.equals(row.id)))
        .get();
    expect(logs, isNotEmpty);
  });

  test('edit expense writes an audit row', () async {
    final row = await createUseCase(
      ExpenseDraft(
          categoryCode: 'rent', description: 'before', amountMicros: 1000),
      actingUserId: 'user_admin',
      actingRoleId: 'role_admin',
    );
    final before = await expenseAuditCount();
    await updateUseCase(row.id, ExpenseEditDraft(description: 'after'),
        actingUserId: 'user_admin', actingRoleId: 'role_admin');
    final after = await expenseAuditCount();
    expect(after, greaterThan(before));
  });

  test('void expense writes an audit row', () async {
    final row = await createUseCase(
      ExpenseDraft(
          categoryCode: 'rent', description: 'to void', amountMicros: 2000),
      actingUserId: 'user_admin',
      actingRoleId: 'role_admin',
    );
    final before = await expenseAuditCount();
    await cancelUseCase(row.id, reason: 'void audit',
        actingUserId: 'user_admin', actingRoleId: 'role_admin');
    final after = await expenseAuditCount();
    expect(after, greaterThan(before));
  });

  test('attach receipt writes an audit row', () async {
    final row = await createUseCase(
      ExpenseDraft(
          categoryCode: 'rent', description: 'receipt', amountMicros: 3000),
      actingUserId: 'user_admin',
      actingRoleId: 'role_admin',
    );
    final before = await expenseAuditCount();
    await attachUseCase(row.id, sourcePath: '/tmp/r.jpg',
        actingUserId: 'user_admin', actingRoleId: 'role_admin');
    final after = await expenseAuditCount();
    expect(after, greaterThan(before));
  });

  test('create category is audited as expense_category', () async {
    final cat = await createCatUseCase(
      ExpenseCategoryDraft(
          code: 'audited_cat', name: 'audited', accountCode: '5100'),
      actingUserId: 'user_admin',
      actingRoleId: 'role_admin',
    );
    final logs = await (db.select(db.auditLogs)
          ..where((a) => a.entityId.equals(cat.id)))
        .get();
    expect(logs, hasLength(1));
    expect(logs.first.entityType, 'expense_category');
  });

  test('toggle category active writes an audit row', () async {
    final cat = await createCatUseCase(
      ExpenseCategoryDraft(
          code: 'toggle_cat', name: 'toggle', accountCode: '5100'),
      actingUserId: 'user_admin',
      actingRoleId: 'role_admin',
    );
    final before = await expenseAuditCount();
    await setCatActive(cat.id, false,
        actingUserId: 'user_admin', actingRoleId: 'role_admin');
    final after = await expenseAuditCount();
    expect(after, greaterThan(before));
  });

  test('system category cannot be deactivated', () async {
    final cats = await _allCategories(repo);
    final system = cats.firstWhere((c) => c.code == 'rent');
    await expectLater(
      setCatActive(system.id, false,
          actingUserId: 'user_admin', actingRoleId: 'role_admin'),
      throwsA(isA<InvalidOperationException>()),
    );
  });
}

Future<List<ExpenseCategoryRow>> _allCategories(ExpenseRepository repo) async {
  final perms = const PermissionService();
  final uc = ListExpenseCategoriesUseCase(repo, perms);
  return uc(activeOnly: false, actingRoleId: 'role_admin');
}
