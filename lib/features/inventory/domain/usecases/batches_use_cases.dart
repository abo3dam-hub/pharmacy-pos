import '../../../../core/constants/permission_codes.dart';
import '../../../../core/errors/exceptions.dart';
import '../../../../domain/services/audit_service.dart';
import '../../../../domain/services/permission_service.dart';
import '../../../../shared/database/app_database.dart';
import '../../../../shared/models/enums.dart';
import '../repositories/inventory_repository.dart';

/// Batches of an item plus its recent ledger movements (§4.8, §4.9).
class ListBatchesUseCase {
  const ListBatchesUseCase(this._repo, this._permissions);

  final InventoryRepository _repo;
  final PermissionService _permissions;

  Future<({List<BatchRow> batches, List<StockMovementRow> movements})> call(
    String itemId, {
    String? actingRoleId,
  }) async {
    await _permissions.requireRolePermission(
        _repo.database, actingRoleId, Perm.stockView);
    final batches = await _repo.batchesForItem(itemId);
    final movements = await _repo.movementsForItem(itemId);
    return (batches: batches, movements: movements);
  }
}

/// Manual batch entry (§4.8): posts an opening `stock_adjustment` movement via
/// the ledger. Requires `stock.adjust` (manual stock entry permission).
class AddBatchUseCase {
  const AddBatchUseCase(this._repo, this._permissions, this._audit);

  final InventoryRepository _repo;
  final PermissionService _permissions;
  final AuditService _audit;

  Future<BatchRow> call(
    AddBatchInput input, {
    String? actingUserId,
    String? actingRoleId,
  }) async {
    final db = _repo.database;
    await _permissions.requireRolePermission(db, actingRoleId, Perm.stockAdjust);
    if (actingUserId == null || actingUserId.isEmpty) {
      throw UnauthorizedException('بيانات المستخدم ناقصة للتسجيل');
    }
    if (input.batchNumber.trim().isEmpty) {
      throw ValidationException('رقم التشغيلة مطلوب');
    }
    if (input.quantityBase <= 0) {
      throw ValidationException('الكمية يجب أن تكون أكبر من صفر');
    }
    if (input.unitCostMicros < 0) {
      throw ValidationException('سعر التكلفة لا يمكن أن يكون سالبًا');
    }
    final item = await _repo.findItem(input.itemId);
    if (item == null) throw NotFoundException('المنتج رقم ${input.itemId} غير موجود');
    if (item.hasExpiry && input.expiryDate == null) {
      throw ValidationException('تاريخ الانتهاء مطلوب لمنتج بتاريخ صلاحية');
    }
    final batch = await _repo.insertBatch(input, actingUserId);
    await _audit.write(
      db,
      userId: actingUserId,
      action: AuditAction.create,
      entityType: 'batch',
      entityId: batch.id,
      after: {
        'item_id': batch.itemId,
        'batch_number': batch.batchNumber,
        'quantity_base': batch.quantityBase,
        'unit_cost_micros': batch.unitCostMicros,
        'expiry_date': batch.expiryDate,
      },
      note: 'إدخال تشغيلة: ${batch.batchNumber} للمنتج ${item.tradeName}',
    );
    return batch;
  }
}

/// Void a batch permission-guard (stock.adjust) + audit. The ledger
/// correction itself runs inside the repository transaction.
class VoidBatchUseCase {
  const VoidBatchUseCase(this._repo, this._permissions, this._audit);

  final InventoryRepository _repo;
  final PermissionService _permissions;
  final AuditService _audit;

  Future<void> call(
    String id, {
    String? actingUserId,
    String? actingRoleId,
  }) async {
    final db = _repo.database;
    await _permissions.requireRolePermission(db, actingRoleId, Perm.stockAdjust);
    if (actingUserId == null || actingUserId.isEmpty) {
      throw UnauthorizedException('بيانات المستخدم ناقصة للتسجيل');
    }
    await _repo.voidBatch(id, actingUserId);
    await _audit.write(
      db,
      userId: actingUserId,
      action: AuditAction.delete,
      entityType: 'batch',
      entityId: id,
      note: 'إلغاء تشغيلة $id',
    );
  }
}