import 'package:flutter_test/flutter_test.dart';
import 'package:pharmacy_pos/core/errors/exceptions.dart';
import 'package:pharmacy_pos/domain/services/purchase_service.dart';
import 'package:pharmacy_pos/domain/services/return_service.dart';
import 'package:pharmacy_pos/domain/services/sale_service.dart';
import 'package:pharmacy_pos/shared/database/app_database.dart';
import 'package:pharmacy_pos/shared/models/enums.dart';

import 'helpers.dart';

void main() {
  late AppDatabase db;

  setUp(() {
    db = newDatabase();
  });

  tearDown(() async {
    await db.close();
  });

  group('ReturnService (§14)', () {
    test('sale return restores stock to the original batch', () async {
      final supplierId = await insertSupplier(db);
      final itemId = await insertItem(db);
      final now = DateTime.now().millisecondsSinceEpoch;

      final purchase = await PurchaseService().recordPurchase(db,
          PurchaseRequest(
            invoiceNumber: 'PI-R1',
            supplierId: supplierId,
            invoiceDate: now,
            userId: 'user_admin',
            lines: [
              PurchaseLineRequest(
                itemId: itemId,
                quantityBase: 10,
                unitCostMicros: 10000,
                unitTypeId: 'unit_strip',
                batchNumber: 'B-R1',
                expiryDate: now + 200 * 24 * 60 * 60 * 1000,
              ),
            ],
          ));
      final originalBatchId = purchase.batches.single.id;

      final sale = await SaleService().recordSale(db, SaleRequest(
        invoiceNumber: 'SI-R1',
        userId: 'user_admin',
        paymentMethod: PaymentMethod.cash,
        paidMicros: 3 * 20000,
        lines: [
          SaleLineRequest(itemId: itemId, quantityBase: 3, unitPriceMicros: 20000, unitTypeId: 'unit_strip'),
        ],
      ));
      final lineId = sale.lines.single.id;
      final itemBefore = await (db.select(db.items)
                ..where((i) => i.id.equals(itemId)))
              .getSingle();
      expect(itemBefore.currentStockBase, 7);

      final outcome = await ReturnService().recordSaleReturn(db,
          SaleReturnRequest(
            returnNumber: 'RT-001',
            originalInvoiceItemId: lineId,
            quantityBase: 2,
            userId: 'user_admin',
            reason: 'مقاس خاطئ',
          ));

      // Stock restored to the SAME batch.
      final batch = await (db.select(db.batches)
                ..where((b) => b.id.equals(originalBatchId)))
              .getSingle();
      expect(batch.quantityBase, 9);
      final item = await (db.select(db.items)
                ..where((i) => i.id.equals(itemId)))
              .getSingle();
      expect(item.currentStockBase, 9);

      // Revenue reversal recorded (negative total).
      expect(outcome.returnOrder.totalMicros, -(2 * 20000));
      expect(outcome.returnItem.quantityBaseSigned, 2);
      expect(outcome.returnItem.batchId, originalBatchId);
      expect(outcome.returnItem.amountMicros, -(2 * 20000));

      // Original line tracks return quantity.
      final line = await (db.select(db.salesInvoiceItems)
                ..where((i) => i.id.equals(lineId)))
              .getSingle();
      expect(line.returnQuantityBase, 2);

      // Ledger has a +2 sale_return movement.
      final movs = await (db.select(db.stockMovements)
                ..where((m) => m.itemId.equals(itemId)))
              .get();
      final ret = movs.firstWhere((m) => m.movementType == MovementType.sale_return);
      expect(ret.quantityBaseSigned, 2);
      expect(ret.batchId, originalBatchId);
    });

    test('cannot return more than sold', () async {
      final supplierId = await insertSupplier(db);
      final itemId = await insertItem(db);
      final now = DateTime.now().millisecondsSinceEpoch;
      await PurchaseService().recordPurchase(db, PurchaseRequest(
        invoiceNumber: 'PI-R2',
        supplierId: supplierId,
        invoiceDate: now,
        userId: 'user_admin',
        lines: [
          PurchaseLineRequest(
            itemId: itemId,
            quantityBase: 5,
            unitCostMicros: 10000,
            unitTypeId: 'unit_strip',
            batchNumber: 'B-R2',
            expiryDate: now + 200 * 24 * 60 * 60 * 1000,
          ),
        ],
      ));
      final sale = await SaleService().recordSale(db, SaleRequest(
        invoiceNumber: 'SI-R2',
        userId: 'user_admin',
        paymentMethod: PaymentMethod.cash,
        paidMicros: 20000,
        lines: [
          SaleLineRequest(itemId: itemId, quantityBase: 1, unitPriceMicros: 20000, unitTypeId: 'unit_strip'),
        ],
      ));

      await expectLater(
        ReturnService().recordSaleReturn(db, SaleReturnRequest(
          returnNumber: 'RT-002',
          originalInvoiceItemId: sale.lines.single.id,
          quantityBase: 2,
          userId: 'user_admin',
        )),
        throwsA(isA<NotEnoughStockException>()),
      );
    });
  });
}