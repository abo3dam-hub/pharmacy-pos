import 'package:flutter_test/flutter_test.dart';
import 'package:pharmacy_pos/core/errors/exceptions.dart';
import 'package:pharmacy_pos/data/daos/batch_dao.dart';
import 'package:pharmacy_pos/data/daos/category_dao.dart';
import 'package:pharmacy_pos/data/daos/item_dao.dart';
import 'package:pharmacy_pos/data/daos/item_supplier_dao.dart';
import 'package:pharmacy_pos/data/daos/manufacturer_dao.dart';
import 'package:pharmacy_pos/data/daos/stock_movement_dao.dart';
import 'package:pharmacy_pos/data/daos/therapeutic_group_dao.dart';
import 'package:pharmacy_pos/data/daos/unit_dao.dart';
import 'package:pharmacy_pos/domain/services/audit_service.dart';
import 'package:pharmacy_pos/domain/services/permission_service.dart';
import 'package:pharmacy_pos/domain/services/stock_service.dart';
import 'package:pharmacy_pos/features/inventory/data/repositories/inventory_repository_impl.dart';
import 'package:pharmacy_pos/features/inventory/domain/repositories/inventory_repository.dart';
import 'package:pharmacy_pos/features/inventory/domain/usecases/bulk_use_cases.dart';
import 'package:pharmacy_pos/features/inventory/domain/usecases/create_item.dart';
import 'package:pharmacy_pos/shared/database/app_database.dart';

import 'helpers.dart';

const _admin = 'user_admin';
const _adminRole = 'role_admin';

({InventoryRepositoryImpl repository, StockService stock}) _repo(AppDatabase db) {
  final stock = StockService();
  final repository = InventoryRepositoryImpl(
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
  );
  return (repository: repository, stock: stock);
}

ItemDraft _draft({
  required String tradeName,
  required String barcode,
  ItemUnitRelation? units = const ItemUnitRelation(
    baseUnitId: 'unit_strip',
    largeUnitId: 'unit_box',
    unitsPerLarge: 10,
  ),
  List<String> supplierIds = const [],
}) {
  return ItemDraft(
    tradeName: tradeName,
    primaryBarcode: barcode,
    categoryId: 'cat_default',
    units: units,
    supplierIds: supplierIds,
  );
}

void main() {
  setUpAll(ensureSqlite);

  test('save 1: full valid create with seeded category + seeded units', () async {
    final db = newDatabase();
    final create =
        CreateItemUseCase(_repo(db).repository, const PermissionService(), const AuditService());
    final row = await create(
      _draft(tradeName: 'بانادول 500', barcode: '6291041500213'),
      actingUserId: _admin,
      actingRoleId: _adminRole,
    );
    expect(row.id, isNotEmpty);
  });

  test('save 2: create WITHOUT units is rejected by the repository', () async {
    final db = newDatabase();
    final create =
        CreateItemUseCase(_repo(db).repository, const PermissionService(), const AuditService());
    final draft = ItemDraft(
      tradeName: 'منتج بدون وحدة',
      primaryBarcode: '9990001112223',
      categoryId: 'cat_default',
    );
    expect(
      () => create(draft, actingUserId: _admin, actingRoleId: _adminRole),
      throwsA(isA<ValidationException>()),
    );
  });

  test('save 3: base unit == packaging unit (unitsPerLarge 1) succeeds', () async {
    final db = newDatabase();
    final create =
        CreateItemUseCase(_repo(db).repository, const PermissionService(), const AuditService());
    final row = await create(
      _draft(
        tradeName: 'منتج وحدة واحدة',
        barcode: '7770001112223',
        units: const ItemUnitRelation(
          baseUnitId: 'unit_tablet',
          largeUnitId: 'unit_tablet',
          unitsPerLarge: 1,
        ),
      ),
      actingUserId: _admin,
      actingRoleId: _adminRole,
    );
    expect(row.id, isNotEmpty);
  });

  test('save 4: partial sale with null markup persists (default applied at UI)', () async {
    final db = newDatabase();
    final create =
        CreateItemUseCase(_repo(db).repository, const PermissionService(), const AuditService());
    final draft = ItemDraft(
      tradeName: 'شريط جزئي',
      primaryBarcode: '6660001112223',
      categoryId: 'cat_default',
      units: const ItemUnitRelation(
        baseUnitId: 'unit_tablet',
        largeUnitId: 'unit_box',
        unitsPerLarge: 10,
      ),
      partialSaleEnabled: true,
      sellablePartUnitId: 'unit_strip',
      partsPerFullProduct: 10,
      sellablePartBaseQuantity: 1,
    );
    final row = await create(draft, actingUserId: _admin, actingRoleId: _adminRole);
    expect(row.partialSaleEnabled, isTrue);
  });

  test('save 5: duplicate unique barcode maps to DuplicateException (not a raw SQL error)', () async {
    final db = newDatabase();
    final create =
        CreateItemUseCase(_repo(db).repository, const PermissionService(), const AuditService());
    await create(
      _draft(tradeName: 'أول', barcode: '6661112223334'),
      actingUserId: _admin,
      actingRoleId: _adminRole,
    );
    expect(
      () => create(
        _draft(tradeName: 'ثانٍ', barcode: '6661112223334'),
        actingUserId: _admin,
        actingRoleId: _adminRole,
      ),
      throwsA(isA<DuplicateException>()),
    );
  });

  test('save 6: preferred suppliers persist, dedupe, and update in place', () async {
    final db = newDatabase();
    final repo = _repo(db).repository;
    final create =
        CreateItemUseCase(repo, const PermissionService(), const AuditService());
    final suppliers = await Future.wait([
      insertSupplier(db, name: 'مورد أ'),
      insertSupplier(db, name: 'مورد ب'),
    ]);
    final row = await create(
      _draft(
        tradeName: 'بموردين',
        barcode: '6661112223335',
        supplierIds: [suppliers[0], suppliers[1], suppliers[0]],
      ),
      actingUserId: _admin,
      actingRoleId: _adminRole,
    );
    expect(await repo.supplierIdsForItem(row.id), unorderedEquals(suppliers));

    final updated = await repo.updateItem(
      row.id,
      _draft(
        tradeName: 'بموردين',
        barcode: '6661112223335',
        supplierIds: [suppliers[1]],
      ),
    );
    expect(updated.id, row.id);
    expect(await repo.supplierIdsForItem(row.id), [suppliers[1]]);

    await repo.updateItem(
      row.id,
      _draft(
        tradeName: 'بموردين',
        barcode: '6661112223335',
        supplierIds: const [],
      ),
    );
    expect(await repo.supplierIdsForItem(row.id), isEmpty);
  });

  test('save 7: bulk shelf edit does not wipe preferred suppliers', () async {
    final db = newDatabase();
    final repo = _repo(db).repository;
    final create =
        CreateItemUseCase(repo, const PermissionService(), const AuditService());
    final supplierId = await insertSupplier(db);
    final row = await create(
      _draft(
        tradeName: 'منتج رف',
        barcode: '6661112223336',
        supplierIds: [supplierId],
      ),
      actingUserId: _admin,
      actingRoleId: _adminRole,
    );
    final bulk = BulkUpdateItemsUseCase(
        repo, const PermissionService(), const AuditService());
    await bulk(
      BulkUpdateInput(
        operation: BulkOperation.changeShelfLocation,
        itemIds: [row.id],
        shelfLocation: 'رف 12',
      ),
      actingUserId: _admin,
      actingRoleId: _adminRole,
    );
    expect(await repo.supplierIdsForItem(row.id), [supplierId]);
  });
}