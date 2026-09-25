/// POS search responsiveness regression tests (Ali, 2026-09-25).
///
/// 1. Latency: catalog search over a 10k-row Arabic catalog stays fast from
///    the very first letter, now that [PosCatalogDao] uses the precomputed
///    `search_text` column (§search-perf) instead of the per-row SQL
///    `replace()` chain on every keystroke.
/// 2. Supersession: a second keystroke cancels the first in-flight query — a
///    slow earlier query must never overwrite fresher results.
/// 3. Normalization parity: alef/hamza spelling variants still match through
///    the `search_text` path.
library;

import 'dart:async';

import 'package:drift/drift.dart' hide isNull;
import 'package:flutter_test/flutter_test.dart';
import 'package:pharmacy_pos/core/data_grid/page_request.dart';
import 'package:pharmacy_pos/data/daos/item_dao.dart';
import 'package:pharmacy_pos/features/sales/data/pos_catalog_dao.dart';
import 'package:pharmacy_pos/features/sales/domain/entities/pos_catalog_item.dart';
import 'package:pharmacy_pos/features/sales/domain/entities/pos_customer.dart';
import 'package:pharmacy_pos/features/sales/domain/entities/pos_invoice.dart';
import 'package:pharmacy_pos/features/sales/domain/entities/pos_return.dart';
import 'package:pharmacy_pos/features/sales/domain/entities/smart_alternative.dart';
import 'package:pharmacy_pos/features/sales/domain/repositories/sales_repository.dart';
import 'package:pharmacy_pos/features/sales/presentation/controllers/pos_workspace_controller.dart';
import 'package:pharmacy_pos/shared/database/app_database.dart';
import 'package:pharmacy_pos/shared/models/enums.dart';

import 'helpers.dart';

const _scaleRows = 10000;

final _baseNames = [
  'بانادول إكسترا',
  'أوجمنتين',
  'أموكسيل',
  'بروفين',
  'فولتارين',
  'كتافلام',
  'أدول',
  'بنادول كولد',
  'كلاريتين',
  'زيرتك',
  'أوميبرازول',
  'رانتدين',
  'ديكلوفيناك',
  'إيبوبروفين',
  'باراسيتامول',
  'سيتامول',
  'ترامادول',
  'كودائين',
  'أسبرين',
  'بلافيكس',
];

ItemRow _row(int i) {
  final name = '${_baseNames[i % _baseNames.length]} ${500 + (i % 7) * 125}ملغ';
  return ItemRow(
    id: 'perf_$i',
    tradeName: name,
    tradeNameEn: 'Product $i EN',
    scientificName: 'Scientific substance ${i % 50}',
    activeIngredient: 'المادة الفعالة ${i % 100}',
    hasExpiry: false,
    isControlledDrug: false,
    lockAutoPriceUpdate: false,
    requiresPrescription: false,
    costMicros: 80000000,
    purchaseDiscountBasisPoints: 0,
    sellingPriceMicros: 100000000,
    subUnitPriceMicros: 0,
    wholesalePriceMicros: 0,
    halfWholesalePriceMicros: 0,
    customPrice1Micros: 0,
    customPrice2Micros: 0,
    vatRateBasisPoints: 0,
    profitMarginBasisPoints: 2500,
    minimumStockBase: 0,
    maximumStockBase: 0,
    currentStockBase: 10,
    partialSaleEnabled: false,
    isActive: true,
    createdAt: 0,
    updatedAt: 0,
  );
}

Future<AppDatabase> _seededDb() async {
  final db = newDatabase();
  final dao = ItemDao(db);
  await db.transaction(() async {
    for (var i = 0; i < _scaleRows; i++) {
      await dao.insert(_row(i));
    }
  });
  return db;
}

Future<int> _medianMs(
  PosCatalogDao dao,
  String query, {
  int repeats = 5,
}) async {
  final times = <int>[];
  for (var i = 0; i < repeats; i++) {
    final sw = Stopwatch()..start();
    await dao.search(
      PageRequest(page: 1, pageSize: 40, search: query),
      inStockOnly: true,
    );
    sw.stop();
    times.add(sw.elapsedMilliseconds);
  }
  times.sort();
  return times[times.length ~/ 2];
}

