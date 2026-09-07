import '../../../../core/constants/account_codes.dart';
import '../../../../core/constants/permission_codes.dart';
import '../../../../core/data_grid/page_request.dart';
import '../../../../core/errors/exceptions.dart';
import '../../../../domain/services/audit_service.dart';
import '../../../../domain/services/permission_service.dart';
import '../../../../shared/database/app_database.dart';
import '../../../../shared/models/enums.dart';
import '../entities/expense_list_item.dart';
import '../repositories/expense_repository.dart';

/// Paged expenses journal listing (`expenses.view`, §16) with joined category
/// / operator / supplier names.
class ListExpensesUseCase {
  const ListExpensesUseCase(this._repo, this._permissions);

  final ExpenseRepository _repo;
  final PermissionService _permissions;

  Future<PageResult<ExpenseListItem>> call(
    PageRequest page, {
    String? categoryCode,
    ExpensePaymentMethod? paymentMethod,
    bool? isVoided,
    int? fromMillis,
    int? toMillis,
    String? actingRoleId,
  }) async {
    await _permissions.requireRolePermission(
        _repo.database, actingRoleId, Perm.expensesView);
    return _repo.listExpenses(
      page: page,
      categoryCode: categoryCode,
      paymentMethod: paymentMethod,
      isVoided: isVoided,
      fromMillis: fromMillis,
      toMillis: toMillis,
    );
  }
}

/// Expense categories master (`expenses.categories.view`) for filters and the
/// booking form.
class ListExpenseCategoriesUseCase {
  const ListExpenseCategoriesUseCase(this._repo, this._permissions);

  final ExpenseRepository _repo;
  final PermissionService _permissions;

  Future<List<ExpenseCategoryRow>> call({
    bool activeOnly = false,
    String? actingRoleId,
  }) async {
    await _permissions.requireRolePermission(
        _repo.database, actingRoleId, Perm.expenseCategoriesView);
    return _repo.listCategories(activeOnly: activeOnly);
  }
}

/// Books an expense (`expenses.create`) — the posting engine validates the
/// user against `expenses.create` again, writes the audit on create and posts
/// GL + drawer atomically (§19).
class CreateExpenseUseCase {
  const CreateExpenseUseCase(this._repo, this._permissions);

  final ExpenseRepository _repo;
  final PermissionService _permissions;

  Future<ExpenseRow> call(
    ExpenseDraft draft, {
    String? actingUserId,
    String? actingRoleId,
  }) async {
    final db = _repo.database;
    await _permissions.requireRolePermission(db, actingRoleId, Perm.expensesCreate);
    if (actingUserId == null || actingUserId.isEmpty) {
      throw UnauthorizedException('بيانات المستخدم ناقصة للتسجيل');
    }
    if (draft.amountMicros <= 0) {
      throw ValidationException('مبلغ المصروف يجب أن يكون موجباً');
    }
    if (draft.description.trim().isEmpty) {
      throw ValidationException('وصف المصروف مطلوب');
    }
    final category = await _repo.findCategory(draft.categoryCode);
    if (category == null || !category.isActive) {
      throw ValidationException('فئة المصروف غير صالحة للتسجيل عليها');
    }
    return _repo.record(draft, userId: actingUserId);
  }
}

/// Edits the only mutable expense fields — description / notes (`expenses.edit`).
/// Amount, category, payment method and date are immutable after posting.
class UpdateExpenseUseCase {
  const UpdateExpenseUseCase(this._repo, this._permissions, this._audit);

  final ExpenseRepository _repo;
  final PermissionService _permissions;
  final AuditService _audit;

  Future<ExpenseRow> call(
    String expenseId,
    ExpenseEditDraft draft, {
    String? actingUserId,
    String? actingRoleId,
  }) async {
    final db = _repo.database;
    await _permissions.requireRolePermission(db, actingRoleId, Perm.expensesEdit);
    if (actingUserId == null || actingUserId.isEmpty) {
      throw UnauthorizedException('بيانات المستخدم ناقصة للتسجيل');
    }
    final before = await _expenseOrThrow(db, expenseId);
    final updated =
        await _repo.updateEditable(expenseId, draft, userId: actingUserId);
    await _audit.write(
      db,
      userId: actingUserId,
      action: AuditAction.update,
      entityType: 'expense',
      entityId: expenseId,
      before: expenseAuditEditJson(before),
      after: expenseAuditEditJson(updated),
      note: 'تعديل مصروف: ${updated.expenseNumber}',
    );
    return updated;
  }
}

