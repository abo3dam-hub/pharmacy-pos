/// Regression tests for the package-vs-base-unit cost-basis fix.
///
/// The pharmacist enters costs per commercial package (the box); the database
/// stores costs per base unit because COGS is computed per base unit
/// (`batch.unitCostMicros × quantityBase`). Every entry point must convert
/// package → base (half-up) on the way in, and base → package on the way out.
///
/// Ali's scenario: package cost 11,000 with 3 parts per package, selling one
/// part at 5,600 → COGS must be ≈ 3,666.667, never 11,000.
library;

import 'package:excel/excel.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pharmacy_pos/core/data_grid/page_request.dart';
import 'package:pharmacy_pos/core/money/money.dart';
import 'package:pharmacy_pos/core/units/package_cost.dart';
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
import 'package:pharmacy_pos/domain/services/sale_service.dart';
import 'package:pharmacy_pos/domain/services/stock_service.dart';
import 'package:pharmacy_pos/features/inventory/data/repositories/inventory_repository_impl.dart';
import 'package:pharmacy_pos/features/inventory/domain/repositories/inventory_repository.dart';
import 'package:pharmacy_pos/features/inventory/domain/services/inventory_excel_service.dart';
import 'package:pharmacy_pos/features/inventory/domain/services/inventory_view_builder.dart';
import 'package:pharmacy_pos/features/inventory/domain/usecases/excel_use_cases.dart';
import 'package:pharmacy_pos/shared/database/app_database.dart';
import 'package:pharmacy_pos/shared/models/enums.dart';

import 'helpers.dart';

int _micros(String s) => Money.parse(s).units;

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

int _col(String name) => InventoryExcelService.headers.indexOf(name);

/// Seeded unit by name (seed_data ships ظرف/علبة/…; creating them again would
/// hit the UNIQUE constraint).
Future<UnitRow> _seededUnit(InventoryRepository repo, String name) async {
  final units = await repo.units();
  return units.singleWhere((u) => u.name == name);
}

/// Builds xlsx bytes with the canonical header row. Cells are positional
/// (null/absent → blank).
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

