import 'package:drift/drift.dart';
import 'categories.dart';
import 'manufacturers.dart';
import 'sub_categories.dart';
import 'therapeutic_groups.dart';

/// Items / medicines master data (§4.7, §5).
///
/// Every field from the specification is an explicit column. Manufacturer,
/// main category, sub-category and therapeutic group are FKs to standalone
/// tables — never free text. Pricing here is the *master/default* profile;
/// batch/purchase-specific historical cost lives on `batches` (§8).
@DataClassName('ItemRow')
@TableIndex(name: 'idx_items_trade_name', columns: {#tradeName})
@TableIndex(name: 'idx_items_trade_name_en', columns: {#tradeNameEn})
@TableIndex(name: 'idx_items_scientific_name', columns: {#scientificName})
@TableIndex(name: 'idx_items_active_ingredient', columns: {#activeIngredient})
@TableIndex(name: 'idx_items_category', columns: {#categoryId})
@TableIndex(name: 'idx_items_sub_category', columns: {#subCategoryId})
@TableIndex(name: 'idx_items_therapeutic_group', columns: {#therapeuticGroupId})
@TableIndex(name: 'idx_items_manufacturer', columns: {#manufacturerId})
class Items extends Table {
  TextColumn get id => text()();
  TextColumn get primaryBarcode => text().nullable().unique()();
  TextColumn get secondaryBarcode => text().nullable().unique()();
  TextColumn get tradeName => text()();
  TextColumn get tradeNameEn => text().nullable()();
  TextColumn get scientificName => text().nullable()();
  TextColumn get activeIngredient => text().nullable()();
  TextColumn get equivalentDrug => text().nullable()();
  TextColumn get manufacturerId =>
      text().nullable().references(Manufacturers, #id)();

  /// Main category (التصنيف الرئيسي) — NN per §4.7.
  TextColumn get categoryId => text().references(Categories, #id)();
  TextColumn get subCategoryId =>
      text().nullable().references(SubCategories, #id)();
  TextColumn get therapeuticGroupId =>
      text().nullable().references(TherapeuticGroups, #id)();
  TextColumn get pharmaForm => text().nullable()();
  TextColumn get dose => text().nullable()();
  TextColumn get sizeVolume => text().nullable()();
  TextColumn get shelfLocation => text().nullable()();

  BoolColumn get hasExpiry => boolean().withDefault(const Constant(false))();
  BoolColumn get printBarcodeLabel =>
      boolean().withDefault(const Constant(false))();
  BoolColumn get isOtc => boolean().withDefault(const Constant(false))();
  BoolColumn get isControlledDrug =>
      boolean().withDefault(const Constant(false))();
  BoolColumn get scaleBarcodeAlert =>
      boolean().withDefault(const Constant(false))();
  BoolColumn get lockAutoPriceUpdate =>
      boolean().withDefault(const Constant(false))();
  BoolColumn get requiresPrescription =>
      boolean().withDefault(const Constant(false))();

  /// Master/default pricing — integer micro-units (scale 4), never REAL (§8,
  /// §23). Percentages are integer basis points (100 bp = 1%).
  IntColumn get costMicros => integer().withDefault(const Constant(0))();
  IntColumn get purchaseDiscountBasisPoints =>
      integer().withDefault(const Constant(0))();
  IntColumn get sellingPriceMicros => integer().withDefault(const Constant(0))();
  IntColumn get subUnitPriceMicros =>
      integer().withDefault(const Constant(0))();
  IntColumn get wholesalePriceMicros =>
      integer().withDefault(const Constant(0))();
  IntColumn get halfWholesalePriceMicros =>
      integer().withDefault(const Constant(0))();
  IntColumn get customPrice1Micros =>
      integer().withDefault(const Constant(0))();
  IntColumn get customPrice2Micros =>
      integer().withDefault(const Constant(0))();
  IntColumn get vatRateBasisPoints =>
      integer().withDefault(const Constant(0))();

  /// Derived profit margin (computed by the price-change workflow, audited).
  IntColumn get profitMarginBasisPoints =>
      integer().withDefault(const Constant(0))();

  /// Stock policy bounds expressed in base units (§7).
  IntColumn get minimumStockBase => integer().withDefault(const Constant(0))();
  IntColumn get maximumStockBase => integer().withDefault(const Constant(0))();

  /// Derived/cache total stock in base units. The authoritative source is the
  /// [stock_movements](StockMovements) ledger (§10); this is re-synced from it.
  IntColumn get currentStockBase => integer().withDefault(const Constant(0))();

  TextColumn get usageInstructions => text().nullable()();
  TextColumn get generalNotes => text().nullable()();
  TextColumn get licenseNumber => text().nullable()();

  BoolColumn get isActive => boolean().withDefault(const Constant(true))();
  IntColumn get createdAt => integer()();
  IntColumn get updatedAt => integer()();

  @override
  Set<Column> get primaryKey => {id};
}