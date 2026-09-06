import '../../../../core/constants/permission_codes.dart';
import '../../../../core/errors/exceptions.dart';
import '../../../../domain/services/audit_service.dart';
import '../../../../domain/services/permission_service.dart';
import '../../../../shared/models/enums.dart';
import '../repositories/inventory_repository.dart';

/// Stock adjustment (جرد/تسوية) posted through the append-only ledger (§9).
/// Requires `stock.adjust`; movement type comes from the adjust screen
/// (manual correction, damaged, expired, count).
class AdjustStockUseCase {
  const AdjustStockUseCase(this._repo, this._permissions, this._audit);

  final InventoryRepository _repo;
  final PermissionService _permissions;
  final AuditService _audit;

  Future<void> call(
    StockAdjustInput input, {
    String? actingUserId,
    String? actingRoleId,
  }) async {
    final db = _repo.database;
    await _permissions.requireRolePermission(db, actingRoleId, Perm.stockAdjust);
    if (actingUserId == null || actingUserId.isEmpty) {
      throw UnauthorizedException('بيانات المستخدم ناقصة للتسجيل');
    }
    if (input.deltaBase == 0) {
      throw ValidationException('كمية التسوية يجب ألا تكون صفرًا');
    }
    if (input.unitCostMicros < 0) {
      throw ValidationException('سعر التكلفة لا يمكن أن يكون سالبًا');
    }
    if (!MovementType.values.any((m) => m.name == input.movementType)) {
      throw ValidationException('نوع حركة مخزون غير معروف: ${input.movementType}');
    }
    await _repo.applyStockAdjustment(input, actingUserId);
    await _audit.write(
      db,
      userId: actingUserId,
      action: AuditAction.update,
      entityType: 'item',
      entityId: input.itemId,
      after: {
        'delta_base': input.deltaBase,
        'movement_type': input.movementType,
        'batch_id': input.batchId,
        'unit_cost_micros': input.unitCostMicros,
      },
      note: input.note ?? 'تسوية مخزون للمنتج ${input.itemId}',
    );
  }
}