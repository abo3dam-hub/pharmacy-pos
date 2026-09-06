/// Lost-sale quick-capture gap closure: the enhanced dialog fields
/// (scientific name + notes) persist to `lost_sales`, and capturing a lost
/// sale never touches stock or financial records.
library;

import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:flutter_test/flutter_test.dart';
import 'package:pharmacy_pos/core/constants/permission_codes.dart';
import 'package:pharmacy_pos/domain/services/return_service.dart';
import 'package:pharmacy_pos/domain/services/sale_service.dart';
import 'package:pharmacy_pos/domain/services/stock_service.dart';
import 'package:pharmacy_pos/features/sales/data/pos_catalog_dao.dart';
import 'package:pharmacy_pos/features/sales/data/sales_repository_impl.dart';
import 'package:pharmacy_pos/features/sales/domain/entities/pos_customer.dart';
import 'package:pharmacy_pos/features/sales/presentation/controllers/pos_workspace_controller.dart';
import 'package:pharmacy_pos/shared/database/app_database.dart';
import 'package:pharmacy_pos/shared/models/enums.dart';

import 'helpers.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late AppDatabase db;
  late SalesRepositoryImpl repo;

  setUp(() async {
    db = newDatabase();
    await awaitCategory(db);
    repo = SalesRepositoryImpl(
      db,
      PosCatalogDao(db),
      const StockService(),
      SaleService(),
      ReturnService(),
    );
  });

  tearDown(() async => db.close());

  Future<int> countLostSales() async {
    final q = db.selectOnly(db.lostSales)..addColumns([db.lostSales.id.count()]);
    return (await q.getSingle()).read(db.lostSales.id.count()) ?? 0;
  }

  test('recordLostSale persists the enhanced draft with scientificName/note',
      () async {
    await repo.recordLostSale(const PosLostSaleDraft(
      requestedItemName: 'بانادول',
      quantityRequested: 3,
      userId: 'user_admin',
      barcode: '6291041500213',
      scientificName: 'Paracetamol',
      note: 'طلب عميل عبر الهاتف',
    ));

    expect(await countLostSales(), 1);
    final row = await (db.select(db.lostSales)
          ..orderBy([(_) => OrderingTerm.desc(db.lostSales.createdAt)])
          ..limit(1))
        .getSingle();
    expect(row.requestedItemName, 'بانادول');
    expect(row.scientificName, 'Paracetamol');
    expect(row.note, 'طلب عميل عبر الهاتف');
    expect(row.quantityRequested, 3);
    expect(row.status, LostSaleStatus.open);
  });

  test('captureLostSale stores the enhanced fields via the controller', () async {
    final itemId = await insertItem(db, barcode: '6291041500213');
    await insertBatch(db, itemId, quantityBase: 8);

    final controller =
        PosWorkspaceController(tabIndex: 0, repository: repo);
    final ok = await controller.captureLostSale(
      productName: 'منتج مطلوب',
      quantity: 2,
      scientificName: 'Substance X',
      note: 'ملاحظة من الصيدلاني',
      actingUserId: 'user_admin',
      permissions: {Perm.lostSalesCreate},
      barcode: '0000000000000',
    );
    expect(ok, isTrue);
    expect(controller.currentState.errorMessage, isNull);

    final row = await (db.select(db.lostSales)).getSingle();
    expect(row.scientificName, 'Substance X');
    expect(row.note, 'ملاحظة من الصيدلاني');
    expect(row.status, LostSaleStatus.open);
  });

  test('captureLostSale never mutates stock or financials', () async {
    final itemId = await insertItem(db, barcode: '6291041500213');
    final batchId = await insertBatch(db, itemId, quantityBase: 8);

    final before = await (db.select(db.batches)
          ..where((b) => b.id.equals(batchId)))
        .getSingle();

    final beforeCount = (await (db.selectOnly(db.stockMovements)
          ..addColumns([db.stockMovements.id.count()]))
        .getSingle())
        .read(db.stockMovements.id.count());

    final controller =
        PosWorkspaceController(tabIndex: 0, repository: repo);
    final ok = await controller.captureLostSale(
      productName: 'منتج ناقص',
      quantity: 5,
      actingUserId: 'user_admin',
      permissions: {Perm.lostSalesCreate},
      barcode: '9999999999999',
    );
    expect(ok, isTrue);

    final after = await (db.select(db.batches)
          ..where((b) => b.id.equals(batchId)))
        .getSingle();
    expect(after.quantityBase, before.quantityBase,
        reason: 'lost-sale capture must not consume stock');

    final invoiceCount = db.selectOnly(db.salesInvoices)
      ..addColumns([db.salesInvoices.id.count()]);
    expect((await invoiceCount.getSingle()).read(db.salesInvoices.id.count()) ?? 0,
        0);
    final afterCount = (await (db.selectOnly(db.stockMovements)
          ..addColumns([db.stockMovements.id.count()]))
        .getSingle())
        .read(db.stockMovements.id.count());
    expect(afterCount, beforeCount,
        reason: 'lost-sale capture must not write stock ledger movements');
  });

  test('captureLostSale permission guard for lost_sales.create', () async {
    final controller =
        PosWorkspaceController(tabIndex: 0, repository: repo);
    final ok = await controller.captureLostSale(
      productName: 'منتج',
      quantity: 1,
      actingUserId: 'user_admin',
      permissions: const {Perm.viewAlternatives},
      barcode: '0000000000000',
    );
    expect(ok, isFalse);
    expect(controller.currentState.errorMessage, isNotNull);
    expect(await countLostSales(), 0);
  });
}