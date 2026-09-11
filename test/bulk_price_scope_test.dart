import 'dart:convert';

import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:flutter_test/flutter_test.dart';
import 'package:pharmacy_pos/core/errors/exceptions.dart';
import 'package:pharmacy_pos/data/daos/active_ingredient_dao.dart';
import 'package:pharmacy_pos/data/daos/batch_dao.dart';
import 'package:pharmacy_pos/data/daos/category_dao.dart';
import 'package:pharmacy_pos/data/daos/indication_dao.dart';
import 'package:pharmacy_pos/data/daos/item_active_ingredient_dao.dart';
import 'package:pharmacy_pos/data/daos/item_dao.dart';
import 'package:pharmacy_pos/data/daos/item_indication_dao.dart';
import 'package:pharmacy_pos/data/daos/item_supplier_dao.dart';
import 'package:pharmacy_pos/data/daos/manufacturer_dao.dart';
import 'package:pharmacy_pos/data/daos/stock_movement_dao.dart';
import 'package:pharmacy_pos/data/daos/unit_dao.dart';
import 'package:pharmacy_pos/domain/services/audit_service.dart';
import 'package:pharmacy_pos/domain/services/permission_service.dart';
import 'package:pharmacy_pos/domain/services/stock_service.dart';
import 'package:pharmacy_pos/features/inventory/data/repositories/inventory_repository_impl.dart';
import 'package:pharmacy_pos/features/inventory/domain/repositories/inventory_repository.dart';
import 'package:pharmacy_pos/features/inventory/domain/usecases/bulk_use_cases.dart';
import 'package:pharmacy_pos/shared/database/app_database.dart';

import 'helpers.dart';

const _admin = 'user_admin';
const _adminRole = 'role_admin';

