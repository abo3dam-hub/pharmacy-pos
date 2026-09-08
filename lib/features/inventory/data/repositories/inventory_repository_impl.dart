import 'package:drift/drift.dart' hide isNull;
import 'package:sqlite3/sqlite3.dart' show SqliteException;

import '../../../../core/data_grid/page_request.dart';
import '../../../../core/errors/exceptions.dart';
import '../../../../core/money/money.dart';
import '../../../../core/util/ids.dart';
import '../../../../data/daos/batch_dao.dart';
import '../../../../data/daos/category_dao.dart';
import '../../../../data/daos/item_dao.dart';
import '../../../../data/daos/item_supplier_dao.dart';
import '../../../../data/daos/manufacturer_dao.dart';
import '../../../../data/daos/stock_movement_dao.dart';
import '../../../../data/daos/therapeutic_group_dao.dart';
import '../../../../data/daos/unit_dao.dart';
import '../../../../domain/services/stock_service.dart';
import '../../../../shared/database/app_database.dart';
import '../../../../shared/models/enums.dart';
import '../../domain/repositories/inventory_repository.dart';

/// Drift-backed implementation of [InventoryRepository]. All stock mutations
/// flow through the append-only ledger (via [StockService]), never as direct
/// table writes (§9, §10).
class InventoryRepositoryImpl implements InventoryRepository {
  const InventoryRepositoryImpl(
    this._db,
    this._itemDao,
    this._categoryDao,
    this._manufacturerDao,
    this._groupDao,
    this._unitDao,
    this._batchDao,
    this._movementDao,
    this._itemSupplierDao,
    this._stock,
  );

  final AppDatabase _db;
  final ItemDao _itemDao;
  final CategoryDao _categoryDao;
  final ManufacturerDao _manufacturerDao;
  final TherapeuticGroupDao _groupDao;
  final UnitDao _unitDao;
  final BatchDao _batchDao;
  final StockMovementDao _movementDao;
  final ItemSupplierDao _itemSupplierDao;
  final StockService _stock;

  @override
  AppDatabase get database => _db;

  @override
  StockService get stockService => _stock;

  // ----- Items -----

  @override
  Future<PageResult<ItemRow>> searchItems(
    PageRequest page, {
    String? categoryId,
    String? manufacturerId,
    bool? onlyActive,
  }) =>
      _itemDao.search(page,
          categoryId: categoryId,
          manufacturerId: manufacturerId,
          onlyActive: onlyActive);

  @override
  Future<ItemRow?> findItem(String id) => _itemDao.byId(id);

  @override
  Future<ItemUnitRow?> itemUnitsFor(String itemId) => (_db.select(_db.itemUnits)
        ..where((u) => u.itemId.equals(itemId)))
      .getSingleOrNull();

  @override
  Future<List<String>> supplierIdsForItem(String itemId) =>
      _itemSupplierDao.supplierIdsForItem(itemId);

  @override
  Future<ItemRow> createItem(ItemDraft draft) async {
    final id = ItemDao.newItemId();
    final now = DateTime.now().millisecondsSinceEpoch;
    await _guarded(() => _db.transaction(() async {
          await _db
              .into(_db.items)
              .insert(_toInsertCompanion(draft, id: id, at: now));
          await _applyUnits(draft.units, itemId: id);
          await _itemSupplierDao.setForItem(id, draft.supplierIds);
        }));
    final row = await _itemDao.byId(id);
    if (row == null) throw NotFoundException('المنتج لم يُحفظ');
    return row;
  }

