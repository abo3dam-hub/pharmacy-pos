import '../../../../core/data_grid/page_request.dart';
import '../../../../domain/services/stock_service.dart';
import '../../../../shared/database/app_database.dart';
import '../entities/inventory_item.dart';

/// Base unit + large unit relation of an item (§4.6).
class ItemUnitRelation {
  const ItemUnitRelation({
    required this.baseUnitId,
    required this.largeUnitId,
    required this.unitsPerLarge,
  });

  final String baseUnitId;
  final String largeUnitId;
  final int unitsPerLarge;
}

/// Batch-entry input (§4.8): a new batch with its initial on-hand quantity.
/// The matching `opening` stock movement is created by the use case.
class AddBatchInput {
  const AddBatchInput({
    required this.itemId,
    required this.batchNumber,
    this.expiryDate,
    required this.quantityBase,
    required this.unitCostMicros,
    this.receivedDate,
    this.supplierId,
    this.bonusQtyBase = 0,
    this.notes,
  });

  final String itemId;
  final String batchNumber;
  final int? expiryDate;
  final int quantityBase;
  final int unitCostMicros;
  final int? receivedDate;
  final String? supplierId;
  final int bonusQtyBase;
  final String? notes;
}

/// Stock adjustment request tracked via the ledger (§9, §10).
class StockAdjustInput {
  const StockAdjustInput({
    required this.itemId,
    required this.batchId,
    required this.movementType,
    required this.deltaBase,
    required this.unitCostMicros,
    this.note,
  });

  final String itemId;
  final String? batchId;
  final String movementType;
  final int deltaBase;
  final int unitCostMicros;
  final String? note;
}

/// Item create/update draft carrying every editable §5 column.
class ItemDraft {
  const ItemDraft({
    this.primaryBarcode,
    this.secondaryBarcode,
    required this.tradeName,
    this.tradeNameEn,
    this.scientificName,
    this.activeIngredient,
    this.equivalentDrug,
    this.manufacturerId,
    this.categoryId,
    this.pharmaForm,
    this.dose,
    this.sizeVolume,
    this.shelfLocation,
    this.hasExpiry = false,
    this.isControlledDrug = false,
    this.lockAutoPriceUpdate = false,
    this.requiresPrescription = false,
    this.costMicros = 0,
    this.purchaseDiscountBasisPoints = 0,
    this.sellingPriceMicros = 0,
    this.subUnitPriceMicros = 0,
    this.wholesalePriceMicros = 0,
    this.halfWholesalePriceMicros = 0,
    this.customPrice1Micros = 0,
    this.customPrice2Micros = 0,
    this.vatRateBasisPoints = 0,
    this.minimumStockBase = 0,
    this.maximumStockBase = 0,
    this.usageInstructions,
    this.generalNotes,
    this.licenseNumber,
    this.units,
this.supplierIds = const [],
    this.activeIngredientIds = const [],
    this.activeIngredientStrengths = const {},
    this.indicationIds = const [],
    this.partialSaleEnabled = false,
    this.sellablePartUnitId,
    this.partsPerFullProduct,
    this.sellablePartBaseQuantity,
    this.partialSaleMarkupBasisPoints,
    this.partialSalePriceMicros,
  });

  final String? primaryBarcode;
  final String? secondaryBarcode;
  final String tradeName;
  final String? tradeNameEn;
  final String? scientificName;
  final String? activeIngredient;
  final String? equivalentDrug;
  final String? manufacturerId;
  final String? categoryId;
  final String? pharmaForm;
  final String? dose;
  final String? sizeVolume;
  final String? shelfLocation;
  final bool hasExpiry;
  final bool isControlledDrug;
  final bool lockAutoPriceUpdate;
  final bool requiresPrescription;
  final int costMicros;
  final int purchaseDiscountBasisPoints;
  final int sellingPriceMicros;
  final int subUnitPriceMicros;
  final int wholesalePriceMicros;
  final int halfWholesalePriceMicros;
  final int customPrice1Micros;
  final int customPrice2Micros;
  final int vatRateBasisPoints;
  final int minimumStockBase;
  final int maximumStockBase;
  final String? usageInstructions;
  final String? generalNotes;
  final String? licenseNumber;
  final ItemUnitRelation? units;
  final List<String> supplierIds;
  final List<String> activeIngredientIds;

  /// Per-ingredient strength (العيار) keyed by active-ingredient id, e.g.
  /// `{'ai_1': '400 mg'}`. Only entries the pharmacist filled are present.
  final Map<String, String> activeIngredientStrengths;
  final List<String> indicationIds;
  final bool partialSaleEnabled;
  final String? sellablePartUnitId;
  final int? partsPerFullProduct;
  final int? sellablePartBaseQuantity;
  final int? partialSaleMarkupBasisPoints;

  /// Manual retail price of ONE sellable part (سعر بيع الجزء) in micro-units,
  /// or NULL for the automatic derived price. The override persists until the
  /// pharmacist explicitly returns to automatic mode (§P17).
  final int? partialSalePriceMicros;

