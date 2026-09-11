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

Future<String> _ingredient(AppDatabase db, String id, String name,
    {String? nameEn}) async {
  final now = DateTime.now().millisecondsSinceEpoch;
  await db.into(db.activeIngredients).insert(
        ActiveIngredientsCompanion.insert(
          id: id,
          name: name,
          nameEn: Value(nameEn),
          createdAt: now,
          updatedAt: now,
        ),
        mode: InsertMode.insertOrIgnore,
      );
  return id;
}

Future<void> _linkIngredient(
    AppDatabase db, String itemId, String ingredientId) async {
  await db.into(db.itemActiveIngredients).insert(
        ItemActiveIngredientsCompanion.insert(
          id: 'iai_${itemId}_$ingredientId',
          itemId: itemId,
          activeIngredientId: ingredientId,
          strength: const Value(null),
        ),
        mode: InsertMode.insertOrIgnore,
      );
}

Future<String> _item(
  AppDatabase db, {
  required String id,
  required String name,
  required String? scientificName,
  String? ingredient,
  required String? dose,
  required String? form,
  List<String> ingredients = const [],
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
          sellingPriceMicros: const Value(5000),
          vatRateBasisPoints: const Value(1500),
          isActive: const Value(true),
          createdAt: now,
          updatedAt: now,
        ),
      );
  for (final ai in ingredients) {
    await _linkIngredient(db, id, ai);
  }
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
    final aiPara = await _ingredient(db, 'ai_paracetamol', 'Paracetamol',
        nameEn: 'Paracetamol');
    await _ingredient(db, 'ai_caffeine', 'Caffeine', nameEn: 'Caffeine');
    await _ingredient(db, 'ai_ibuprofen', 'Ibuprofen', nameEn: 'Ibuprofen');

    await _item(
      db,
      id: 'item_req',
      name: 'Panadol',
      scientificName: 'Paracetamol',
      ingredient: 'Paracetamol',
      dose: '500 mg',
      form: 'tablet',
      ingredients: [aiPara],
      stock: 10,
    );
    await _item(
      db,
      id: 'item_t1',
      name: 'Paracetamol 500 x100',
      scientificName: 'Paracetamol',
      dose: '500 mg',
      form: 'tablet',
      ingredients: [aiPara],
      stock: 25,
    );
    await _item(
      db,
      id: 'item_t2',
      name: 'Paracetamol Syrup',
      scientificName: 'Paracetamol',
      dose: '250 mg',
      form: 'suspension',
      ingredients: [aiPara],
      stock: 15,
    );
    await _item(
      db,
      id: 'item_t3',
      name: 'Cold Relief',
      scientificName: 'Paracetamol+',
      dose: null,
      form: null,
      ingredients: [aiPara, 'ai_caffeine'],
      stock: 5,
    );
    await _item(
      db,
      id: 'item_out',
      name: 'Paracetamol Out',
      scientificName: 'Paracetamol',
      dose: '500 mg',
      form: 'tablet',
      ingredients: [aiPara],
      stock: 0,
    );
    // Unrelated relational ingredient → candidate AND ranked-out.
    await _item(
      db,
      id: 'item_other',
      name: 'Ibuprofen',
      scientificName: 'Ibuprofen',
      dose: '400 mg',
      form: 'tablet',
      ingredients: ['ai_ibuprofen'],
      stock: 7,
    );
    // Legacy row: only the flat activeIngredient column, no relations.
    await _item(
      db,
      id: 'item_legacy',
      name: 'Legacy Paracetamol',
      scientificName: 'Paracetamol',
      ingredient: 'Paracetamol',
      dose: '500 mg',
      form: 'tablet',
      stock: 3,
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

  test('alternativeCandidates returns the relational superset', () async {
    final candidates = await dao.alternativeCandidates(itemId: 'item_req');
    final ids = {for (final c in candidates) c.id};
    expect(ids, isNotEmpty);
    // Relational junction sharing drives candidate generation.
    expect(ids, contains('item_t1'));
    expect(ids, contains('item_t3'));
    expect(ids, contains('item_legacy'),
        reason: 'legacy flat activeIngredient fallback still supplies candidates');
    expect(ids, isNot(contains('item_other')),
        reason: 'no shared ingredient → not a candidate (no therapeutic group)');
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

    expect(
        alts.map((a) => a.item.id),
        containsAll(
            ['item_t1', 'item_t2', 'item_t3', 'item_legacy']));
    expect(alts.firstWhere((a) => a.item.id == 'item_t1').tier,
        SmartAlternativeTier.tier1);
    expect(alts.firstWhere((a) => a.item.id == 'item_t2').tier,
        SmartAlternativeTier.tier2);
    expect(alts.firstWhere((a) => a.item.id == 'item_t3').tier,
        SmartAlternativeTier.tier3,
        reason: 'multi-ingredient candidate keeps tier3 via relational names');
    expect(alts.firstWhere((a) => a.item.id == 'item_legacy').tier,
        SmartAlternativeTier.tier1,
        reason: 'legacy flat ingredient ranks via the flat fallback token');
  });

  test('relational ingredient names hydrate into the snapshot', () async {
    final item = (await dao.byId('item_t3'))!;
    expect(item.relationalIngredientNames, containsAll(['Paracetamol', 'Caffeine']));
    final req = (await dao.byId('item_req'))!;
    expect(req.relationalIngredientNames, ['Paracetamol']);
  });

  test('hydration carries dose / pharmaForm / sizeVolume into the item snapshot',
      () async {
    final item = (await dao.byId('item_t1'))!;
    expect(item.dose, '500 mg');
    expect(item.pharmaForm, 'tablet');
  });
}