import 'dart:io';

import 'package:drift/native.dart';
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

/// The scale the field experience was reported at (≈11.3k catalogue rows).
const _scaleRows = 11300;

/// The CI `perf-file-db` job (/CI job #4) runs this file with
/// `PHARMACY_FILE_DB=1` so the guardrail also covers real disk fsync stalls,
/// which an in-memory database cannot expose.
bool get _fileDb => Platform.environment['PHARMACY_FILE_DB'] == '1';

Future<AppDatabase> _database() async {
  if (!_fileDb) return newDatabase();
  final dir = await Directory.systemTemp.createTemp('pharmacy_perf_db_');
  return AppDatabase(NativeDatabase(File('${dir.path}/perf.sqlite')));
}

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

void main() {
  setUpAll(ensureSqlite);

  test(
      'catalog-level ingest stays linear: 11,300 fresh rows create + audit in '
      'one pass and re-import them as updates'
          '${_fileDb ? ' (file-backed DB)' : ' (in-memory DB)'}', () async {
    final db = await _database();
    final repo = _repo(db);
    final useCase = ImportItemsUseCase(
        repo, const PermissionService(), const AuditService());

    // barcode column (0), trade name column (2) — all other cells blank.
    final sheet = <List<String?>>[
      for (var i = 1; i <= _scaleRows; i++) ...[
        [
          '9930000000000${(100000 + i).toString().substring(1)}',
          null,
          'منتج أداء $i',
        ],
      ],
    ];
    final bytes = _xlsx(sheet);

    final sw = Stopwatch()..start();
    final first = await useCase
        .call(bytes, actingUserId: _admin, actingRoleId: _adminRole);
    sw.stop();
    final firstMs = sw.elapsedMilliseconds;
    // ignore: avoid_print
    print('applyImport fresh $_scaleRows rows: ${firstMs}ms');

    expect(first.created, _scaleRows);
    expect(first.updated, 0);
    if (first.issues.isNotEmpty) {
      // ignore: avoid_print
      print('sample issues: ${first.issues.take(3).toList()} '
          '(${first.issues.length} total)');
    }
    expect(first.issues, isEmpty, reason: 'a clean sheet must import fully');
    final count = await db
        .customSelect('SELECT COUNT(*) AS c FROM items')
        .getSingle();
    expect(count.read<int>('c'), _scaleRows);

    // One audit row per imported item + the bulk summary; createdMaster = 0.
    final audits = await db.select(db.auditLogs).get();
    final itemAudits =
        audits.where((a) => a.entityType == 'item').length;
    expect(itemAudits, _scaleRows + 1, reason: 'per-row + bulkOp summary');

    // Re-running the same sheet must hit the deterministic update path at the
    // same scale — the regression that preceded the identity fix collapsed
    // every barcode-less row into one item here.
    final sw2 = Stopwatch()..start();
    final second = await useCase
        .call(bytes, actingUserId: _admin, actingRoleId: _adminRole);
    sw2.stop();
    final secondMs = sw2.elapsedMilliseconds;
    // ignore: avoid_print
    print('applyImport re-run $_scaleRows rows: ${secondMs}ms');
    expect(second.created, 0);
    expect(second.updated, _scaleRows);

    // Guardrail against a performance regression, not a micro-benchmark: the
    // previous per-row transaction + per-row audit path blew well past this on
    // a file-backed DB; the ceiling exists to fail loudly, the printed numbers
    // give the real measurement. The file-backed CI job gets a wider ceiling
    // because shared-Runner disk I/O is noisier than a local disk.
    final ceilingMs = _fileDb ? 300000 : 120000;
    expect(firstMs, lessThan(ceilingMs),
        reason: 'a 11.3k fresh import must not take minutes');
    expect(secondMs, lessThan(ceilingMs));
  }, timeout: const Timeout(Duration(minutes: 10)));
}