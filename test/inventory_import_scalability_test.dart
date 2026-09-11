import 'package:drift/drift.dart';
import 'package:excel/excel.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pharmacy_pos/core/data_grid/page_request.dart';
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
import 'package:pharmacy_pos/features/inventory/domain/services/inventory_excel_service.dart';
import 'package:pharmacy_pos/features/inventory/domain/services/inventory_view_builder.dart';
import 'package:pharmacy_pos/features/inventory/domain/usecases/excel_use_cases.dart';
import 'package:pharmacy_pos/shared/database/app_database.dart';
import 'package:pharmacy_pos/shared/models/enums.dart';

import 'helpers.dart';

const _admin = 'user_admin';
const _adminRole = 'role_admin';

/// Repository wrapper that counts the catalog-level methods the Excel engine
/// must (and must not) call. Under Phase 18.2A the import/export loads the full
/// catalog exactly once per operation and never issues a `searchItems` scan —
/// any per-row catalog query would surface here as unexpected counts.
class CountingRepo extends InventoryRepositoryImpl {
  CountingRepo(AppDatabase db)
    : super(
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

  int allItemsCalls = 0;
  int searchItemsCalls = 0;

  @override
  Future<List<ItemRow>> allItems() {
    allItemsCalls++;
    return super.allItems();
  }

  @override
  Future<PageResult<ItemRow>> searchItems(
    PageRequest page, {
    String? categoryId,
    String? manufacturerId,
    bool? onlyActive,
    bool? inStockOnly,
  }) {
    searchItemsCalls++;
    return super.searchItems(
      page,
      categoryId: categoryId,
      manufacturerId: manufacturerId,
      onlyActive: onlyActive,
      inStockOnly: inStockOnly,
    );
  }
}

/// Builds xlsx bytes with the canonical header row. Positions align with
/// [InventoryExcelService.headers]; null → blank.
List<int> _xlsx(List<List<String?>> rows) {
  final excel = Excel.createExcel();
  final sheet = excel['products'];
  sheet.appendRow([
    for (final h in InventoryExcelService.headers) TextCellValue(h),
  ]);
  for (final r in rows) {
    final cells = <CellValue>[];
    for (var i = 0; i < InventoryExcelService.headers.length; i++) {
      final v = r.length > i ? r[i] : null;
      cells.add(v == null ? TextCellValue('') : TextCellValue(v));
    }
    sheet.appendRow(cells);
  }
  return excel.save(fileName: 'inventory.xlsx')!;
}

Future<int> _itemCount(AppDatabase db) async {
  final count = await db
      .customSelect('SELECT COUNT(*) AS c FROM items')
      .getSingle();
  return count.read<int>('c');
}

Future<void> _seedItems(AppDatabase db, int count) async {
  final now = DateTime.now().millisecondsSinceEpoch;
  for (var start = 1; start <= count; start += 500) {
    final end = (start + 499) < count ? start + 499 : count;
    await db.batch((final b) {
      for (var i = start; i <= end; i++) {
        b.insert(
          db.items,
          ItemsCompanion.insert(
            id: 'item_scale_$i',
            primaryBarcode: Value('00629010000${i.toString().padLeft(5, '0')}'),
            tradeName: 'منتج تجريبي $i',
            createdAt: now,
            updatedAt: now,
          ),
        );
      }
    });
  }
}

void main() {
  setUpAll(ensureSqlite);

  group('excel scalable engine (§27 Phase 18.2A)', () {
    test(
      '14,001-row export/import matches every row, one catalog load, no scans',
      () async {
        final db = newDatabase();
        await awaitCategory(db);
        await _seedItems(db, 14001);

        final repo = CountingRepo(db);
        final excel = InventoryExcelService(repo);

        // Export the whole catalog (row 10,001 and beyond exist in the sheet).
        final bytes = await ExportItemsUseCase(
          repo,
          const PermissionService(),
          excel,
          viewBuilder: InventoryViewBuilder(repo),
        )(actingRoleId: _adminRole);
        expect(
          Excel.decodeBytes(bytes).tables['products']!.maxRows,
          14002,
          reason: 'header row + 14 001 products',
        );

        // Import the exported sheet. Every row carries its real barcode, so
        // all 14 001 must resolve to the existing items — including rows after
        // index 10,000, which a `pageSize: 10 000` catalog scan could never
        // reach (those would become duplicate creates).
        final summary = await ImportItemsUseCase(
          repo,
          const PermissionService(),
          const AuditService(),
        )(bytes, actingUserId: _admin, actingRoleId: _adminRole);

        expect(summary.created, 0);
        expect(summary.updated, 14001);
        expect(
          summary.issues,
          isEmpty,
          reason: 'a barcode-identified sheet row must never be ambiguous',
        );

        // One full catalog load for the export + one for the import, and no
        // per-row catalog scan anywhere in the pipeline.
        expect(repo.allItemsCalls, 2);
        expect(
          repo.searchItemsCalls,
          0,
          reason: 'import/export must never fall back to a catalog scan',
        );

        // Duplicate import would have created rows; the master stays 14 001.
        expect(await _itemCount(db), 14001);
      },
      timeout: const Timeout(Duration(minutes: 6)),
    );

    test(
      'duplicate trade names disambiguate via dose/form/manufacturer',
      () async {
        final db = newDatabase();
        await awaitCategory(db);
        final repo = CountingRepo(db);
        final ai = await repo.createActiveIngredient(
          MasterDataDraft(name: 'مادة اختبار'),
        );
        final mfrA = await repo.createManufacturer(
          MasterDataDraft(name: 'شركة الأولى'),
        );
        final mfrB = await repo.createManufacturer(
          MasterDataDraft(name: 'شركة الثانية'),
        );

        final itemA = await repo.createItem(
          ItemDraft(
            tradeName: 'دواء مكرر',
            dose: '500 ملغ',
            pharmaForm: 'أقراص',
            manufacturerId: mfrA.id,
            activeIngredientIds: [ai.id],
            activeIngredientStrengths: {ai.id: '500 ملغ'},
          ),
        );
        final itemB = await repo.createItem(
          ItemDraft(
            tradeName: 'دواء مكرر',
            dose: '125 ملغ',
            pharmaForm: 'شراب',
            manufacturerId: mfrB.id,
            activeIngredientIds: [ai.id],
            activeIngredientStrengths: {ai.id: '125 ملغ'},
          ),
        );

        final service = InventoryExcelService(repo);

        // (a) Trade name only, both candidates equal → ambiguous, never guessed.
        final nameless = await service.parseImport(
          _xlsx([
            [null, null, 'دواء مكرر'],
          ]),
        );
        expect(nameless.rows, isEmpty);
        expect(nameless.issues.any((m) => m.contains('أكثر من منتج')), isTrue);

        // (b) Full composite identity narrows to exactly item A.
        final fullySpecified = await service.parseImport(
          _xlsx([
            [
              null,
              null,
              'دواء مكرر',
              null,
              null,
              null,
              'مادة اختبار:500 ملغ',
              null,
              'شركة الأولى',
              null,
              null,
              null,
              null,
              null,
              null,
              null,
              null,
              null,
              null,
              null,
              null,
              null,
              null,
              null,
              'أقراص',
              '500 ملغ',
              null,
            ],
          ]),
        );
        expect(fullySpecified.issues, isEmpty);
        expect(fullySpecified.rows.single.existingItemId, itemA.id);
        expect(fullySpecified.rows.single.existingItemId, isNot(itemB.id));

        // (c) A single provided discriminator (dose) also narrows correctly.
        final byDose = await service.parseImport(
          _xlsx([
            [
              null,
              null,
              'دواء مكرر',
              null,
              null,
              null,
              null,
              null,
              null,
              null,
              null,
              null,
              null,
              null,
              null,
              null,
              null,
              null,
              null,
              null,
              null,
              null,
              null,
              null,
              null,
              '500 ملغ',
              null,
            ],
          ]),
        );
        expect(byDose.issues, isEmpty);
        expect(byDose.rows.single.existingItemId, itemA.id);
      },
    );

    test('package_shape / units are never part of the identity', () async {
      final db = newDatabase();
      await awaitCategory(db);
      final repo = CountingRepo(db);
      final ai = await repo.createActiveIngredient(
        MasterDataDraft(name: 'مادة مشتركة'),
      );
      final mfr = await repo.createManufacturer(
        MasterDataDraft(name: 'شركة موحدة'),
      );

      final ItemDraft base = ItemDraft(
        tradeName: 'نفس الهوية',
        dose: '250 ملغ',
        pharmaForm: 'أقراص',
        manufacturerId: mfr.id,
        activeIngredientIds: [ai.id],
        activeIngredientStrengths: {ai.id: '250 ملغ'},
      );
      // Product B shares the full composite identity with product A (trade
      // name, dose, form, manufacturer, ingredient+strength) but differs only
      // in package_size and unit relation — non-identity fields.
      await repo.createItem(base);
      await repo.createItem(
        ItemDraft(
          tradeName: base.tradeName,
          dose: base.dose,
          pharmaForm: base.pharmaForm,
          manufacturerId: base.manufacturerId,
          activeIngredientIds: base.activeIngredientIds,
          activeIngredientStrengths: base.activeIngredientStrengths,
          sizeVolume: 'صندوق 50',
          units: const ItemUnitRelation(
            baseUnitId: 'unit_strip',
            largeUnitId: 'unit_box',
            unitsPerLarge: 10,
          ),
        ),
      );

      // A fully specified sheet row (composite identity) must still be
      // ambiguous, because the two products differ only in package fields.
      final parsed = await InventoryExcelService(repo).parseImport(
        _xlsx([
          [
            null,
            null,
            'نفس الهوية',
            null,
            null,
            null,
            'مادة مشتركة:250 ملغ',
            null,
            'شركة موحدة',
          ],
        ]),
      );
      expect(parsed.rows, isEmpty);
      expect(
        parsed.issues.any((m) => m.contains('أكثر من منتج')),
        isTrue,
        reason: 'package_shape/sizeVolume/units must not disambiguate',
      );
    });

    test('unknown barcode creates; no source-id is ever synthesised', () async {
      final db = newDatabase();
      await awaitCategory(db);
      final repo = CountingRepo(db);
      await repo.createActiveIngredient(MasterDataDraft(name: 'مادة'));
      await repo.createItem(const ItemDraft(tradeName: 'منتج بباركود'));

      final bytes = _xlsx([
        ['999000999', null, 'منتج باسم جديد'],
      ]);
      final summary = await ImportItemsUseCase(
        repo,
        const PermissionService(),
        const AuditService(),
      )(bytes, actingUserId: _admin, actingRoleId: _adminRole);

      expect(
        summary.created,
        1,
        reason: 'a barcode that matches nobody identifies a new product',
      );
      expect(summary.issues, isEmpty);
      final created = (await repo.searchItems(
        const PageRequest(pageSize: 100),
      )).items.singleWhere((i) => i.tradeName == 'منتج باسم جديد');
      expect(
        created.primaryBarcode,
        '999000999',
        reason: 'the sheet barcode is stored as-is; never a fuzzy edit',
      );
      // The pre-existing same-name-style item is untouched.
      expect(await _itemCount(db), 2);
    });

    test('in-file duplicate rows target one item only', () async {
      final db = newDatabase();
      await awaitCategory(db);
      final repo = CountingRepo(db);

      final bytes = _xlsx([
        ['111111111', null, 'منتج أول'],
        ['111111111', null, 'منتج أول'],
      ]);
      final summary = await ImportItemsUseCase(
        repo,
        const PermissionService(),
        const AuditService(),
      )(bytes, actingUserId: _admin, actingRoleId: _adminRole);
      expect(summary.created, 1);
      expect(summary.issues.any((m) => m.contains('مكرر داخل الملف')), isTrue);
      expect(await _itemCount(db), 1);
    });

    test(
      're-importing the same sheet updates instead of duplicating',
      () async {
        final db = newDatabase();
        await awaitCategory(db);
        final repo = CountingRepo(db);
        final bytes = _xlsx([
          ['222222222', null, 'منتج ثان'],
          ['333333333', null, 'منتج ثالث'],
        ]);
        final import = ImportItemsUseCase(
          repo,
          const PermissionService(),
          const AuditService(),
        );
        final first = await import(
          bytes,
          actingUserId: _admin,
          actingRoleId: _adminRole,
        );
        expect(first.created, 2);
        expect(await _itemCount(db), 2);

        final second = await import(
          bytes,
          actingUserId: _admin,
          actingRoleId: _adminRole,
        );
        expect(second.created, 0);
        expect(second.updated, 2);
        expect(second.issues, isEmpty);
        expect(
          await _itemCount(db),
          2,
          reason: 'duplicate import must never duplicate items',
        );
      },
    );

    test(
      'unknown master data is auto-created so the full sheet imports',
      () async {
        final db = newDatabase();
        await awaitCategory(db);
        final repo = CountingRepo(db);

        // Two rows referencing the same unknown category/manufacturer/
        // ingredient/indication/units plus one row with a distinct unknown
        // manufacturer — mirrors the supplier's raw catalog sheet.
        final bytes = _xlsx([
          [
            '111000001',
            null,
            'بانادول أصلي',
            null,
            null,
            null,
            'باراسيتامول:500 ملغ',
            'أدوية عامة',
            'فرسان الأدوية',
            'صداع',
            null,
            null,
            'شريط',
            'علبة',
            null,
            null,
            null,
            null,
            null,
            '3000',
            null,
            null,
            null,
            null,
            null,
            null,
            null,
          ],
          [
            '111000002',
            null,
            'بانادول إكسترا',
            null,
            null,
            null,
            'باراسيتامول:500 ملغ',
            'أدوية عامة',
            'فرسان الأدوية',
            'صداع',
            null,
            null,
            'شريط',
            'علبة',
            null,
            null,
            null,
            null,
            null,
            '3500',
            null,
            null,
            null,
            null,
            null,
            null,
            null,
          ],
          [
            '111000003',
            null,
            'دواء تابع لشركة أخرى',
            null,
            null,
            null,
            null,
            null,
            'مختلفة كلياً',
            null,
            null,
            null,
            null,
            null,
            null,
            null,
            null,
            null,
            null,
            null,
            null,
            null,
            null,
            null,
            null,
            null,
            null,
          ],
        ]);

        final summary = await ImportItemsUseCase(
          repo,
          const PermissionService(),
          const AuditService(),
        )(bytes, actingUserId: _admin, actingRoleId: _adminRole);

        expect(
          summary.issues,
          isEmpty,
          reason: 'unknown master data must never skip a row anymore',
        );
        expect(
          summary.created,
          3,
          reason: 'all three sheet rows import end-to-end',
        );
        // category(1) + manufacturers(2) + ingredient(1) + indication(1)
        // + units(1, 'شريط' — 'علبة' already ships in seed data) == 6 distinct
        // auto-created master rows.
        expect(summary.createdMaster, 6);

        final categoryNames = (await db.select(db.categories).get())
            .map((r) => r.name)
            .toList();
        final manufacturerNames = (await db.select(db.manufacturers).get())
            .map((r) => r.name)
            .toList();
        final ingredientNames = (await db.select(db.activeIngredients).get())
            .map((r) => r.name)
            .toList();
        final indicationNames = (await db.select(db.indications).get())
            .map((r) => r.name)
            .toList();
        final unitNames = (await db.select(db.units).get())
            .map((r) => r.name)
            .toList();
        expect(categoryNames, contains('أدوية عامة'));
        expect(
          manufacturerNames,
          containsAll(['فرسان الأدوية', 'مختلفة كلياً']),
        );
        expect(ingredientNames, contains('باراسيتامول'));
        expect(indicationNames, contains('صداع'));
        expect(unitNames, containsAll(['شريط', 'علبة']));

        // Each auto-created master row is audited like a normal create.
        final auditRows = await db.select(db.auditLogs).get();
        final masterAudits = auditRows
            .where((a) => a.action == AuditAction.create.name)
            .where((a) => a.entityId.startsWith('cat_'))
            .toList();
        expect(masterAudits.length, 1,
            reason: 'the auto-created category is audited once');

        expect(
          await _itemCount(db),
          3,
          reason: 'previously-skipped rows now land as items',
        );

        // Re-importing the same sheet must find the master data it already
        // created (zero new master rows, updates in place).
        final second = await ImportItemsUseCase(
          repo,
          const PermissionService(),
          const AuditService(),
        )(bytes, actingUserId: _admin, actingRoleId: _adminRole);
        expect(second.created, 0);
        expect(second.updated, 3);
        expect(
          second.createdMaster,
          0,
          reason: 'previously auto-created master data is reused by name',
        );
      },
    );

    test('in-stock filter keeps only items with current stock > 0', () async {
      final db = newDatabase();
      await awaitCategory(db);
      final repo = CountingRepo(db);

      final outOfStock = await repo.createItem(
        const ItemDraft(tradeName: 'منتج نفد'),
      );
      expect(outOfStock.id, isNotEmpty);
      final stocked = await repo.createItem(
        const ItemDraft(tradeName: 'منتج متوفر'),
      );
      await insertBatch(db, stocked.id, quantityBase: 5);

      final page = const PageRequest(page: 1, pageSize: 100);
      final all = await repo.searchItems(page);
      expect(all.total, 2);
      expect(
        all.items.map((i) => i.currentStockBase).any((s) => s > 0),
        isTrue,
        reason: 'one of the two has live stock',
      );

      final inStock = await repo.searchItems(
        page,
        inStockOnly: true,
      );
      expect(inStock.total, 1);
      expect(inStock.items.single.tradeName, 'منتج متوفر');

      final allOut = await repo.searchItems(page, inStockOnly: false);
      expect(allOut.total, 2, reason: 'explicit false = the full catalog');
    });
  });
}
