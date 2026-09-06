import '../../../../core/data_grid/page_request.dart';
import '../../../../core/constants/permission_codes.dart';
import '../../../../core/errors/exceptions.dart';
import '../../../../data/daos/supplier_dao.dart';
import '../../../../domain/services/audit_service.dart';
import '../../../../domain/services/permission_service.dart';
import '../../../../shared/database/app_database.dart';
import '../../../../shared/models/enums.dart';
import '../repositories/supplier_repository.dart';

/// Paginated supplier master listing (`suppliers.view`, §16).
class ListSuppliersUseCase {
  const ListSuppliersUseCase(this._repo, this._permissions);

  final SupplierRepository _repo;
  final PermissionService _permissions;

  Future<PageResult<SupplierRow>> call(
    PageRequest page, {
    String? actingRoleId,
  }) async {
    await _permissions.requireRolePermission(
        _repo.database, actingRoleId, Perm.suppliersView);
    return _repo.search(page);
  }
}

/// Active suppliers for purchase-form dropdowns (`suppliers.view`).
class AllSuppliersUseCase {
  const AllSuppliersUseCase(this._repo, this._permissions);

  final SupplierRepository _repo;
  final PermissionService _permissions;

  Future<List<SupplierRow>> call({String? actingRoleId}) async {
    await _permissions.requireRolePermission(
        _repo.database, actingRoleId, Perm.suppliersView);
    return _repo.allActive();
  }
}

/// Creates a supplier (`suppliers.create`) and audits the creation (§17).
class CreateSupplierUseCase {
  const CreateSupplierUseCase(this._repo, this._permissions, this._audit);

  final SupplierRepository _repo;
  final PermissionService _permissions;
  final AuditService _audit;

  Future<SupplierRow> call(
    SupplierDraft draft, {
    String? actingUserId,
    String? actingRoleId,
  }) async {
    final db = _repo.database;
    await _permissions.requireRolePermission(
        db, actingRoleId, Perm.suppliersCreate);
    if (actingUserId == null || actingUserId.isEmpty) {
      throw UnauthorizedException('بيانات المستخدم ناقصة للتسجيل');
    }
    _validate(draft);
    final created = await _repo.create(draft, userId: actingUserId);
    await _audit.write(
      db,
      userId: actingUserId,
      action: AuditAction.create,
      entityType: 'supplier',
      entityId: created.id,
      after: supplierAuditJson(created),
      note: 'إضافة مورد: ${created.name}',
    );
    return created;
  }
}

/// Updates a supplier's master fields (`suppliers.edit`) with an audit trail.
class UpdateSupplierUseCase {
  const UpdateSupplierUseCase(this._repo, this._permissions, this._audit);

  final SupplierRepository _repo;
  final PermissionService _permissions;
  final AuditService _audit;

  Future<SupplierRow> call(
    String id,
    SupplierDraft draft, {
    String? actingUserId,
    String? actingRoleId,
  }) async {
    final db = _repo.database;
    await _permissions.requireRolePermission(db, actingRoleId, Perm.suppliersEdit);
    if (actingUserId == null || actingUserId.isEmpty) {
      throw UnauthorizedException('بيانات المستخدم ناقصة للتسجيل');
    }
    _validate(draft);
    final before = await _repo.findById(id);
    if (before == null) {
      throw NotFoundException('المورد غير موجود: $id');
    }
    final updated = await _repo.update(id, draft, userId: actingUserId);
    await _audit.write(
      db,
      userId: actingUserId,
      action: AuditAction.update,
      entityType: 'supplier',
      entityId: id,
      before: supplierAuditJson(before),
      after: supplierAuditJson(updated),
      note: 'تعديل مورد: ${updated.name}',
    );
    return updated;
  }
}

/// Toggles a supplier's active flag (`suppliers.edit`, soft delete §28).
class SetSupplierActiveUseCase {
  const SetSupplierActiveUseCase(this._repo, this._permissions, this._audit);

  final SupplierRepository _repo;
  final PermissionService _permissions;
  final AuditService _audit;

  Future<void> call(
    String id,
    bool active, {
    String? actingUserId,
    String? actingRoleId,
  }) async {
    final db = _repo.database;
    await _permissions.requireRolePermission(db, actingRoleId, Perm.suppliersEdit);
    if (actingUserId == null || actingUserId.isEmpty) {
      throw UnauthorizedException('بيانات المستخدم ناقصة للتسجيل');
    }
    await _repo.setActive(id, active, userId: actingUserId);
    await _audit.write(
      db,
      userId: actingUserId,
      action: AuditAction.update,
      entityType: 'supplier',
      entityId: id,
      after: {'is_active': active},
      note: active ? 'إعادة تفعيل مورد' : 'تعطيل مورد',
    );
  }
}

/// Paginated derived supplier balances (`suppliers.view`, §25).
class SupplierBalancesUseCase {
  const SupplierBalancesUseCase(this._repo, this._permissions);

  final SupplierRepository _repo;
  final PermissionService _permissions;

  Future<PageResult<SupplierBalanceRow>> call(
    PageRequest page, {
    String? actingRoleId,
  }) async {
    await _permissions.requireRolePermission(
        _repo.database, actingRoleId, Perm.suppliersView);
    return _repo.balances(page);
  }
}

/// One page of a supplier's statement (كشف الحساب) with running balances.
/// Gated by `suppliers.view` and `reports.view_purchases` (§16 viewer role).
class SupplierStatementUseCase {
  const SupplierStatementUseCase(this._repo, this._permissions);

  final SupplierRepository _repo;
  final PermissionService _permissions;

  Future<SupplierStatementPage> call(
    String supplierId, {
    required int fromDate,
    required int toDate,
    required int page,
    required int pageSize,
    String? actingRoleId,
  }) async {
    final db = _repo.database;
    await _permissions.requireRolePermission(db, actingRoleId, Perm.suppliersView);
    await _permissions.requireRolePermission(
        db, actingRoleId, Perm.reportsViewPurchases);
    return _repo.statement(
      supplierId,
      fromDate: fromDate,
      toDate: toDate,
      page: page,
      pageSize: pageSize,
    );
  }
}

void _validate(SupplierDraft draft) {
  if (draft.name.trim().isEmpty) {
    throw ValidationException('اسم المورد مطلوب');
  }
  if (draft.openingBalanceMicros < 0) {
    throw ValidationException('الرصيد الافتتاحي لا يمكن أن يكون سالباً');
  }
  if (draft.creditLimitMicros < 0) {
    throw ValidationException('الحد الائتماني لا يمكن أن يكون سالباً');
  }
}

/// Compact stable JSON projection for the audit trail (§17).
Map<String, Object?> supplierAuditJson(SupplierRow row) => {
      'name': row.name,
      'code': row.code,
      'phone': row.phone,
      'contact_person': row.contactPerson,
      'tax_vat_number': row.taxVatNumber,
      'opening_balance_micros': row.openingBalanceMicros,
      'credit_limit_micros': row.creditLimitMicros,
      'is_active': row.isActive,
    };