  @override
  Future<ItemRow> updateItem(String id, ItemDraft draft) async {
    final existing = await _itemDao.byId(id);
    if (existing == null) throw NotFoundException('المنتج رقم $id غير موجود');
    final now = DateTime.now().millisecondsSinceEpoch;
    await _guarded(() => _db.transaction(() async {
          await (_db.update(_db.items)..where((i) => i.id.equals(id)))
              .write(_toUpdateCompanion(draft, at: now));
          // Keep the existing unit relation when the update does not carry one
          // (e.g. bulk category/shelf edits); `createItem` still requires units.
          if (draft.units != null) {
            await _applyUnits(draft.units, itemId: id);
          }
          await _itemSupplierDao.setForItem(id, draft.supplierIds);
        }));
    final row = await _itemDao.byId(id);
    if (row == null) throw NotFoundException('المنتج رقم $id غير موجود');
    return row;
  }

  @override
  Future<void> setItemActive(String id, bool active) =>
      _itemDao.setActive(id, active);

  Future<void> _applyUnits(ItemUnitRelation? relation, {required String itemId}) async {
    if (relation == null) {
      throw ValidationException('وحدة القياس مطلوبة للمنتج');
    }
    await _unitDao.setBaseLargeRelation(
      itemId,
      baseUnitId: relation.baseUnitId,
      largeUnitId: relation.largeUnitId,
      unitsPerLarge: relation.unitsPerLarge,
    );
  }

  /// Maps raw SQLite constraint errors (e.g. a duplicate unique barcode) onto
  /// the domain exception hierarchy so the UI can render a specific message
  /// instead of a generic save error.
  Future<T> _guarded<T>(Future<T> Function() action) async {
    try {
      return await action();
    } on SqliteException catch (e) {
      // SQLITE_CONSTRAINT (19) / SQLITE_CONSTRAINT_UNIQUE (2067).
      if (e.extendedResultCode == 2067 || e.resultCode == 19) {
        throw DuplicateException('البيانات موجودة مسبقًا (ربما الباركود مستخدم بالفعل)');
      }
      throw DatabaseException('فشل حفظ المنتج في قاعدة البيانات', cause: e);
    }
  }

  ItemsCompanion _toInsertCompanion(ItemDraft d,
      {required String id, required int at}) {
    return ItemsCompanion.insert(
      id: id,
      primaryBarcode: Value(d.primaryBarcode),
      secondaryBarcode: Value(d.secondaryBarcode),
      tradeName: d.tradeName,
      tradeNameEn: Value(d.tradeNameEn),
      scientificName: Value(d.scientificName),
      activeIngredient: Value(d.activeIngredient),
      equivalentDrug: Value(d.equivalentDrug),
      manufacturerId: Value(d.manufacturerId),
      categoryId: d.categoryId,
      subCategoryId: Value(d.subCategoryId),
      therapeuticGroupId: Value(d.therapeuticGroupId),
      pharmaForm: Value(d.pharmaForm),
      dose: Value(d.dose),
      sizeVolume: Value(d.sizeVolume),
      shelfLocation: Value(d.shelfLocation),
      hasExpiry: Value(d.hasExpiry),
      printBarcodeLabel: Value(d.printBarcodeLabel),
      isOtc: Value(d.isOtc),
      isControlledDrug: Value(d.isControlledDrug),
      scaleBarcodeAlert: Value(d.scaleBarcodeAlert),
      lockAutoPriceUpdate: Value(d.lockAutoPriceUpdate),
      requiresPrescription: Value(d.requiresPrescription),
      costMicros: Value(d.costMicros),
      purchaseDiscountBasisPoints: Value(d.purchaseDiscountBasisPoints),
      sellingPriceMicros: Value(d.sellingPriceMicros),
      subUnitPriceMicros: Value(d.subUnitPriceMicros),
      wholesalePriceMicros: Value(d.wholesalePriceMicros),
      halfWholesalePriceMicros: Value(d.halfWholesalePriceMicros),
      customPrice1Micros: Value(d.customPrice1Micros),
      customPrice2Micros: Value(d.customPrice2Micros),
      vatRateBasisPoints: Value(d.vatRateBasisPoints),
      profitMarginBasisPoints: Value(marginFor(d.costMicros, d.sellingPriceMicros)),
      minimumStockBase: Value(d.minimumStockBase),
      maximumStockBase: Value(d.maximumStockBase),
      usageInstructions: Value(d.usageInstructions),
      generalNotes: Value(d.generalNotes),
      licenseNumber: Value(d.licenseNumber),
      partialSaleEnabled: Value(d.partialSaleEnabled),
      sellablePartUnitId: Value(d.sellablePartUnitId),
      partsPerFullProduct: Value(d.partsPerFullProduct),
      sellablePartBaseQuantity: Value(d.sellablePartBaseQuantity),
      partialSaleMarkupBasisPoints: Value(d.partialSaleMarkupBasisPoints),
      createdAt: at,
      updatedAt: at,
    );
  }

