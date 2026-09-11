import 'package:excel/excel.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pharmacy_pos/core/data_grid/page_request.dart';
import 'package:pharmacy_pos/core/money/money.dart';
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

int _micros(String s) => Money.parse(s).units;

/// Builds xlsx bytes with the canonical Phase 18.1 header row. Cells are
/// positional (null/absent → blank).
List<int> _xlsx(List<List<String?>> rows) {
  final excel = Excel.createExcel();
  final sheet = excel['products'];
  sheet.appendRow(
      [for (final h in InventoryExcelService.headers) TextCellValue(h)]);
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

int _col(String name) => InventoryExcelService.headers.indexOf(name);

Future<ItemRow?> _byBarcode(AppDatabase db, String barcode) async {
  final result = await _repo(db).searchItems(const PageRequest(pageSize: 1000));
  for (final row in result.items) {
    if (row.primaryBarcode == barcode || row.secondaryBarcode == barcode) {
      return row;
    }
  }
  return null;
}

String _cellText(CellValue? value) {
  if (value == null) return '';
  if (value is TextCellValue) return value.toString();
  if (value is IntCellValue) return value.value.toString();
  if (value is DoubleCellValue) {
    final t = value.value.toStringAsFixed(2);
    return t.endsWith('.00') ? t.substring(0, t.length - 3) : t;
  }
  return value.toString();
}

void main() {
  setUpAll(ensureSqlite);

  group('excel product-master contract (§27 Phase 18.1)', () {
    test('A. full-profile export/import is a lossless round-trip', () async {
      final db = newDatabase();
      await awaitCategory(db);
      final repo = _repo(db);

      final mfr = await repo.createManufacturer(
          MasterDataDraft(name: 'شركة العافية'));
      final ai1 = await repo.createActiveIngredient(
          MasterDataDraft(name: 'باراسيتامول'));
      final ai2 = await repo.createActiveIngredient(
          MasterDataDraft(name: 'كافيين'));
      final ind =
          await repo.createIndication(MasterDataDraft(name: 'صداع'));

      final draft = ItemDraft(
        primaryBarcode: '6291041500213',
        secondaryBarcode: 'SEC123',
        tradeName: 'بنادول أدفانس',
        tradeNameEn: 'Panadol Adv',
        scientificName: 'Paracetamol + Caffeine',
        activeIngredient: 'Paracetamol + Caffeine',
        equivalentDrug: 'بنادول العادي',
        manufacturerId: mfr.id,
        categoryId: 'cat_test_default',
        pharmaForm: 'أقراص',
        dose: '500 mg',
        sizeVolume: '24 قرص',
        shelfLocation: 'رف أ-1',
        hasExpiry: true,
        isControlledDrug: true,
        lockAutoPriceUpdate: true,
        requiresPrescription: true,
        costMicros: _micros('4.00'),
        purchaseDiscountBasisPoints: 200,
        sellingPriceMicros: _micros('8.00'),
        subUnitPriceMicros: _micros('0.80'),
        wholesalePriceMicros: _micros('7.00'),
        halfWholesalePriceMicros: _micros('6.50'),
        customPrice1Micros: _micros('9.00'),
        vatRateBasisPoints: 900,
        minimumStockBase: 5,
        maximumStockBase: 100,
        usageInstructions: 'استخدم حسب الإرشاد',
        generalNotes: 'ملاحظة عامة',
        licenseNumber: 'D-2024',
        units: ItemUnitRelation(
            baseUnitId: 'unit_strip', largeUnitId: 'unit_box', unitsPerLarge: 10),
        activeIngredientIds: [ai1.id, ai2.id],
        activeIngredientStrengths: {ai1.id: '500 ملغ', ai2.id: '65 ملغ'},
        indicationIds: [ind.id],
        partialSaleEnabled: true,
        sellablePartUnitId: 'unit_strip',
        partsPerFullProduct: 10,
        sellablePartBaseQuantity: 1,
        partialSaleMarkupBasisPoints: 2000,
      );

      final item = await repo.createItem(draft);

      final excel = InventoryExcelService(repo);
      final export = ExportItemsUseCase(
          repo, const PermissionService(), excel,
          viewBuilder: InventoryViewBuilder(repo));
      final bytes = await export(actingRoleId: _adminRole);

      final import =
          ImportItemsUseCase(repo, const PermissionService(), const AuditService());
      final summary =
          await import(bytes, actingUserId: _admin, actingRoleId: _adminRole);
      expect(summary.created, 0);
      expect(summary.updated, 1);
      expect(summary.issues, isEmpty);

      final round = (await repo.findItem(item.id))!;
      expect(round.equivalentDrug, 'بنادول العادي');
      expect(round.pharmaForm, 'أقراص');
      expect(round.dose, '500 mg');
      expect(round.sizeVolume, '24 قرص');
      expect(round.shelfLocation, 'رف أ-1');
      expect(round.hasExpiry, isTrue);
      expect(round.isControlledDrug, isTrue);
      expect(round.lockAutoPriceUpdate, isTrue);
      expect(round.requiresPrescription, isTrue);
      expect(round.costMicros, _micros('4.00'));
      expect(round.sellingPriceMicros, _micros('8.00'));
      expect(round.wholesalePriceMicros, _micros('7.00'));
      expect(round.halfWholesalePriceMicros, _micros('6.50'));
      expect(round.customPrice1Micros, _micros('9.00'));
      expect(round.purchaseDiscountBasisPoints, 200);
      expect(round.vatRateBasisPoints, 900);
      expect(round.minimumStockBase, 5);
      expect(round.maximumStockBase, 100);
      expect(round.usageInstructions, 'استخدم حسب الإرشاد');
      expect(round.generalNotes, 'ملاحظة عامة');
      expect(round.licenseNumber, 'D-2024');
      expect(round.partialSaleEnabled, isTrue);
      expect(round.partsPerFullProduct, 10);
      expect(round.partialSaleMarkupBasisPoints, 2000);
      expect(round.sellablePartUnitId, 'unit_strip');

      final rels = await repo.activeIngredientRelationsForItem(item.id);
      expect({for (final r in rels) r.activeIngredientId},
          {ai1.id, ai2.id});
      expect({for (final r in rels) r.strength},
          containsAll(['500 ملغ', '65 ملغ']));
      expect(await repo.indicationIdsForItem(item.id), [ind.id]);

      final units = await repo.itemUnitsFor(item.id);
      expect(units!.baseUnitId, 'unit_strip');
      expect(units.largeUnitId, 'unit_box');
      expect(units.unitsPerLarge, 10);
    });

    test('B. no-units item exports a blank parts-count and round-trips',
        () async {
      final db = newDatabase();
      await awaitCategory(db);
      final repo = _repo(db);
      await repo.createItem(const ItemDraft(
        primaryBarcode: '6291041500999',
        tradeName: 'دواء بدون تشكيلة',
      ));

      final excel = InventoryExcelService(repo);
      final export = ExportItemsUseCase(
          repo, const PermissionService(), excel,
          viewBuilder: InventoryViewBuilder(repo));
      final bytes = await export(actingRoleId: _adminRole);

      final decoded = Excel.decodeBytes(bytes);
      final sheet = decoded.tables['products']!;
      final row = sheet.row(1);
      expect(_cellText(row[_col('عدد الأجزاء')]?.value), isEmpty,
          reason: 'unit-less products export an empty parts-count, not 1');
      expect(_cellText(row[_col('الأجزاء')]?.value), isEmpty);

      final import =
          ImportItemsUseCase(repo, const PermissionService(), const AuditService());
      final summary =
          await import(bytes, actingUserId: _admin, actingRoleId: _adminRole);
      expect(summary.updated, 1);
      expect(summary.issues, isEmpty);
      final item = (await _byBarcode(db, '6291041500999'))!;
      expect(await repo.itemUnitsFor(item.id), isNull);
    });

    test('C. trade-name-only sheet row creates an item with defaults',
        () async {
      final db = newDatabase();
      await awaitCategory(db);
      final repo = _repo(db);
      final bytes = _xlsx([
        [
          null,
          null,
          'منتج باسم فقط',
        ],
      ]);
      // Sanity: the row is really trade-name-only.
      final parsed = await InventoryExcelService(repo)
          .parseImport(bytes);
      expect(parsed.issues, isEmpty);
      expect(parsed.rows.single.draft.tradeName, 'منتج باسم فقط');

      final import =
          ImportItemsUseCase(repo, const PermissionService(), const AuditService());
      final summary =
          await import(bytes, actingUserId: _admin, actingRoleId: _adminRole);
      expect(summary.created, 1);
      expect(summary.issues, isEmpty);

      final result =
          await repo.searchItems(const PageRequest(pageSize: 100));
      final row = result.items.singleWhere((i) => i.tradeName == 'منتج باسم فقط');
      expect(row.sellingPriceMicros, 0);
      expect(row.costMicros, 0);
      expect(row.categoryId, isNull);
      expect(await repo.itemUnitsFor(row.id), isNull);
    });

    test('D. blank cells on an update preserve the existing values', () async {
      final db = newDatabase();
      await awaitCategory(db);
      final repo = _repo(db);
      final ai1 = await repo.createActiveIngredient(
          MasterDataDraft(name: 'باراسيتامول'));
      final ind =
          await repo.createIndication(MasterDataDraft(name: 'صداع'));

      final item = await repo.createItem(ItemDraft(
        primaryBarcode: '6291041500888',
        tradeName: 'دواء قبل التعديل',
        equivalentDrug: 'مكافئ قديم',
        categoryId: 'cat_test_default',
        shelfLocation: 'رف ب-2',
        hasExpiry: true,
        costMicros: _micros('5.00'),
        sellingPriceMicros: _micros('10.00'),
        vatRateBasisPoints: 1500,
        minimumStockBase: 3,
        maximumStockBase: 30,
        units: ItemUnitRelation(
            baseUnitId: 'unit_strip', largeUnitId: 'unit_strip', unitsPerLarge: 10),
        activeIngredientIds: [ai1.id],
        activeIngredientStrengths: {ai1.id: '500 ملغ'},
        indicationIds: [ind.id],
      ));

      // Update sheet: only the wholesale price is explicit; every other
      // optional cell is blank and must preserve the existing value (Phase
      // 18.1 blank-preserves contract). The trade name stays unchanged so the
      // row matches the existing item via the trade-name fallback (the barcode
      // cell is deliberately blank).
      final cols = <String?>[
        null, // 0 primary barcode (blank → preserved via trade-name match)
        null, // 1 secondary barcode
        'دواء قبل التعديل', // 2 trade name (same → match key)
        null, // 3 EN
        null, // 4 scientific
        null, // 5 flat ingredient
        null, // 6 relational ingredients
        null, // 7 category
        null, // 8 manufacturer
        null, // 9 indications
        null, // 10 location
        null, // 11 has expiry
        null, // 12 parts
        null, // 13 packaging
        null, // 14 parts count
        null, // 15 selling price
        '11.00', // 16 wholesale
        null, // 17 half
        null, // 18 vat
        null, // 19 cost
        null, // 20 min
        null, // 21 max
        null, // 22 stock
        null, // 23 equivalent
        null, // 24 pharma form
        null, // 25 dose
        null, // 26 volume
      ];
      final bytes2 = _xlsx([cols]);

      final import =
          ImportItemsUseCase(repo, const PermissionService(), const AuditService());
      final summary = await import(
          // The trade-name match must reach the existing item despite the
          // blank barcode column.
          bytes2,
          actingUserId: _admin,
          actingRoleId: _adminRole);
      expect(summary.updated, 1);
      expect(summary.issues, isEmpty);

      final round = (await repo.findItem(item.id))!;
      expect(round.tradeName, 'دواء قبل التعديل',
          reason: 'trade name is the match key and stays unchanged');
      expect(round.primaryBarcode, '6291041500888',
          reason: 'blank barcode preserves the existing primary barcode');
      expect(round.sellingPriceMicros, _micros('10.00'),
          reason: 'blank selling preserves; only explicit cells change');
      expect(round.wholesalePriceMicros, _micros('11.00'));
      expect(round.costMicros, _micros('5.00'));
      expect(round.vatRateBasisPoints, 1500);
      expect(round.minimumStockBase, 3);
      expect(round.shelfLocation, 'رف ب-2');
      expect(round.equivalentDrug, 'مكافئ قديم');
      expect(round.hasExpiry, isTrue);

      final rels = await repo.activeIngredientRelationsForItem(item.id);
      expect(rels.single.strength, '500 ملغ');
      expect(await repo.indicationIdsForItem(item.id), [ind.id]);
      final units = await repo.itemUnitsFor(item.id);
      expect(units!.unitsPerLarge, 10);
    });

    test('E. `Name:strength` ;-separated relational ingredients import',
        () async {
      final db = newDatabase();
      await awaitCategory(db);
      final repo = _repo(db);
      final ai1 = await repo.createActiveIngredient(
          MasterDataDraft(name: 'أموكسيسيلين')) ;
      final ai2 = await repo.createActiveIngredient(
          MasterDataDraft(name: 'حمض الكلافولانيك')) ;

      final bytes = _xlsx([
        [
          '6291041500777',
          null,
          'أوجمنتين',
          null,
          null,
          null,
          'أموكسيسيلين:500 ملغ ; حمض الكلافولانيك:125 ملغ',
        ],
      ]);
      final import =
          ImportItemsUseCase(repo, const PermissionService(), const AuditService());
      final summary =
          await import(bytes, actingUserId: _admin, actingRoleId: _adminRole);
      expect(summary.created, 1);
      expect(summary.issues, isEmpty);

      final result =
          await repo.searchItems(const PageRequest(pageSize: 100));
      final row = result.items.singleWhere((i) => i.tradeName == 'أوجمنتين');
      final rels = await repo.activeIngredientRelationsForItem(row.id);
      final byIngredient = {
        for (final r in rels) r.activeIngredientId: r.strength,
      };
      expect(byIngredient[ai1.id], '500 ملغ');
      expect(byIngredient[ai2.id], '125 ملغ');
    });

    test('F. partially-specified unit relation is rejected with an issue',
        () async {
      final db = newDatabase();
      await awaitCategory(db);
      final repo = _repo(db);

      final bytes = _xlsx([
        [
          '6291041500666',
          null,
          'منتج بوحدة ناقصة',
          null,
          null,
          null,
          null,
          null,
          null,
          null,
          null,
          null,
          'ظرف', // parts given, packaging blank → incomplete
        ],
      ]);
      final import =
          ImportItemsUseCase(repo, const PermissionService(), const AuditService());
      final summary =
          await import(bytes, actingUserId: _admin, actingRoleId: _adminRole);
      expect(summary.created, 0);
      expect(summary.issues, isNotEmpty);
      expect(summary.issues.any((m) => m.contains('الوحدات')), isTrue,
          reason: 'a one-sided unit spec is reported, never half-applied');
    });

    test('G. financial fields optional: blank preserves on update, zero on create',
        () async {
      final db = newDatabase();
      await awaitCategory(db);
      final repo = _repo(db);

      // G1: new item with only a trade name + price left blank → 0 defaults.
      final createBytes = _xlsx([
        ['6291041500555', null, 'دواء بدون سعر'],
      ]);
      final import =
          ImportItemsUseCase(repo, const PermissionService(), const AuditService());
      final created = await import(
          createBytes, actingUserId: _admin, actingRoleId: _adminRole);
      expect(created.created, 1);
      final createdRow = (await _byBarcode(db, '6291041500555'))!;
      expect(createdRow.sellingPriceMicros, 0);
      expect(createdRow.costMicros, 0);

      // G2: update leaves a blank price untouched while applying a new cost.
      await repo.updateItem(
          createdRow.id,
          const ItemDraft(tradeName: 'دواء بدون سعر',
              primaryBarcode: '6291041500555',
              sellingPriceMicros: 4000000, costMicros: 2000000));
      final updateBytes = _xlsx([
        [
          '6291041500555',
          null,
          'دواء بدون سعر',
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
          null, // selling blank → preserved
          null,
          null,
          null,
          '3.00', // cost explicitly set
        ],
      ]);
      final updated = await import(
          updateBytes, actingUserId: _admin, actingRoleId: _adminRole);
      expect(updated.updated, 1);
      expect(updated.issues, isEmpty);
      final round = (await _byBarcode(db, '6291041500555'))!;
      expect(round.sellingPriceMicros, 4000000,
          reason: 'blank financial cells preserve the existing value');
      expect(round.costMicros, Money.parse('3.00').units);
    });
  });
}