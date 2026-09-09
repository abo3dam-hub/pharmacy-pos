import 'package:flutter_test/flutter_test.dart';
import 'package:pharmacy_pos/data/daos/active_ingredient_dao.dart';
import 'package:pharmacy_pos/data/daos/indication_dao.dart';
import 'package:pharmacy_pos/data/daos/item_active_ingredient_dao.dart';
import 'package:pharmacy_pos/data/daos/item_indication_dao.dart';
import 'package:pharmacy_pos/data/daos/batch_dao.dart';
import 'package:pharmacy_pos/data/daos/category_dao.dart';
import 'package:pharmacy_pos/data/daos/item_dao.dart';
import 'package:pharmacy_pos/data/daos/item_supplier_dao.dart';
import 'package:pharmacy_pos/data/daos/manufacturer_dao.dart';
import 'package:pharmacy_pos/data/daos/stock_movement_dao.dart';
import 'package:pharmacy_pos/data/daos/therapeutic_group_dao.dart';
import 'package:pharmacy_pos/data/daos/unit_dao.dart';
import 'package:pharmacy_pos/domain/services/stock_service.dart';
import 'package:pharmacy_pos/features/inventory/data/repositories/inventory_repository_impl.dart';
import 'package:pharmacy_pos/features/inventory/domain/repositories/inventory_repository.dart';
import 'package:pharmacy_pos/shared/database/app_database.dart';

import 'helpers.dart';

({MasterDataDraft ingredientDraft, MasterDataDraft indicationDraft})
    _given() {
  final ingredient = MasterDataDraft(
      name: 'باراسيتامول', nameEn: 'Paracetamol');
  final indication =
      MasterDataDraft(name: 'صداع', nameEn: 'Headache');
  return (ingredientDraft: ingredient, indicationDraft: indication);
}

void main() {
  late InventoryRepositoryImpl repo;
  late AppDatabase db;

  setUp(() async {
    db = newDatabase();
    final stock = StockService();
    repo = InventoryRepositoryImpl(
      db,
      ItemDao(db),
      CategoryDao(db),
      ManufacturerDao(db),
      TherapeuticGroupDao(db),
      UnitDao(db),
      BatchDao(db),
      StockMovementDao(db),
      ItemSupplierDao(db),
      stock,
      ActiveIngredientDao(db),
      IndicationDao(db),
      ItemActiveIngredientDao(db),
      ItemIndicationDao(db),
    );
  });

  tearDown(() async => db.close());

  test('create/update item persists active-ingredient and indication junctions '
      'and syncs the denormalized ingredient summary', () async {
    final given = _given();
    final ingredient =
        await repo.createActiveIngredient(given.ingredientDraft);
    final indication = await repo.createIndication(given.indicationDraft);

    final created = await repo.createItem(
      ItemDraft(
        tradeName: 'بانادول',
        categoryId: 'cat_test_default',
        units: const ItemUnitRelation(
          baseUnitId: 'unit_strip',
          largeUnitId: 'unit_box',
          unitsPerLarge: 10,
        ),
        activeIngredientIds: [ingredient.id],
        indicationIds: [indication.id],
      ),
    );

    expect(await repo.activeIngredientIdsForItem(created.id),
        [ingredient.id]);
    expect(await repo.indicationIdsForItem(created.id), [indication.id]);
    expect(created.activeIngredient, 'باراسيتامول');

    final updated = await repo.updateItem(
      created.id,
      ItemDraft(
        tradeName: 'بانادول',
        categoryId: 'cat_test_default',
        units: const ItemUnitRelation(
          baseUnitId: 'unit_strip',
          largeUnitId: 'unit_box',
          unitsPerLarge: 10,
        ),
        activeIngredientIds: [ingredient.id, ingredient.id],
        indicationIds: <String>[],
      ),
    );

    expect(await repo.activeIngredientIdsForItem(created.id),
        [ingredient.id]);
    expect(await repo.indicationIdsForItem(created.id), isEmpty);
    expect(updated.activeIngredient, 'باراسيتامول');
  });

  test('master-data CRUD lists active ingredients and indications', () async {
    final given = _given();
    final ingredient =
        await repo.createActiveIngredient(given.ingredientDraft);
    final indication = await repo.createIndication(given.indicationDraft);

    final ingredients = await repo.activeIngredients();
    final indications = await repo.indications();
    expect(ingredients.single.id, ingredient.id);
    expect(indications.single.id, indication.id);
  });
}