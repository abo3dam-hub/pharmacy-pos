/// Performance regression (§30): the POS invoice search must not run N+1
/// queries per invoice. `searchSaleInvoices` builds a whole page with a fixed
/// set of batched loads (customers + lines + names in `IN` queries), so the
/// number of SELECTs must stay constant as invoices accumulate.
library;

import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pharmacy_pos/core/constants/permission_codes.dart';
import 'package:pharmacy_pos/core/data_grid/page_request.dart';
import 'package:pharmacy_pos/domain/services/return_service.dart';
import 'package:pharmacy_pos/domain/services/sale_service.dart';
import 'package:pharmacy_pos/domain/services/stock_service.dart';
import 'package:pharmacy_pos/features/sales/data/pos_catalog_dao.dart';
import 'package:pharmacy_pos/features/sales/data/sales_repository_impl.dart';
import 'package:pharmacy_pos/features/sales/domain/entities/pos_catalog_item.dart';
import 'package:pharmacy_pos/features/sales/presentation/controllers/pos_workspace_controller.dart';
import 'package:pharmacy_pos/shared/database/app_database.dart';

import 'helpers.dart';

/// Counts every SELECT executed on the wrapped connection.
class CountingInterceptor extends QueryInterceptor {
  int selectCount = 0;

  @override
  Future<List<Map<String, Object?>>> runSelect(
    QueryExecutor executor,
    String statement,
    List<Object?> args,
  ) async {
    selectCount++;
    return executor.runSelect(statement, args);
  }
}

void main() {
  late CountingInterceptor counter;
  late AppDatabase db;
  late SalesRepositoryImpl repo;
  late PosWorkspaceController controller;

  setUp(() {
    ensureSqlite();
    counter = CountingInterceptor();
    db = AppDatabase(
      NativeDatabase.memory().interceptWith(counter),
    );
    repo = SalesRepositoryImpl(
        db, PosCatalogDao(db), StockService(), SaleService(), ReturnService());
    controller = PosWorkspaceController(tabIndex: 0, repository: repo);
  });

  tearDown(() async {
    await db.close();
  });

  Future<String> seedItemAndBatch(String barcode) async {
    await insertItem(db, barcode: barcode);
    final itemId = (await (db.select(db.items)
          ..where((i) => i.primaryBarcode.equals(barcode)))
        .getSingle())
        .id;
    await (db.update(db.items)..where((i) => i.id.equals(itemId))).write(
      ItemsCompanion(
        sellingPriceMicros: const Value(50000),
        isActive: const Value(true),
        vatRateBasisPoints: const Value(0),
      ),
    );
    await insertBatch(
      db,
      itemId,
      quantityBase: 100,
      unitCostMicros: 10000,
      batchNumber: 'B-$barcode',
    );
    return itemId;
  }

  Future<void> completeSale(String barcode) async {
    final PosCatalogItem item = (await repo.itemById(
        (await (db.select(db.items)
              ..where((i) => i.primaryBarcode.equals(barcode)))
            .getSingle())
            .id))!;
    await controller.addToCart(item, quantity: 2);
    final total = controller.totals.totalMicros;
    controller.updatePaymentInputs(cashReceivedMicros: total);
    final outcome = await controller.checkout(
      actingUserId: 'user_admin',
      permissions: {Perm.sell},
    );
    expect(outcome, isNotNull);
  }

  Future<int> searchSelectCount() async {
    final page = await repo.searchSaleInvoices(
      PageRequest(page: 1, pageSize: 100),
    );
    expect(page.items, isNotEmpty);
    return counter.selectCount;
  }

  group('searchSaleInvoices — bounded queries (§30 no N+1)', () {
    test('query cost is constant as the page grows', () async {
      await seedItemAndBatch('S001');
      await completeSale('S001');

      counter.selectCount = 0;
      final costForOne = await searchSelectCount();

      for (final barcode in ['S002', 'S003', 'S004', 'S005']) {
        await seedItemAndBatch(barcode);
        await completeSale(barcode);
      }
      expect(await (db.select(db.salesInvoices)).get(), hasLength(5));

      counter.selectCount = 0;
      final costForFive = await searchSelectCount();

      // Batched building costs the same regardless of page size. Old per-head
      // code grew ~5 SELECTs per extra invoice — difference >> 2 would fail.
      expect(costForFive - costForOne, lessThanOrEqualTo(2));
    });

    test('loaded invoice views are correct after batching', () async {
      await seedItemAndBatch('S010');
      await completeSale('S010');

      final page = await repo.searchSaleInvoices(
        PageRequest(page: 1, pageSize: 100),
      );
      expect(page.total, 1);
      final view = page.items.single;
      expect(view.lines, hasLength(1));
      expect(view.lines.single.itemName, 'بانادول (Panadol)');
      expect(view.lines.single.batchNumber, isNotEmpty);
      expect(view.lines.single.unitTypeName, isNotEmpty);
      expect(view.totalMicros, 100000);
    });
  });
}