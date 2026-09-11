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

  test('alternativeCandidates: relational-primary, flat only for legacy items',
      () async {
    final candidates = await dao.alternativeCandidates(itemId: 'item_req');
    final ids = {for (final c in candidates) c.id};
    expect(ids, isNotEmpty);
    // Relational junction sharing drives candidate generation.
    expect(ids, contains('item_t1'));
    expect(ids, contains('item_t3'));
    expect(ids, isNot(contains('item_legacy')),
        reason: 'item_req has relational ingredients → the flat free-text '
            'fallback is not consulted (relational is primary, Phase 18.1)');
    expect(ids, isNot(contains('item_other')),
        reason: 'no shared ingredient → not a candidate (no therapeutic group)');
    expect(candidates.any((c) => c.id == 'item_out'), isFalse,
        reason: 'unavailable items are excluded from the candidate set');

    // A legacy item (no relational ingredients) still gets the flat fallback.
    final legacyCandidates =
        await dao.alternativeCandidates(itemId: 'item_legacy');
    final legacyIds = {for (final c in legacyCandidates) c.id};
    expect(legacyIds, contains('item_req'),
        reason: 'legacy flat activeIngredient fallback still supplies candidates');
  });

  test('smartAlternatives ranks tiers and drops unrelated / empty stock',
      () async {
    final requested = (await dao.byId('item_req'))!;
    final alts = await repo.smartAlternatives(requested);

    // item_other shares nothing → never ranked; item_out has no stock → dropped;
    // item_legacy is not a candidate for a relational requested item (18.1).
    expect(alts.map((a) => a.item.id), isNot(contains('item_other')));
    expect(alts.map((a) => a.item.id), isNot(contains('item_out')));
    expect(alts.map((a) => a.item.id), isNot(contains('item_legacy')));

    expect(
        alts.map((a) => a.item.id),
        containsAll(['item_t1', 'item_t2', 'item_t3']));
    expect(alts.firstWhere((a) => a.item.id == 'item_t1').tier,
        SmartAlternativeTier.tier1);
    expect(alts.firstWhere((a) => a.item.id == 'item_t2').tier,
        SmartAlternativeTier.tier2);
    expect(alts.firstWhere((a) => a.item.id == 'item_t3').tier,
        SmartAlternativeTier.tier3,
        reason: 'multi-ingredient candidate keeps tier3 via relational names');

    // Legacy requested item → the flat fallback still ranks equivalents.
    final legacyRequested = (await dao.byId('item_legacy'))!;
    final legacyAlts = await repo.smartAlternatives(legacyRequested);
    expect(legacyAlts.map((a) => a.item.id), contains('item_req'));
    expect(legacyAlts.firstWhere((a) => a.item.id == 'item_req').tier,
        SmartAlternativeTier.tier1,
        reason: 'legacy flat ingredient ranks via the flat fallback token');
  });

  test('same-manufacturer candidates and ranking tie-break', () async {
    await _item(
      db,
      id: 'item_mfr',
      name: 'Panadol Extra',
      scientificName: 'Paracetamol',
      ingredient: null,
      dose: '500 mg',
      form: 'tablet',
      ingredients: ['ai_paracetamol'],
      stock: 9,
    );
    await _item(
      db,
      id: 'item_other_mfr',
      name: 'Mfr Competitor',
      scientificName: 'Paracetamol',
      ingredient: null,
      dose: '500 mg',
      form: 'tablet',
      ingredients: ['ai_paracetamol'],
      stock: 9,
    );
    final now = DateTime.now().millisecondsSinceEpoch;
    await db.into(db.manufacturers).insert(
          ManufacturersCompanion.insert(
              id: 'mfr_a', name: 'شركة أ', createdAt: now, updatedAt: now),
          mode: InsertMode.insertOrIgnore,
        );
    await db.into(db.manufacturers).insert(
          ManufacturersCompanion.insert(
              id: 'mfr_b', name: 'شركة ب', createdAt: now, updatedAt: now),
          mode: InsertMode.insertOrIgnore,
        );
    await (db.update(db.items)..where((i) => i.id.equals('item_req')))
        .write(const ItemsCompanion(manufacturerId: Value('mfr_a')));
    await (db.update(db.items)..where((i) => i.id.equals('item_mfr')))
        .write(const ItemsCompanion(manufacturerId: Value('mfr_a')));
    await (db.update(db.items)..where((i) => i.id.equals('item_other_mfr')))
        .write(const ItemsCompanion(manufacturerId: Value('mfr_b')));

    final candidates = await dao.alternativeCandidates(itemId: 'item_req');
    expect({for (final c in candidates) c.id}, containsAll(
        ['item_mfr', 'item_other_mfr']),
        reason: 'same-manufacturer products join the candidate superset');

    final req = (await dao.byId('item_req'))!;
    final alts = await repo.smartAlternatives(req);
    final ranked = alts.map((a) => a.item.id).toList();
    // Same tier + same stock → same-manufacturer (مfr_a) wins the tie-break.
    expect(ranked.indexOf('item_mfr'),
        lessThan(ranked.indexOf('item_other_mfr')));
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