import '../../../../core/data_grid/page_request.dart';
import '../../../../core/constants/permission_codes.dart';
import '../../../../core/errors/exceptions.dart';
import '../../../../domain/services/audit_service.dart';
import '../../../../domain/services/permission_service.dart';
import '../../../../shared/database/app_database.dart';
import '../../../../shared/models/enums.dart';
import '../repositories/customer_repository.dart';

/// Creates a customer/patient (`customers.create`) and audits the creation (§17).
class CreateCustomerUseCase {
  const CreateCustomerUseCase(this._repo, this._permissions, this._audit);

  final CustomerRepository _repo;
  final PermissionService _permissions;
  final AuditService _audit;

  Future<CustomerRow> call(
    CustomerDraft draft, {
    String? actingUserId,
    String? actingRoleId,
  }) async {
    final db = _repo.database;
    await _permissions.requireRolePermission(
        db, actingRoleId, Perm.customersCreate);
    if (actingUserId == null || actingUserId.isEmpty) {
      throw UnauthorizedException('بيانات المستخدم ناقصة للتسجيل');
    }
    _validate(draft);
    final created = await _repo.create(draft, userId: actingUserId);
    await _audit.write(
      db,
      userId: actingUserId,
      action: AuditAction.create,
      entityType: 'customer',
      entityId: created.id,
      after: customerAuditJson(created),
      note: 'إضافة عميل: ${created.name}',
    );
    return created;
  }
}

/// Updates a customer's master fields (`customers.edit`) with an audit trail.
/// An opening-balance mutation is recorded explicitly.
class UpdateCustomerUseCase {
  const UpdateCustomerUseCase(this._repo, this._permissions, this._audit);

  final CustomerRepository _repo;
  final PermissionService _permissions;
  final AuditService _audit;

  Future<CustomerRow> call(
    String id,
    CustomerDraft draft, {
    String? actingUserId,
    String? actingRoleId,
  }) async {
    final db = _repo.database;
    await _permissions.requireRolePermission(db, actingRoleId, Perm.customersEdit);
    if (actingUserId == null || actingUserId.isEmpty) {
      throw UnauthorizedException('بيانات المستخدم ناقصة للتسجيل');
    }
    _validate(draft);
    final before = await _repo.findById(id);
    if (before == null) {
      throw NotFoundException('العميل غير موجود: $id');
    }
    final updated = await _repo.update(id, draft, userId: actingUserId);
    await _audit.write(
      db,
      userId: actingUserId,
      action: AuditAction.update,
      entityType: 'customer',
      entityId: id,
      before: customerAuditJson(before),
      after: customerAuditJson(updated),
      note: 'تعديل عميل: ${updated.name}',
    );
    if (before.openingBalanceMicros != draft.openingBalanceMicros) {
      await _audit.write(
        db,
        userId: actingUserId,
        action: AuditAction.update,
        entityType: 'customer_balance',
        entityId: id,
        before: {'opening_balance_micros': before.openingBalanceMicros},
        after: {'opening_balance_micros': draft.openingBalanceMicros},
        note: 'تعديل الرصيد الافتتاحي للعميل: ${updated.name}',
      );
    }
    return updated;
  }
}

/// Toggles a customer's active flag (`customers.edit`, soft delete §28).
class SetCustomerActiveUseCase {
  const SetCustomerActiveUseCase(this._repo, this._permissions, this._audit);

  final CustomerRepository _repo;
  final PermissionService _permissions;
  final AuditService _audit;

  Future<void> call(
    String id,
    bool active, {
    String? actingUserId,
    String? actingRoleId,
  }) async {
    final db = _repo.database;
    await _permissions.requireRolePermission(db, actingRoleId, Perm.customersEdit);
    if (actingUserId == null || actingUserId.isEmpty) {
      throw UnauthorizedException('بيانات المستخدم ناقصة للتسجيل');
    }
    await _repo.setActive(id, active, userId: actingUserId);
    await _audit.write(
      db,
      userId: actingUserId,
      action: AuditAction.update,
      entityType: 'customer',
      entityId: id,
      after: {'is_active': active},
      note: active ? 'إعادة تفعيل عميل' : 'تعطيل عميل',
    );
  }
}