  /// Rebuilds a draft from a persisted row (bulk edits, Excel import).
  factory ItemDraft.fromRow(
    ItemRow row, {
    ItemUnitRelation? units,
    List<String> supplierIds = const [],
    List<String> activeIngredientIds = const [],
    Map<String, String> activeIngredientStrengths = const {},
    List<String> indicationIds = const [],
  }) =>
      ItemDraft(
        primaryBarcode: row.primaryBarcode,
        secondaryBarcode: row.secondaryBarcode,
        tradeName: row.tradeName,
        tradeNameEn: row.tradeNameEn,
        scientificName: row.scientificName,
        activeIngredient: row.activeIngredient,
        equivalentDrug: row.equivalentDrug,
        manufacturerId: row.manufacturerId,
        categoryId: row.categoryId,
        pharmaForm: row.pharmaForm,
        dose: row.dose,
        sizeVolume: row.sizeVolume,
        shelfLocation: row.shelfLocation,
        hasExpiry: row.hasExpiry,
        isControlledDrug: row.isControlledDrug,
        lockAutoPriceUpdate: row.lockAutoPriceUpdate,
        requiresPrescription: row.requiresPrescription,
        costMicros: row.costMicros,
        purchaseDiscountBasisPoints: row.purchaseDiscountBasisPoints,
        sellingPriceMicros: row.sellingPriceMicros,
        subUnitPriceMicros: row.subUnitPriceMicros,
        wholesalePriceMicros: row.wholesalePriceMicros,
        halfWholesalePriceMicros: row.halfWholesalePriceMicros,
        customPrice1Micros: row.customPrice1Micros,
        customPrice2Micros: row.customPrice2Micros,
        vatRateBasisPoints: row.vatRateBasisPoints,
        minimumStockBase: row.minimumStockBase,
        maximumStockBase: row.maximumStockBase,
        usageInstructions: row.usageInstructions,
        generalNotes: row.generalNotes,
        licenseNumber: row.licenseNumber,
        units: units,
        supplierIds: supplierIds,
        activeIngredientIds: activeIngredientIds,
        activeIngredientStrengths: activeIngredientStrengths,
        indicationIds: indicationIds,
        partialSaleEnabled: row.partialSaleEnabled,
        sellablePartUnitId: row.sellablePartUnitId,
        partsPerFullProduct: row.partsPerFullProduct,
        sellablePartBaseQuantity: row.sellablePartBaseQuantity,
        partialSaleMarkupBasisPoints: row.partialSaleMarkupBasisPoints,
        partialSalePriceMicros: row.partialSalePriceMicros,
      );

  ItemDraft copyWith({
    String? tradeName,
    String? categoryId,
    String? shelfLocation,
    List<String>? supplierIds,
    List<String>? activeIngredientIds,
    List<String>? indicationIds,
    Map<String, String>? activeIngredientStrengths,
    String? activeIngredient,
  }) =>
      ItemDraft(
        primaryBarcode: primaryBarcode,
        secondaryBarcode: secondaryBarcode,
        tradeName: tradeName ?? this.tradeName,
        tradeNameEn: tradeNameEn,
        scientificName: scientificName,
        activeIngredient: activeIngredient ?? this.activeIngredient,
        equivalentDrug: equivalentDrug,
        manufacturerId: manufacturerId,
        categoryId: categoryId ?? this.categoryId,
        pharmaForm: pharmaForm,
        dose: dose,
        sizeVolume: sizeVolume,
        shelfLocation: shelfLocation ?? this.shelfLocation,
        hasExpiry: hasExpiry,
        isControlledDrug: isControlledDrug,
        lockAutoPriceUpdate: lockAutoPriceUpdate,
        requiresPrescription: requiresPrescription,
        costMicros: costMicros,
        purchaseDiscountBasisPoints: purchaseDiscountBasisPoints,
        sellingPriceMicros: sellingPriceMicros,
        subUnitPriceMicros: subUnitPriceMicros,
        wholesalePriceMicros: wholesalePriceMicros,
        halfWholesalePriceMicros: halfWholesalePriceMicros,
        customPrice1Micros: customPrice1Micros,
        customPrice2Micros: customPrice2Micros,
        vatRateBasisPoints: vatRateBasisPoints,
        minimumStockBase: minimumStockBase,
        maximumStockBase: maximumStockBase,
        usageInstructions: usageInstructions,
        generalNotes: generalNotes,
        licenseNumber: licenseNumber,
        units: units,
        supplierIds: supplierIds ?? this.supplierIds,
        activeIngredientIds: activeIngredientIds ?? this.activeIngredientIds,
        activeIngredientStrengths:
            activeIngredientStrengths ?? this.activeIngredientStrengths,
        indicationIds: indicationIds ?? this.indicationIds,
        partialSaleEnabled: partialSaleEnabled,
        sellablePartUnitId: sellablePartUnitId,
        partsPerFullProduct: partsPerFullProduct,
        sellablePartBaseQuantity: sellablePartBaseQuantity,
        partialSaleMarkupBasisPoints: partialSaleMarkupBasisPoints,
        partialSalePriceMicros: partialSalePriceMicros,
      );
}