  ItemsCompanion _toUpdateCompanion(ItemDraft d, {required int at}) {
    return ItemsCompanion(
      primaryBarcode: Value(d.primaryBarcode),
      secondaryBarcode: Value(d.secondaryBarcode),
      tradeName: Value(d.tradeName),
      tradeNameEn: Value(d.tradeNameEn),
      scientificName: Value(d.scientificName),
      activeIngredient: Value(d.activeIngredient),
      equivalentDrug: Value(d.equivalentDrug),
      manufacturerId: Value(d.manufacturerId),
      categoryId: Value(d.categoryId),
      subCategoryId: Value(d.subCategoryId),
      therapeuticGroupId: Value(d.therapeuticGroupId),
      pharmaForm: Value(d.pharmaForm),
      dose: Value(d.dose),
      sizeVolume: Value(d.sizeVolume),
      shelfLocation: Value(d.shelfLocation),
      hasExpiry: Value(d.hasExpiry),
      printBarcodeLabel: Value(d.printBarcodeLabel),
      isOtc: Value(d.isOtc),
      isControlledDrug: Value(d.isControlledDrug),
      scaleBarcodeAlert: Value(d.scaleBarcodeAlert),
      lockAutoPriceUpdate: Value(d.lockAutoPriceUpdate),
      requiresPrescription: Value(d.requiresPrescription),
      costMicros: Value(d.costMicros),
      purchaseDiscountBasisPoints: Value(d.purchaseDiscountBasisPoints),
      sellingPriceMicros: Value(d.sellingPriceMicros),
      subUnitPriceMicros: Value(d.subUnitPriceMicros),
      wholesalePriceMicros: Value(d.wholesalePriceMicros),
      halfWholesalePriceMicros: Value(d.halfWholesalePriceMicros),
      customPrice1Micros: Value(d.customPrice1Micros),
      customPrice2Micros: Value(d.customPrice2Micros),
      vatRateBasisPoints: Value(d.vatRateBasisPoints),
      profitMarginBasisPoints: Value(marginFor(d.costMicros, d.sellingPriceMicros)),
      minimumStockBase: Value(d.minimumStockBase),
      maximumStockBase: Value(d.maximumStockBase),
      usageInstructions: Value(d.usageInstructions),
      generalNotes: Value(d.generalNotes),
      licenseNumber: Value(d.licenseNumber),
      partialSaleEnabled: Value(d.partialSaleEnabled),
      sellablePartUnitId: Value(d.sellablePartUnitId),
      partsPerFullProduct: Value(d.partsPerFullProduct),
      sellablePartBaseQuantity: Value(d.sellablePartBaseQuantity),
      partialSaleMarkupBasisPoints: Value(d.partialSaleMarkupBasisPoints),
      updatedAt: Value(at),
    );
  }

  /// Derived profit margin = (retail − cost) ÷ cost, in basis points (§8).
  /// Computed with integer math only via [Money]; 0 when cost is not yet set.
  static int marginFor(int costMicros, int sellingMicros) {
    if (costMicros <= 0) return 0;
    final cost = Money.fromUnits(costMicros);
    final price = Money.fromUnits(sellingMicros);
    final diff = price - cost;
    return diff.timesRatio(10000, costMicros).units;
  }