/// Fake repository with a controllable search: each query parks on a
/// [Completer] the test completes manually, simulating slow/fast queries.
class _ControllableSalesRepository implements SalesRepository {
  final _pending = <String, Completer<PageResult<PosCatalogItem>>>{};

  @override
  Future<PageResult<PosCatalogItem>> searchCatalog(
    PageRequest request, {
    bool? inStockOnly,
  }) {
    final completer = Completer<PageResult<PosCatalogItem>>();
    _pending[request.search] = completer;
    return completer.future;
  }

  void complete(String query, String markerItemId) {
    final request = PageRequest(search: query);
    _pending.remove(query)?.complete(
      PageResult(
        items: [
          PosCatalogItem(
            id: markerItemId,
            tradeName: 'marker $query',
            isControlledDrug: false,
            requiresPrescription: false,
            isActive: true,
            sellingPriceMicros: 1000,
            vatRateBasisPoints: 0,
            currentStockBase: 10,
            availableStockBase: 10,
            baseUnitId: 'u1',
            baseUnitName: 'شريط',
            largeUnitId: 'u2',
            largeUnitName: 'علبة',
            unitsPerLarge: 1,
            partialSaleEnabled: false,
          ),
        ],
        total: 1,
        request: request,
      ),
    );
  }

  @override
  Future<PosCatalogItem?> itemByBarcode(String barcode) =>
      throw UnimplementedError();
  @override
  Future<PosCatalogItem?> itemById(String id) => throw UnimplementedError();
  @override
  Future<List<PosCustomer>> findCustomers(String query, {int limit = 20}) =>
      throw UnimplementedError();
  @override
  Future<List<PosRxSummary>> activePrescriptionsForCustomer(String customerId) =>
      throw UnimplementedError();
  @override
  Future<String> nextInvoiceNumber() => throw UnimplementedError();
  @override
  Future<String> nextReturnNumber() => throw UnimplementedError();
  @override
  Future<PosSaleOutcome> checkout(PosCheckoutCommand command) =>
      throw UnimplementedError();
  @override
  Future<void> voidInvoice(
    String invoiceId, {
    required String userId,
    required String reason,
  }) =>
      throw UnimplementedError();
  @override
  Future<PosReturnOutcome> returnSaleLine(PosReturnCommand command) =>
      throw UnimplementedError();
  @override
  Future<PageResult<PosReturnView>> listReturns(PageRequest request) =>
      throw UnimplementedError();
  @override
  Future<({PosReturnView header, List<PosReturnLineView> lines})?> returnDetail(
    String returnId,
  ) =>
      throw UnimplementedError();
  @override
  Future<PageResult<PosInvoiceView>> searchSaleInvoices(
    PageRequest request, {
    SaleStatus? status,
    PaymentMethod? paymentMethod,
    String? userId,
    int? fromMillis,
    int? toMillis,
  }) =>
      throw UnimplementedError();
  @override
  Future<PosInvoiceView?> invoiceViewById(String invoiceId) =>
      throw UnimplementedError();
  @override
  Future<List<SmartAlternative>> smartAlternatives(PosCatalogItem item) =>
      throw UnimplementedError();
  @override
  Future<void> recordLostSale(PosLostSaleDraft draft) =>
      throw UnimplementedError();
  @override
  Future<int> availableStock(String itemId) => throw UnimplementedError();
}