void main() {
  Future<String> insertManufacturer(AppDatabase db, String id) async {
    final now = DateTime.now().millisecondsSinceEpoch;
    await db.into(db.manufacturers).insert(
          ManufacturersCompanion.insert(
            id: id,
            name: id,
            createdAt: now,
            updatedAt: now,
          ),
          mode: InsertMode.insertOrIgnore,
        );
    return id;
  }

  Future<String> insertPriced(
    AppDatabase db, {
    required String id,
    required String barcode,
    String? manufacturerId,
    int sellingPriceMicros = 100000,
  }) async {
    final now = DateTime.now().millisecondsSinceEpoch;
    await db.into(db.items).insert(
          ItemsCompanion.insert(
            id: id,
            primaryBarcode: Value(barcode),
            tradeName: id,
            tradeNameEn: Value(id),
            scientificName: Value(id),
            categoryId: const Value('cat_test_default'),
            manufacturerId: Value(manufacturerId),
            sellingPriceMicros: Value(sellingPriceMicros),
            createdAt: now,
            updatedAt: now,
          ),
          mode: InsertMode.insertOrIgnore,
        );
    return id;
  }

  late AppDatabase db;
  late InventoryRepositoryImpl repo;
  late BulkUpdateItemsUseCase useCase;

  setUp(() async {
    db = newDatabase();
    await awaitCategory(db);
    final stock = StockService();
    repo = InventoryRepositoryImpl(
      db,
      ItemDao(db),
      CategoryDao(db),
      ManufacturerDao(db),
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
    useCase = BulkUpdateItemsUseCase(
        repo, const PermissionService(), const AuditService());
  });

  tearDown(() async => db.close());

  test('manual scope (default) only touches the selected items', () async {
    await insertPriced(db, id: 'it_a', barcode: '1111111111111');
    await insertPriced(db, id: 'it_b', barcode: '2222222222222');

    final updated = await useCase(
      BulkUpdateInput(
        operation: BulkOperation.adjustPricePercent,
        itemIds: const ['it_a'],
        basisPoints: 1000,
      ),
      actingUserId: _admin,
      actingRoleId: _adminRole,
    );

    expect(updated, 1);
    expect((await repo.findItem('it_a'))!.sellingPriceMicros, 110000);
    expect((await repo.findItem('it_b'))!.sellingPriceMicros, 100000);
  });

  test('manufacturer scope raises prices for the whole manufacturer', () async {
    await insertManufacturer(db, 'mfr_one');
    await insertManufacturer(db, 'mfr_two');
    await insertPriced(
        db, id: 'it_a', barcode: '1111111111111', manufacturerId: 'mfr_one');
    await insertPriced(
        db, id: 'it_b', barcode: '2222222222222', manufacturerId: 'mfr_two');
    await insertPriced(
        db, id: 'it_c', barcode: '3333333333333', manufacturerId: 'mfr_one');

    final updated = await useCase(
      BulkUpdateInput(
        operation: BulkOperation.adjustPricePercent,
        itemIds: const ['it_a'],
        basisPoints: 1000,
        priceScope: BulkPriceScope.manufacturer,
        priceManufacturerId: 'mfr_one',
      ),
      actingUserId: _admin,
      actingRoleId: _adminRole,
    );

    expect(updated, 2);
    expect((await repo.findItem('it_a'))!.sellingPriceMicros, 110000);
    expect((await repo.findItem('it_b'))!.sellingPriceMicros, 100000);
    expect((await repo.findItem('it_c'))!.sellingPriceMicros, 110000);
  });

  test('supplier scope raises prices for products linked to the supplier',
      () async {
    final supplierId = await insertSupplier(db);
    await insertPriced(db, id: 'it_a', barcode: '1111111111111');
    await insertPriced(db, id: 'it_b', barcode: '2222222222222');
    await insertPriced(db, id: 'it_c', barcode: '3333333333333');

    await repo.updateItem(
      'it_c',
      ItemDraft.fromRow((await repo.findItem('it_c'))!,
          supplierIds: [supplierId]),
    );

    final updated = await useCase(
      BulkUpdateInput(
        operation: BulkOperation.adjustPricePercent,
        itemIds: const ['it_a'],
        basisPoints: 1000,
        priceScope: BulkPriceScope.supplier,
        priceSupplierId: supplierId,
      ),
      actingUserId: _admin,
      actingRoleId: _adminRole,
    );

    expect(updated, 1);
    expect((await repo.findItem('it_a'))!.sellingPriceMicros, 100000);
    expect((await repo.findItem('it_c'))!.sellingPriceMicros, 110000);
  });

  test('all scope raises prices across the whole catalog', () async {
    await insertPriced(db, id: 'it_a', barcode: '1111111111111');
    await insertPriced(db, id: 'it_b', barcode: '2222222222222');

    final updated = await useCase(
      BulkUpdateInput(
        operation: BulkOperation.adjustPricePercent,
        itemIds: const [],
        basisPoints: 1000,
        priceScope: BulkPriceScope.all,
      ),
      actingUserId: _admin,
      actingRoleId: _adminRole,
    );

    expect(updated, 2);
    expect((await repo.findItem('it_a'))!.sellingPriceMicros, 110000);
    expect((await repo.findItem('it_b'))!.sellingPriceMicros, 110000);
  });

  test('catalog-wide price sweep is audited with scope metadata', () async {
    await insertPriced(db, id: 'it_a', barcode: '1111111111111');
    await useCase(
      BulkUpdateInput(
        operation: BulkOperation.adjustPricePercent,
        itemIds: const [],
        basisPoints: 1000,
        priceScope: BulkPriceScope.all,
      ),
      actingUserId: _admin,
      actingRoleId: _adminRole,
    );

    final rows = await (db.select(db.auditLogs)
          ..where((a) => a.action.equals('bulk_op')))
        .get();
    final record = rows.single;
    final after = jsonDecode(record.afterData!) as Map<String, dynamic>;
    expect(after['price_scope'], 'all');
    expect(after['target'], 1);
    expect(after['updated'], 1);
  });

  test('manufacturer scope without an id is rejected', () async {
    expect(
      () => useCase(
        BulkUpdateInput(
          operation: BulkOperation.adjustPricePercent,
          itemIds: const ['it_a'],
          basisPoints: 1000,
          priceScope: BulkPriceScope.manufacturer,
        ),
        actingUserId: _admin,
        actingRoleId: _adminRole,
      ),
      throwsA(isA<ValidationException>()),
    );
  });
}