  // ----- Lookups -----

  @override
  Future<CategoryRow?> categoryById(String id) => _categoryDao.byId(id);

  @override
  Future<SubCategoryRow?> subCategoryById(String id) =>
      (_db.select(_db.subCategories)..where((s) => s.id.equals(id)))
          .getSingleOrNull();

  @override
  Future<ManufacturerRow?> manufacturerById(String id) =>
      (_db.select(_db.manufacturers)..where((m) => m.id.equals(id)))
          .getSingleOrNull();

  @override
  Future<TherapeuticGroupRow?> groupById(String id) => _groupDao.byId(id);

  @override
  Future<UnitRow?> unitById(String id) => _unitDao.byId(id);

  // ----- Categories & sub-categories -----

  @override
  Future<List<CategoryRow>> categories() => _categoryDao.all();

  @override
  Future<List<SubCategoryRow>> subCategories(String categoryId) =>
      _categoryDao.subCategories(categoryId);

  @override
  Future<CategoryRow> createCategory(MasterDataDraft draft) async {
    final id = CategoryDao.newCategoryId();
    final now = DateTime.now().millisecondsSinceEpoch;
    final row = CategoryRow(
      id: id,
      name: draft.name.trim(),
      nameEn: draft.nameEn,
      description: draft.description,
      isActive: true,
      createdAt: now,
      updatedAt: now,
    );
    await _categoryDao.insertCategory(row);
    return row;
  }

  @override
  Future<CategoryRow> updateCategory(String id, MasterDataDraft draft) async {
    final existing = await _categoryDao.byId(id);
    if (existing == null) throw NotFoundException('التصنيف رقم $id غير موجود');
    final row = CategoryRow(
      id: existing.id,
      name: draft.name.trim(),
      nameEn: draft.nameEn,
      description: draft.description,
      isActive: existing.isActive,
      createdAt: existing.createdAt,
      updatedAt: DateTime.now().millisecondsSinceEpoch,
    );
    await _categoryDao.updateCategory(row);
    return row;
  }

  @override
  Future<void> setCategoryActive(String id, bool active) =>
      _categoryDao.setCategoryActive(id, active);

  @override
  Future<SubCategoryRow> createSubCategory(MasterDataDraft draft) async {
    if (draft.categoryId == null) {
      throw ValidationException('اختر التصنيف الرئيسي أولًا');
    }
    final id = CategoryDao.newSubCategoryId();
    final now = DateTime.now().millisecondsSinceEpoch;
    final row = SubCategoryRow(
      id: id,
      categoryId: draft.categoryId!,
      name: draft.name.trim(),
      nameEn: draft.nameEn,
      description: draft.description,
      isActive: true,
      createdAt: now,
      updatedAt: now,
    );
    await _categoryDao.insertSubCategory(row);
    return row;
  }

  @override
  Future<SubCategoryRow> updateSubCategory(
      String id, MasterDataDraft draft) async {
    final existing = await (_db.select(_db.subCategories)
          ..where((s) => s.id.equals(id)))
        .getSingleOrNull();
    if (existing == null) throw NotFoundException('التصنيف الفرعي رقم $id غير موجود');
    final row = SubCategoryRow(
      id: existing.id,
      categoryId: draft.categoryId ?? existing.categoryId,
      name: draft.name.trim(),
      nameEn: draft.nameEn,
      description: draft.description,
      isActive: existing.isActive,
      createdAt: existing.createdAt,
      updatedAt: DateTime.now().millisecondsSinceEpoch,
    );
    await _categoryDao.updateSubCategory(row);
    return row;
  }

  @override
  Future<void> setSubCategoryActive(String id, bool active) =>
      _categoryDao.setSubCategoryActive(id, active);

  // ----- Manufacturers -----

  @override
  Future<List<ManufacturerRow>> manufacturers() => _manufacturerDao.all();

  @override
  Future<PageResult<ManufacturerRow>> searchManufacturers(PageRequest page) =>
      _manufacturerDao.search(page);

