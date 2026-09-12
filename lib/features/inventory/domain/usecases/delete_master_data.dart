import '../../../../core/constants/permission_codes.dart';
import '../../../../core/errors/exceptions.dart';
import '../../../../domain/services/audit_service.dart';
import '../../../../domain/services/permission_service.dart';
import '../../../../shared/models/enums.dart';
import '../repositories/inventory_repository.dart';

/// Base for the audited master-data deletes. Requires `inventory.delete` (not
/// the edit permission): removing a registry row is a destructive,
/// admin-by-default action. The repository enforces the "in use" safety rule.
abstract class _DeleteMasterData {
  const _DeleteMasterData(this._repo, this._permissions, this._audit);

  final InventoryRepository _repo;
  final PermissionService _permissions;
  final AuditService _audit;

  String get _entityType;

  Future<void> _run(String id, Future<void> Function() delete,
      {String? actingUserId, String? actingRoleId}) async {
    final db = _repo.database;
    await _permissions.requireRolePermission(
        db, actingRoleId, Perm.inventoryDelete);
    final userId = actingUserId;
    if (userId == null || userId.isEmpty) {
      throw UnauthorizedException('بيانات المستخدم ناقصة للتسجيل');
    }
    await delete();
    await _audit.write(
      db,
      userId: userId,
      action: AuditAction.delete,
      entityType: _entityType,
      entityId: id,
      note: 'حذف $_entityType $id',
    );
  }
}

class DeleteCategoryUseCase extends _DeleteMasterData {
  const DeleteCategoryUseCase(super.repo, super.permissions, super.audit);

  @override
  String get _entityType => 'category';

  Future<void> call(String id,
          {String? actingUserId, String? actingRoleId}) =>
      _run(id, () => _repo.deleteCategory(id),
          actingUserId: actingUserId, actingRoleId: actingRoleId);
}

class DeleteManufacturerUseCase extends _DeleteMasterData {
  const DeleteManufacturerUseCase(super.repo, super.permissions, super.audit);

  @override
  String get _entityType => 'manufacturer';

  Future<void> call(String id,
          {String? actingUserId, String? actingRoleId}) =>
      _run(id, () => _repo.deleteManufacturer(id),
          actingUserId: actingUserId, actingRoleId: actingRoleId);
}

class DeleteUnitUseCase extends _DeleteMasterData {
  const DeleteUnitUseCase(super.repo, super.permissions, super.audit);

  @override
  String get _entityType => 'unit';

  Future<void> call(String id,
          {String? actingUserId, String? actingRoleId}) =>
      _run(id, () => _repo.deleteUnit(id),
          actingUserId: actingUserId, actingRoleId: actingRoleId);
}

class DeleteActiveIngredientUseCase extends _DeleteMasterData {
  const DeleteActiveIngredientUseCase(
      super.repo, super.permissions, super.audit);

  @override
  String get _entityType => 'active_ingredient';

  Future<void> call(String id,
          {String? actingUserId, String? actingRoleId}) =>
      _run(id, () => _repo.deleteActiveIngredient(id),
          actingUserId: actingUserId, actingRoleId: actingRoleId);
}

class DeleteIndicationUseCase extends _DeleteMasterData {
  const DeleteIndicationUseCase(super.repo, super.permissions, super.audit);

  @override
  String get _entityType => 'indication';

  Future<void> call(String id,
          {String? actingUserId, String? actingRoleId}) =>
      _run(id, () => _repo.deleteIndication(id),
          actingUserId: actingUserId, actingRoleId: actingRoleId);
}