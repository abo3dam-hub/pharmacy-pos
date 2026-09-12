import 'package:drift/drift.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pharmacy_pos/core/data_grid/page_request.dart';
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
import 'package:pharmacy_pos/features/inventory/application/inventory_controller.dart';
import 'package:pharmacy_pos/features/inventory/data/repositories/inventory_repository_impl.dart';
import 'package:pharmacy_pos/features/inventory/domain/repositories/inventory_repository.dart';
import 'package:pharmacy_pos/features/inventory/domain/services/inventory_excel_service.dart';
import 'package:pharmacy_pos/features/inventory/domain/services/inventory_view_builder.dart';
import 'package:pharmacy_pos/features/inventory/domain/usecases/batches_use_cases.dart';
import 'package:pharmacy_pos/features/inventory/domain/usecases/bulk_use_cases.dart';
import 'package:pharmacy_pos/features/inventory/domain/usecases/create_item.dart';
import 'package:pharmacy_pos/features/inventory/domain/usecases/delete_item.dart';
import 'package:pharmacy_pos/features/inventory/domain/usecases/excel_use_cases.dart';
import 'package:pharmacy_pos/features/inventory/domain/usecases/list_items.dart';
import 'package:pharmacy_pos/features/inventory/domain/usecases/set_item_active.dart';
import 'package:pharmacy_pos/features/inventory/domain/usecases/stock_use_cases.dart';
import 'package:pharmacy_pos/features/inventory/domain/usecases/update_item.dart';
import 'package:pharmacy_pos/shared/database/app_database.dart';
import 'package:pharmacy_pos/shared/models/enums.dart';

import 'helpers.dart';

const _admin = 'user_admin';
const _adminRole = 'role_admin';