/// Master-data draft shared by categories, manufacturers, units, active
/// ingredients and indications (§4.1–4.6). Sub-categories and therapeutic
/// groups were removed in Phase 18 (v12).
class MasterDataDraft {
  const MasterDataDraft({
    required this.name,
    this.nameEn,
    this.description,
    this.categoryId,
    this.country,
    this.phone,
    this.website,
    this.abbreviation,
  });

  final String name;
  final String? nameEn;
  final String? description;
  final String? categoryId;
  final String? country;
  final String? phone;
  final String? website;
  final String? abbreviation;
}

/// Data-access contract for the inventory feature. Mirrors the DAO layer so
/// use cases stay free of SQL; stock mutations go through the ledger.
abstract class InventoryRepository {
  AppDatabase get database;
  StockService get stockService;

  // Items (§4.7)
  Future<PageResult<ItemRow>> searchItems(
    PageRequest page, {
    String? categoryId,
    String? manufacturerId,
    bool? onlyActive,
  });

  /// Loads the complete item catalog in one round trip (no page-size ceiling)
  /// for the Excel export/import engine so a multi-thousand-row sheet never
  /// triggers a full-database scan per sheet row (§27, Phase 18.2A).
  Future<List<ItemRow>> allItems();
  Future<ItemRow?> findItem(String id);
  Future<ItemRow> createItem(ItemDraft draft);
  Future<ItemRow> updateItem(String id, ItemDraft draft);
  Future<void> setItemActive(String id, bool active);
  Future<ItemUnitRow?> itemUnitsFor(String itemId);
  Future<List<String>> supplierIdsForItem(String itemId);
  Future<List<String>> itemIdsForSupplier(String supplierId);

  // Named lookups for the items grid
  Future<CategoryRow?> categoryById(String id);
  Future<ManufacturerRow?> manufacturerById(String id);
  Future<UnitRow?> unitById(String id);

  // Categories (§4.3)
  Future<List<CategoryRow>> categories();
  Future<CategoryRow> createCategory(MasterDataDraft draft);
  Future<CategoryRow> updateCategory(String id, MasterDataDraft draft);
  Future<void> setCategoryActive(String id, bool active);

  // Manufacturers (§4.1)
  Future<List<ManufacturerRow>> manufacturers();
  Future<PageResult<ManufacturerRow>> searchManufacturers(PageRequest page);
  Future<ManufacturerRow> createManufacturer(MasterDataDraft draft);
  Future<ManufacturerRow> updateManufacturer(String id, MasterDataDraft draft);
  Future<void> setManufacturerActive(String id, bool active);

  // Units (§4.5)
  Future<List<UnitRow>> units({bool? activeOnly});
  Future<UnitRow> createUnit(MasterDataDraft draft);
  Future<UnitRow> updateUnit(String id, MasterDataDraft draft);

  // Active ingredients (§4.2b)
  Future<List<ActiveIngredientRow>> activeIngredients({bool? activeOnly});
  Future<ActiveIngredientRow> createActiveIngredient(MasterDataDraft draft);
  Future<ActiveIngredientRow> updateActiveIngredient(
      String id, MasterDataDraft draft);
  Future<void> setActiveIngredientActive(String id, bool active);

  // Indications (§4.2c)
  Future<List<IndicationRow>> indications({bool? activeOnly});
  Future<IndicationRow> createIndication(MasterDataDraft draft);
  Future<IndicationRow> updateIndication(String id, MasterDataDraft draft);
  Future<void> setIndicationActive(String id, bool active);

  // Per-item taxonomy relations
  Future<List<String>> activeIngredientIdsForItem(String itemId);
  Future<List<ItemActiveIngredientRow>> activeIngredientRelationsForItem(
      String itemId);
  Future<List<String>> indicationIdsForItem(String itemId);

  /// Batch projections used by the grid and the Excel export so relational
  /// taxonomy is resolved in one round trip per page.
Future<Map<String, List<ItemIngredientRef>>> activeIngredientRefsForItems(
    Set<String> itemIds);
  Future<Map<String, List<String>>> indicationNamesForItems(
    Set<String> itemIds);

  /// Bulk catalog projections for the import engine (Phase 18.2A): relational
  /// ingredient rows, indication ids and unit relations for a whole set of item
  /// ids, so blank-preserve and composite matching never query per item.
  Future<Map<String, List<ItemActiveIngredientRow>>>
      activeIngredientRelationsForItems(Set<String> itemIds);
  Future<Map<String, List<String>>> indicationIdsForItems(Set<String> itemIds);
  Future<Map<String, ItemUnitRow>> itemUnitsForItems(Set<String> itemIds);

  // Batches & ledger (§4.8, §4.9)
  Future<List<BatchRow>> batchesForItem(String itemId);
  Future<BatchRow?> findBatch(String id);
  Future<BatchRow> insertBatch(AddBatchInput input, String userId);
  Future<List<StockMovementRow>> movementsForItem(String itemId, {int limit});
  Future<void> applyStockAdjustment(StockAdjustInput input, String userId);
  Future<void> voidBatch(String id, String userId);
}