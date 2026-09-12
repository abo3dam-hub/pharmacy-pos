import '../../../../core/constants/permission_codes.dart';
import '../../../../core/errors/exceptions.dart';
import '../../../../domain/services/audit_service.dart';
import '../../../../domain/services/permission_service.dart';
import '../../../../shared/models/enums.dart';
import '../repositories/inventory_repository.dart';

/// Physically deletes an unused item (§28). Requires `inventory.delete` (a
/// distinct, admin-by-default permission). Safe-delete rules live in the
/// repository: the item must carry no stock, batch, ledger or document
/// reference, otherwise the delete is rejected and deactivation is the answer.
class DeleteItemUseCase {
  const DeleteItemUseCase(this._repo, this._permissions, this._audit);

  final InventoryRepository _repo;
  final PermissionService _permissions;
  final AuditService _audit;

  Future<void> call(
    String id, {
    String? actingUserId,
    String? actingRoleId,
  }) async {
    final db = _repo.database;
    await _permissions.requireRolePermission(db, actingRoleId, Perm.inventoryDelete);
    if (actingUserId == null || actingUserId.isEmpty) {
      throw UnauthorizedException('بيانات المستخدم ناقصة للتسجيل');
    }
    final item = await _repo.findItem(id);
    if (item == null) throw NotFoundException('المنتج رقم $id غير موجود');
    await _repo.deleteItem(id);
    await _audit.write(
      db,
      userId: actingUserId,
      action: AuditAction.delete,
      entityType: 'item',
      entityId: id,
      note: 'حذف منتج: ${item.tradeName}',
    );
  }
}