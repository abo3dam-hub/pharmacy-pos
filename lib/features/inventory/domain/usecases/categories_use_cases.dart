import '../../../../core/constants/permission_codes.dart';
import '../../../../core/errors/exceptions.dart';
import '../../../../domain/services/audit_service.dart';
import '../../../../domain/services/permission_service.dart';
import '../../../../shared/database/app_database.dart';
import '../../../../shared/models/enums.dart';
import '../repositories/inventory_repository.dart';

/// Categories & sub-categories listing (with their sub-rows).
class ListCategoriesUseCase {
  const ListCategoriesUseCase(this._repo, this._permissions);

  final InventoryRepository _repo;
  final PermissionService _permissions;

  Future<({List<CategoryRow> categories, List<SubCategoryRow> allSubs})> call({
    String? actingRoleId,
  }) async {
    await _permissions.requireRolePermission(
        _repo.database, actingRoleId, Perm.inventoryView);
    final categories = await _repo.categories();
    final allSubs = <SubCategoryRow>[];
    for (final c in categories) {
      allSubs.addAll(await _repo.subCategories(c.id));
    }
    return (categories: categories, allSubs: allSubs);
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

/// Create/update a sub-category (§4.6).
class SaveSubCategoryUseCase {
  const SaveSubCategoryUseCase(this._repo, this._permissions, this._audit);

  final InventoryRepository _repo;
  final PermissionService _permissions;
  final AuditService _audit;

  Future<SubCategoryRow> create(
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
      throw ValidationException('اسم التصنيف الفرعي مطلوب');
    }
    final row = await _repo.createSubCategory(draft);
    await _audit.write(
      db,
      userId: actingUserId,
      action: AuditAction.create,
      entityType: 'sub_category',
      entityId: row.id,
      after: {'name': row.name, 'category_id': row.categoryId},
      note: 'إنشاء تصنيف فرعي: ${row.name}',
    );
    return row;
  }

  Future<SubCategoryRow> update(
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
      throw ValidationException('اسم التصنيف الفرعي مطلوب');
    }
    final row = await _repo.updateSubCategory(id, draft);
    await _audit.write(
      db,
      userId: actingUserId,
      action: AuditAction.update,
      entityType: 'sub_category',
      entityId: row.id,
      after: {'name': row.name, 'category_id': row.categoryId},
      note: 'تعديل تصنيف فرعي: ${row.name}',
    );
    return row;
  }
}

/// Toggle the soft-delete flag of a category / sub-category (audited).
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

  Future<void> subCategory(
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
    await _repo.setSubCategoryActive(id, active);
    await _audit.write(
      db,
      userId: actingUserId,
      action: active ? AuditAction.restore : AuditAction.delete,
      entityType: 'sub_category',
      entityId: id,
      note: active ? 'تفعيل تصنيف فرعي $id' : 'إيقاف تصنيف فرعي $id',
    );
  }
}