/// Enables/disables the customer account (credit) flag (`customers.edit`).
class SetCustomerAccountUseCase {
  const SetCustomerAccountUseCase(this._repo, this._permissions, this._audit);

  final CustomerRepository _repo;
  final PermissionService _permissions;
  final AuditService _audit;

  Future<void> call(
    String id,
    bool enabled, {
    String? actingUserId,
    String? actingRoleId,
  }) async {
    final db = _repo.database;
    await _permissions.requireRolePermission(db, actingRoleId, Perm.customersEdit);
    if (actingUserId == null || actingUserId.isEmpty) {
      throw UnauthorizedException('بيانات المستخدم ناقصة للتسجيل');
    }
    await _repo.setAccount(id, enabled, userId: actingUserId);
    await _audit.write(
      db,
      userId: actingUserId,
      action: AuditAction.update,
      entityType: 'customer',
      entityId: id,
      after: {'has_account': enabled},
      note: enabled ? 'تفعيل حساب العميل' : 'تعطيل حساب العميل',
    );
  }
}

/// Paginated customer master listing (`customers.view`, §16).
class ListCustomersUseCase {
  const ListCustomersUseCase(this._repo, this._permissions);

  final CustomerRepository _repo;
  final PermissionService _permissions;

  Future<PageResult<CustomerRow>> call(
    PageRequest page, {
    String? actingRoleId,
  }) async {
    await _permissions.requireRolePermission(
        _repo.database, actingRoleId, Perm.customersView);
    return _repo.search(page);
  }
}

/// Active customers for prescription-form dropdowns (`customers.view`).
class AllCustomersUseCase {
  const AllCustomersUseCase(this._repo, this._permissions);

  final CustomerRepository _repo;
  final PermissionService _permissions;

  Future<List<CustomerRow>> call({String? actingRoleId}) async {
    await _permissions.requireRolePermission(
        _repo.database, actingRoleId, Perm.customersView);
    return _repo.allActive();
  }
}

/// One page of a customer's statement (كشف حساب العميل) with running balances.
/// Gated by `customers.view` and `reports.view_sales` (§16 viewer role).
class CustomerStatementUseCase {
  const CustomerStatementUseCase(this._repo, this._permissions);

  final CustomerRepository _repo;
  final PermissionService _permissions;

  Future<CustomerStatementPage> call(
    String customerId, {
    required int fromDate,
    required int toDate,
    required int page,
    required int pageSize,
    String? actingRoleId,
  }) async {
    final db = _repo.database;
    await _permissions.requireRolePermission(db, actingRoleId, Perm.customersView);
    await _permissions.requireRolePermission(
        db, actingRoleId, Perm.reportsViewSales);
    return _repo.statement(
      customerId,
      fromDate: fromDate,
      toDate: toDate,
      page: page,
      pageSize: pageSize,
    );
  }
}

void _validate(CustomerDraft draft) {
  if (draft.name.trim().isEmpty) {
    throw ValidationException('اسم العميل مطلوب');
  }
  if (draft.openingBalanceMicros < 0) {
    throw ValidationException('الرصيد الافتتاحي لا يمكن أن يكون سالباً');
  }
  if (draft.creditLimitMicros < 0) {
    throw ValidationException('الحد الائتماني لا يمكن أن يكون سالباً');
  }
}

/// Compact stable JSON projection for the audit trail (§17).
Map<String, Object?> customerAuditJson(CustomerRow row) => {
      'name': row.name,
      'phone': row.phone,
      'has_account': row.hasAccount,
      'opening_balance_micros': row.openingBalanceMicros,
      'credit_limit_micros': row.creditLimitMicros,
      'is_active': row.isActive,
    };