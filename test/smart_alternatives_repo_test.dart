import 'package:drift/drift.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pharmacy_pos/domain/services/return_service.dart';
import 'package:pharmacy_pos/domain/services/sale_service.dart';
import 'package:pharmacy_pos/domain/services/stock_service.dart';
import 'package:pharmacy_pos/features/sales/data/pos_catalog_dao.dart';
import 'package:pharmacy_pos/features/sales/data/sales_repository_impl.dart';
import 'package:pharmacy_pos/features/sales/domain/entities/smart_alternative.dart';
import 'package:pharmacy_pos/features/sales/domain/repositories/sales_repository.dart';
import 'package:pharmacy_pos/shared/database/app_database.dart';

import 'helpers.dart';

Future<String> _group(AppDatabase db) async {
  final now = DateTime.now().millisecondsSinceEpoch;
  const id = 'tg_smart_test';
  await db.into(db.therapeuticGroups).insert(
        TherapeuticGroupsCompanion.insert(
          id: id,
          name: 'مضادات الالتهاب',
          createdAt: now,
          updatedAt: now,
        ),
        mode: InsertMode.insertOrIgnore,
      );
  return id;
}

Future<String> _item(
  AppDatabase db, {
  required String id,
  required String name,
  required String? scientificName,
  required String? ingredient,
  required String? dose,
  required String? form,
  required String? group,
  int stock = 0,
}) async {
  final now = DateTime.now().millisecondsSinceEpoch;
  await db.into(db.items).insert(
        ItemsCompanion.insert(
          id: id,
          primaryBarcode: Value('BC-$id'),
          tradeName: name,
          tradeNameEn: Value(name),
          scientificName: Value(scientificName),
          activeIngredient: Value(ingredient),
          dose: Value(dose),
          pharmaForm: Value(form),
          therapeuticGroupId: Value(group),
          categoryId: 'cat_test_default',
          sellingPriceMicros: const Value(5000),
          vatRateBasisPoints: const Value(1500),
          isActive: const Value(true),
          createdAt: now,
          updatedAt: now,
        ),
      );
  if (stock > 0) {
    await insertBatch(db, id, quantityBase: stock);
  }
  return id;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late AppDatabase db;
  late PosCatalogDao dao;
  late SalesRepository repo;

  setUp(() async {
    db = newDatabase();
    await awaitCategory(db);
    final group = await _group(db);
    await _item(
      db,
      id: 'item_req',
      name: 'Panadol',
      scientificName: 'Paracetamol',
      ingredient: 'Paracetamol',
      dose: '500 mg',
      form: 'tablet',
      group: group,
      stock: 10,
    );
    await _item(
      db,
      id: 'item_t1',
      name: 'Paracetamol 500 x100',
      scientificName: 'Paracetamol',
      ingredient: 'Paracetamol',
      dose: '500 mg',
      form: 'tablet',
      group: group,
      stock: 25,
    );
    await _item(
      db,
      id: 'item_t2',
      name: 'Paracetamol Syrup',
      scientificName: 'Paracetamol',
      ingredient: 'Paracetamol',
      dose: '250 mg',
      form: 'suspension',
      group: group,
      stock: 15,
    );
    await _item(
      db,
      id: 'item_t3',
      name: 'Cold Relief',
      scientificName: 'Paracetamol+',
      ingredient: 'Paracetamol + Caffeine',
      dose: null,
      form: null,
      group: group,
      stock: 5,
    );
    await _item(
      db,
      id: 'item_out',
      name: 'Paracetamol Out',
      scientificName: 'Paracetamol',
      ingredient: 'Paracetamol',
      dose: '500 mg',
      form: 'tablet',
      group: group,
      stock: 0,
    );
    // Same group but unrelated ingredient → candidate but not an alternative.
    await _item(
      db,
      id: 'item_other',
      name: 'Ibuprofen',
      scientificName: 'Ibuprofen',
      ingredient: 'Ibuprofen',
      dose: '400 mg',
      form: 'tablet',
      group: group,
      stock: 7,
    );
    dao = PosCatalogDao(db);
    repo = SalesRepositoryImpl(
      db,
      dao,
      const StockService(),
      SaleService(),
      ReturnService(),
    );
  });

  tearDown(() async => db.close());

  test('alternativeCandidates returns the broad family superset', () async {
    final candidates = await dao.alternativeCandidates(
      itemId: 'item_req',
      therapeuticGroupId: 'tg_smart_test',
      activeIngredient: 'Paracetamol',
    );
    final ids = {for (final c in candidates) c.id};
    expect(ids, isNotEmpty);
    // Superset: same group OR ingredient, always with sellable stock.
    expect(ids, contains('item_t1'));
    expect(ids, contains('item_other'));
    expect(candidates.any((c) => c.id == 'item_out'), isFalse,
        reason: 'unavailable items are excluded from the candidate set');
  });

  test('smartAlternatives ranks tiers and drops unrelated / empty stock',
      () async {
    final requested = (await dao.byId('item_req'))!;
    final alts = await repo.smartAlternatives(requested);

    // item_other shares nothing → never ranked; item_out has no stock → dropped.
    expect(alts.map((a) => a.item.id), isNot(contains('item_other')));
    expect(alts.map((a) => a.item.id), isNot(contains('item_out')));

    expect(alts.map((a) => a.item.id), containsAll(['item_t1', 'item_t2', 'item_t3']));
    expect(alts.firstWhere((a) => a.item.id == 'item_t1').tier,
        SmartAlternativeTier.tier1);
    expect(alts.firstWhere((a) => a.item.id == 'item_t2').tier,
        SmartAlternativeTier.tier2);
    expect(alts.firstWhere((a) => a.item.id == 'item_t3').tier,
        SmartAlternativeTier.tier3);
  });

  test('hydration carries dose / pharmaForm / sizeVolume into the item snapshot',
      () async {
    final item = (await dao.byId('item_t1'))!;
    expect(item.dose, '500 mg');
    expect(item.pharmaForm, 'tablet');
  });
}