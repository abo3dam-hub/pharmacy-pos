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
import 'package:pharmacy_pos/domain/services/audit_service.dart';
import 'package:pharmacy_pos/domain/services/permission_service.dart';
import 'package:pharmacy_pos/domain/services/stock_service.dart';
import 'package:pharmacy_pos/features/inventory/data/repositories/inventory_repository_impl.dart';
import 'package:pharmacy_pos/features/inventory/domain/services/inventory_excel_service.dart';
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

Future<int> _itemCount(AppDatabase db) async {
  final count = await db
      .customSelect('SELECT COUNT(*) AS c FROM items')
      .getSingle();
  return count.read<int>('c');
}

void main() {
  setUpAll(ensureSqlite);

  group('in-file duplicate identity (§18.2A regression)', () {
    test(
      'repeating trade names with distinct strengths each import; '
      'master data is created once per name',
      () async {
        final db = newDatabase();
        await awaitCategory(db);
        final repo = _repo(db);

        // Shaped like the supplier's real sheet: 8 trade names × 6 variants,
        // each variant differing only by active-ingredient strength, no
        // barcodes, all master data previously unknown.
        const manufacturers = [
          'فرسان الأدوية',
          'ابن رشد',
          'ميديم',
          'رام فارما',
        ];
        const ingredients = [
          'باراسيتامول',
          'إيبوبروفين',
          'أموكسيسيلين',
          'فيتامين د',
          'هيسبيريدين',
        ];
        const tradeNames = [
          'بانادول',
          'بروفين',
          'أموكسيل',
          'فيتامين د3',
          'ديوسمين',
          'سيترامول',
          'فولتارين',
          'أوغمنتين',
        ];

        final rows = <List<String?>>[];
        for (var p = 0; p < tradeNames.length; p++) {
          for (var variant = 0; variant < 6; variant++) {
            rows.add([
              null,
              null,
              tradeNames[p],
              null,
              null,
              null,
              '${ingredients[p % ingredients.length]}:${variant + 1}%',
              null,
              manufacturers[p % manufacturers.length],
            ]);
          }
        }
        expect(rows.length, 48);

        final summary = await ImportItemsUseCase(
          repo,
          const PermissionService(),
          const AuditService(),
        )(_xlsx(rows), actingUserId: _admin, actingRoleId: _adminRole);

        expect(
          summary.created,
          48,
          reason: 'every distinct trade-name+strength row is a new product',
        );
        expect(summary.updated, 0);
        expect(summary.issues, isEmpty);
        expect(
          summary.createdMaster,
          manufacturers.length + ingredients.length,
          reason: 'the 4 distinct manufacturers + 5 ingredients, once each',
        );
        expect(
          await _itemCount(db),
          48,
          reason: 'the first row was being the only import was the bug',
        );

        // Re-importing collapses to zero creates: every row now updates.
        final second = await ImportItemsUseCase(
          repo,
          const PermissionService(),
          const AuditService(),
        )(_xlsx(rows), actingUserId: _admin, actingRoleId: _adminRole);
        expect(second.created, 0);
        expect(second.updated, 48);
        expect(second.createdMaster, 0);
      },
    );

    test('truly identical rows still collapse to one item', () async {
      final db = newDatabase();
      await awaitCategory(db);
      final repo = _repo(db);

      // Two rows with the same full creation identity (same trade name,
      // dose, form, manufacturer, ingredient + strength).
      final rows = <List<String?>>[
        [
          null,
          null,
          'بانادول إكسترا',
          null,
          null,
          null,
          'باراسيتامول:500 ملغ',
          null,
          'فرسان الأدوية',
        ],
        [
          null,
          null,
          'بانادول إكسترا',
          null,
          null,
          null,
          'باراسيتامول:500 ملغ',
          null,
          'فرسان الأدوية',
        ],
      ];

      final summary = await ImportItemsUseCase(
        repo,
        const PermissionService(),
        const AuditService(),
      )(_xlsx(rows), actingUserId: _admin, actingRoleId: _adminRole);

      expect(summary.created, 1);
      expect(
        summary.issues.any((m) => m.contains('مكرر داخل الملف')),
        isTrue,
        reason: 'an exact in-file duplicate is still reported, not created',
      );
      expect(await _itemCount(db), 1);
    });

    test('distinct strengths are not reported as in-file duplicates', () async {
      final db = newDatabase();
      await awaitCategory(db);
      final repo = _repo(db);

      final parsed = await InventoryExcelService(repo).parseImport(
        _xlsx([
          [null, null, 'سيبروفلوكساسين'],
          [null, null, 'سيبروفلوكساسين', null, null, null, 'مادة:2%'],
        ]),
      );
      expect(
        parsed.issues.any((m) => m.contains('مكرر داخل الملف')),
        isFalse,
        reason: 'identical trade names with different ingredients are distinct',
      );
    });
  });
}