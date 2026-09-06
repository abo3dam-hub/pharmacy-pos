import '../../../../core/constants/permission_codes.dart';
import '../../../../core/errors/exceptions.dart';
import '../../../../domain/services/audit_service.dart';
import '../../../../domain/services/permission_service.dart';
import '../../../../shared/database/app_database.dart';
import '../../../../shared/models/enums.dart';
import '../repositories/inventory_repository.dart';
import 'create_item.dart' show itemAuditJson;

/// Updates an item's §5 profile. Requires `inventory.edit`, audits the change,
/// and records an explicit `price_change` audit entry whenever master pricing
/// changed (§17, §23).
class UpdateItemUseCase {
  const UpdateItemUseCase(this._repo, this._permissions, this._audit);

  final InventoryRepository _repo;
  final PermissionService _permissions;
  final AuditService _audit;

  Future<ItemRow> call(
    String id,
    ItemDraft draft, {
    String? actingUserId,
    String? actingRoleId,
  }) async {
    final db = _repo.database;
    await _permissions.requireRolePermission(db, actingRoleId, Perm.inventoryEdit);
    if (actingUserId == null || actingUserId.isEmpty) {
      throw UnauthorizedException('بيانات المستخدم ناقصة للتسجيل');
    }
    final before = await _repo.findItem(id);
    if (before == null) throw NotFoundException('المنتج رقم $id غير موجود');
    if (draft.tradeName.trim().isEmpty) {
      throw ValidationException('الاسم التجاري مطلوب');
    }

    final after = await _repo.updateItem(id, draft);

    await _audit.write(
      db,
      userId: actingUserId,
      action: AuditAction.update,
      entityType: 'item',
      entityId: id,
      before: itemAuditJson(before),
      after: itemAuditJson(after),
      note: 'تعديل منتج: ${after.tradeName}',
    );
    if (!_samePricing(before, after)) {
      await _audit.write(
        db,
        userId: actingUserId,
        action: AuditAction.priceChange,
        entityType: 'item',
        entityId: id,
        before: ({
          'cost_micros': before.costMicros,
          'selling_price_micros': before.sellingPriceMicros,
          'sub_unit_price_micros': before.subUnitPriceMicros,
          'wholesale_price_micros': before.wholesalePriceMicros,
          'half_wholesale_price_micros': before.halfWholesalePriceMicros,
          'custom_price1_micros': before.customPrice1Micros,
          'custom_price2_micros': before.customPrice2Micros,
          'purchase_discount_basis_points': before.purchaseDiscountBasisPoints,
          'vat_rate_basis_points': before.vatRateBasisPoints,
        }),
        after: ({
          'cost_micros': after.costMicros,
          'selling_price_micros': after.sellingPriceMicros,
          'sub_unit_price_micros': after.subUnitPriceMicros,
          'wholesale_price_micros': after.wholesalePriceMicros,
          'half_wholesale_price_micros': after.halfWholesalePriceMicros,
          'custom_price1_micros': after.customPrice1Micros,
          'custom_price2_micros': after.customPrice2Micros,
          'purchase_discount_basis_points': after.purchaseDiscountBasisPoints,
          'vat_rate_basis_points': after.vatRateBasisPoints,
        }),
        note: 'تحديث أسعار المنتج: ${after.tradeName}',
      );
    }
    return after;
  }

  static bool _samePricing(ItemRow a, ItemRow b) =>
      a.costMicros == b.costMicros &&
      a.sellingPriceMicros == b.sellingPriceMicros &&
      a.subUnitPriceMicros == b.subUnitPriceMicros &&
      a.wholesalePriceMicros == b.wholesalePriceMicros &&
      a.halfWholesalePriceMicros == b.halfWholesalePriceMicros &&
      a.customPrice1Micros == b.customPrice1Micros &&
      a.customPrice2Micros == b.customPrice2Micros &&
      a.purchaseDiscountBasisPoints == b.purchaseDiscountBasisPoints &&
      a.vatRateBasisPoints == b.vatRateBasisPoints;
}