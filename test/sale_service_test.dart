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
    await PurchaseService().recordPurchase(db, PurchaseRequest(
      invoiceNumber: 'PI-${DateTime.now().microsecondsSinceEpoch}',
      supplierId: supplierId,
      invoiceDate: now,
      userId: 'user_admin',
      lines: [
        PurchaseLineRequest(
          itemId: itemId,
          quantityBase: qty,
          unitCostMicros: costMicros,
          batchNumber: 'B${DateTime.now().microsecondsSinceEpoch}',
          expiryDate: now + 365 * 24 * 60 * 60 * 1000,
        ),
      ],
    ));
  }

  group('SaleService (§11)', () {
    test('sale deducts FEFO stock, posts ledger and records profit', () async {
      final itemId = await insertItem(db);
      await seedPurchase(itemId, 10, 10000 /* 1.00 */);

      final service = SaleService();
      final outcome = await service.recordSale(db, SaleRequest(
        invoiceNumber: 'SI-001',
        userId: 'user_admin',
        paymentMethod: PaymentMethod.cash,
        paidMicros: 3 * 20000, // 3 × 2.00
        lines: [
          SaleLineRequest(
            itemId: itemId,
            quantityBase: 3,
            unitPriceMicros: 20000,
          ),
        ],
      ));

      expect(outcome.invoice.totalMicros, 3 * 20000);
      expect(outcome.invoice.totalCostMicros, 3 * 10000);
      expect(outcome.invoice.profitMicros, 3 * 10000);
      expect(outcome.lines, hasLength(1));
      expect(outcome.lines.single.quantityBaseSigned, 3);
      expect(outcome.lines.single.unitCostMicros, 10000);

      // Stock + ledger state.
      final item = await (db.select(db.items)
                ..where((i) => i.id.equals(itemId)))
              .getSingle();
      expect(item.currentStockBase, 7);
      final movs = await (db.select(db.stockMovements)
                ..where((m) => m.itemId.equals(itemId)))
              .get();
      expect(movs, hasLength(2)); // purchase + sale
      final saleMov = movs.firstWhere((m) => m.movementType == MovementType.sale);
      expect(saleMov.quantityBaseSigned, -3);
    });

    test('sale cannot exceed stock (atomic rollback)', () async {
      final itemId = await insertItem(db);
      await seedPurchase(itemId, 2, 10000);

      final service = SaleService();
      await expectLater(
        service.recordSale(db, SaleRequest(
          invoiceNumber: 'SI-002',
          userId: 'user_admin',
          paymentMethod: PaymentMethod.cash,
          paidMicros: 3 * 20000,
          lines: [
            SaleLineRequest(itemId: itemId, quantityBase: 3, unitPriceMicros: 20000),
          ],
        )),
        throwsA(isA<NotEnoughStockException>()),
      );

      // No partial state survived.
      final item = await (db.select(db.items)
                ..where((i) => i.id.equals(itemId)))
              .getSingle();
      expect(item.currentStockBase, 2);
      final invs = await db.select(db.salesInvoices).get();
      expect(invs, isEmpty);
    });

    test('unpaid completed sale is rejected', () async {
      final itemId = await insertItem(db);
      await seedPurchase(itemId, 5, 10000);
      final service = SaleService();
      await expectLater(
        service.recordSale(db, SaleRequest(
          invoiceNumber: 'SI-003',
          userId: 'user_admin',
          paymentMethod: PaymentMethod.credit,
          paidMicros: 0,
          lines: [
            SaleLineRequest(
                itemId: itemId, quantityBase: 1, unitPriceMicros: 20000),
          ],
        )),
        throwsA(isA<InvalidOperationException>()),
      );
    });
  });
}