({InventoryRepositoryImpl repository, StockService stock, ItemDao itemDao})
    _repo(AppDatabase db) {
  final stock = StockService();
  final repository = InventoryRepositoryImpl(
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
  return (repository: repository, stock: stock, itemDao: ItemDao(db));
}

const _draft = ItemDraft(
  primaryBarcode: '6291041500213',
  tradeName: 'بانادول',
  tradeNameEn: 'Panadol',
  scientificName: 'Paracetamol',
  categoryId: 'cat_test_default',
  pharmaForm: 'أقراص',
  hasExpiry: true,
  costMicros: 5000,
  sellingPriceMicros: 7500,
  vatRateBasisPoints: 1500,
  minimumStockBase: 5,
  units: ItemUnitRelation(
    baseUnitId: 'unit_strip',
    largeUnitId: 'unit_box',
    unitsPerLarge: 10,
  ),
);

const _draftUpdated = ItemDraft(
  primaryBarcode: '6291041500213',
  tradeName: 'بانادول',
  tradeNameEn: 'Panadol',
  scientificName: 'Paracetamol',
  categoryId: 'cat_test_default',
  pharmaForm: 'أقراص',
  hasExpiry: true,
  costMicros: 5000,
  sellingPriceMicros: 9000,
  vatRateBasisPoints: 1500,
  minimumStockBase: 5,
  units: ItemUnitRelation(
    baseUnitId: 'unit_strip',
    largeUnitId: 'unit_box',
    unitsPerLarge: 10,
  ),
);

void main() {
  setUpAll(ensureSqlite);

  group('inventory (§7 §8 §9 §10)', () {
    test('create item persists a full §5 profile and search returns it', () async {
      final db = newDatabase();
      await awaitCategory(db);
      final repo = _repo(db).repository;
      final create = CreateItemUseCase(repo, const PermissionService(), const AuditService());

      final row = await create(_draft, actingUserId: _admin, actingRoleId: _adminRole);

      expect(row.id, isNotEmpty);
      expect(row.primaryBarcode, '6291041500213');
      expect(row.hasExpiry, isTrue);
      expect(row.sellingPriceMicros, 7500);

      final list = ListItemsUseCase(repo, const PermissionService(),
          viewBuilder: InventoryViewBuilder(repo));
      final result = await list(
        const PageRequest(page: 1, pageSize: 30),
        actingRoleId: _adminRole,
      );
      expect(result.total, 1);
      expect(result.items.single.item.id, row.id);
      expect(result.items.single.categoryName, 'أدوية اختبار');
    }, skip: false);

    test('update changes prices and audits a price_change', () async {
      final db = newDatabase();
      final id = await insertItem(db);
      final repo = _repo(db).repository;
      final update = UpdateItemUseCase(repo, const PermissionService(), const AuditService());

      final updated = await update(
        id,
        _draftUpdated,
        actingUserId: _admin,
        actingRoleId: _adminRole,
      );

      expect(updated.sellingPriceMicros, 9000);
      final audits = await (db.select(db.auditLogs)
            ..where((a) =>
                a.entityType.equals('item') &
                a.action.equals('price_change'))
            ..limit(1))
          .get();
      expect(audits, hasLength(1));
      expect(audits.single.userId, _admin);
    });

    test('addBatch opens a ledger movement and raises on-hand', () async {
      final db = newDatabase();
      final id = await insertItem(db);
      final repo = _repo(db).repository;
      final addBatch = AddBatchUseCase(repo, const PermissionService(), const AuditService());

      final batch = await addBatch(
        AddBatchInput(
          itemId: id,
          batchNumber: 'B1',
          quantityBase: 10,
          unitCostMicros: 4000,
          receivedDate: DateTime.now().millisecondsSinceEpoch,
        ),
        actingUserId: _admin,
        actingRoleId: _adminRole,
      );

      expect(batch.originalQuantityBase, 10);
      final item = await repo.findItem(id);
      expect(item!.currentStockBase, 10);

      final batches = await repo.batchesForItem(id);
      expect(batches, hasLength(1));
      final movements = await repo.movementsForItem(id, limit: 5);
      expect(movements, hasLength(1));
      expect(movements.single.refType, 'batch');
    });

    test('voidBatch flattens remaining stock with a manual_correction', () async {
      final db = newDatabase();
      final id = await insertItem(db);
      final repo = _repo(db).repository;
      final addBatch = AddBatchUseCase(repo, const PermissionService(), const AuditService());
      final batch = await addBatch(
        AddBatchInput(itemId: id, batchNumber: 'V1', quantityBase: 8, unitCostMicros: 3000),
        actingUserId: _admin,
        actingRoleId: _adminRole,
      );

      await VoidBatchUseCase(repo, const PermissionService(), const AuditService())
          .call(batch.id, actingUserId: _admin, actingRoleId: _adminRole);

      final updated = await repo.batchesForItem(id);
      expect(updated.single.isVoided, isTrue);
      expect(updated.single.quantityBase, 0);
      final item = await repo.findItem(id);
      expect(item!.currentStockBase, 0);
      final movements = await repo.movementsForItem(id, limit: 10);
      expect(
          movements.map((m) => m.movementType), contains(MovementType.manual_correction));
    });

    test('adjustStock increases/decreases ledger and stock', () async {
      final db = newDatabase();
      final id = await insertItem(db);
      final repo = _repo(db).repository;
      final addBatch = AddBatchUseCase(repo, const PermissionService(), const AuditService());
      final batch = await addBatch(
        AddBatchInput(itemId: id, batchNumber: 'A1', quantityBase: 20, unitCostMicros: 2000),
        actingUserId: _admin,
        actingRoleId: _adminRole,
      );

      final adjust = AdjustStockUseCase(repo, const PermissionService(), const AuditService());
      await adjust(
        StockAdjustInput(
          itemId: id,
          batchId: batch.id,
          movementType: MovementType.stock_adjustment.name,
          deltaBase: 5,
          unitCostMicros: 2000,
          note: 'زيادة',
        ),
        actingUserId: _admin,
        actingRoleId: _adminRole,
      );
      expect((await repo.findItem(id))!.currentStockBase, 25);

      await adjust(
        StockAdjustInput(
          itemId: id,
          batchId: batch.id,
          movementType: MovementType.stock_adjustment.name,
          deltaBase: -3,
          unitCostMicros: 2000,
          note: 'نقص',
        ),
        actingUserId: _admin,
        actingRoleId: _adminRole,
      );
      expect((await repo.findItem(id))!.currentStockBase, 22);
      expect((await repo.batchesForItem(id)).single.quantityBase, 22);
    });

    test('bulk change of category updates every selected item', () async {
      final db = newDatabase();
      final repo = _repo(db).repository;
      final u = BulkUpdateItemsUseCase(repo, const PermissionService(), const AuditService());
      final ids = <String>[
        await insertItem(db, barcode: '1111111111111'),
        await insertItem(db, barcode: '2222222222222'),
      ];
      await db.into(db.categories).insert(
            CategoriesCompanion.insert(
              id: 'cat_target',
              name: 'مستلزمات',
              nameEn: const Value('Supplies'),
              createdAt: DateTime.now().millisecondsSinceEpoch,
              updatedAt: DateTime.now().millisecondsSinceEpoch,
            ),
            mode: InsertMode.insertOrIgnore,
          );

      final updated = await u(
        BulkUpdateInput(
          operation: BulkOperation.changeCategory,
          itemIds: ids,
          categoryId: 'cat_target',
        ),
        actingUserId: _admin,
        actingRoleId: _adminRole,
      );

      expect(updated, 2);
      for (final i in ids) {
        expect((await repo.findItem(i))!.categoryId, 'cat_target');
      }
      final audits = await (db.select(db.auditLogs)
            ..where((a) => a.action.equals('bulk_op')))
          .get();
      expect(audits, isNotEmpty);
    });

    test('permission gates: viewer role cannot create inventory', () async {
      final db = newDatabase();
      await awaitCategory(db);
      final repo = _repo(db).repository;
      final create = CreateItemUseCase(repo, const PermissionService(), const AuditService());

      expect(
        () => create(_draft, actingUserId: 'user_viewer', actingRoleId: 'role_viewer'),
        throwsA(isA<UnauthorizedException>()),
      );
    });

    test('load defaults to in-stock; the full catalog is a toggle away',
        () async {
      final db = newDatabase();
      await awaitCategory(db);
      final h = _repo(db);
      final repo = h.repository;
      final out = await repo.createItem(
        const ItemDraft(tradeName: 'بلا مخزون'),
      );
      expect(out.id, isNotEmpty);
      final inStock = await repo.createItem(
        const ItemDraft(tradeName: 'بمخزون'),
      );
      await insertBatch(db, inStock.id, quantityBase: 4);

      final controller = InventoryController(
        ListItemsUseCase(repo, const PermissionService(),
            viewBuilder: InventoryViewBuilder(repo)),
        CreateItemUseCase(repo, const PermissionService(), const AuditService()),
        UpdateItemUseCase(repo, const PermissionService(), const AuditService()),
        SetItemActiveUseCase(
            repo, const PermissionService(), const AuditService()),
        DeleteItemUseCase(repo, const PermissionService(), const AuditService()),
        AddBatchUseCase(repo, const PermissionService(), const AuditService()),
        VoidBatchUseCase(
            repo, const PermissionService(), const AuditService()),
        ListBatchesUseCase(repo, const PermissionService()),
        AdjustStockUseCase(repo, const PermissionService(), const AuditService()),
        BulkUpdateItemsUseCase(
            repo, const PermissionService(), const AuditService()),
        ExportItemsUseCase(repo, const PermissionService(),
            InventoryExcelService(repo),
            viewBuilder: InventoryViewBuilder(repo)),
        ImportItemsUseCase(repo, const PermissionService(), const AuditService()),
      );

      // Opening the inventory view shows only what actually is on the shelf.
      await controller.load(actingRoleId: _adminRole);
      expect(controller.state.inStockOnly, isTrue,
          reason: 'the in-stock view is the first screen');
      expect(controller.state.total, 1);
      expect(
        controller.state.items.single.item.tradeName,
        'بمخزون',
      );

      // The product tree (full catalog) is reachable with a flip.
      await controller.load(inStockOnly: false, actingRoleId: _adminRole);
      expect(controller.state.total, 2);

      // Reload keeps the current mode.
      await controller.reload();
      expect(controller.state.total, 2,
          reason: 'reload must not silently snap back to in-stock-only');
    });
  });

  group('inventory excel (§21)', () {
    test('export then import round-trips existing items', () async {
      final db = newDatabase();
      final repo = _repo(db).repository;
      await insertItem(db, barcode: '6291041500213');

      final excel = InventoryExcelService(repo);
      final export = ExportItemsUseCase(
          repo, const PermissionService(), excel,
          viewBuilder: InventoryViewBuilder(repo));
      final bytes = await export(actingRoleId: _adminRole);
      expect(bytes, isNotEmpty);

      final import = ImportItemsUseCase(repo, const PermissionService(), const AuditService());
      final summary = await import(bytes, actingUserId: _admin, actingRoleId: _adminRole);

      expect(summary.created, 0);
      expect(summary.updated, 1);
      expect(summary.issues, isEmpty);
    }, skip: false);
  });
}