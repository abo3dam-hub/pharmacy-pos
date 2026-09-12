import 'dart:io';

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
import 'package:pharmacy_pos/features/inventory/domain/usecases/excel_use_cases.dart';
import 'package:pharmacy_pos/shared/database/app_database.dart';

import 'helpers.dart';

const _admin = 'user_admin';
const _adminRole = 'role_admin';

final _issueRowRe = RegExp(r'الصف (\d+)');
final _ambiguousRe = RegExp(r'يطابق أكثر من منتج');

/// The supplier's real catalogue sheet checked into the repo. This test is the
/// end-to-end acceptance: every time the file is present it is replayed into a
/// fresh database on the *new* import engine, so a change in parsing/dedupe
/// semantics cannot silently drift away from the real data shape. When the
/// file is absent (e.g. a fresh clone) the test self-skips instead of failing.
final _realFile = File('test1.xlsx');

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

void main() {
  setUpAll(ensureSqlite);

  if (!_realFile.existsSync()) {
    test('real catalogue file import (test1.xlsx)', () {},
        skip: 'test1.xlsx is not present in the repo — real-file acceptance '
            'runs once the file is committed');
    return;
  }

  test('the real catalogue file test1.xlsx imports end-to-end and updates on '
      're-import', () async {
    final db = newDatabase();
    final repo = _repo(db);
    final useCase = ImportItemsUseCase(
        repo, const PermissionService(), const AuditService());
    final bytes = _realFile.readAsBytesSync();

    final sw = Stopwatch()..start();
    final first =
        await useCase.call(bytes, actingUserId: _admin, actingRoleId: _adminRole);
    sw.stop();
    // ignore: avoid_print
    print('test1.xlsx first pass → created=${first.created} '
        'updated=${first.updated} master=${first.createdMaster} '
        'issues=${first.issues.length} in ${sw.elapsedMilliseconds}ms');
    if (first.issues.isNotEmpty) {
      // ignore: avoid_print
      print('  sample issues: ${first.issues.take(5).join(' · ')}');
    }

    final count = await db
        .customSelect('SELECT COUNT(*) AS c FROM items')
        .getSingle();
    expect(count.read<int>('c'), first.created,
        reason: 'every successfully created row must actually persist');

    final audits = await db.select(db.auditLogs).get();
    expect(
        audits.where((a) => a.entityType == 'item').length,
        first.created + first.updated + 1,
        reason: 'per-row journal + the bulk summary');

    // Re-running the same bytes over the populated DB must hit the update path
    // and touch exactly the rows the first pass created.
    final sw2 = Stopwatch()..start();
    final second =
        await useCase.call(bytes, actingUserId: _admin, actingRoleId: _adminRole);
    sw2.stop();
    // ignore: avoid_print
    print('test1.xlsx second pass → created=${second.created} '
        'updated=${second.updated} issues=${second.issues.length} '
        'in ${sw2.elapsedMilliseconds}ms');
    expect(second.created, 0,
        reason: 'a re-import must never re-create rows');

    // Rows the first pass created can turn into issues on the second pass only
    // when the name-only fallback identity becomes ambiguous ('>1 product with
    // the same name' — products without a barcode). These are expected data
    // quality guards, not dedupe drift: every other created row must update.
    final p1IssueRows = <int>{
      for (final issue in first.issues)
        if (_issueRowRe.firstMatch(issue) case final m?)
          int.parse(m.group(1)!),
    };
    final p2IssueRows = <int>{
      for (final issue in second.issues)
        if (_issueRowRe.firstMatch(issue) case final m?)
          int.parse(m.group(1)!),
    };
    final flipped = p2IssueRows.difference(p1IssueRows).toList()..sort();
    expect(second.updated, first.created - flipped.length,
        reason: 'every created row must either update or be guarded as '
            'ambiguous — nothing silently dropped');
    final ambiguousRowIssues = second.issues
        .where((i) => _ambiguousRe.hasMatch(i) && _issueRowRe.hasMatch(i))
        .toList();
    final flippedAmbiguousRows = <int>{
      for (final i in ambiguousRowIssues)
        if (_issueRowRe.firstMatch(i) case final m?)
          int.parse(m.group(1)!),
    }.intersection(flipped.toSet());
    expect(flippedAmbiguousRows.length, flipped.length,
        reason: 'every created-but-not-updated row must be a name-ambiguity '
            'guard on re-import (the only legal way a created row flips)');
    if (flipped.isNotEmpty) {
      // ignore: avoid_print
      print('  re-import name-ambiguity guards (need barcode / عيار / شكل / '
          'شركة in the source file): $flipped');
      for (final i in ambiguousRowIssues) {
        // ignore: avoid_print
        print('    $i');
      }
    }
  }, timeout: const Timeout(Duration(minutes: 10)));
}