  @override
  Future<ManufacturerRow> createManufacturer(MasterDataDraft draft) async {
    final id = ManufacturerDao.newManufacturerId();
    final now = DateTime.now().millisecondsSinceEpoch;
    final row = ManufacturerRow(
      id: id,
      name: draft.name.trim(),
      country: draft.country,
      phone: draft.phone,
      website: draft.website,
      notes: draft.description,
      isActive: true,
      createdAt: now,
      updatedAt: now,
    );
    await _manufacturerDao.insert(row);
    return row;
  }

  @override
  Future<ManufacturerRow> updateManufacturer(
      String id, MasterDataDraft draft) async {
    final existing = await (_db.select(_db.manufacturers)
          ..where((m) => m.id.equals(id)))
        .getSingleOrNull();
    if (existing == null) throw NotFoundException('الشركة رقم $id غير موجودة');
    final row = ManufacturerRow(
      id: existing.id,
      name: draft.name.trim(),
      country: draft.country,
      phone: draft.phone,
      website: draft.website,
      notes: draft.description,
      isActive: existing.isActive,
      createdAt: existing.createdAt,
      updatedAt: DateTime.now().millisecondsSinceEpoch,
    );
    await _manufacturerDao.update(row);
    return row;
  }

  @override
  Future<void> setManufacturerActive(String id, bool active) =>
      _manufacturerDao.setActive(id, active);

  // ----- Therapeutic groups -----

  @override
  Future<List<TherapeuticGroupRow>> therapeuticGroups() => _groupDao.all();

  @override
  Future<TherapeuticGroupRow> createTherapeuticGroup(MasterDataDraft draft) async {
    final id = TherapeuticGroupDao.newGroupId();
    final now = DateTime.now().millisecondsSinceEpoch;
    final row = TherapeuticGroupRow(
      id: id,
      name: draft.name.trim(),
      description: draft.description,
      isActive: true,
      createdAt: now,
      updatedAt: now,
    );
    await _groupDao.insert(row);
    return row;
  }

  @override
  Future<TherapeuticGroupRow> updateTherapeuticGroup(
      String id, MasterDataDraft draft) async {
    final existing = await _groupDao.byId(id);
    if (existing == null) throw NotFoundException('المجموعة رقم $id غير موجودة');
    final row = TherapeuticGroupRow(
      id: existing.id,
      name: draft.name.trim(),
      description: draft.description,
      isActive: existing.isActive,
      createdAt: existing.createdAt,
      updatedAt: DateTime.now().millisecondsSinceEpoch,
    );
    await _groupDao.update(row);
    return row;
  }

  @override
  Future<void> setTherapeuticGroupActive(String id, bool active) =>
      _groupDao.setActive(id, active);

  // ----- Units -----

  @override
  Future<List<UnitRow>> units({bool? activeOnly}) => _unitDao.all(activeOnly: activeOnly);

  @override
  Future<UnitRow> createUnit(MasterDataDraft draft) async {
    final id = UnitDao.newUnitId();
    final now = DateTime.now().millisecondsSinceEpoch;
    final row = UnitRow(
      id: id,
      name: draft.name.trim(),
      nameEn: draft.nameEn,
      abbreviation: draft.abbreviation,
      description: draft.description,
      isActive: true,
      createdAt: now,
      updatedAt: now,
    );
    await _unitDao.insert(row);
    return row;
  }

  @override
  Future<UnitRow> updateUnit(String id, MasterDataDraft draft) async {
    final existing = await _unitDao.byId(id);
    if (existing == null) throw NotFoundException('الوحدة رقم $id غير موجودة');
    final row = UnitRow(
      id: existing.id,
      name: draft.name.trim(),
      nameEn: draft.nameEn,
      abbreviation: draft.abbreviation,
      description: draft.description,
      isActive: existing.isActive,
      createdAt: existing.createdAt,
      updatedAt: DateTime.now().millisecondsSinceEpoch,
    );
    await _unitDao.update(row);
    return row;
  }

