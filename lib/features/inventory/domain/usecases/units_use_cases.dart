import '../../../../core/constants/permission_codes.dart';
import '../../../../core/errors/exceptions.dart';
import '../../../../core/util/ids.dart';
import '../../../../domain/services/audit_service.dart';
import '../../../../domain/services/permission_service.dart';
import '../../../../shared/database/app_database.dart';
import '../../../../shared/models/enums.dart';
import '../repositories/inventory_repository.dart';

/// Active unit list for conversions/dropdowns.
class ListUnitsUseCase {
  const ListUnitsUseCase(this._repo, this._permissions);

  final InventoryRepository _repo;
  final PermissionService _permissions;

  Future<List<UnitRow>> call({bool activeOnly = true, String? actingRoleId}) async {
    await _permissions.requireRolePermission(
        _repo.database, actingRoleId, Perm.inventoryView);
    return _repo.units(activeOnly: activeOnly);
  }
}

/// Create/update a measurement unit (§4.5). Renames propagate to future item
/// relations; existing relations keep the row id.
class SaveUnitUseCase {
  const SaveUnitUseCase(this._repo, this._permissions, this._audit);

  final InventoryRepository _repo;
  final PermissionService _permissions;
  final AuditService _audit;

  Future<UnitRow> create(
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
      throw ValidationException('اسم الوحدة مطلوب');
    }
    final row = await _repo.createUnit(draft);
    await _audit.write(
      db,
      userId: actingUserId,
      action: AuditAction.create,
      entityType: 'unit',
      entityId: row.id,
      after: {'name': row.name, 'name_en': row.nameEn, 'abbr': row.abbreviation},
      note: 'إنشاء وحدة قياس: ${row.name}',
    );
    return row;
  }

  Future<UnitRow> update(
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
      throw ValidationException('اسم الوحدة مطلوب');
    }
    final row = await _repo.updateUnit(id, draft);
    await _audit.write(
      db,
      userId: actingUserId,
      action: AuditAction.update,
      entityType: 'unit',
      entityId: row.id,
      after: {'name': row.name, 'name_en': row.nameEn, 'abbr': row.abbreviation},
      note: 'تعديل وحدة قياس: ${row.name}',
    );
    return row;
  }
}

/// Adds a batch entry module id (opening-balance style). Kept here so all
/// batch-related ids live in one place.
String batchRelatedId() => newId('brl');