import 'package:excel/excel.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pharmacy_pos/core/errors/exceptions.dart';
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

InventoryRepositoryImpl _repo(AppDatabase db) => InventoryRepositoryImpl(
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

List<int> _xlsx(int dataRows) {
  final excel = Excel.createExcel();
  final sheet = excel['products'];
  sheet.appendRow([
    for (final h in InventoryExcelService.headers) TextCellValue(h),
  ]);
  for (var i = 1; i <= dataRows; i++) {
    sheet.appendRow([
      TextCellValue('993100000000${(1000000 + i).toString().substring(1)}'),
      TextCellValue(''),
      TextCellValue('منتج تقدم $i'),
    ]);
  }
  return excel.save()!;
}

/// Fakes an in-flight import that blocks until the controller asks it to stop
/// — deterministic test of the cancel wiring without timing flakes.
class _BlockingImport extends ImportItemsUseCase {
  _BlockingImport(super.repo, super.permissions, super.audit);

  @override
  Future<ImportSummary> call(
    List<int> bytes, {
    String? actingUserId,
    String? actingRoleId,
    void Function(ImportProgress? progress)? onProgress,
    bool Function()? shouldCancel,
  }) async {
    onProgress?.call(const ImportProgress(
        stage: ImportStage.applying, processed: 1, total: 100));
    while (!(shouldCancel?.call() ?? false)) {
      await Future<void>.delayed(const Duration(milliseconds: 5));
    }
    throw ImportCancelledException();
  }
}

Future<void> main() async {
  setUpAll(ensureSqlite);

  test('parse and apply both stream progress; last event reports 100%',
      () async {
    final db = newDatabase();
    final repo = _repo(db);
    final useCase = ImportItemsUseCase(
        repo, const PermissionService(), const AuditService());
    final events = <ImportProgress>[];
    await useCase(
      _xlsx(700),
      actingUserId: _admin,
      actingRoleId: _adminRole,
      onProgress: (p) {
        if (p != null) events.add(p);
      },
    );
    expect(events, isNotEmpty);
    expect(events.map((e) => e.stage), containsAll([
      ImportStage.parsing,
      ImportStage.applying,
    ]));
    final last = events.last;
    expect(last.stage, ImportStage.applying);
    expect(last.processed, last.total,
        reason: 'the final progress event reports the full sheet');
    expect(last.total, 700);
  });

  test('cancel during apply rolls the whole sheet back atomically', () async {
    final db = newDatabase();
    final repo = _repo(db);
    final entries = [
      for (var i = 1; i <= 200; i++)
        ImportApplyEntry(
          rowNumber: i,
          draft: ItemDraft(
            tradeName: 'منتج ملفوف $i',
            primaryBarcode: 'RC${i.toString().padLeft(8, '0')}',
          ),
        ),
    ];
    var cancelledSignal = false;
    await expectLater(
      repo.applyImport(
        entries,
        onProgress: (processed, total) => cancelledSignal = true,
        shouldCancel: () => cancelledSignal,
      ),
      throwsA(isA<ImportCancelledException>()),
    );
    final count = await db
        .customSelect('SELECT COUNT(*) AS c FROM items')
        .getSingle();
    expect(count.read<int>('c'), 0,
        reason: 'cancellation inside the transaction must not leave a partial '
            'sheet behind');
  });

  test('cancel during parse aborts before anything persists', () async {
    final db = newDatabase();
    final repo = _repo(db);
    final useCase = ImportItemsUseCase(
        repo, const PermissionService(), const AuditService());
    await expectLater(
      useCase(
        _xlsx(300),
        actingUserId: _admin,
        actingRoleId: _adminRole,
        shouldCancel: () => true,
      ),
      throwsA(isA<ImportCancelledException>()),
    );
    final count = await db
        .customSelect('SELECT COUNT(*) AS c FROM items')
        .getSingle();
    expect(count.read<int>('c'), 0);
  });

  test(
      'controller cancelImport surfaces ImportCancelledFailure and frees the '
      'spinner (busy false)', () async {
    final db = newDatabase();
    final repo = _repo(db);
    final perms = const PermissionService();
    final audit = const AuditService();
    final builder = InventoryViewBuilder(repo);
    final controller = InventoryController(
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
      _BlockingImport(repo, perms, audit),
    );

    final future = controller.importExcel(
      _xlsx(100),
      actingUserId: _admin,
      actingRoleId: _adminRole,
    );
    // Wait for the fake import to post its first progress event.
    while (controller.state.importProgress == null) {
      await Future<void>.delayed(const Duration(milliseconds: 2));
    }
    expect(controller.state.busy, isTrue);
    expect(controller.state.importProgress!.stage, ImportStage.applying);

    controller.cancelImport();
    final failure = await future;
    expect(failure, isA<ImportCancelledFailure>());
    expect(controller.state.busy, isFalse);
    expect(controller.state.importProgress, isNull);
    expect(controller.state.error, isNull,
        reason: 'a user cancel is an informational notice, not an error');
  });
}