void main() {
  setUpAll(ensureSqlite);

  group('package_cost helpers', () {
    test('11000 package / 3 parts → 3666.6667 micros per base unit', () {
      expect(
        packageCostToBaseUnitCost(_micros('11000'), 3),
        _micros('3666.6667'),
      );
    });

    test('identity when the package holds a single base unit', () {
      expect(packageCostToBaseUnitCost(_micros('11000'), 1), _micros('11000'));
      expect(packageCostToBaseUnitCost(_micros('11000'), 0), _micros('11000'));
      expect(packageCostToBaseUnitCost(_micros('11000'), -2), _micros('11000'));
    });

    test('base → package is exact multiplication', () {
      expect(
        baseUnitCostToPackageCost(_micros('3666.6667'), 3),
        _micros('11000.0001'),
      );
      expect(baseUnitCostToPackageCost(_micros('5'), 1), _micros('5'));
    });

    test('package → base → package round-trips to the stored value', () {
      final base = packageCostToBaseUnitCost(_micros('11000'), 3);
      final back = packageCostToBaseUnitCost(
        baseUnitCostToPackageCost(base, 3),
        3,
      );
      expect(back, base);
    });
  });

  group('excel import cost basis', () {
    test('sheet cost 11000 with 3 parts stores 3666.6667 per base unit',
        () async {
      final db = newDatabase();
      await awaitCategory(db);
      final repo = _repo(db);
      final row =
          List<String?>.filled(InventoryExcelService.headers.length, null);
      row[_col('الاسم التجاري')] = 'دواء التكلفة';
      row[_col('الأجزاء')] = 'ظرف';
      row[_col('التعبئة التجارية')] = 'علبة';
      row[_col('عدد الأجزاء')] = '3';
      row[_col('سعر التكلفة')] = '11000';
      final bytes = _xlsx([row]);

      final import = ImportItemsUseCase(
          repo, const PermissionService(), const AuditService());
      final summary = await import(bytes,
          actingUserId: 'user_admin', actingRoleId: 'role_admin');
      expect(summary.created, 1);
      expect(summary.issues, isEmpty);

      final created = (await repo.searchItems(const PageRequest(pageSize: 10)))
          .items
          .singleWhere((i) => i.tradeName == 'دواء التكلفة');
      expect(
        created.costMicros,
        _micros('3666.6667'),
        reason: 'the sheet cost is per package; storage is per base unit',
      );
      final units = await repo.itemUnitsFor(created.id);
      expect(units!.unitsPerLarge, 3);
    });

    test('export writes the package-scale cost back', () async {
      final db = newDatabase();
      await awaitCategory(db);
      final repo = _repo(db);
      final baseUnit = await _seededUnit(repo, 'ظرف');
      final largeUnit = await _seededUnit(repo, 'علبة');
      await repo.createItem(ItemDraft(
        tradeName: 'دواء التصدير',
        categoryId: 'cat_test_default',
        costMicros: _micros('3666.6667'),
        units: ItemUnitRelation(
          baseUnitId: baseUnit.id,
          largeUnitId: largeUnit.id,
          unitsPerLarge: 3,
        ),
      ));

      final excel = InventoryExcelService(repo);
      final export = ExportItemsUseCase(
        repo,
        const PermissionService(),
        excel,
        viewBuilder: InventoryViewBuilder(repo),
      );
      final bytes = await export(actingRoleId: 'role_admin');
      final decoded = Excel.decodeBytes(bytes);
      final sheet = decoded.tables['products']!;
      final costCell = sheet.row(1)[_col('سعر التكلفة')]?.value;
      // The sheet shows two decimals like every other money column, so
      // 11,000.0001 displays as 11,000.00 — and re-importing it divides back
      // to exactly the stored 3,666.6667 (110,000,000 ÷ 3 rounds half-up to
      // 36,666,667), so the round-trip is stable.
      expect(
        Money.parse(costCell.toString()).units,
        _micros('11000'),
        reason: 'export shows the pharmacist-facing package cost',
      );
    });
  });

  group('margin on the package basis', () {
    test('stored margin compares package cost against package price', () async {
      final db = newDatabase();
      await awaitCategory(db);
      final repo = _repo(db);
      final baseUnit = await _seededUnit(repo, 'ظرف');
      final largeUnit = await _seededUnit(repo, 'علبة');
      final item = await repo.createItem(ItemDraft(
        tradeName: 'دواء الهامش',
        categoryId: 'cat_test_default',
        costMicros: _micros('3666.6667'),
        sellingPriceMicros: _micros('14000'),
        units: ItemUnitRelation(
          baseUnitId: baseUnit.id,
          largeUnitId: largeUnit.id,
          unitsPerLarge: 3,
        ),
      ));
      // (14,000 − 11,000.0001) ÷ 11,000.0001 ≈ 27.27% — not the 281% the
      // mixed-basis computation produced.
      expect(item.profitMarginBasisPoints, 2727);
    });
  });

  group("Ali's COGS scenario", () {
    test('selling one part posts COGS 3666.6667 — never the 11000 box cost',
        () async {
      final db = newDatabase();
      final itemId = await insertItem(db);
      // Entry path: the pharmacist types the *package* cost 11,000 for a
      // 3-part box; the batch stores the per-base-unit cost.
      final perBase = packageCostToBaseUnitCost(_micros('11000'), 3);
      expect(perBase, _micros('3666.6667'));
      await insertBatch(db, itemId, quantityBase: 3, unitCostMicros: perBase);

      final outcome = await SaleService().recordSale(
        db,
        SaleRequest(
          invoiceNumber: 'SI-COGS-PART-11000',
          userId: 'user_admin',
          paymentMethod: PaymentMethod.cash,
          paidMicros: _micros('5600'),
          lines: [
            SaleLineRequest(
              itemId: itemId,
              quantityBase: 1,
              quantity: 1,
              unitBaseQuantity: 1,
              unitPriceMicros: _micros('5600'),
              unitTypeId: 'unit_part',
            ),
          ],
        ),
      );

      expect(outcome.invoice.totalMicros, _micros('5600'));
      expect(outcome.invoice.totalCostMicros, _micros('3666.6667'));
      expect(
        outcome.invoice.totalCostMicros,
        isNot(_micros('11000')),
        reason: 'the historic bug posted the whole box cost for one part',
      );
    });
  });
}
