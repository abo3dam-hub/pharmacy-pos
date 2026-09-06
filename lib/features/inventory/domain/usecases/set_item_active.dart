import '../../../../core/constants/permission_codes.dart';
import '../../../../core/errors/exceptions.dart';
import '../../../../domain/services/audit_service.dart';
import '../../../../domain/services/permission_service.dart';
import '../../../../shared/models/enums.dart';
import '../repositories/inventory_repository.dart';

/// Deactivates an item (soft delete, §28). Requires `inventory.edit`. Items are
/// never physically removed from the database.
class SetItemActiveUseCase {
  const SetItemActiveUseCase(this._repo, this._permissions, this._audit);

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
    final item = await _repo.findItem(id);
    if (item == null) throw NotFoundException('المنتج رقم $id غير موجود');
    await _repo.setItemActive(id, active);
    await _audit.write(
      db,
      userId: actingUserId,
      action: active ? AuditAction.restore : AuditAction.delete,
      entityType: 'item',
      entityId: id,
      note: active
          ? 'تفعيل منتج: ${item.tradeName}'
          : 'إيقاف منتج: ${item.tradeName}',
    );
  }
}