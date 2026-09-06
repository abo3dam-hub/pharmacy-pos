import '../../../../core/constants/permission_codes.dart';
import '../../../../core/errors/exceptions.dart';
import '../../../../core/money/money.dart';
import '../../../../domain/services/audit_service.dart';
import '../../../../domain/services/permission_service.dart';
import '../../../../shared/database/app_database.dart';
import '../../../../shared/models/enums.dart';
import '../repositories/inventory_repository.dart';
import 'create_item.dart' show itemAuditJson;

/// Supported multi-selection grid operations (§22, "Bulk Actions").
enum BulkOperation { changeCategory, changeShelfLocation, adjustPricePercent }

/// Bulk-edit request over a selection of item ids. Exactly one of
/// [categoryId] / [shelfLocation] / [basisPoints] applies, per [operation].
class BulkUpdateInput {
  const BulkUpdateInput({
    required this.operation,
    required this.itemIds,
    this.categoryId,
    this.shelfLocation,
    this.basisPoints = 0,
  });

  final BulkOperation operation;
  final List<String> itemIds;
  final String? categoryId;
  final String? shelfLocation;
  final int basisPoints;

  bool get isValidRequest => itemIds.isNotEmpty;
}

/// Bulk grid editing (§22): audited per row + one summarised `bulk_op` audit
/// record (§17). Price-by-% requires the `change_prices` permission and
/// applies integer Money math only.
class BulkUpdateItemsUseCase {
  const BulkUpdateItemsUseCase(this._repo, this._permissions, this._audit);

  final InventoryRepository _repo;
  final PermissionService _permissions;
  final AuditService _audit;

  Future<int> call(
    BulkUpdateInput input, {
    String? actingUserId,
    String? actingRoleId,
  }) async {
    final db = _repo.database;
    if (!input.isValidRequest) {
      throw ValidationException('حدد منتجًا واحدًا على الأقل');
    }
    if (actingUserId == null || actingUserId.isEmpty) {
      throw UnauthorizedException('بيانات المستخدم ناقصة للتسجيل');
    }
    await _validate(db, input, actingRoleId);

    var updated = 0;
    for (final id in input.itemIds) {
      final row = await _repo.findItem(id);
      if (row == null) continue;
      final before = itemAuditJson(row);
      final draft = await _draftFor(row, input);
      final afterRow = await _repo.updateItem(id, draft);
      await _audit.write(
        db,
        userId: actingUserId,
        action: input.operation == BulkOperation.adjustPricePercent
            ? AuditAction.priceChange
            : AuditAction.update,
        entityType: 'item',
        entityId: id,
        before: before,
        after: itemAuditJson(afterRow),
        note: _auditNote(input),
      );
      updated++;
    }

    await _audit.write(
      db,
      userId: actingUserId,
      action: AuditAction.bulkOp,
      entityType: 'item',
      entityId: 'bulk:${DateTime.now().microsecondsSinceEpoch}',
      after: {
        'operation': input.operation.name,
        'count': input.itemIds.length,
        'updated': updated,
        'basis_points': input.basisPoints,
        'category_id': input.categoryId,
        'shelf_location': input.shelfLocation,
      },
      note: 'عملية جماعية (${input.operation.name}) على $updated منتجات',
    );
    return updated;
  }

  Future<void> _validate(
    AppDatabase db,
    BulkUpdateInput input,
    String? actingRoleId,
  ) async {
    final forbidden = 'التصنيف الهدف مطلوب';
    switch (input.operation) {
      case BulkOperation.changeCategory:
        await _permissions.requireRolePermission(
            db, actingRoleId, Perm.inventoryEdit);
        if (input.categoryId == null || input.categoryId!.isEmpty) {
          throw ValidationException(forbidden);
        }
      case BulkOperation.changeShelfLocation:
        await _permissions.requireRolePermission(
            db, actingRoleId, Perm.inventoryEdit);
        if (input.shelfLocation == null || input.shelfLocation!.trim().isEmpty) {
          throw ValidationException('الموقع على الرف مطلوب');
        }
      case BulkOperation.adjustPricePercent:
        await _permissions.requireRolePermission(
            db, actingRoleId, Perm.changePrices);
        if (input.basisPoints == 0) {
          throw ValidationException('نسبة التعديل يجب ألا تكون صفرًا');
        }
    }
  }

