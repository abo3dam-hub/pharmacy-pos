/// POS Phase 7 integration tests against a real in-memory Drift database
/// (`AppDatabase.forTesting()` via `newDatabase()`).
///
/// Covers the prescription-gated cart, mixed RX/OTC carts, FEFO batch
/// consumption, partial returns with RX reversal, transactional rollback on
/// underpayment, and the end-to-end RBAC gate.
library;

import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:flutter_test/flutter_test.dart';
import 'package:pharmacy_pos/core/constants/permission_codes.dart';
import 'package:pharmacy_pos/core/data_grid/page_request.dart';
import 'package:pharmacy_pos/domain/services/purchase_service.dart';
import 'package:pharmacy_pos/domain/services/stock_service.dart';
import 'package:pharmacy_pos/features/sales/data/pos_catalog_dao.dart';
import 'package:pharmacy_pos/features/sales/data/sales_repository_impl.dart';
import 'package:pharmacy_pos/features/sales/domain/entities/pos_cart.dart';
import 'package:pharmacy_pos/features/sales/domain/entities/pos_catalog_item.dart';
import 'package:pharmacy_pos/features/sales/domain/entities/pos_customer.dart';
import 'package:pharmacy_pos/features/sales/domain/entities/pos_invoice.dart';
import 'package:pharmacy_pos/features/sales/presentation/controllers/pos_workspace_controller.dart';
import 'package:pharmacy_pos/features/sales/presentation/controllers/pos_workspace_state.dart';
import 'package:pharmacy_pos/domain/services/return_service.dart';
import 'package:pharmacy_pos/domain/services/sale_service.dart';
import 'package:pharmacy_pos/shared/database/app_database.dart';
import 'package:pharmacy_pos/shared/models/enums.dart';

import 'package:pharmacy_pos/core/errors/exceptions.dart';
import 'package:pharmacy_pos/features/sales/domain/repositories/sales_repository.dart';
import 'package:pharmacy_pos/features/sales/domain/usecases/payment_calculator.dart';

import 'helpers.dart';

Future<String> _seedItem(
  AppDatabase db, {
  required String barcode,
  required int sellingPriceMicros,
}) async {
  await insertItem(db, barcode: barcode);
  final itemId = (await (db.select(db.items)
        ..where((i) => i.primaryBarcode.equals(barcode)))
      .getSingle())
      .id;
  await (db.update(db.items)..where((i) => i.id.equals(itemId))).write(
    ItemsCompanion(
      sellingPriceMicros: Value(sellingPriceMicros),
      isActive: const Value(true),
      vatRateBasisPoints: const Value(0),
    ),
  );
  return itemId;
}

Future<void> _seedUnit(
  AppDatabase db,
  String id,
  String name,
) async {
  await db.into(db.units).insert(
        UnitsCompanion.insert(
          id: id,
          name: name,
          createdAt: DateTime.now().millisecondsSinceEpoch,
          updatedAt: DateTime.now().millisecondsSinceEpoch,
        ),
        mode: InsertMode.insertOrIgnore,
      );
}

Future<String> _seedCustomer(
  AppDatabase db, {
  String name = 'عميل تجريبي',
}) async {
  final now = DateTime.now().millisecondsSinceEpoch;
  final id = 'customer_$now';
  await db.into(db.customers).insert(
        CustomersCompanion.insert(
          id: id,
          name: name,
          phone: const Value('0000000000'),
          createdAt: now,
          updatedAt: now,
        ),
      );
  return id;
}

Future<void> _seedItemUnits(
  AppDatabase db,
  String itemId, {
  required String baseUnitId,
  required String largeUnitId,
  required int unitsPerLarge,
}) async {
  await _seedUnit(db, baseUnitId, 'وحدات صغيرة');
  await _seedUnit(db, largeUnitId, 'وحدات كبيرة');
  await db.into(db.itemUnits).insert(
        ItemUnitsCompanion.insert(
          id: 'iu_$itemId',
          itemId: itemId,
          baseUnitId: baseUnitId,
          largeUnitId: largeUnitId,
          unitsPerLarge: Value(unitsPerLarge),
        ),
        mode: InsertMode.insertOrIgnore,
      );
}