/// Void-cancels an expense (`expenses.void`). Reversal is exactly-once — the
/// `is_voided` guard and the audit (`void`) live in the posting engine.
class CancelExpenseUseCase {
  const CancelExpenseUseCase(this._repo, this._permissions);

  final ExpenseRepository _repo;
  final PermissionService _permissions;

  Future<ExpenseRow> call(
    String expenseId, {
    required String reason,
    String? actingUserId,
    String? actingRoleId,
  }) async {
    final db = _repo.database;
    await _permissions.requireRolePermission(db, actingRoleId, Perm.expensesVoid);
    if (actingUserId == null || actingUserId.isEmpty) {
      throw UnauthorizedException('بيانات المستخدم ناقصة للتسجيل');
    }
    return _repo.cancel(expenseId, reason: reason, userId: actingUserId);
  }
}

/// Attaches a scanned receipt to a non-voided expense (`expenses.edit`).
class AttachReceiptUseCase {
  const AttachReceiptUseCase(this._repo, this._permissions, this._audit);

  final ExpenseRepository _repo;
  final PermissionService _permissions;
  final AuditService _audit;

  Future<String> call(
    String expenseId, {
    required String sourcePath,
    String? actingUserId,
    String? actingRoleId,
  }) async {
    final db = _repo.database;
    await _permissions.requireRolePermission(db, actingRoleId, Perm.expensesEdit);
    if (actingUserId == null || actingUserId.isEmpty) {
      throw UnauthorizedException('بيانات المستخدم ناقصة للتسجيل');
    }
    final stored =
        await _repo.attachReceipt(expenseId, sourcePath: sourcePath, userId: actingUserId);
    await _audit.write(
      db,
      userId: actingUserId,
      action: AuditAction.update,
      entityType: 'expense',
      entityId: expenseId,
      after: {'receipt_path': stored},
      note: 'إرفاق مقبوض لمصروف',
    );
    return stored;
  }
}

/// Removes a stored receipt (`expenses.edit`).
class RemoveReceiptUseCase {
  const RemoveReceiptUseCase(this._repo, this._permissions, this._audit);

  final ExpenseRepository _repo;
  final PermissionService _permissions;
  final AuditService _audit;

  Future<void> call(
    String expenseId, {
    String? actingUserId,
    String? actingRoleId,
  }) async {
    final db = _repo.database;
    await _permissions.requireRolePermission(db, actingRoleId, Perm.expensesEdit);
    if (actingUserId == null || actingUserId.isEmpty) {
      throw UnauthorizedException('بيانات المستخدم ناقصة للتسجيل');
    }
    await _repo.removeReceipt(expenseId, userId: actingUserId);
    await _audit.write(
      db,
      userId: actingUserId,
      action: AuditAction.update,
      entityType: 'expense',
      entityId: expenseId,
      after: {'receipt_path': null},
      note: 'إزالة مقبوض المصروف',
    );
  }
}

/// Creates a new expense category (`expenses.categories.manage`). System
/// blocks are seeded and never user-editable.
class CreateExpenseCategoryUseCase {
  const CreateExpenseCategoryUseCase(this._repo, this._permissions, this._audit);

  final ExpenseRepository _repo;
  final PermissionService _permissions;
  final AuditService _audit;

  Future<ExpenseCategoryRow> call(
    ExpenseCategoryDraft draft, {
    String? actingUserId,
    String? actingRoleId,
  }) async {
    final db = _repo.database;
    await _permissions.requireRolePermission(
        db, actingRoleId, Perm.expenseCategoriesManage);
    if (actingUserId == null || actingUserId.isEmpty) {
      throw UnauthorizedException('بيانات المستخدم ناقصة للتسجيل');
    }
    _validateCategoryDraft(draft);
    if (await _repo.findCategory(draft.code) != null) {
      throw ValidationException('كود الفئة مستخدم مسبقاً: ${draft.code}');
    }
    final created =
        await _repo.createCategory(draft, userId: actingUserId);
    await _audit.write(
      db,
      userId: actingUserId,
      action: AuditAction.create,
      entityType: 'expense_category',
      entityId: created.id,
      after: expenseCategoryAuditJson(created),
      note: 'إضافة فئة مصروف: ${created.name}',
    );
    return created;
  }
}

