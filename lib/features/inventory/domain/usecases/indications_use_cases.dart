import '../../../../core/constants/permission_codes.dart';
import '../../../../core/errors/exceptions.dart';
import '../../../../domain/services/audit_service.dart';
import '../../../../domain/services/permission_service.dart';
import '../../../../shared/database/app_database.dart';
import '../../../../shared/models/enums.dart';
import '../repositories/inventory_repository.dart';

/// Full indication list.
class ListIndicationsUseCase {
  const ListIndicationsUseCase(this._repo, this._permissions);

  final InventoryRepository _repo;
  final PermissionService _permissions;

  Future<List<IndicationRow>> call({String? actingRoleId}) async {
    await _permissions.requireRolePermission(
        _repo.database, actingRoleId, Perm.inventoryView);
    return _repo.indications();
  }
}

/// Create/update an indication (audited).
class SaveIndicationUseCase {
  const SaveIndicationUseCase(
      this._repo, this._permissions, this._audit);

  final InventoryRepository _repo;
  final PermissionService _permissions;
  final AuditService _audit;

  Future<IndicationRow> create(
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
      throw ValidationException('اسم الاستطباب مطلوب');
    }
    final row = await _repo.createIndication(draft);
    await _audit.write(
      db,
      userId: actingUserId,
      action: AuditAction.create,
      entityType: 'indication',
      entityId: row.id,
      after: {'name': row.name},
      note: 'إنشاء استطباب: ${row.name}',
    );
    return row;
  }

  Future<IndicationRow> update(
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
      throw ValidationException('اسم الاستطباب مطلوب');
    }
    final row = await _repo.updateIndication(id, draft);
    await _audit.write(
      db,
      userId: actingUserId,
      action: AuditAction.update,
      entityType: 'indication',
      entityId: row.id,
      after: {'name': row.name},
      note: 'تعديل استطباب: ${row.name}',
    );
    return row;
  }
}

/// Toggle soft-delete for an indication (audited).
class SetIndicationActiveUseCase {
  const SetIndicationActiveUseCase(
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
    await _repo.setIndicationActive(id, active);
    await _audit.write(
      db,
      userId: actingUserId,
      action: active ? AuditAction.restore : AuditAction.delete,
      entityType: 'indication',
      entityId: id,
      note: active ? 'تفعيل استطباب $id' : 'إيقاف استطباب $id',
    );
  }
}