  // ----- Batches & ledger -----

  @override
  Future<List<BatchRow>> batchesForItem(String itemId) => _batchDao.byItem(itemId);

  @override
  Future<BatchRow?> findBatch(String id) => _batchDao.byId(id);

  @override
  Future<List<StockMovementRow>> movementsForItem(String itemId, {int limit = 50}) =>
      _movementDao.byItem(itemId, limit: limit);

  /// Manual batch entry (§4.8): inserts the batch and opens its balance with a
  /// `stock_adjustment` ledger movement inside one transaction (§26). Purchase
  /// receive batches arrive through the purchase flow (later phase).
  @override
  Future<BatchRow> insertBatch(AddBatchInput input, String userId) async {
    final id = BatchDao.newBatchId();
    final now = DateTime.now().millisecondsSinceEpoch;
    await _db.transaction(() async {
      await _batchDao.insert(BatchRow(
        id: id,
        itemId: input.itemId,
        batchNumber: input.batchNumber.trim(),
        productionDate: null,
        expiryDate: input.expiryDate,
        // Balance is established by the ledger movement below, never seeded
        // directly, so `quantity_base` stays a live ledger-backed balance (§4.8).
        quantityBase: 0,
        originalQuantityBase: input.quantityBase,
        unitCostMicros: input.unitCostMicros,
        bonusQtyBase: input.bonusQtyBase,
        supplierId: input.supplierId,
        receivedDate: input.receivedDate ?? now,
        notes: input.notes,
        isVoided: false,
        createdAt: now,
        updatedAt: now,
      ));
      await _stock.applyMovement(
        _db,
        itemId: input.itemId,
        batchId: id,
        movementType: MovementType.stock_adjustment,
        quantityBaseSigned: input.quantityBase,
        unitCostMicros: input.unitCostMicros,
        refType: 'batch',
        refId: id,
        userId: userId,
        note: input.notes ?? 'إدخال تشغيلة يدوي',
        atMillis: now,
      );
    });
    final row = await _batchDao.byId(id);
    if (row == null) throw NotFoundException('التشغيلة لم تُحفظ');
    return row;
  }

  /// Voiding a batch is a ledger operation: it flattens its remaining balance
  /// via a `manual_correction` movement and then flags the batch (§4.8).
  @override
  Future<void> voidBatch(String id, String userId) async {
    final batch = await _batchDao.byId(id);
    if (batch == null) throw NotFoundException('التشغيلة رقم $id غير موجودة');
    if (batch.quantityBase == 0) {
      await _batchDao.voidBatch(id);
      return;
    }
    await _db.transaction(() async {
      if (batch.quantityBase > 0) {
        await _stock.applyMovement(
          _db,
          itemId: batch.itemId,
          batchId: id,
          movementType: MovementType.manual_correction,
          quantityBaseSigned: -batch.quantityBase,
          unitCostMicros: batch.unitCostMicros,
          refType: 'void_batch',
          refId: id,
          userId: userId,
          note: 'إلغاء تشغيلة',
          atMillis: DateTime.now().millisecondsSinceEpoch,
        );
      }
      await _batchDao.voidBatch(id);
    });
  }

  @override
  Future<void> applyStockAdjustment(StockAdjustInput input, String userId) async {
    final item = await _itemDao.byId(input.itemId);
    if (item == null) throw NotFoundException('المنتج رقم ${input.itemId} غير موجود');
    await _db.transaction(() async {
      await _stock.applyMovement(
        _db,
        itemId: input.itemId,
        batchId: input.batchId,
        movementType: MovementType.values.byName(input.movementType),
        quantityBaseSigned: input.deltaBase,
        unitCostMicros: input.unitCostMicros,
        refType: 'adjustment',
        refId: newId('adj'),
        userId: userId,
        note: input.note,
      );
    });
  }
}