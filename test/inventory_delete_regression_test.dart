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
import 'package:pharmacy_pos/features/inventory/domain/usecases/delete_item.dart';
import 'package:pharmacy_pos/features/inventory/domain/usecases/delete_master_data.dart';
import 'package:pharmacy_pos/shared/database/app_database.dart';
import 'package:pharmacy_pos/shared/models/enums.dart';

import 'helpers.dart';

const _admin = 'user_admin';
const _adminRole = 'role_admin';
const _pharmacistRole = 'role_pharmacist';

InventoryRepositoryImpl _repo(AppDatabase db) {
  return InventoryRepositoryImpl(
    db,
    ItemDao(db),
    CategoryDao(db),
    ManufacturerDao(db),
    UnitDao(db),
    BatchDao(db),
    StockMovementDao(db),
    ItemSupplierDao(db),
    StockService(),
    ActiveIngredientDao(db),
    IndicationDao(db),
    ItemActiveIngredientDao(db),
    ItemIndicationDao(db),
  );
}

void main() {
  setUpAll(ensureSqlite);

  group('§28 item delete', () {
    test('an item with stock on the shelf is rejected', () async {
      final db = newDatabase();
      final repo = _repo(db);
      final item = await repo.createItem(const ItemDraft(tradeName: 'بمخزون'));
      await insertBatch(db, item.id, quantityBase: 4);

      await expectLater(
        repo.deleteItem(item.id),
        throwsA(isA<InvalidOperationException>()),
      );
      expect(await repo.findItem(item.id), isNotNull,
          reason: 'a blocked delete must leave the item intact');
    });

    test('an item with ledger history is rejected even at zero stock', () async {
      final db = newDatabase();
      final repo = _repo(db);
      final item = await repo.createItem(const ItemDraft(tradeName: 'مباع'));
      final batch = await insertBatch(db, item.id, quantityBase: 4);
      await StockService().applyMovement(
        db,
        itemId: item.id,
        batchId: batch,
        movementType: MovementType.sale,
        quantityBaseSigned: -4,
        unitCostMicros: 10000,
        refType: 'sale',
        refId: 'sale_test',
        userId: _admin,
        note: 'drawn down to zero',
      );

      await expectLater(
        repo.deleteItem(item.id),
        throwsA(predicate(
          (e) => e is InvalidOperationException && e.failure.message.contains('لا يمكن'),
        )),
      );
      expect(await repo.findItem(item.id), isNotNull);
    });

    test('an unused item is deleted with its relations and audited', () async {
      final db = newDatabase();
      final repo = _repo(db);
      await repo.createActiveIngredient(
          const MasterDataDraft(name: 'باراسيتامول'));
      final ingredient = await repo.createActiveIngredient(
          const MasterDataDraft(name: 'إيبوبروفين'));
      final item = await repo.createItem(
        ItemDraft(
          tradeName: 'مزيج',
          activeIngredientIds: [ingredient.id],
          activeIngredientStrengths: {ingredient.id: '200mg'},
          sellingPriceMicros: 5000,
        ),
      );

      await DeleteItemUseCase(repo, const PermissionService(), const AuditService())
          .call(item.id, actingUserId: _admin, actingRoleId: _adminRole);

      expect(await repo.findItem(item.id), isNull);
      expect(await (db.select(db.itemActiveIngredients)).get(), isEmpty,
          reason: 'relations must be cleaned up with the item');
      final audits = await (db.select(db.auditLogs)).get();
      expect(audits, hasLength(1));
      expect(audits.single.action, AuditAction.delete.name);
      expect(audits.single.entityType, 'item');
      expect(audits.single.userId, _admin);
    });

    test('item delete requires inventory.delete', () async {
      final db = newDatabase();
      final repo = _repo(db);
      final item = await repo.createItem(const ItemDraft(tradeName: 'مهم'));
      await expectLater(
        DeleteItemUseCase(repo, const PermissionService(), const AuditService())
            .call(item.id, actingUserId: _admin, actingRoleId: _pharmacistRole),
        throwsA(isA<UnauthorizedException>()),
      );
      expect(await repo.findItem(item.id), isNotNull);
    });
  });

  group('§28 master-data delete', () {
    test('manufacturer: unused deletable, linked to an item rejected', () async {
      final db = newDatabase();
      final repo = _repo(db);
      final free = await repo.createManufacturer(
          const MasterDataDraft(name: 'شركة حرة'));
      await repo.deleteManufacturer(free.id);
      expect(
        await (db.select(db.manufacturers)
              ..where((m) => m.id.equals(free.id)))
            .getSingleOrNull(),
        isNull,
      );

      final owned = await repo.createManufacturer(
          const MasterDataDraft(name: 'شركة مع منتجات'));
      await repo.createItem(ItemDraft(
        tradeName: 'بماركة',
        manufacturerId: owned.id,
      ));
      await expectLater(
        repo.deleteManufacturer(owned.id),
        throwsA(isA<InvalidOperationException>()),
      );
    });

    test('category: unused deletable, linked to an item rejected', () async {
      final db = newDatabase();
      final repo = _repo(db);
      final free = await repo.createCategory(
          const MasterDataDraft(name: 'تصنيف حر'));
      await repo.deleteCategory(free.id);
      expect(
        await (db.select(db.categories)
              ..where((c) => c.id.equals(free.id)))
            .getSingleOrNull(),
        isNull,
      );

      final owned = await repo.createCategory(
          const MasterDataDraft(name: 'تصنيف مستخدم'));
      await repo.createItem(ItemDraft(
        tradeName: 'في تصنيف',
        categoryId: owned.id,
      ));
      await expectLater(
        repo.deleteCategory(owned.id),
        throwsA(isA<InvalidOperationException>()),
      );
    });

    test('unit: unused deletable, base unit of an item rejected', () async {
      final db = newDatabase();
      final repo = _repo(db);
      final free = await repo.createUnit(
          const MasterDataDraft(name: 'وحدة حرة', abbreviation: 'وح'));
      await repo.deleteUnit(free.id);
      expect(
        await (db.select(db.units)..where((u) => u.id.equals(free.id)))
            .getSingleOrNull(),
        isNull,
      );

      final base = await repo.createUnit(
          const MasterDataDraft(name: 'العبوة', abbreviation: 'عب'));
      final large =
          await repo.createUnit(const MasterDataDraft(name: 'الصندوق', abbreviation: 'ص'));
      await repo.createItem(ItemDraft(
        tradeName: 'بوحدات',
        units: ItemUnitRelation(
          baseUnitId: base.id,
          largeUnitId: large.id,
          unitsPerLarge: 10,
        ),
      ));
      await expectLater(
        repo.deleteUnit(base.id),
        throwsA(isA<InvalidOperationException>()),
      );
    });

    test('active ingredient: unused deletable, used by an item rejected',
        () async {
      final db = newDatabase();
      final repo = _repo(db);
      final free = await repo.createActiveIngredient(
          const MasterDataDraft(name: 'مادة حرة'));
      await repo.deleteActiveIngredient(free.id);
      expect(
        await (db.select(db.activeIngredients)
              ..where((a) => a.id.equals(free.id)))
            .getSingleOrNull(),
        isNull,
      );

      final used = await repo.createActiveIngredient(
          const MasterDataDraft(name: 'مادة مستخدمة'));
      await repo.createItem(ItemDraft(
        tradeName: 'يحتوي',
        activeIngredientIds: [used.id],
        activeIngredientStrengths: {used.id: '500mg'},
      ));
      await expectLater(
        repo.deleteActiveIngredient(used.id),
        throwsA(isA<InvalidOperationException>()),
      );
    });

    test('indication: unused deletable, used by an item rejected', () async {
      final db = newDatabase();
      final repo = _repo(db);
      final free = await repo.createIndication(
          const MasterDataDraft(name: 'استطباب حر'));
      await repo.deleteIndication(free.id);
      expect(
        await (db.select(db.indications)
              ..where((i) => i.id.equals(free.id)))
            .getSingleOrNull(),
        isNull,
      );

      final used = await repo.createIndication(
          const MasterDataDraft(name: 'استطباب مستخدم'));
      await repo.createItem(ItemDraft(
        tradeName: 'لأعراض',
        indicationIds: [used.id],
      ));
      await expectLater(
        repo.deleteIndication(used.id),
        throwsA(isA<InvalidOperationException>()),
      );
    });

    test('master-data deletes are audited and permission-gated', () async {
      final db = newDatabase();
      final repo = _repo(db);
      final unit = await repo.createUnit(
          const MasterDataDraft(name: 'وحدة مسجلة', abbreviation: 'م'));
      final useCase =
          DeleteUnitUseCase(repo, const PermissionService(), const AuditService());
      await useCase
          .call(unit.id, actingUserId: _admin, actingRoleId: _adminRole);
      final audits = await (db.select(db.auditLogs)).get();
      expect(audits.single.action, AuditAction.delete.name);
      expect(audits.single.entityType, 'unit');

      final protected = await repo.createUnit(
          const MasterDataDraft(name: 'وحدة محمية', abbreviation: 'ح'));
      await expectLater(
        useCase.call(protected.id,
            actingUserId: _admin, actingRoleId: _pharmacistRole),
        throwsA(isA<UnauthorizedException>()),
      );
    });
  });
}