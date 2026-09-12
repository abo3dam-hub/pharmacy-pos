import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:flutter_test/flutter_test.dart';
import 'package:pharmacy_pos/core/errors/exceptions.dart';
import 'package:pharmacy_pos/domain/services/purchase_service.dart';
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

  Future<void> seedPurchase(String itemId, int qty, int costMicros) async {
    final supplierId = await insertSupplier(db);
    final now = DateTime.now().millisecondsSinceEpoch;
    await PurchaseService().recordPurchase(
      db,
      PurchaseRequest(
        invoiceNumber: 'PI-${DateTime.now().microsecondsSinceEpoch}',
        supplierId: supplierId,
        invoiceDate: now,
        userId: 'user_admin',
        lines: [
          PurchaseLineRequest(
            itemId: itemId,
            quantityBase: qty,
            unitCostMicros: costMicros,
            unitTypeId: 'unit_strip',
            batchNumber: 'B${DateTime.now().microsecondsSinceEpoch}',
            expiryDate: now + 365 * 24 * 60 * 60 * 1000,
          ),
        ],
      ),
    );
  }

  group('SaleService (§11)', () {
    test('sale deducts FEFO stock, posts ledger and records profit', () async {
      final itemId = await insertItem(db);
      await seedPurchase(itemId, 10, 10000 /* 1.00 */);

      final service = SaleService();
      final outcome = await service.recordSale(
        db,
        SaleRequest(
          invoiceNumber: 'SI-001',
          userId: 'user_admin',
          paymentMethod: PaymentMethod.cash,
          paidMicros: 3 * 20000, // 3 × 2.00
          lines: [
            SaleLineRequest(
              itemId: itemId,
              quantityBase: 3,
              unitPriceMicros: 20000,
              unitTypeId: 'unit_strip',
            ),
          ],
        ),
      );

      expect(outcome.invoice.totalMicros, 3 * 20000);
      expect(outcome.invoice.totalCostMicros, 3 * 10000);
      expect(outcome.invoice.profitMicros, 3 * 10000);
      expect(outcome.lines, hasLength(1));
      expect(outcome.lines.single.quantityBaseSigned, 3);
      expect(outcome.lines.single.unitCostMicros, 10000);

      // Stock + ledger state.
      final item = await (db.select(
        db.items,
      )..where((i) => i.id.equals(itemId))).getSingle();
      expect(item.currentStockBase, 7);
      final movs = await (db.select(
        db.stockMovements,
      )..where((m) => m.itemId.equals(itemId))).get();
      expect(movs, hasLength(2)); // purchase + sale
      final saleMov = movs.firstWhere(
        (m) => m.movementType == MovementType.sale,
      );
      expect(saleMov.quantityBaseSigned, -3);
    });

    test('sale cannot exceed stock (atomic rollback)', () async {
      final itemId = await insertItem(db);
      await seedPurchase(itemId, 2, 10000);

      final service = SaleService();
      await expectLater(
        service.recordSale(
          db,
          SaleRequest(
            invoiceNumber: 'SI-002',
            userId: 'user_admin',
            paymentMethod: PaymentMethod.cash,
            paidMicros: 3 * 20000,
            lines: [
              SaleLineRequest(
                itemId: itemId,
                quantityBase: 3,
                unitPriceMicros: 20000,
                unitTypeId: 'unit_strip',
              ),
            ],
          ),
        ),
        throwsA(isA<NotEnoughStockException>()),
      );

      // No partial state survived.
      final item = await (db.select(
        db.items,
      )..where((i) => i.id.equals(itemId))).getSingle();
      expect(item.currentStockBase, 2);
      final invs = await db.select(db.salesInvoices).get();
      expect(invs, isEmpty);
    });

    test('unpaid completed sale is rejected', () async {
      final itemId = await insertItem(db);
      await seedPurchase(itemId, 5, 10000);
      final service = SaleService();
      await expectLater(
        service.recordSale(
          db,
          SaleRequest(
            invoiceNumber: 'SI-003',
            userId: 'user_admin',
            paymentMethod: PaymentMethod.credit,
            paidMicros: 0,
            lines: [
              SaleLineRequest(
                itemId: itemId,
                quantityBase: 1,
                unitPriceMicros: 20000,
                unitTypeId: 'unit_strip',
              ),
            ],
          ),
        ),
        throwsA(isA<InvalidOperationException>()),
      );
    });

    test(
      'box + part lines persist sell-unit money exactly (two-mode lock)',
      () async {
        // Acceptance: box = 14,000; 3 parts × 5,600 = 16,800 → 30,800 total.
        final itemId = await insertItem(db);
        await (db.update(db.items)..where((i) => i.id.equals(itemId))).write(
          ItemsCompanion(
            partialSaleEnabled: const Value(true),
            sellablePartUnitId: const Value('unit_part'),
            partsPerFullProduct: const Value(3),
            sellablePartBaseQuantity: const Value(1),
            partialSaleMarkupBasisPoints: const Value(2000),
          ),
        );
        await seedPurchase(itemId, 50, 500);

        final outcome = await SaleService().recordSale(
          db,
          SaleRequest(
            invoiceNumber: 'SI-P1',
            userId: 'user_admin',
            paymentMethod: PaymentMethod.cash,
            paidMicros: 14000 + 16800,
            lines: [
              SaleLineRequest(
                itemId: itemId,
                quantityBase: 30,
                unitPriceMicros: 14000,
                unitTypeId: 'unit_box',
                quantity: 1,
                unitBaseQuantity: 30,
              ),
              SaleLineRequest(
                itemId: itemId,
                quantityBase: 3,
                unitPriceMicros: 5600,
                unitTypeId: 'unit_part',
                quantity: 3,
                unitBaseQuantity: 1,
              ),
            ],
          ),
        );

        // Exact invoice money — never the 19,601-style reconstruction.
        expect(outcome.invoice.subtotalMicros, 30800);
        expect(outcome.invoice.totalMicros, 30800);
        expect(outcome.invoice.totalCostMicros, 33 * 500);
        expect(outcome.invoice.profitMicros, 30800 - 33 * 500);

        final boxRow = outcome.lines.firstWhere(
          (l) => l.unitTypeId == 'unit_box',
        );
        expect(boxRow.quantityBaseSigned, 30);
        expect(boxRow.unitBaseQuantity, 30);
        expect(boxRow.lineTotalMicros, 14000);
        final partRow = outcome.lines.firstWhere(
          (l) => l.unitTypeId == 'unit_part',
        );
        expect(partRow.quantityBaseSigned, 3);
        expect(partRow.unitBaseQuantity, 1);
        expect(partRow.lineTotalMicros, 16800);

        // Inventory consumed 33 base units (30 box + 3 part).
        final item = await (db.select(
          db.items,
        )..where((i) => i.id.equals(itemId))).getSingle();
        expect(item.currentStockBase, 17);

        // Persisted rows keep the sell-unit metadata.
        final rows = await (db.select(
          db.salesInvoiceItems,
        )..where((i) => i.itemId.equals(itemId))).get();
        expect(rows, hasLength(2));
        expect(rows.map((r) => r.unitBaseQuantity).toSet(), {30, 1});
        expect(
          rows.map((r) => r.lineSubtotalMicros).reduce((a, b) => a + b),
          30800,
        );
      },
    );

    test(
      'FEFO split partitions sell-unit money exactly across batches',
      () async {
        final itemId = await insertItem(db);
        await seedPurchase(itemId, 20, 400);
        await seedPurchase(itemId, 12, 600);

        final outcome = await SaleService().recordSale(
          db,
          SaleRequest(
            invoiceNumber: 'SI-P2',
            userId: 'user_admin',
            paymentMethod: PaymentMethod.cash,
            paidMicros: 15400,
            lines: [
              SaleLineRequest(
                itemId: itemId,
                quantityBase: 30,
                unitPriceMicros: 14000,
                unitTypeId: 'unit_box',
                quantity: 1,
                unitBaseQuantity: 30,
                vatRateBasisPoints: 1000,
              ),
            ],
          ),
        );

        // 30 base → 20 from the cost-400 batch + 10 from the cost-600 batch.
        expect(outcome.lines, hasLength(2));
        final rows = outcome.lines;
        expect(rows.map((l) => l.quantityBaseSigned).toSet(), {10, 20});
        expect(rows.map((l) => l.unitCostMicros).toSet(), {400, 600});

        // Slot money is an exact integer partition of the line totals.
        expect(
          rows.map((l) => l.lineSubtotalMicros).reduce((a, b) => a + b),
          14000,
        );
        expect(rows.map((l) => l.taxMicros).reduce((a, b) => a + b), 1400);
        expect(
          rows.map((l) => l.lineTotalMicros).reduce((a, b) => a + b),
          14000,
        );
        final slot1 = rows.firstWhere((l) => l.quantityBaseSigned == 20);
        expect(slot1.lineSubtotalMicros, 9333);
        expect(slot1.taxMicros, 933);
        final slot2 = rows.firstWhere((l) => l.quantityBaseSigned == 10);
        expect(slot2.lineSubtotalMicros, 4667);
        expect(slot2.taxMicros, 467);

        // Invoice aggregation stays exact too.
        expect(outcome.invoice.subtotalMicros, 14000);
        expect(outcome.invoice.vatTotalMicros, 1400);
        expect(outcome.invoice.totalMicros, 15400);
        expect(outcome.invoice.totalCostMicros, 20 * 400 + 10 * 600);
        expect(outcome.invoice.profitMicros, 14000 - (20 * 400 + 10 * 600));

        // Row money persists in exact agreement with the line totals.
        final persisted = await (db.select(
          db.salesInvoiceItems,
        )..where((i) => i.itemId.equals(itemId))).get();
        expect(
          persisted.map((r) => r.lineSubtotalMicros).reduce((a, b) => a + b),
          14000,
        );
        expect(persisted.map((r) => r.taxMicros).reduce((a, b) => a + b), 1400);
        expect(persisted.map((r) => r.unitBaseQuantity).toSet(), {30});
      },
    );
  });
}
