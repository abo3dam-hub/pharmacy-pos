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
import 'package:pharmacy_pos/domain/services/stock_service.dart';
import 'package:pharmacy_pos/features/inventory/data/repositories/inventory_repository_impl.dart';
import 'package:pharmacy_pos/features/inventory/domain/repositories/inventory_repository.dart';
import 'package:pharmacy_pos/features/inventory/domain/services/inventory_excel_service.dart';
import 'package:pharmacy_pos/shared/database/app_database.dart';

import 'helpers.dart';

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

/// Regression: each imported item keeps only its own indications.
/// Guards the report "every item ended up with ALL indications from the
/// Excel file" — the import assigns per-row indication links; the dialog
/// merely shows the whole master list as a picker.
void main() {
  setUpAll(ensureSqlite);

  test('each imported item keeps only its own indications', () async {
    final db = newDatabase();
    await awaitCategory(db);
    final repo = _repo(db);

    List<String?> row(String barcode, String name, String? indications) {
      final r = List<String?>.filled(
        InventoryExcelService.headers.length,
        null,
      );
      r[0] = barcode; // الرمز الشريطي الرئيسي
      r[2] = name; // الاسم التجاري
      r[9] = indications; // الاستطبابات
      return r;
    }

    final parsed = await InventoryExcelService(repo).parseImport(
      _xlsx([
        row('6000000000011', 'دواء أ', 'صداع؛حرارة'),
        row('6000000000022', 'دواء ب', 'سعال'),
        row('6000000000033', 'دواء ج', null),
      ]),
    );
    expect(parsed.issues, isEmpty);

    await repo.applyImport([
      for (final r in parsed.rows)
        ImportApplyEntry(
          rowNumber: r.rowNumber,
          draft: r.draft,
          existingItemId: r.existingItemId,
        ),
    ]);

    final names = <String, List<String>>{};
    for (final item in await db.select(db.items).get()) {
      final ids = await repo.indicationIdsForItem(item.id);
      final rows = await (db.select(
        db.indications,
      )..where((t) => t.id.isIn(ids))).get();
      names[item.tradeName] = [for (final x in rows) x.name]..sort();
    }
    expect(names['دواء أ'], ['حرارة', 'صداع']);
    expect(names['دواء ب'], ['سعال']);
    expect(names['دواء ج'], isEmpty);
  });
}
