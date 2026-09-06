import '../../../../core/constants/permission_codes.dart';
import '../../../../core/data_grid/page_request.dart';
import '../../../../core/errors/exceptions.dart';
import '../../../../domain/services/audit_service.dart';
import '../../../../domain/services/permission_service.dart';
import '../../../../shared/database/app_database.dart';
import '../../../../shared/models/enums.dart';
import '../repositories/inventory_repository.dart';

/// Paged manufacturer search (§4.1, §22).
class ListManufacturersUseCase {
  const ListManufacturersUseCase(this._repo, this._permissions);

  final InventoryRepository _repo;
  final PermissionService _permissions;

  Future<PageResult<ManufacturerRow>> call(
    PageRequest page, {
    String? actingRoleId,
  }) async {
    await _permissions.requireRolePermission(
        _repo.database, actingRoleId, Perm.inventoryView);
    return _repo.searchManufacturers(page);
  }
}

/// Create/update a manufacturer (audited).
class SaveManufacturerUseCase {
  const SaveManufacturerUseCase(this._repo, this._permissions, this._audit);

  final InventoryRepository _repo;
  final PermissionService _permissions;
  final AuditService _audit;

  Future<ManufacturerRow> create(
    MasterDataDraft draft, {
    String? actingUserId,
    String? actingRoleId,
  }) async {
    final db = _repo.database;
    await _permissions.requireRolePermission(db, actingRoleId, Perm.inventoryEdit);
    if (actingUserId == null || actingUserId.isEmpty) {
      throw UnauthorizedException('بيانات المستخدم ناقصة للتسجيل');
    }
    if (draft.name.trim().isEmpty) {
      throw ValidationException('اسم الشركة مطلوب');
    }
    final row = await _repo.createManufacturer(draft);
    await _audit.write(
      db,
      userId: actingUserId,
      action: AuditAction.create,
      entityType: 'manufacturer',
      entityId: row.id,
      after: {'name': row.name, 'country': row.country},
      note: 'إنشاء شركة تصنيع: ${row.name}',
    );
    return row;
  }

  Future<ManufacturerRow> update(
    String id,
    MasterDataDraft draft, {
    String? actingUserId,
    String? actingRoleId,
  }) async {
    final db = _repo.database;
    await _permissions.requireRolePermission(db, actingRoleId, Perm.inventoryEdit);
    if (actingUserId == null || actingUserId.isEmpty) {
      throw UnauthorizedException('بيانات المستخدم ناقصة للتسجيل');
    }
    if (draft.name.trim().isEmpty) {
      throw ValidationException('اسم الشركة مطلوب');
    }
    final row = await _repo.updateManufacturer(id, draft);
    await _audit.write(
      db,
      userId: actingUserId,
      action: AuditAction.update,
      entityType: 'manufacturer',
      entityId: row.id,
      after: {'name': row.name, 'country': row.country},
      note: 'تعديل شركة تصنيع: ${row.name}',
    );
    return row;
  }
}

/// Toggle soft-delete for a manufacturer (audited).
class SetManufacturerActiveUseCase {
  const SetManufacturerActiveUseCase(
      this._repo, this._permissions, this._audit);

  final InventoryRepository _repo;
  final PermissionService _permissions;
  final AuditService _audit;

  Future<void> call(
    String id,
    bool active, {
    String? actingUserId,
    String? actingRoleId,
  }) async {
    final db = _repo.database;
    await _permissions.requireRolePermission(db, actingRoleId, Perm.inventoryEdit);
    if (actingUserId == null || actingUserId.isEmpty) {
      throw UnauthorizedException('بيانات المستخدم ناقصة للتسجيل');
    }
    await _repo.setManufacturerActive(id, active);
    await _audit.write(
      db,
      userId: actingUserId,
      action: active ? AuditAction.restore : AuditAction.delete,
      entityType: 'manufacturer',
      entityId: id,
      note: active ? 'تفعيل شركة تصنيع $id' : 'إيقاف شركة تصنيع $id',
    );
  }
}

/// All manufacturers for dropdown / export lookups.
class AllManufacturersUseCase {
  const AllManufacturersUseCase(this._repo, this._permissions);

  final InventoryRepository _repo;
  final PermissionService _permissions;

  Future<List<ManufacturerRow>> call({String? actingRoleId}) async {
    await _permissions.requireRolePermission(
        _repo.database, actingRoleId, Perm.inventoryView);
    return _repo.manufacturers();
  }
}