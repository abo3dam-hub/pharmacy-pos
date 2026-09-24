import 'package:excel/excel.dart';
import 'package:flutter_test/flutter_test.dart';
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
import 'package:pharmacy_pos/domain/services/return_service.dart';
import 'package:pharmacy_pos/domain/services/sale_service.dart';
import 'package:pharmacy_pos/domain/services/stock_service.dart';
import 'package:pharmacy_pos/features/inventory/data/repositories/inventory_repository_impl.dart';
import 'package:pharmacy_pos/features/inventory/domain/repositories/inventory_repository.dart';
import 'package:pharmacy_pos/features/inventory/domain/services/inventory_excel_service.dart';
import 'package:pharmacy_pos/features/sales/data/pos_catalog_dao.dart';
import 'package:pharmacy_pos/features/sales/data/sales_repository_impl.dart';
import 'package:pharmacy_pos/shared/database/app_database.dart';
import 'package:pharmacy_pos/core/data_grid/page_request.dart';

import 'helpers.dart';

InventoryRepositoryImpl _invRepo(AppDatabase db) => InventoryRepositoryImpl(
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

SalesRepositoryImpl _salesRepo(AppDatabase db) => SalesRepositoryImpl(
  db,
  PosCatalogDao(db),
  const StockService(),
  SaleService(),
  ReturnService(),
);

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
  return excel.save()!;
}

/// End-to-end: catalog items imported with relational active ingredients
/// yield smart alternatives through the sales repository.
void main() {
  setUpAll(ensureSqlite);

  test('imported catalog items yield smart alternatives', () async {
    final db = newDatabase();
    await awaitCategory(db);
    final inv = _invRepo(db);
    final sales = _salesRepo(db);

    List<String?> row(
      String barcode,
      String name,
      String ingredients, {
      String? indications,
      String? manufacturer,
    }) {
      final r = List<String?>.filled(
        InventoryExcelService.headers.length,
        null,
      );
      r[0] = barcode;
      r[2] = name;
      r[6] = ingredients; // المواد الفعالة (relational name:strength)
      r[8] = manufacturer;
      r[9] = indications;
      r[15] = '100'; // سعر البيع
      return r;
    }

    final parsed = await InventoryExcelService(inv).parseImport(
      _xlsx([
        row(
          '6000000000011',
          'دواء أ',
          'باراسيتامول:500ملغ',
          indications: 'صداع',
          manufacturer: 'شركة X',
        ),
        row(
          '6000000000022',
          'دواء ب',
          'باراسيتامول:500ملغ',
          indications: 'صداع',
          manufacturer: 'شركة Y',
        ),
        row(
          '6000000000033',
          'دواء ج',
          'ايبوبروفين:200ملغ',
          indications: 'صداع',
          manufacturer: 'شركة X',
        ),
      ]),
    );
    expect(parsed.issues, isEmpty);
    await inv.applyImport([
      for (final r in parsed.rows)
        ImportApplyEntry(
          rowNumber: r.rowNumber,
          draft: r.draft,
          existingItemId: r.existingItemId,
        ),
    ]);

    final catalog = await PosCatalogDao(
      db,
    ).search(const PageRequest(page: 0, pageSize: 10));
    final requested = catalog.items.firstWhere((c) => c.tradeName == 'دواء أ');
    final alts = await sales.smartAlternatives(requested);
    expect(alts, isNotEmpty, reason: 'دواء ب shares the ingredient');
  });
}