void main() {
  setUpAll(ensureSqlite);

  group('POS search latency (10k-row catalog)', () {
    test('first-letter search p50 stays under 150ms', () async {
      final db = await _seededDb();
      addTearDown(db.close);
      final dao = PosCatalogDao(db);
      // Warm up (JIT, page cache).
      await dao.search(
        const PageRequest(page: 1, pageSize: 40, search: 'x'),
        inStockOnly: true,
      );

      final p50 = await _medianMs(dao, 'ب');
      expect(p50, lessThan(150), reason: '1-letter query p50=${p50}ms');
    });

    test('two-letter and full-word searches stay fast', () async {
      final db = await _seededDb();
      addTearDown(db.close);
      final dao = PosCatalogDao(db);
      await dao.search(
        const PageRequest(page: 1, pageSize: 40, search: 'x'),
        inStockOnly: true,
      );

      expect(await _medianMs(dao, 'با'), lessThan(100));
      expect(await _medianMs(dao, 'بانادول'), lessThan(100));
    });

    test('results are correct through the search_text path', () async {
      final db = await _seededDb();
      addTearDown(db.close);
      final dao = PosCatalogDao(db);

      // 500 بانادول rows out of 10k (20 base names × 500 each).
      final result = await dao.search(
        const PageRequest(page: 1, pageSize: 40, search: 'بانادول'),
        inStockOnly: true,
      );
      expect(result.total, 500);
      expect(result.items, hasLength(40));
      expect(
        result.items.every((i) => i.tradeName.contains('بانادول')),
        isTrue,
      );
      // Relevance: name-prefix matches come first.
      expect(result.items.first.tradeName.startsWith('بانادول'), isTrue);
    });

    test('alef/hamza spelling variants still match', () async {
      final db = await _seededDb();
      addTearDown(db.close);
      final dao = PosCatalogDao(db);

      // Stored as أوجمنتين; typed with plain alef.
      final result = await dao.search(
        const PageRequest(page: 1, pageSize: 40, search: 'اوجمنتين'),
        inStockOnly: true,
      );
      expect(result.total, 500);
    });

    test('legacy fallback still matches rows with NULL search_text', () async {
      final db = newDatabase();
      addTearDown(db.close);
      final dao = ItemDao(db);
      await dao.insert(_row(0));
      // Simulate a pre-v14 row that missed the backfill.
      await (db.update(db.items)
            ..where((i) => i.id.equals('perf_0')))
          .write(const ItemsCompanion(searchText: Value(null)));

      final result = await PosCatalogDao(db).search(
        const PageRequest(page: 1, pageSize: 40, search: 'بانادول'),
        inStockOnly: true,
      );
      expect(result.total, 1);
      expect(result.items.single.id, 'perf_0');
    });
  });

  group('POS search supersession', () {
    test('second keystroke supersedes the first in-flight query', () async {
      final repo = _ControllableSalesRepository();
      final controller = PosWorkspaceController(tabIndex: 0, repository: repo);

      // First keystroke: slow query parks on its completer.
      final first = controller.search('ا');
      // Second keystroke before the first completes.
      final second = controller.search('اب');

      // The stale first query finally returns with WRONG (older) results.
      repo.complete('ا', 'stale_item');
      await first;
      await Future<void>.delayed(Duration.zero);

      // Stale results must not flash over the fresher query.
      final mid = controller.currentState;
      expect(mid.searchQuery, 'اب');
      expect(
        mid.searchResults?.items.any((i) => i.id == 'stale_item') ?? false,
        isFalse,
      );

      // The fresher query lands normally.
      repo.complete('اب', 'fresh_item');
      await second;
      final done = controller.currentState;
      expect(done.loading, isFalse);
      expect(done.searchResults?.items.single.id, 'fresh_item');
    });

    test('clearing the field clears results immediately', () async {
      final repo = _ControllableSalesRepository();
      final controller = PosWorkspaceController(tabIndex: 0, repository: repo);

      final pending = controller.search('اب');
      await controller.search('');
      final state = controller.currentState;
      expect(state.searchQuery, isEmpty);
      expect(state.searchResults, isNull);
      expect(state.loading, isFalse);

      // The orphaned query must not repopulate results afterwards.
      repo.complete('اب', 'orphan_item');
      await pending;
      await Future<void>.delayed(Duration.zero);
      expect(controller.currentState.searchResults, isNull);
    });
  });
}