Future<({String prescriptionId, String prescriptionItemId})>
    _seedPrescription(
  AppDatabase db, {
  required String customerId,
  required String itemId,
  int quantityBase = 200,
}) async {
  final now = DateTime.now().millisecondsSinceEpoch;
  final rxId = 'rx_$now';
  final piId = 'pi_$now';
  await db.into(db.prescriptions).insert(
        PrescriptionsCompanion.insert(
          id: rxId,
          prescriptionNumber: 'RX-$now',
          customerId: customerId,
          patientName: 'مريض اختبار',
          doctorName: const Value('د. اختبار'),
          doctorSpecialty: const Value('general'),
          issuedAt: now,
          notes: const Value.absent(),
          status: PrescriptionStatus.active,
          createdBy: 'user_admin',
          createdAt: now,
          updatedAt: now,
        ),
      );
  await db.into(db.prescriptionItems).insert(
        PrescriptionItemsCompanion.insert(
          id: piId,
          prescriptionId: rxId,
          itemId: itemId,
          quantityBase: quantityBase,
          dispensedQuantityBase: const Value(0),
          isDispensed: const Value(false),
          dosage: const Value('مرة يومياً'),
          frequency: const Value('صباحاً'),
          durationDays: const Value(7),
          createdAt: now,
        ),
      );
  return (prescriptionId: rxId, prescriptionItemId: piId);
}

({AppDatabase db, SalesRepositoryImpl repo, PosWorkspaceController controller})
    _harness() {
  final db = newDatabase();
  final repo = SalesRepositoryImpl(
      db, PosCatalogDao(db), const StockService(), SaleService(), ReturnService());
  final controller = PosWorkspaceController(tabIndex: 0, repository: repo);
  return (db: db, repo: repo, controller: controller);
}

