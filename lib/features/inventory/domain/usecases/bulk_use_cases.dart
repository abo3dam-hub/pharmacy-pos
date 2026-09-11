import '../../../../core/constants/permission_codes.dart';
import '../../../../core/data_grid/page_request.dart';
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

/// How a price adjustment is scoped over the catalog.
enum BulkPriceScope {
  /// Every product in the catalog (selection ignored).
  all,

  /// All products of a chosen manufacturer (selection ignored).
  manufacturer,

  /// All products linked to a chosen preferred supplier (selection ignored).
  supplier,

  /// Only the explicitly selected products.
  manual,
}

/// Bulk-edit request over a selection of item ids. Exactly one of
/// [categoryId] / [shelfLocation] / [basisPoints] applies, per [operation].
/// Price adjustments additionally carry a [priceScope] that expands the set
/// beyond the selection for the `all` / `manufacturer` / `supplier` modes.
class BulkUpdateInput {
  const BulkUpdateInput({
    required this.operation,
    required this.itemIds,
    this.categoryId,
    this.shelfLocation,
    this.basisPoints = 0,
    this.priceScope = BulkPriceScope.manual,
    this.priceManufacturerId,
    this.priceSupplierId,
  });

  final BulkOperation operation;
  final List<String> itemIds;
  final String? categoryId;
  final String? shelfLocation;
  final int basisPoints;
  final BulkPriceScope priceScope;
  final String? priceManufacturerId;
  final String? priceSupplierId;

  bool get isValidRequest =>
      itemIds.isNotEmpty || operation == BulkOperation.adjustPricePercent;
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

    final ids = await _operatingIds(db, input);
    var updated = 0;
    for (final id in ids) {
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
        'price_scope': input.priceScope.name,
        'price_manufacturer_id': input.priceManufacturerId,
        'price_supplier_id': input.priceSupplierId,
        'target': ids.length,
        'updated': updated,
        'selection': input.itemIds.length,
        'basis_points': input.basisPoints,
        'category_id': input.categoryId,
        'shelf_location': input.shelfLocation,
      },
      note: 'عملية جماعية (${input.operation.name} - ${input.priceScope.name})'
          ' على $updated منتجات',
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
        if (input.priceScope == BulkPriceScope.manufacturer &&
            (input.priceManufacturerId == null ||
                input.priceManufacturerId!.isEmpty)) {
          throw ValidationException('اختر المصنّع لتوسيع نطاق التعديل');
        }
        if (input.priceScope == BulkPriceScope.supplier &&
            (input.priceSupplierId == null ||
                input.priceSupplierId!.isEmpty)) {
          throw ValidationException('اختر المورد لنطاق التعديل');
        }
        if (input.priceScope == BulkPriceScope.manual &&
            input.itemIds.isEmpty) {
          throw ValidationException('حدد منتجًا واحدًا على الأقل');
        }
    }
  }

  /// Resolves the operating item set for the requested price scope. For the
  /// catalog-wide modes the selection is ignored and the scope is expanded.
  Future<List<String>> _operatingIds(
    AppDatabase db,
    BulkUpdateInput input,
  ) async {
    switch (input.priceScope) {
      case BulkPriceScope.manual:
        return input.itemIds;
      case BulkPriceScope.all:
      case BulkPriceScope.manufacturer:
        final page = await _repo.searchItems(
          const PageRequest(page: 1, pageSize: 1000000),
          manufacturerId: input.priceManufacturerId,
        );
        return [for (final row in page.items) row.id];
      case BulkPriceScope.supplier:
        return _repo.itemIdsForSupplier(input.priceSupplierId ??
            '');
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
    final supplierIds = await _repo.supplierIdsForItem(row.id);
    final draft = ItemDraft.fromRow(
        row, units: relation, supplierIds: supplierIds);

    switch (input.operation) {
      case BulkOperation.changeCategory:
        return draft.copyWith(tradeName: row.tradeName, categoryId: input.categoryId);
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
      pharmaForm: draft.pharmaForm,
      dose: draft.dose,
      sizeVolume: draft.sizeVolume,
      shelfLocation: draft.shelfLocation,
      hasExpiry: draft.hasExpiry,
      isControlledDrug: draft.isControlledDrug,
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
      supplierIds: draft.supplierIds,
    );
  }

  String _auditNote(BulkUpdateInput input) => switch (input.operation) {
        BulkOperation.changeCategory => 'تغيير تصنيف جماعي إلى ${input.categoryId}',
        BulkOperation.changeShelfLocation =>
          'تغيير موقع رف جماعي إلى ${input.shelfLocation}',
        BulkOperation.adjustPricePercent =>
          'تعديل أسعار جماعي (${input.basisPoints} نقطة أساس، '
              'نطاق ${input.priceScope.name})',
      };
}