import '../../../../core/constants/permission_codes.dart';
import '../../../../core/errors/exceptions.dart';
import '../../../../domain/services/audit_service.dart';
import '../../../../domain/services/permission_service.dart';
import '../../../../shared/database/app_database.dart';
import '../../../../shared/models/enums.dart';
import '../repositories/inventory_repository.dart';

/// Creates an item with its full §5 profile. Requires `inventory.create` and
/// audits the creation (immutable trail, §17).
class CreateItemUseCase {
  const CreateItemUseCase(this._repo, this._permissions, this._audit);

  final InventoryRepository _repo;
  final PermissionService _permissions;
  final AuditService _audit;

  Future<ItemRow> call(
    ItemDraft draft, {
    String? actingUserId,
    String? actingRoleId,
  }) async {
    final db = _repo.database;
    await _permissions.requireRolePermission(db, actingRoleId, Perm.inventoryCreate);
    if (actingUserId == null || actingUserId.isEmpty) {
      throw UnauthorizedException('بيانات المستخدم ناقصة للتسجيل');
    }
    if (draft.tradeName.trim().isEmpty) {
      throw ValidationException('الاسم التجاري مطلوب');
    }
    final created = await _repo.createItem(draft);
    await _audit.write(
      db,
      userId: actingUserId,
      action: AuditAction.create,
      entityType: 'item',
      entityId: created.id,
      after: itemAuditJson(created),
      note: 'إنشاء منتج: ${created.tradeName}',
    );
    return created;
  }
}

/// Compact stable projection of an item for audit JSON (§17).
Map<String, Object?> itemAuditJson(ItemRow row) => {
      'trade_name': row.tradeName,
      'primary_barcode': row.primaryBarcode,
      'secondary_barcode': row.secondaryBarcode,
      'scientific_name': row.scientificName,
      'category_id': row.categoryId,
      'cost_micros': row.costMicros,
      'selling_price_micros': row.sellingPriceMicros,
      'wholesale_price_micros': row.wholesalePriceMicros,
      'minimum_stock_base': row.minimumStockBase,
      'maximum_stock_base': row.maximumStockBase,
      'is_active': row.isActive,
    };