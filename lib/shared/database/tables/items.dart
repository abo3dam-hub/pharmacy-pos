import 'package:drift/drift.dart';
import 'categories.dart';
import 'manufacturers.dart';
import 'sub_categories.dart';
import 'therapeutic_groups.dart';
import 'units.dart';

@DataClassName('ItemRow')
@TableIndex(name: 'idx_items_trade_name', columns: {#tradeName})
@TableIndex(name: 'idx_items_category', columns: {#categoryId})
@TableIndex(name: 'idx_items_sub_category', columns: {#subCategoryId})
@TableIndex(name: 'idx_items_manufacturer', columns: {#manufacturerId})
class Items extends Table {
  TextColumn get id => text()();
  TextColumn get primaryBarcode => text().unique()();
  TextColumn get secondaryBarcode => text().nullable().unique()();
  TextColumn get tradeName => text()();
  TextColumn get tradeNameEn => text().nullable()();
  TextColumn get scientificName => text().nullable()();
  TextColumn get activeIngredient => text().nullable()();
  TextColumn get equivalentDrug => text().nullable()();
  TextColumn get manufacturerId =>
      text().nullable().references(Manufacturers, #id)();
  TextColumn get categoryId =>
      text().nullable().references(Categories, #id)();
  TextColumn get subCategoryId =>
      text().nullable().references(SubCategories, #id)();
  TextColumn get therapeuticGroupId =>
      text().nullable().references(TherapeuticGroups, #id)();
  TextColumn get pharmaForm => text().nullable()();
  TextColumn get dose => text().nullable()();
  TextColumn get sizeVolume => text().nullable()();
  TextColumn get shelfLocation => text().nullable()();

  /// Default base unit of measure for this item.
  TextColumn get baseUnitId => text().nullable().references(Units, #id)();

  BoolColumn get hasExpiry => boolean().withDefault(const Constant(true))();
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

  /// Financial values — stored as integer micro-units (scale 4), never REAL.
  IntColumn get costMicros => integer().withDefault(const Constant(0))();
  IntColumn get sellingPriceMicros => integer().withDefault(const Constant(0))();
  IntColumn get wholesalePriceMicros => integer().withDefault(const Constant(0))();
  IntColumn get minimumSalePriceMicros => integer().withDefault(const Constant(0))();
  IntColumn get vatRateBasisPoints => integer().withDefault(const Constant(0))();

  /// Percentages stored as integer basis points (100 bp = 1%).
  IntColumn get discountBasisPoints => integer().withDefault(const Constant(0))();
  IntColumn get maxDiscountBasisPoints =>
      integer().withDefault(const Constant(0))();
  IntColumn get profitTargetBasisPoints =>
      integer().withDefault(const Constant(0))();
  IntColumn get purchaseMarginBasisPoints =>
      integer().withDefault(const Constant(0))();
  IntColumn get saleMarginBasisPoints =>
      integer().withDefault(const Constant(0))();

  /// Stock policy bounds expressed in base units.
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