import 'package:flutter_test/flutter_test.dart';
import 'package:pharmacy_pos/core/errors/failures.dart';
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

import 'helpers.dart';

const _admin = 'user_admin';
const _adminRole = 'role_admin';

const _draft = ItemDraft(
  primaryBarcode: '6291041500213',
  tradeName: 'بانادول',
  tradeNameEn: 'Panadol',
  scientificName: 'Paracetamol',
  categoryId: 'cat_default',
  costMicros: 5000,
  sellingPriceMicros: 7500,
  units: ItemUnitRelation(
    baseUnitId: 'unit_strip',
    largeUnitId: 'unit_box',
    unitsPerLarge: 10,
  ),
);

InventoryController _controller(AppDatabase db) {
  final stock = StockService();
  final repo = InventoryRepositoryImpl(
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
  final perms = const PermissionService();
  final audit = const AuditService();
  final builder = InventoryViewBuilder(repo);
  return InventoryController(
    ListItemsUseCase(repo, perms, viewBuilder: builder),
    CreateItemUseCase(repo, perms, audit),
    UpdateItemUseCase(repo, perms, audit),
    SetItemActiveUseCase(repo, perms, audit),
    DeleteItemUseCase(repo, perms, audit),
    AddBatchUseCase(repo, perms, audit),
    VoidBatchUseCase(repo, perms, audit),
    ListBatchesUseCase(repo, perms),
    AdjustStockUseCase(repo, perms, audit),
    BulkUpdateItemsUseCase(repo, perms, audit),
    ExportItemsUseCase(repo, perms, InventoryExcelService(repo),
        viewBuilder: builder),
    ImportItemsUseCase(repo, perms, audit),
  );
}

void main() {
  setUpAll(ensureSqlite);

  test(
      'busy clears on the error path too, and the grid shows no phantom rows',
      () async {
    final db = newDatabase();
    final controller = _controller(db);

    await controller.load(inStockOnly: false, actingRoleId: _adminRole);
    expect(controller.state.status, InventoryStatus.ready);
    expect(controller.state.busy, isFalse);

    // Phase 18 contract: units are optional — a trade-name-only product saves.
    final okFailure = await controller.createItem(
      const ItemDraft(tradeName: 'بانادول بدون وحدة'),
      actingUserId: _admin,
      actingRoleId: _adminRole,
    );
    expect(okFailure, isNull,
        reason: 'an item without a base unit is valid under Phase 18');
    expect(controller.state.total, 1);

    // A duplicate barcode still fails via the unique index and must release
    // the spinner without leaking a phantom row into the grid.
    await insertItem(db);
    await controller.load(inStockOnly: false, actingRoleId: _adminRole);
    final failure = await controller.createItem(
      const ItemDraft(
        tradeName: 'بانادول مكرر',
        primaryBarcode: '6291041500213',
      ),
      actingUserId: _admin,
      actingRoleId: _adminRole,
    );
    expect(failure, isNotNull,
        reason: 'a duplicate barcode is rejected by the repository');
    expect(controller.state.busy, isFalse,
        reason: 'a failed save must release the UI spinner');
    expect(controller.state.status, InventoryStatus.ready);
    expect(controller.state.total, 2,
        reason: 'the rejected create must not leak into the grid');
  });

  test('busy clears after a valid create and the new row is shown', () async {
    final db = newDatabase();
    final controller = _controller(db);

    await controller.load(inStockOnly: false, actingRoleId: _adminRole);
    final failure = await controller.createItem(
      _draft,
      actingUserId: _admin,
      actingRoleId: _adminRole,
    );
    expect(failure, isNull);
    expect(controller.state.busy, isFalse,
        reason: 'a successful save must release the UI spinner');
    expect(controller.state.status, InventoryStatus.ready);
    expect(controller.state.total, 1);
  });

  test(
      'product edit surfaces the root-cause failure of a duplicate-barcode '
      'edit (not a generic save error)', () async {
    final db = newDatabase();
    final controller = _controller(db);
    await controller.load(inStockOnly: false, actingRoleId: _adminRole);

    final a = await controller.createItem(
      const ItemDraft(tradeName: 'منتج أ', primaryBarcode: 'BC_A-EDIT'),
      actingUserId: _admin,
      actingRoleId: _adminRole,
    );
    final b = await controller.createItem(
      const ItemDraft(tradeName: 'منتج ب', primaryBarcode: 'BC_B-EDIT'),
      actingUserId: _admin,
      actingRoleId: _adminRole,
    );
    expect(a, isNull);
    expect(b, isNull);
    expect(controller.state.total, 2);

    final idB = controller.state.items
        .singleWhere((v) => v.item.primaryBarcode == 'BC_B-EDIT')
        .item
        .id;

    // Editing produces a duplicate primary barcode on the *same* save the
    // product form submits — the exact scenario the UI must explain.
    final failure = await controller.updateItem(
      idB,
      const ItemDraft(
        tradeName: 'منتج ب',
        primaryBarcode: 'BC_A-EDIT',
      ),
      actingUserId: _admin,
      actingRoleId: _adminRole,
    );
    expect(failure, isA<DuplicateFailure>(),
        reason: 'the UNIQUE barcode constraint must surface as the specific '
            'root-cause failure and its message, so the UI shows the cause '
            'instead of the generic save error');
    expect(failure!.message, isNotEmpty);
    expect(controller.state.busy, isFalse,
        reason: 'the failed edit releases the spinner');
    expect(controller.state.status, InventoryStatus.ready);
    expect(controller.state.total, 2,
        reason: 'the failed edit leaks no phantom row');
  });
}