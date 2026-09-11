import '../../../../core/constants/permission_codes.dart';
import '../../../../core/errors/exceptions.dart';
import '../../../../domain/services/audit_service.dart';
import '../../../../domain/services/permission_service.dart';
import '../../../../shared/database/app_database.dart';
import '../../../../shared/models/enums.dart';
import '../repositories/inventory_repository.dart';

/// Categories listing.
class ListCategoriesUseCase {
  const ListCategoriesUseCase(this._repo, this._permissions);

  final InventoryRepository _repo;
  final PermissionService _permissions;

  Future<({List<CategoryRow> categories})> call({
    String? actingRoleId,
  }) async {
    await _permissions.requireRolePermission(
        _repo.database, actingRoleId, Perm.inventoryView);
    return (categories: await _repo.categories());
  }
}

/// Create/update a main category. Requires `inventory.edit` and audits.
class SaveCategoryUseCase {
  const SaveCategoryUseCase(this._repo, this._permissions, this._audit);

  final InventoryRepository _repo;
  final PermissionService _permissions;
  final AuditService _audit;

  Future<CategoryRow> create(
    MasterDataDraft draft, {
    String? actingUserId,
    String? actingRoleId,
  }) =>
      _run(draft, actingUserId, actingRoleId, createOnly: true);

  Future<CategoryRow> update(
    String id,
    MasterDataDraft draft, {
    String? actingUserId,
    String? actingRoleId,
  }) =>
      _run(draft, actingUserId, actingRoleId, id: id);

  Future<CategoryRow> _run(
    MasterDataDraft draft,
    String? actingUserId,
    String? actingRoleId, {
    String? id,
    bool createOnly = false,
  }) async {
    final db = _repo.database;
    await _permissions.requireRolePermission(db, actingRoleId, Perm.inventoryEdit);
    if (actingUserId == null || actingUserId.isEmpty) {
      throw UnauthorizedException('بيانات المستخدم ناقصة للتسجيل');
    }
    if (draft.name.trim().isEmpty) {
      throw ValidationException('اسم التصنيف مطلوب');
    }
    final row =
        createOnly ? await _repo.createCategory(draft) : await _repo.updateCategory(id!, draft);
    await _audit.write(
      db,
      userId: actingUserId,
      action: createOnly ? AuditAction.create : AuditAction.update,
      entityType: 'category',
      entityId: row.id,
      after: {'name': row.name, 'name_en': row.nameEn},
      note: '${createOnly ? 'إنشاء' : 'تعديل'} تصنيف: ${row.name}',
    );
    return row;
  }
}

/// Toggle the soft-delete flag of a category (audited).
class SetCategoryActiveUseCase {
  const SetCategoryActiveUseCase(this._repo, this._permissions, this._audit);

  final InventoryRepository _repo;
  final PermissionService _permissions;
  final AuditService _audit;

  Future<void> category(
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
    await _repo.setCategoryActive(id, active);
    await _audit.write(
      db,
      userId: actingUserId,
      action: active ? AuditAction.restore : AuditAction.delete,
      entityType: 'category',
      entityId: id,
      note: active ? 'تفعيل تصنيف $id' : 'إيقاف تصنيف $id',
    );
  }
}