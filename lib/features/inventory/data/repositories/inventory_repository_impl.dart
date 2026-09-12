import 'package:drift/drift.dart' hide isNull;
import 'package:sqlite3/sqlite3.dart' show SqliteException;

import '../../../../core/data_grid/page_request.dart';
import '../../../../core/errors/exceptions.dart';
import '../../../../core/money/money.dart';
import '../../../../core/util/ids.dart';
import '../../../../data/daos/active_ingredient_dao.dart';
import '../../../../data/daos/batch_dao.dart';
import '../../../../data/daos/category_dao.dart';
import '../../../../data/daos/indication_dao.dart';
import '../../../../data/daos/item_active_ingredient_dao.dart';
import '../../../../data/daos/item_dao.dart';
import '../../../../data/daos/item_indication_dao.dart';
import '../../../../data/daos/item_supplier_dao.dart';
import '../../../../data/daos/manufacturer_dao.dart';
import '../../../../data/daos/stock_movement_dao.dart';
import '../../../../data/daos/unit_dao.dart';
import '../../domain/entities/inventory_item.dart';
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
    this._unitDao,
    this._batchDao,
    this._movementDao,
    this._itemSupplierDao,
    this._stock,
    this._activeIngredientDao,
    this._indicationDao,
    this._itemActiveIngredientDao,
    this._itemIndicationDao,
  );

  final AppDatabase _db;
  final ItemDao _itemDao;
  final CategoryDao _categoryDao;
  final ManufacturerDao _manufacturerDao;
  final UnitDao _unitDao;
  final BatchDao _batchDao;
  final StockMovementDao _movementDao;
  final ItemSupplierDao _itemSupplierDao;
  final StockService _stock;
  final ActiveIngredientDao _activeIngredientDao;
  final IndicationDao _indicationDao;
  final ItemActiveIngredientDao _itemActiveIngredientDao;
  final ItemIndicationDao _itemIndicationDao;

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
    bool? inStockOnly,
  }) =>
      _itemDao.search(page,
          categoryId: categoryId,
          manufacturerId: manufacturerId,
          onlyActive: onlyActive,
          inStockOnly: inStockOnly);

  @override
  Future<List<ItemRow>> allItems() => (_db.select(
        _db.items,
      )..orderBy([(i) => OrderingTerm.asc(i.tradeName)])).get();

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
  Future<List<String>> itemIdsForSupplier(String supplierId) =>
      _itemSupplierDao.itemIdsForSupplier(supplierId);

  @override
  Future<ItemRow> createItem(ItemDraft draft) async {
    final id = ItemDao.newItemId();
    final now = DateTime.now().millisecondsSinceEpoch;
    final withSummary = await _syncIngredientSummary(draft);
    await _guarded(() => _db.transaction(() async {
          await _db
              .into(_db.items)
              .insert(_toInsertCompanion(withSummary, id: id, at: now));
          if (draft.units != null) {
            await _applyUnits(draft.units, itemId: id);
          }
          await _itemSupplierDao.setForItem(id, draft.supplierIds);
          await _itemActiveIngredientDao.setForItem(id, draft.activeIngredientIds,
              strengths: draft.activeIngredientStrengths);
          await _itemIndicationDao.setForItem(id, draft.indicationIds);
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
    final withSummary = await _syncIngredientSummary(draft);
    await _guarded(() => _db.transaction(() async {
          await (_db.update(_db.items)..where((i) => i.id.equals(id)))
              .write(_toUpdateCompanion(withSummary, at: now));
          // Keep the existing unit relation when the update does not carry one
          // (e.g. bulk category/shelf edits); units are optional under the
          // Phase 18 contract (trade name is the only required field).
          if (draft.units != null) {
            await _applyUnits(draft.units, itemId: id);
          }
          await _itemSupplierDao.setForItem(id, draft.supplierIds);
          await _itemActiveIngredientDao.setForItem(id, draft.activeIngredientIds,
              strengths: draft.activeIngredientStrengths);
          await _itemIndicationDao.setForItem(id, draft.indicationIds);
        }));
    final row = await _itemDao.byId(id);
    if (row == null) throw NotFoundException('المنتج رقم $id غير موجود');
    return row;
  }

  /// Keeps the denormalized `items.active_ingredient` column in step with the
  /// junction table: when the draft carries junction ids, rebuild the comma
  /// summary from the linked ingredient names (preserving legacy free-text
  /// when the form did not touch the taxonomy).
  Future<ItemDraft> _syncIngredientSummary(ItemDraft draft) async {
    if (draft.activeIngredientIds.isEmpty) return draft;
    final names = <String>[];
    for (final id in draft.activeIngredientIds.toSet()) {
      final row = await _activeIngredientDao.byId(id);
      if (row != null) names.add(row.name);
    }
    return draft.copyWith(
      activeIngredient: names.join(', '),
    );
  }

  @override
  Future<void> setItemActive(String id, bool active) =>
      _itemDao.setActive(id, active);

  /// Any persisted document (ledger, batch, invoice line or prescription line)
  /// pins an item into history. Deleting such an item would corrupt reports
  /// and stock bookkeeping, so it is rejected outright; discontinued products
  /// are deactivated instead (§28 soft delete).
  Future<bool> _itemHasHistory(String id) =>
      _db.customSelect(
        'SELECT (EXISTS(SELECT 1 FROM batches WHERE item_id = ?1 LIMIT 1))'
        ' + (EXISTS(SELECT 1 FROM stock_movements WHERE item_id = ?1 LIMIT 1))'
        ' + (EXISTS(SELECT 1 FROM sales_invoice_items WHERE item_id = ?1 LIMIT 1))'
        ' + (EXISTS(SELECT 1 FROM purchase_invoice_items WHERE item_id = ?1 LIMIT 1))'
        ' + (EXISTS(SELECT 1 FROM prescription_items WHERE item_id = ?1 LIMIT 1))'
        ' AS n',
        variables: [Variable(id)],
      ).getSingle().then((r) => r.read<int>('n') > 0);

  @override
  Future<void> deleteItem(String id) async {
    final item = await _itemDao.byId(id);
    if (item == null) throw NotFoundException('المنتج رقم $id غير موجود');
    if (item.currentStockBase != 0) {
      throw InvalidOperationException(
          'لا يمكن حذف منتج لديه مخزون؛ أوقفه واستهلك أو سوِّ مخزونه أولاً');
    }
    if (await _itemHasHistory(id)) {
      throw InvalidOperationException(
          'لا يمكن حذف منتج مرتبط بتشغيلات أو حركات أو فواتير؛ أوقفه بدلاً من ذلك');
    }
    await _guarded(() => _db.transaction(() async {
          await _deleteItemRelations(id);
          await (_db.delete(_db.items)..where((i) => i.id.equals(id))).go();
        }));
  }

  Future<void> _deleteItemRelations(String id) async {
    await (_db.delete(_db.itemSuppliers)..where((r) => r.itemId.equals(id)))
        .go();
    await (_db.delete(_db.itemActiveIngredients)
          ..where((r) => r.itemId.equals(id)))
        .go();
    await (_db.delete(_db.itemIndications)
          ..where((r) => r.itemId.equals(id)))
        .go();
    await (_db.delete(_db.itemUnits)..where((r) => r.itemId.equals(id))).go();
  }

  Future<void> _applyUnits(ItemUnitRelation? relation, {required String itemId}) async {
    if (relation == null) return;
    await _unitDao.setBaseLargeRelation(
      itemId,
      baseUnitId: relation.baseUnitId,
      largeUnitId: relation.largeUnitId,
      unitsPerLarge: relation.unitsPerLarge,
    );
  }

  /// Maps raw SQLite constraint errors onto the domain exception hierarchy so
  /// the UI can render a specific message instead of a generic save error:
  ///   * SQLITE_CONSTRAINT_UNIQUE   (extended 2067) → DuplicateException (e.g.
  ///     a barcode already used by another product, or a master-data name that
  ///     already exists),
  ///   * SQLITE_CONSTRAINT_FOREIGNKEY (extended 787) → ValidationException
  ///     (a referenced master row is missing or was deleted),
  ///   * anything else is reported as a DB failure with its own message.
  Future<T> _guarded<T>(Future<T> Function() action) async {
    try {
      return await action();
    } on SqliteException catch (e) {
      if (e.extendedResultCode == 2067) {
        throw DuplicateException('البيانات موجودة مسبقًا (ربما الاسم أو الباركود مستخدم بالفعل)');
      }
      if (e.extendedResultCode == 787) {
        throw ValidationException(
            'القيمة المختارة غير صالحة؛ تأكد من أن التصنيف والشركة والوحدة '
            'والمواد الفعالة الموجودة لا تزال متاحة');
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
      categoryId: Value(d.categoryId),
      pharmaForm: Value(d.pharmaForm),
      dose: Value(d.dose),
      sizeVolume: Value(d.sizeVolume),
      shelfLocation: Value(d.shelfLocation),
      hasExpiry: Value(d.hasExpiry),
      isControlledDrug: Value(d.isControlledDrug),
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
      partialSalePriceMicros: Value(d.partialSalePriceMicros),
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
      pharmaForm: Value(d.pharmaForm),
      dose: Value(d.dose),
      sizeVolume: Value(d.sizeVolume),
      shelfLocation: Value(d.shelfLocation),
      hasExpiry: Value(d.hasExpiry),
      isControlledDrug: Value(d.isControlledDrug),
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
      partialSalePriceMicros: Value(d.partialSalePriceMicros),
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
  Future<ManufacturerRow?> manufacturerById(String id) =>
      (_db.select(_db.manufacturers)..where((m) => m.id.equals(id)))
          .getSingleOrNull();

  @override
  Future<UnitRow?> unitById(String id) => _unitDao.byId(id);

  // ----- Categories -----

  @override
  Future<List<CategoryRow>> categories() => _categoryDao.all();

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
    await _guarded(() => _categoryDao.insertCategory(row));
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
    await _guarded(() => _categoryDao.updateCategory(row));
    return row;
  }

  @override
  Future<void> setCategoryActive(String id, bool active) =>
      _categoryDao.setCategoryActive(id, active);

  @override
  Future<void> deleteCategory(String id) async {
    final category = await _categoryDao.byId(id);
    if (category == null) throw NotFoundException('التصنيف رقم $id غير موجود');
    if (await _existsRaw(
        'SELECT 1 FROM items WHERE category_id = ?1 LIMIT 1', id: id)) {
      throw InvalidOperationException(
          'لا يمكن حذف تصنيف مرتبط بمنتجات؛ انقل المنتجات أو أوقف التصنيف');
    }
    await _guarded(() async {
      await (_db.delete(_db.categories)..where((c) => c.id.equals(id))).go();
    });
  }

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
    await _guarded(() => _manufacturerDao.insert(row));
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
    await _guarded(() => _manufacturerDao.update(row));
    return row;
  }

  @override
  Future<void> setManufacturerActive(String id, bool active) =>
      _manufacturerDao.setActive(id, active);

  @override
  Future<void> deleteManufacturer(String id) async {
    final manufacturer = await (_db.select(_db.manufacturers)
          ..where((m) => m.id.equals(id)))
        .getSingleOrNull();
    if (manufacturer == null) throw NotFoundException('الشركة رقم $id غير موجودة');
    if (await _existsRaw(
        'SELECT 1 FROM items WHERE manufacturer_id = ?1 LIMIT 1', id: id)) {
      throw InvalidOperationException(
          'لا يمكن حذف شركة مرتبطة بمنتجات؛ انقل منتجاتها أو أوقفها');
    }
    await _guarded(() async {
      await (_db.delete(_db.manufacturers)..where((m) => m.id.equals(id)))
          .go();
    });
  }

  // ----- Active ingredients -----

  @override
  Future<List<ActiveIngredientRow>> activeIngredients({bool? activeOnly}) =>
      _activeIngredientDao.all(activeOnly: activeOnly);

  @override
  Future<ActiveIngredientRow> createActiveIngredient(MasterDataDraft draft) async {
    final id = ActiveIngredientDao.newActiveIngredientId();
    final now = DateTime.now().millisecondsSinceEpoch;
    final row = ActiveIngredientRow(
      id: id,
      name: draft.name.trim(),
      nameEn: draft.nameEn,
      description: draft.description,
      isActive: true,
      createdAt: now,
      updatedAt: now,
    );
    await _guarded(() => _activeIngredientDao.insert(row));
    return row;
  }

  @override
  Future<ActiveIngredientRow> updateActiveIngredient(
      String id, MasterDataDraft draft) async {
    final existing = await _activeIngredientDao.byId(id);
    if (existing == null) throw NotFoundException('المادة الفعالة رقم $id غير موجودة');
    final row = ActiveIngredientRow(
      id: existing.id,
      name: draft.name.trim(),
      nameEn: draft.nameEn,
      description: draft.description,
      isActive: existing.isActive,
      createdAt: existing.createdAt,
      updatedAt: DateTime.now().millisecondsSinceEpoch,
    );
    await _guarded(() => _activeIngredientDao.update(row));
    return row;
  }

  @override
  Future<void> setActiveIngredientActive(String id, bool active) =>
      _activeIngredientDao.setActive(id, active);

  @override
  Future<void> deleteActiveIngredient(String id) async {
    final ingredient = await _activeIngredientDao.byId(id);
    if (ingredient == null) {
      throw NotFoundException('المادة الفعالة رقم $id غير موجودة');
    }
    if (await _existsRaw(
        'SELECT 1 FROM item_active_ingredients WHERE active_ingredient_id = ?1 '
        'LIMIT 1',
        id: id)) {
      throw InvalidOperationException(
          'لا يمكن حذف مادة فعالة مستخدمة في منتجات؛ أزل المادة من منتجاتها '
          'أو أوقفها');
    }
    await _guarded(() async {
      await (_db.delete(_db.activeIngredients)
            ..where((a) => a.id.equals(id)))
          .go();
    });
  }

  // ----- Indications -----

  @override
  Future<List<IndicationRow>> indications({bool? activeOnly}) =>
      _indicationDao.all(activeOnly: activeOnly);

  @override
  Future<IndicationRow> createIndication(MasterDataDraft draft) async {
    final id = IndicationDao.newIndicationId();
    final now = DateTime.now().millisecondsSinceEpoch;
    final row = IndicationRow(
      id: id,
      name: draft.name.trim(),
      nameEn: draft.nameEn,
      description: draft.description,
      isActive: true,
      createdAt: now,
      updatedAt: now,
    );
    await _guarded(() => _indicationDao.insert(row));
    return row;
  }

  @override
  Future<IndicationRow> updateIndication(String id, MasterDataDraft draft) async {
    final existing = await _indicationDao.byId(id);
    if (existing == null) throw NotFoundException('الاستطباب رقم $id غير موجود');
    final row = IndicationRow(
      id: existing.id,
      name: draft.name.trim(),
      nameEn: draft.nameEn,
      description: draft.description,
      isActive: existing.isActive,
      createdAt: existing.createdAt,
      updatedAt: DateTime.now().millisecondsSinceEpoch,
    );
    await _guarded(() => _indicationDao.update(row));
    return row;
  }

  @override
  Future<void> setIndicationActive(String id, bool active) =>
      _indicationDao.setActive(id, active);

  @override
  Future<void> deleteIndication(String id) async {
    final indication = await _indicationDao.byId(id);
    if (indication == null) throw NotFoundException('الاستطباب رقم $id غير موجود');
    if (await _existsRaw(
        'SELECT 1 FROM item_indications WHERE indication_id = ?1 LIMIT 1',
        id: id)) {
      throw InvalidOperationException(
          'لا يمكن حذف استطباب مستخدم في منتجات؛ أوقفه بدلاً من ذلك');
    }
    await _guarded(() async {
      await (_db.delete(_db.indications)..where((i) => i.id.equals(id))).go();
    });
  }

  // ----- Per-item taxonomy relations -----

  @override
  Future<List<String>> activeIngredientIdsForItem(String itemId) =>
      _itemActiveIngredientDao.activeIngredientIdsForItem(itemId);

  @override
  Future<List<ItemActiveIngredientRow>> activeIngredientRelationsForItem(
          String itemId) =>
      _itemActiveIngredientDao.forItem(itemId);

  @override
  Future<List<String>> indicationIdsForItem(String itemId) =>
      _itemIndicationDao.indicationIdsForItem(itemId);

  @override
  Future<Map<String, List<ItemActiveIngredientRow>>>
  activeIngredientRelationsForItems(Set<String> itemIds) async {
    if (itemIds.isEmpty) return const {};
    final rows = await _itemActiveIngredientDao.forItemIds(itemIds);
    final out = <String, List<ItemActiveIngredientRow>>{};
    for (final r in rows) {
      out.putIfAbsent(r.itemId, () => []).add(r);
    }
    return out;
  }

  @override
  Future<Map<String, List<String>>> indicationIdsForItems(
    Set<String> itemIds,
  ) async {
    if (itemIds.isEmpty) return const {};
    final rows = await _itemIndicationDao.forItemIds(itemIds);
    final out = <String, List<String>>{};
    for (final r in rows) {
      out.putIfAbsent(r.itemId, () => []).add(r.indicationId);
    }
    return out;
  }

  @override
  Future<Map<String, ItemUnitRow>> itemUnitsForItems(Set<String> itemIds) async {
    if (itemIds.isEmpty) return const {};
    final rows = await (_db.select(_db.itemUnits)
          ..where((u) => u.itemId.isIn(itemIds)))
        .get();
    return {for (final r in rows) r.itemId: r};
  }

  @override
  Future<Map<String, List<ItemIngredientRef>>> activeIngredientRefsForItems(
      Set<String> itemIds) async {
    if (itemIds.isEmpty) return const {};
    final names = {
      for (final r in await _activeIngredientDao.all()) r.id: r.name,
    };
    final relations = await _itemActiveIngredientDao.forItemIds(itemIds);
    final out = <String, List<ItemIngredientRef>>{};
    for (final r in relations) {
      out.putIfAbsent(r.itemId, () => []).add(ItemIngredientRef(
            name: names[r.activeIngredientId] ?? r.activeIngredientId,
            strength: r.strength,
          ));
    }
    return out;
  }

  @override
  Future<Map<String, List<String>>> indicationNamesForItems(
      Set<String> itemIds) async {
    if (itemIds.isEmpty) return const {};
    final names = {
      for (final r in await _indicationDao.all()) r.id: r.name,
    };
    final relations = await _itemIndicationDao.forItemIds(itemIds);
    final out = <String, List<String>>{};
    for (final r in relations) {
      out.putIfAbsent(r.itemId, () => []).add(names[r.indicationId] ?? r.indicationId);
    }
    return out;
  }

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
    await _guarded(() => _unitDao.insert(row));
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
    await _guarded(() => _unitDao.update(row));
    return row;
  }

  /// A unit is reusable only when nothing references it: item unit relations,
  /// items sold by the part, or a sales-history line typed in that unit.
  @override
  Future<void> deleteUnit(String id) async {
    final unit = await _unitDao.byId(id);
    if (unit == null) throw NotFoundException('الوحدة رقم $id غير موجودة');
    if (await _existsRaw(
            'SELECT 1 FROM item_units WHERE base_unit_id = ?1 '
            'OR large_unit_id = ?1 LIMIT 1',
            id: id) ||
        await _existsRaw(
            'SELECT 1 FROM items WHERE sellable_part_unit_id = ?1 LIMIT 1',
            id: id) ||
        await _existsRaw(
            'SELECT 1 FROM sales_invoice_items WHERE unit_type_id = ?1 LIMIT 1',
            id: id)) {
      throw InvalidOperationException(
          'لا يمكن حذف وحدة مستخدمة في منتجات أو فواتير؛ أوقفها بدلاً من ذلك');
    }
    await _guarded(() async {
      await (_db.delete(_db.units)..where((u) => u.id.equals(id))).go();
    });
  }

  Future<bool> _existsRaw(String sql, {required String id}) async {
    final result =
        await _db.customSelect(sql, variables: [Variable(id)]).getSingleOrNull();
    return result != null;
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