void main() {
  late AppDatabase db;
  late SalesRepositoryImpl repo;
  late PosWorkspaceController controller;

  setUp(() {
    final harness = _harness();
    db = harness.db;
    repo = harness.repo;
    controller = harness.controller;
  });

  tearDown(() async {
    await db.close();
  });

  group('RX partial → dispensed', () {
    test('a box dispensed against a 200-base rx keeps status partially dispensed',
        () async {
      final itemId =
          await _seedItem(db, barcode: 'RX001', sellingPriceMicros: 100000);
      await (db.update(db.items)..where((i) => i.id.equals(itemId))).write(
            ItemsCompanion(requiresPrescription: const Value(true)),
          );
      await _seedItemUnits(db, itemId,
          baseUnitId: 'unit_strip',
          largeUnitId: 'unit_box',
          unitsPerLarge: 100);

      final supplierId = await insertSupplier(db);
      final now = DateTime.now().millisecondsSinceEpoch;
      await PurchaseService().recordPurchase(
        db,
        PurchaseRequest(
          invoiceNumber: 'PI-RX-1',
          supplierId: supplierId,
          invoiceDate: now,
          userId: 'user_admin',
          lines: [
            PurchaseLineRequest(
              itemId: itemId,
              quantityBase: 300,
              unitCostMicros: 15000,
              unitTypeId: 'unit_strip',
              batchNumber: 'BAT-RX',
              expiryDate: now + 365 * 86400000,
            ),
          ],
        ),
      );

      final customerId = await _seedCustomer(db);
      final rx =
          await _seedPrescription(db, customerId: customerId, itemId: itemId);

      final PosCatalogItem item = (await repo.itemById(itemId))!;
      expect(item.availableStockBase, 300);

      await controller.selectCustomer(PosCustomer(
        id: customerId,
        name: 'عميل تجريبي',
        hasAccount: false,
        isActive: true,
        balanceMicros: 0,
      ));
      final PosWorkspaceState afterCustomer = controller.currentState;
      expect(afterCustomer.activePrescriptions, hasLength(1));
      controller.selectPrescription(rx.prescriptionId);

      await controller.addToCart(item, quantity: 1);
      expect(controller.currentState.cart, hasLength(1));
      final cartLine = controller.currentState.cart.single;
      expect(cartLine.unitMode, PosLineUnitMode.largeUnit);
      expect(cartLine.prescriptionItemId, rx.prescriptionItemId);

      final total = controller.totals.totalMicros;
      expect(total, 100000);
      controller.updatePaymentInputs(cashReceivedMicros: total + 100000);

      final outcome = await controller.checkout(
        actingUserId: 'user_admin',
        permissions: {Perm.sell},
      );
      expect(outcome, isNotNull);
      expect(outcome!.invoice.totalMicros, 100000);
      expect(outcome.lines, hasLength(1));
      expect(outcome.lines.single.prescriptionItemId, rx.prescriptionItemId);

      final pi = await (db.select(db.prescriptionItems)
            ..where((p) => p.id.equals(rx.prescriptionItemId)))
          .getSingle();
      expect(pi.dispensedQuantityBase, 100);
      expect(pi.isDispensed, false);

      final rxRow = await (db.select(db.prescriptions)
            ..where((p) => p.id.equals(rx.prescriptionId)))
          .getSingle();
      expect(rxRow.status, PrescriptionStatus.partially_dispensed);

      final batch = await (db.select(db.batches)
            ..where((b) => b.itemId.equals(itemId)))
          .getSingle();
      expect(batch.quantityBase, 200);

      final search = await repo.searchSaleInvoices(
        PageRequest(page: 1, pageSize: 10, search: outcome.invoice.invoiceNumber),
      );
      expect(search.total, 1);
      expect(search.items.single.id, outcome.invoice.id);
      expect(search.items.single.prescriptionId, rx.prescriptionId);
    });
  });

  group('RX + OTC mixed cart', () {
    test('OTC sells freely while the Rx item stays prescription-linked', () async {
      final otcId =
          await _seedItem(db, barcode: 'OTC001', sellingPriceMicros: 50000);
      final rxId =
          await _seedItem(db, barcode: 'RX002', sellingPriceMicros: 100000);
      await (db.update(db.items)..where((i) => i.id.equals(rxId))).write(
            ItemsCompanion(requiresPrescription: const Value(true)),
          );

      await insertBatch(
          db, otcId, quantityBase: 100, unitCostMicros: 5000, batchNumber: 'B-OTC');
      await insertBatch(
          db, rxId, quantityBase: 100, unitCostMicros: 10000, batchNumber: 'B-RX');

      final customerId = await _seedCustomer(db, name: 'عميل مختلط');
      final rx = await _seedPrescription(
          db, customerId: customerId, itemId: rxId, quantityBase: 100);

      final PosCatalogItem otcItem = (await repo.itemById(otcId))!;
      final PosCatalogItem rxItem = (await repo.itemById(rxId))!;
      expect(otcItem.availableStockBase, 100);
      expect(rxItem.availableStockBase, 100);

      await controller.selectCustomer(PosCustomer(
        id: customerId,
        name: 'عميل مختلط',
        hasAccount: false,
        isActive: true,
        balanceMicros: 0,
      ));
      controller.selectPrescription(rx.prescriptionId);

      await controller.addToCart(otcItem, quantity: 5);
      expect(controller.currentState.cart, hasLength(1));
      expect(controller.currentState.cart.single.prescriptionItemId, isNull);

      await controller.addToCart(rxItem, quantity: 2);
      expect(controller.currentState.cart, hasLength(2));
      final rxCartLine =
          controller.currentState.cart.firstWhere((l) => l.item.id == rxId);
      expect(rxCartLine.prescriptionItemId, rx.prescriptionItemId);

      final total = controller.totals.totalMicros;
      expect(total, 450000);
      controller.updatePaymentInputs(cashReceivedMicros: total);

      final outcome = await controller.checkout(
        actingUserId: 'user_admin',
        permissions: {Perm.sell},
      );
      expect(outcome, isNotNull);
      expect(outcome!.invoice.totalMicros, 450000);
      expect(outcome.lines, hasLength(2));

      final otcLine = outcome.lines.firstWhere((l) => l.itemId == otcId);
      expect(otcLine.quantityBaseSigned, 5);
      expect(otcLine.unitPriceMicros, 50000);
      expect(otcLine.lineTotalMicros, 250000);
      expect(otcLine.prescriptionItemId, isNull);

      final rxLine = outcome.lines.firstWhere((l) => l.itemId == rxId);
      expect(rxLine.quantityBaseSigned, 2);
      expect(rxLine.unitPriceMicros, 100000);
      expect(rxLine.lineTotalMicros, 200000);
      expect(rxLine.prescriptionItemId, rx.prescriptionItemId);
    });
  });

  group('FEFO multi-batch', () {
    test('older expiry batch drains before the newer one', () async {
      final itemId = await _seedItem(db, barcode: 'FEFO001', sellingPriceMicros: 50000);
      await (db.update(db.items)..where((i) => i.id.equals(itemId))).write(
            ItemsCompanion(hasExpiry: const Value(true)),
          );

      final supplierId = await insertSupplier(db);
      final now = DateTime.now().millisecondsSinceEpoch;
      await PurchaseService().recordPurchase(
        db,
        PurchaseRequest(
          invoiceNumber: 'PI-FEFO-1',
          supplierId: supplierId,
          invoiceDate: now,
          userId: 'user_admin',
          lines: [
            PurchaseLineRequest(
              itemId: itemId,
              quantityBase: 20,
              unitCostMicros: 5000,
              unitTypeId: 'unit_strip',
              batchNumber: 'FEFO-A',
              expiryDate: now + 30 * 86400000,
            ),
            PurchaseLineRequest(
              itemId: itemId,
              quantityBase: 30,
              unitCostMicros: 6000,
              unitTypeId: 'unit_strip',
              batchNumber: 'FEFO-B',
              expiryDate: now + 90 * 86400000,
            ),
          ],
        ),
      );

      final PosCatalogItem item = (await repo.itemById(itemId))!;
      expect(item.availableStockBase, 50);

      await controller.addToCart(item, quantity: 25);
      expect(controller.currentState.cart.single.quantity, 25);

      final total = controller.totals.totalMicros;
      expect(total, 25 * 50000);
      controller.updatePaymentInputs(cashReceivedMicros: total);

      final outcome = await controller.checkout(
        actingUserId: 'user_admin',
        permissions: {Perm.sell},
      );
      expect(outcome, isNotNull);
      expect(outcome!.lines, hasLength(2));

      final batches = await (db.select(db.batches)
            ..where((b) => b.itemId.equals(itemId)))
          .get();
      final batchA = batches.singleWhere((b) => b.batchNumber == 'FEFO-A');
      final batchB = batches.singleWhere((b) => b.batchNumber == 'FEFO-B');
      expect(batchA.quantityBase, 0);
      expect(batchB.quantityBase, 25);

      final itemAfter = await (db.select(db.items)
            ..where((i) => i.id.equals(itemId)))
          .getSingle();
      expect(itemAfter.currentStockBase, 25);
    });
  });

  group('Partial return + over-return prevention + RX reversal', () {
    test('returns restore stock, reject over-return, and reverse the rx', () async {
      final itemId =
          await _seedItem(db, barcode: 'RET001', sellingPriceMicros: 100000);
      await _seedItemUnits(db, itemId,
          baseUnitId: 'unit_strip',
          largeUnitId: 'unit_box',
          unitsPerLarge: 100);

      final supplierId = await insertSupplier(db);
      final now = DateTime.now().millisecondsSinceEpoch;
      await PurchaseService().recordPurchase(
        db,
        PurchaseRequest(
          invoiceNumber: 'PI-RET-1',
          supplierId: supplierId,
          invoiceDate: now,
          userId: 'user_admin',
          lines: [
            PurchaseLineRequest(
              itemId: itemId,
              quantityBase: 300,
              unitCostMicros: 8000,
              unitTypeId: 'unit_strip',
              batchNumber: 'RET-BAT',
              expiryDate: now + 365 * 86400000,
            ),
          ],
        ),
      );

      final customerId = await _seedCustomer(db, name: 'عميل مرتجع');
      final rx = await _seedPrescription(
          db, customerId: customerId, itemId: itemId, quantityBase: 100);

      final saleOutcome = await repo.checkout(PosCheckoutCommand(
        invoiceNumber: 'SI-RET-1',
        lines: [
          PosSaleLineInput(
            itemId: itemId,
            quantityBase: 10,
            unitPriceMicros: 10000,
            unitTypeId: 'unit_strip',
            vatRateBasisPoints: 0,
            discountBasisPoints: 0,
            prescriptionItemId: rx.prescriptionItemId,
          ),
        ],
        paymentMethod: PosPaymentMethod.cash,
        paidMicros: 100000,
        userId: 'user_admin',
        customerId: customerId,
        prescriptionId: rx.prescriptionId,
      ));
      final saleLineId = saleOutcome.lines.single.id;
      expect(saleOutcome.lines.single.quantityBaseSigned, 10);
      expect(saleOutcome.lines.single.unitPriceMicros, 10000);

      var pi = await (db.select(db.prescriptionItems)
            ..where((p) => p.id.equals(rx.prescriptionItemId)))
          .getSingle();
      expect(pi.dispensedQuantityBase, 10);

      final return4 = await repo.returnSaleLine(PosReturnCommand(
        returnNumber: 'RT-$now-1',
        originalInvoiceItemId: saleLineId,
        quantityBase: 4,
        userId: 'user_admin',
        reason: 'إرجاع جزئي',
      ));
      expect(return4.restoredQuantityBase, 4);

      var line = await (db.select(db.salesInvoiceItems)
            ..where((l) => l.id.equals(saleLineId)))
          .getSingle();
      expect(line.returnQuantityBase, 4);

      pi = await (db.select(db.prescriptionItems)
            ..where((p) => p.id.equals(rx.prescriptionItemId)))
          .getSingle();
      expect(pi.dispensedQuantityBase, 6);

      await expectLater(
        repo.returnSaleLine(PosReturnCommand(
          returnNumber: 'RT-$now-2',
          originalInvoiceItemId: saleLineId,
          quantityBase: 7,
          userId: 'user_admin',
          reason: 'إرجاع زائد',
        )),
        throwsA(isA<NotEnoughStockException>()),
      );

      line = await (db.select(db.salesInvoiceItems)
            ..where((l) => l.id.equals(saleLineId)))
          .getSingle();
      expect(line.returnQuantityBase, 4);
      pi = await (db.select(db.prescriptionItems)
            ..where((p) => p.id.equals(rx.prescriptionItemId)))
          .getSingle();
      expect(pi.dispensedQuantityBase, 6);

      final return6 = await repo.returnSaleLine(PosReturnCommand(
        returnNumber: 'RT-$now-3',
        originalInvoiceItemId: saleLineId,
        quantityBase: 6,
        userId: 'user_admin',
        reason: 'إرجاع الباقي',
      ));
      expect(return6.restoredQuantityBase, 6);

      line = await (db.select(db.salesInvoiceItems)
            ..where((l) => l.id.equals(saleLineId)))
          .getSingle();
      expect(line.returnQuantityBase, 10);

      pi = await (db.select(db.prescriptionItems)
            ..where((p) => p.id.equals(rx.prescriptionItemId)))
          .getSingle();
      expect(pi.dispensedQuantityBase, 0);
      expect(pi.isDispensed, false);

      final rxRow = await (db.select(db.prescriptions)
            ..where((p) => p.id.equals(rx.prescriptionId)))
          .getSingle();
      expect(rxRow.status, PrescriptionStatus.active);

      final batch = await (db.select(db.batches)
            ..where((b) => b.itemId.equals(itemId)))
          .getSingle();
      expect(batch.quantityBase, 300);
    });
  });

  group('paid < total rollback atomicity', () {
    test('underpaid checkout rolls back the invoice and stock atomically', () async {
      final itemId =
          await _seedItem(db, barcode: 'PAID001', sellingPriceMicros: 50000);
      await insertBatch(
          db, itemId, quantityBase: 10, unitCostMicros: 10000, batchNumber: 'PAID-B');

      await expectLater(
        repo.checkout(PosCheckoutCommand(
          invoiceNumber: 'SI-PAID-1',
          lines: [
            PosSaleLineInput(
              itemId: itemId,
              quantityBase: 3,
              unitPriceMicros: 50000,
              unitTypeId: 'unit_strip',
              vatRateBasisPoints: 0,
              discountBasisPoints: 0,
            ),
          ],
          paymentMethod: PosPaymentMethod.cash,
          paidMicros: 10000,
          userId: 'user_admin',
        )),
        throwsA(isA<InvalidOperationException>()),
      );

      expect(await db.select(db.salesInvoices).get(), isEmpty);

      final batch = await (db.select(db.batches)
            ..where((b) => b.itemId.equals(itemId)))
          .getSingle();
      expect(batch.quantityBase, 10);
      final item = await (db.select(db.items)
            ..where((i) => i.id.equals(itemId)))
          .getSingle();
      expect(item.currentStockBase, 10);
      expect(await db.select(db.stockMovements).get(), hasLength(1));
    });
  });

  group('RBAC gate end-to-end', () {
    test('sell flag passes the controller but engine role rule rejects', () async {
      final itemId =
          await _seedItem(db, barcode: 'RBAC001', sellingPriceMicros: 50000);
      await insertBatch(
          db, itemId, quantityBase: 10, unitCostMicros: 10000, batchNumber: 'RBAC-B');

      final now = DateTime.now().millisecondsSinceEpoch;
      await db.into(db.users).insert(UsersCompanion.insert(
        id: 'user_viewer',
        username: 'viewer',
        passwordHash: 'hash',
        fullName: 'مشاهد',
        roleId: 'role_viewer',
        createdAt: now,
        updatedAt: now,
      ));

      final PosCatalogItem item = (await repo.itemById(itemId))!;
      await controller.addToCart(item, quantity: 2);
      final total = controller.totals.totalMicros;
      expect(total, 100000);
      controller.updatePaymentInputs(cashReceivedMicros: total);

      final controllerOutcome = await controller.checkout(
        actingUserId: 'user_viewer',
        permissions: {Perm.sell},
      );
      expect(controllerOutcome, isNull);
      expect(controller.currentState.errorMessage, isNotNull);
      expect(await db.select(db.salesInvoices).get(), isEmpty);

      await expectLater(
        repo.checkout(PosCheckoutCommand(
          invoiceNumber: 'SI-RBAC-1',
          lines: [
            PosSaleLineInput(
              itemId: itemId,
              quantityBase: 2,
              unitPriceMicros: 50000,
              unitTypeId: 'unit_strip',
              vatRateBasisPoints: 0,
              discountBasisPoints: 0,
            ),
          ],
          paymentMethod: PosPaymentMethod.cash,
          paidMicros: total,
          userId: 'user_viewer',
        )),
        throwsA(isA<UnauthorizedException>()),
      );

      expect(await db.select(db.salesInvoices).get(), isEmpty);
      final batch = await (db.select(db.batches)
            ..where((b) => b.itemId.equals(itemId)))
          .getSingle();
      expect(batch.quantityBase, 10);
    });
  });
}