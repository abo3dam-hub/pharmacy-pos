import '../../../../core/constants/permission_codes.dart';
import '../../../../core/errors/exceptions.dart';
import '../../../../domain/services/audit_service.dart';
import '../../../../domain/services/permission_service.dart';
import '../../../../shared/database/app_database.dart';
import '../../../../shared/models/enums.dart';
import '../repositories/inventory_repository.dart';

/// Full active-ingredient list.
class ListActiveIngredientsUseCase {
  const ListActiveIngredientsUseCase(this._repo, this._permissions);

  final InventoryRepository _repo;
  final PermissionService _permissions;

  Future<List<ActiveIngredientRow>> call({String? actingRoleId}) async {
    await _permissions.requireRolePermission(
        _repo.database, actingRoleId, Perm.inventoryView);
    return _repo.activeIngredients();
  }
}

/// Create/update an active ingredient (audited).
class SaveActiveIngredientUseCase {
  const SaveActiveIngredientUseCase(
      this._repo, this._permissions, this._audit);

  final InventoryRepository _repo;
  final PermissionService _permissions;
  final AuditService _audit;

  Future<ActiveIngredientRow> create(
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
      throw ValidationException('اسم المادة الفعالة مطلوب');
    }
    final row = await _repo.createActiveIngredient(draft);
    await _audit.write(
      db,
      userId: actingUserId,
      action: AuditAction.create,
      entityType: 'active_ingredient',
      entityId: row.id,
      after: {'name': row.name},
      note: 'إنشاء مادة فعالة: ${row.name}',
    );
    return row;
  }

  Future<ActiveIngredientRow> update(
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
      throw ValidationException('اسم المادة الفعالة مطلوب');
    }
    final row = await _repo.updateActiveIngredient(id, draft);
    await _audit.write(
      db,
      userId: actingUserId,
      action: AuditAction.update,
      entityType: 'active_ingredient',
      entityId: row.id,
      after: {'name': row.name},
      note: 'تعديل مادة فعالة: ${row.name}',
    );
    return row;
  }
}

/// Toggle soft-delete for an active ingredient (audited).
class SetActiveIngredientActiveUseCase {
  const SetActiveIngredientActiveUseCase(
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
    await _repo.setActiveIngredientActive(id, active);
    await _audit.write(
      db,
      userId: actingUserId,
      action: active ? AuditAction.restore : AuditAction.delete,
      entityType: 'active_ingredient',
      entityId: id,
      note: active ? 'تفعيل مادة فعالة $id' : 'إيقاف مادة فعالة $id',
    );
  }
}