
library;

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:pharmacy_pos/core/errors/exceptions.dart';
import 'package:pharmacy_pos/domain/services/financial_posting_service.dart';
import 'package:pharmacy_pos/domain/services/permission_service.dart';
import 'package:pharmacy_pos/domain/services/audit_service.dart';
import 'package:pharmacy_pos/features/expenses/data/expense_repository_impl.dart';
import 'package:pharmacy_pos/features/expenses/domain/repositories/expense_repository.dart';
import 'package:pharmacy_pos/features/expenses/domain/services/receipt_storage.dart';
import 'package:pharmacy_pos/features/expenses/domain/usecases/expenses_use_cases.dart';
import 'package:pharmacy_pos/shared/database/app_database.dart';
import 'package:pharmacy_pos/shared/models/enums.dart';

import 'helpers.dart';

class _TestReceiptStorage implements ReceiptStorage {
  _TestReceiptStorage(this._dir);
  final String _dir;

  @override
  Future<String> save(String sourcePath) async => '$_dir/stored.jpg';

  @override
  Future<void> delete(String storedPath) async {
    final f = File(storedPath);
    if (f.existsSync()) f.deleteSync();
  }
}

void main() {
  late AppDatabase db;
  late ExpenseRepository repo;
  late CreateExpenseUseCase createUseCase;
  late UpdateExpenseUseCase updateUseCase;
  late CancelExpenseUseCase cancelUseCase;
  late AttachReceiptUseCase attachUseCase;
  late RemoveReceiptUseCase removeUseCase;
  late Directory tmpDir;

  setUp(() async {
    db = newDatabase();
    tmpDir = Directory.systemTemp.createTempSync('receipt_test');
    repo = ExpenseRepositoryImpl(
        db, _TestReceiptStorage(tmpDir.path), const FinancialPostingService());
    final perms = const PermissionService();
    final audit = const AuditService();
    createUseCase = CreateExpenseUseCase(repo, perms);
    updateUseCase = UpdateExpenseUseCase(repo, perms, audit);
    cancelUseCase = CancelExpenseUseCase(repo, perms);
    attachUseCase = AttachReceiptUseCase(repo, perms, audit);
    removeUseCase = RemoveReceiptUseCase(repo, perms, audit);
  });

  tearDown(() async {
    tmpDir.deleteSync(recursive: true);
    await db.close();
  });

  test('record -> edit description -> cancel full lifecycle', () async {
    final row = await createUseCase(
      ExpenseDraft(categoryCode: 'rent', description: 'rent', amountMicros: 100000),
      actingUserId: 'user_admin',
      actingRoleId: 'role_admin',
    );
    expect(row.description, 'rent');
    expect(row.expenseNumber, startsWith('EXP-'));

    final edited = await updateUseCase(
      row.id,
      ExpenseEditDraft(description: 'edited', notes: 'note'),
      actingUserId: 'user_admin',
      actingRoleId: 'role_admin',
    );
    expect(edited.description, 'edited');
    expect(edited.notes, 'note');

    final voided = await cancelUseCase(
      row.id,
      reason: 'wrong entry',
      actingUserId: 'user_admin',
      actingRoleId: 'role_admin',
    );
    expect(voided.isVoided, isTrue);
  });

  test('attach and then remove a receipt', () async {
    final row = await createUseCase(
      ExpenseDraft(categoryCode: 'rent', description: 'receipt', amountMicros: 5000),
      actingUserId: 'user_admin',
      actingRoleId: 'role_admin',
    );
    expect(row.receiptPath, isNull);

    final storedPath = await attachUseCase(
      row.id,
      sourcePath: '${tmpDir.path}/test.jpg',
      actingUserId: 'user_admin',
      actingRoleId: 'role_admin',
    );
    expect(storedPath, isNotEmpty);

    final afterAttach = await (db.select(db.expenses)..where((e) => e.id.equals(row.id))).getSingle();
    expect(afterAttach.receiptPath, isNotNull);

    await removeUseCase(row.id, actingUserId: 'user_admin', actingRoleId: 'role_admin');
    final afterRemove = await (db.select(db.expenses)..where((e) => e.id.equals(row.id))).getSingle();
    expect(afterRemove.receiptPath, isNull);
  });

  test('cannot edit or attach receipt on a voided expense', () async {
    final row = await createUseCase(
      ExpenseDraft(categoryCode: 'rent', description: 'voided', amountMicros: 3000),
      actingUserId: 'user_admin',
      actingRoleId: 'role_admin',
    );
    await cancelUseCase(row.id, reason: 'void', actingUserId: 'user_admin', actingRoleId: 'role_admin');

    await expectLater(
      updateUseCase(row.id, ExpenseEditDraft(description: 'nope'), actingUserId: 'user_admin', actingRoleId: 'role_admin'),
      throwsA(isA<InvalidOperationException>()),
    );
    await expectLater(
      attachUseCase(row.id, sourcePath: '${tmpDir.path}/no.jpg', actingUserId: 'user_admin', actingRoleId: 'role_admin'),
      throwsA(isA<InvalidOperationException>()),
    );
  });

  test('cash and card expenses both stored in DB', () async {
    final cashRow = await createUseCase(
      ExpenseDraft(categoryCode: 'rent', description: 'cash', amountMicros: 10000, paymentMethod: ExpensePaymentMethod.cash),
      actingUserId: 'user_admin',
      actingRoleId: 'role_admin',
    );
    final cardRow = await createUseCase(
      ExpenseDraft(categoryCode: 'utilities', description: 'card', amountMicros: 8000, paymentMethod: ExpensePaymentMethod.card),
      actingUserId: 'user_admin',
      actingRoleId: 'role_admin',
    );
    final all = await (db.select(db.expenses)).get();
    expect(all, hasLength(2));
    expect(all.any((e) => e.id == cashRow.id && e.paymentMethod == 'cash'), isTrue);
    expect(all.any((e) => e.id == cardRow.id && e.paymentMethod == 'card'), isTrue);
  });
}
