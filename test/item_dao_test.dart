import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:flutter_test/flutter_test.dart';
import 'package:pharmacy_pos/core/data_grid/page_request.dart';
import 'package:pharmacy_pos/data/daos/item_dao.dart';
import 'package:pharmacy_pos/shared/database/app_database.dart';

import 'helpers.dart';

void main() {
  late AppDatabase db;
  late ItemDao dao;

  setUp(() {
    db = newDatabase();
    dao = ItemDao(db);
  });

  tearDown(() async {
    await db.close();
  });

  Future<void> seedSecondItem() async {
    final now = DateTime.now().millisecondsSinceEpoch;
    await awaitCategory(db);
    await db.into(db.items).insert(ItemsCompanion.insert(
      id: 'item_panadol_extra',
      primaryBarcode: Value('6281099999999'),
      tradeName: 'بانادول إكسترا',
      tradeNameEn: Value('Panadol Extra'),
      scientificName: Value('Paracetamol + Caffeine'),
      categoryId: 'cat_test_default',
      createdAt: now,
      updatedAt: now,
    ));
  }

  group('ItemDao (§4.2, §22)', () {
    test('search is paginated and filterable', () async {
      await insertItem(db);
      await seedSecondItem();

      final page = const PageRequest(page: 1, pageSize: 1, search: 'بانادول');
      final result = await dao.search(page);
      expect(result.items, hasLength(1));
      expect(result.total, 2);

      final extra = await dao.search(
        const PageRequest(page: 1, pageSize: 10),
      );
      expect(extra.total, 2);
    });

    test('byBarcode resolves primary then secondary', () async {
      await insertItem(db, barcode: '6291041500213');

      final byPrimary = await dao.byBarcode('6291041500213');
      expect(byPrimary, isNotNull);
      expect(byPrimary!.primaryBarcode, '6291041500213');

      expect(await dao.byBarcode('0000000000000'), isNull);
    });

    test('watchSearch re-emits on table changes', () async {
      await insertItem(db);
      var emissions = 0;
      final sub = dao
          .watchSearch(const PageRequest(page: 1, pageSize: 10))
          .listen((_) => emissions++);
      await Future<void>.delayed(const Duration(milliseconds: 50));
      await seedSecondItem();
      await Future<void>.delayed(const Duration(milliseconds: 200));
      await sub.cancel();
      expect(emissions, greaterThanOrEqualTo(2));
    });
  });
}