/// Edits a non-system expense category (`expenses.categories.manage`).
class UpdateExpenseCategoryUseCase {
  const UpdateExpenseCategoryUseCase(this._repo, this._permissions, this._audit);

  final ExpenseRepository _repo;
  final PermissionService _permissions;
  final AuditService _audit;

  Future<ExpenseCategoryRow> call(
    String categoryId,
    ExpenseCategoryDraft draft, {
    String? actingUserId,
    String? actingRoleId,
  }) async {
    final db = _repo.database;
    await _permissions.requireRolePermission(
        db, actingRoleId, Perm.expenseCategoriesManage);
    if (actingUserId == null || actingUserId.isEmpty) {
      throw UnauthorizedException('بيانات المستخدم ناقصة للتسجيل');
    }
    _validateCategoryDraft(draft);
    final updated =
        await _repo.updateCategory(categoryId, draft, userId: actingUserId);
    await _audit.write(
      db,
      userId: actingUserId,
      action: AuditAction.update,
      entityType: 'expense_category',
      entityId: categoryId,
      after: expenseCategoryAuditJson(updated),
      note: 'تعديل فئة مصروف: ${updated.name}',
    );
    return updated;
  }
}

/// Toggles a non-system expense category (`expenses.categories.manage`).
class SetExpenseCategoryActiveUseCase {
  const SetExpenseCategoryActiveUseCase(this._repo, this._permissions, this._audit);

  final ExpenseRepository _repo;
  final PermissionService _permissions;
  final AuditService _audit;

  Future<void> call(
    String categoryId,
    bool active, {
    String? actingUserId,
    String? actingRoleId,
  }) async {
    final db = _repo.database;
    await _permissions.requireRolePermission(
        db, actingRoleId, Perm.expenseCategoriesManage);
    if (actingUserId == null || actingUserId.isEmpty) {
      throw UnauthorizedException('بيانات المستخدم ناقصة للتسجيل');
    }
    await _repo.setCategoryActive(categoryId, active, userId: actingUserId);
    await _audit.write(
      db,
      userId: actingUserId,
      action: AuditAction.update,
      entityType: 'expense_category',
      entityId: categoryId,
      after: {'is_active': active},
      note: active ? 'إعادة تفعيل فئة مصروف' : 'تعطيل فئة مصروف',
    );
  }
}

void _validateCategoryDraft(ExpenseCategoryDraft draft) {
  if (draft.code.trim().isEmpty) {
    throw ValidationException('كود الفئة مطلوب');
  }
  if (!RegExp(r'^[a-z_][a-z0-9_]{1,31}$').hasMatch(draft.code.trim())) {
    throw ValidationException('كود الفئة بأحرف لاتينية صغيرة وأرقام وشرطة سفلية فقط');
  }
  if (draft.name.trim().isEmpty) {
    throw ValidationException('اسم الفئة مطلوب');
  }
  if (!_isAccountCode(draft.accountCode)) {
    throw ValidationException('رمز الحساب يجب أن يكون رقماً حسابياً صالحاً (4 خانات)');
  }
}

bool _isAccountCode(String code) {
  return RegExp(r'^\d{4}$').hasMatch(code) &&
      SystemAccountCode.operatingExpenses.compareTo(code) <= 0;
}

Future<ExpenseRow> _expenseOrThrow(AppDatabase db, String id) async {
  final row = await (db.select(db.expenses)..where((e) => e.id.equals(id)))
      .getSingleOrNull();
  if (row == null) {
    throw NotFoundException('المصروف غير موجود: $id');
  }
  return row;
}

Map<String, Object?> expenseAuditEditJson(ExpenseRow row) => {
      'expense_number': row.expenseNumber,
      'description': row.description,
      'notes': row.notes,
    };

Map<String, Object?> expenseCategoryAuditJson(ExpenseCategoryRow row) => {
      'code': row.code,
      'name': row.name,
      'name_en': row.nameEn,
      'account_code': row.accountCode,
      'is_active': row.isActive,
      'is_system': row.isSystem,
    };