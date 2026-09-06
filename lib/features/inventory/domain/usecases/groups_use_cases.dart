import '../../../../core/constants/permission_codes.dart';
import '../../../../core/errors/exceptions.dart';
import '../../../../domain/services/audit_service.dart';
import '../../../../domain/services/permission_service.dart';
import '../../../../shared/database/app_database.dart';
import '../../../../shared/models/enums.dart';
import '../repositories/inventory_repository.dart';

/// Full therapeutic-group list.
class ListTherapeuticGroupsUseCase {
  const ListTherapeuticGroupsUseCase(this._repo, this._permissions);

  final InventoryRepository _repo;
  final PermissionService _permissions;

  Future<List<TherapeuticGroupRow>> call({String? actingRoleId}) async {
    await _permissions.requireRolePermission(
        _repo.database, actingRoleId, Perm.inventoryView);
    return _repo.therapeuticGroups();
  }
}

/// Create/update a therapeutic group (audited).
class SaveTherapeuticGroupUseCase {
  const SaveTherapeuticGroupUseCase(
      this._repo, this._permissions, this._audit);

  final InventoryRepository _repo;
  final PermissionService _permissions;
  final AuditService _audit;

  Future<TherapeuticGroupRow> create(
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
      throw ValidationException('اسم المجموعة مطلوب');
    }
    final row = await _repo.createTherapeuticGroup(draft);
    await _audit.write(
      db,
      userId: actingUserId,
      action: AuditAction.create,
      entityType: 'therapeutic_group',
      entityId: row.id,
      after: {'name': row.name},
      note: 'إنشاء مجموعة علاجية: ${row.name}',
    );
    return row;
  }

  Future<TherapeuticGroupRow> update(
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
      throw ValidationException('اسم المجموعة مطلوب');
    }
    final row = await _repo.updateTherapeuticGroup(id, draft);
    await _audit.write(
      db,
      userId: actingUserId,
      action: AuditAction.update,
      entityType: 'therapeutic_group',
      entityId: row.id,
      after: {'name': row.name},
      note: 'تعديل مجموعة علاجية: ${row.name}',
    );
    return row;
  }
}

/// Toggle soft-delete for a therapeutic group (audited).
class SetTherapeuticGroupActiveUseCase {
  const SetTherapeuticGroupActiveUseCase(
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
    await _repo.setTherapeuticGroupActive(id, active);
    await _audit.write(
      db,
      userId: actingUserId,
      action: active ? AuditAction.restore : AuditAction.delete,
      entityType: 'therapeutic_group',
      entityId: id,
      note: active ? 'تفعيل مجموعة علاجية $id' : 'إيقاف مجموعة علاجية $id',
    );
  }
}