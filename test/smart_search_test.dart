import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:flutter_test/flutter_test.dart';
import 'package:pharmacy_pos/core/data_grid/page_request.dart';
import 'package:pharmacy_pos/core/util/smart_search.dart';
import 'package:pharmacy_pos/data/daos/active_ingredient_dao.dart';
import 'package:pharmacy_pos/data/daos/indication_dao.dart';
import 'package:pharmacy_pos/data/daos/item_active_ingredient_dao.dart';
import 'package:pharmacy_pos/data/daos/item_dao.dart';
import 'package:pharmacy_pos/data/daos/item_indication_dao.dart';
import 'package:pharmacy_pos/features/sales/data/pos_catalog_dao.dart';
import 'package:pharmacy_pos/shared/database/app_database.dart';

import 'helpers.dart';

void main() {
  late AppDatabase db;
  late ItemDao itemDao;
  late PosCatalogDao catalog;

  setUp(() {
    db = newDatabase();
    itemDao = ItemDao(db);
    catalog = PosCatalogDao(db);
  });

  tearDown(() async => db.close());

  Future<String> insertAmoxicillin() async {
    final now = DateTime.now().millisecondsSinceEpoch;
    await awaitCategory(db);
    final id = 'item_amox';
    await db.into(db.items).insert(ItemsCompanion.insert(
          id: id,
          primaryBarcode: Value('6291041500213'),
          tradeName: 'أموكسيسيلين',
          tradeNameEn: Value('Amoxicillin'),
          scientificName: Value('Amoxicillin'),
          categoryId: 'cat_test_default',
          currentStockBase: Value(5),
          createdAt: now,
          updatedAt: now,
        ));
    return id;
  }

  test('normalize folds alef/yeh variations and strips vocalisation', () {
    expect(SmartSearch.normalize('أَمُوكسيسيلين'), 'اموكسيسيلين');
    expect(SmartSearch.normalize('إبرة'), 'ابره');
    expect(SmartSearch.normalize('قلم رصاصٌ'), 'قلم رصاص');
    expect(SmartSearch.normalize('Jarch'), 'jarch');
  });

  test('ItemDao matches Arabic variations of stored names', () async {
    await insertAmoxicillin();

    final noHamza = await itemDao.search(
      const PageRequest(page: 1, pageSize: 10, search: 'اموكسيسيلين'),
    );
    expect(noHamza.total, 1);

    final sedLow = await itemDao.search(
      const PageRequest(page: 1, pageSize: 10, search: 'اموكسيسيلين'),
    );
    expect(sedLow.items.single.tradeName, 'أموكسيسيلين');
  });

  test('ItemDao finds items by linked ingredient name', () async {
    await insertAmoxicillin();
    final ingredientDao = ActiveIngredientDao(db);
    final junction = ItemActiveIngredientDao(db);
    final now = DateTime.now().millisecondsSinceEpoch;
    await ingredientDao.insert(ActiveIngredientRow(
      id: 'aig_parac',
      name: 'باراسيتامول',
      nameEn: 'Paracetamol',
      description: null,
      isActive: true,
      createdAt: now,
      updatedAt: now,
    ));
    await junction.setForItem('item_amox', ['aig_parac']);

    final byIngredient = await itemDao.search(
      const PageRequest(page: 1, pageSize: 10, search: 'باراسيتامول'),
    );
    expect(byIngredient.items.single.id, 'item_amox');
  });

  test('ItemDao finds items by linked indication name', () async {
    final itemId = await insertAmoxicillin();
    final indicationDao = IndicationDao(db);
    final junction = ItemIndicationDao(db);
    final now = DateTime.now().millisecondsSinceEpoch;
    await indicationDao.insert(IndicationRow(
      id: 'ind_head',
      name: 'صداع',
      nameEn: 'Headache',
      description: null,
      isActive: true,
      createdAt: now,
      updatedAt: now,
    ));
    await junction.setForItem(itemId, ['ind_head']);

    final byIndication = await itemDao.search(
      const PageRequest(page: 1, pageSize: 10, search: 'صداع'),
    );
    expect(byIndication.items.single.id, itemId);
  });

  test('PosCatalogDao normalizes variants and honors inStockOnly', () async {
    await insertAmoxicillin();
    await insertItem(db, barcode: '6281000000001');

    final normalized = await catalog.search(
      const PageRequest(page: 1, pageSize: 10, search: 'اموكسيسيلين'),
    );
    expect(normalized.items.single.tradeName, 'أموكسيسيلين');

    final stockOnly = await catalog.search(
      const PageRequest(page: 1, pageSize: 10, search: 'اموكسيسيلين'),
      inStockOnly: true,
    );
    expect(stockOnly.total, 1);

    final otherInStock = await catalog.search(
      const PageRequest(page: 1, pageSize: 10, search: '62810'),
    );
    expect(otherInStock.items, hasLength(1));
  });

  test('ItemDao and PosCatalogDao match by equivalent drug and manufacturer',
      () async {
    final now = DateTime.now().millisecondsSinceEpoch;
    await awaitCategory(db);
    await db.into(db.manufacturers).insert(ManufacturersCompanion.insert(
          id: 'manu_pharma',
          name: 'فارما العالمية',
          isActive: const Value(true),
          createdAt: now,
          updatedAt: now,
        ));
    await db.into(db.items).insert(ItemsCompanion.insert(
          id: 'item_equiv',
          tradeName: 'بانادول اكسترا',
          scientificName: const Value('Paracetamol + Caffeine'),
          equivalentDrug: const Value('Panadol Extra'),
          categoryId: 'cat_test_default',
          manufacturerId: const Value('manu_pharma'),
          currentStockBase: const Value(3),
          createdAt: now,
          updatedAt: now,
        ));

    final byEquivalent = await itemDao.search(
      const PageRequest(page: 1, pageSize: 10, search: 'Panadol'),
    );
    expect(byEquivalent.items.map((i) => i.id), contains('item_equiv'));

    final byManufacturerItem = await itemDao.search(
      const PageRequest(page: 1, pageSize: 10, search: 'فارما العالميه'),
    );
    expect(byManufacturerItem.items.map((i) => i.id), contains('item_equiv'),
        reason: 'manufacturer name search is alef-normalized and hits items');

    final byManufacturerPos = await catalog.search(
      const PageRequest(page: 1, pageSize: 10, search: 'فارما'),
    );
    expect(byManufacturerPos.items.map((i) => i.id), contains('item_equiv'));
  });

  test('relevance ranks exact/prefix trade-name matches first', () async {
    final now = DateTime.now().millisecondsSinceEpoch;
    await awaitCategory(db);
    Future<void> insert(String id, String name) async {
      await db.into(db.items).insert(ItemsCompanion.insert(
            id: id,
            tradeName: name,
            categoryId: 'cat_test_default',
            currentStockBase: const Value(1),
            createdAt: now,
            updatedAt: now,
          ));
    }

    await insert('item_exact', 'سولبادين');
    await insert('item_prefix', 'سولبادين اقراص');
    await insert('item_other', 'مسكن قوي مذاب في الماء للسولبادين');

    final result = await itemDao.search(
      const PageRequest(page: 1, pageSize: 10, search: 'سولبادين'),
    );
    expect(result.items.map((i) => i.id).take(2),
        ['item_exact', 'item_prefix'],
        reason: 'exact then prefix trade-name matches lead the search page');
  });
}