  Future<ItemDraft> _draftFor(ItemRow row, BulkUpdateInput input) async {
    final units = await _repo.itemUnitsFor(row.id);
    final relation = units == null
        ? null
        : ItemUnitRelation(
            baseUnitId: units.baseUnitId,
            largeUnitId: units.largeUnitId,
            unitsPerLarge: units.unitsPerLarge,
          );
    final draft = ItemDraft.fromRow(row, units: relation);

    switch (input.operation) {
      case BulkOperation.changeCategory:
        return draft.copyWith(
            tradeName: row.tradeName,
            categoryId: input.categoryId,
            subCategoryId: null);
      case BulkOperation.changeShelfLocation:
        return draft.copyWith(shelfLocation: input.shelfLocation);
      case BulkOperation.adjustPricePercent:
        return _applyPercent(draft, input.basisPoints);
    }
  }

  ItemDraft _applyPercent(ItemDraft draft, int basisPoints) {
    int adj(int micros) => Money.fromUnits(micros).addPercent(basisPoints).units;
    return ItemDraft(
      primaryBarcode: draft.primaryBarcode,
      secondaryBarcode: draft.secondaryBarcode,
      tradeName: draft.tradeName,
      tradeNameEn: draft.tradeNameEn,
      scientificName: draft.scientificName,
      activeIngredient: draft.activeIngredient,
      equivalentDrug: draft.equivalentDrug,
      manufacturerId: draft.manufacturerId,
      categoryId: draft.categoryId,
      subCategoryId: draft.subCategoryId,
      therapeuticGroupId: draft.therapeuticGroupId,
      pharmaForm: draft.pharmaForm,
      dose: draft.dose,
      sizeVolume: draft.sizeVolume,
      shelfLocation: draft.shelfLocation,
      hasExpiry: draft.hasExpiry,
      printBarcodeLabel: draft.printBarcodeLabel,
      isOtc: draft.isOtc,
      isControlledDrug: draft.isControlledDrug,
      scaleBarcodeAlert: draft.scaleBarcodeAlert,
      lockAutoPriceUpdate: draft.lockAutoPriceUpdate,
      requiresPrescription: draft.requiresPrescription,
      costMicros: draft.costMicros,
      purchaseDiscountBasisPoints: draft.purchaseDiscountBasisPoints,
      sellingPriceMicros: adj(draft.sellingPriceMicros),
      subUnitPriceMicros: adj(draft.subUnitPriceMicros),
      wholesalePriceMicros: adj(draft.wholesalePriceMicros),
      halfWholesalePriceMicros: adj(draft.halfWholesalePriceMicros),
      customPrice1Micros: adj(draft.customPrice1Micros),
      customPrice2Micros: adj(draft.customPrice2Micros),
      vatRateBasisPoints: draft.vatRateBasisPoints,
      minimumStockBase: draft.minimumStockBase,
      maximumStockBase: draft.maximumStockBase,
      usageInstructions: draft.usageInstructions,
      generalNotes: draft.generalNotes,
      licenseNumber: draft.licenseNumber,
      units: draft.units,
    );
  }

  String _auditNote(BulkUpdateInput input) => switch (input.operation) {
        BulkOperation.changeCategory => 'تغيير تصنيف جماعي إلى ${input.categoryId}',
        BulkOperation.changeShelfLocation =>
          'تغيير موقع رف جماعي إلى ${input.shelfLocation}',
        BulkOperation.adjustPricePercent =>
          'تعديل أسعار جماعي (${input.basisPoints} نقطة أساس)',
      };
}