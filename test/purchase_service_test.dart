import 'package:flutter_test/flutter_test.dart';
import 'package:pharmacy_pos/domain/services/purchase_service.dart';
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

  group('PurchaseService (§12, §13)', () {
    test('records purchase with bonus-adjusted effective cost', () async {
      final supplierId = await insertSupplier(db);
      final itemId = await insertItem(db);
      final service = PurchaseService();

      final now = DateTime.now().millisecondsSinceEpoch;
      final outcome = await service.recordPurchase(db, PurchaseRequest(
        invoiceNumber: 'PI-001',
        supplierId: supplierId,
        invoiceDate: now,
        paidMicros: 100 * 10000, // 100.00
        userId: 'user_admin',
        lines: [
          PurchaseLineRequest(
            itemId: itemId,
            quantityBase: 100,
            unitCostMicros: 10000, // 1.00
            batchNumber: 'B100',
            expiryDate: now + 365 * 24 * 60 * 60 * 1000,
            bonuses: const [
              PurchaseBonusRequest(quantityBase: 10),
              PurchaseBonusRequest(quantityBase: 5),
              PurchaseBonusRequest(
                  quantityBase: 2, bonusType: PurchaseBonusType.priceDiscount),
            ],
          ),
        ],
      ));

      // 117 effective units into one batch.
      expect(outcome.invoice.totalMicros, 100 * 10000);
      expect(outcome.batches, hasLength(1));
      final batch = outcome.batches.single;
      expect(batch.quantityBase, 117);
      expect(batch.originalQuantityBase, 117);
      expect(batch.unitCostMicros, 8547); // 1,000,000 / 117 half-up (0.8547)

      final line = outcome.lines.single;
      expect(line.effectiveQuantityBase, 117);
      expect(line.bonusQuantityBase, 17);

      // Ledger + cache.
      final item = await (db.select(db.items)
                ..where((i) => i.id.equals(itemId)))
              .getSingle();
      expect(item.currentStockBase, 117);
      final movs = await (db.select(db.stockMovements)
                ..where((m) => m.itemId.equals(itemId)))
              .get();
      expect(movs.single.quantityBaseSigned, 117);

      final bonuses = await (db.select(db.purchaseBonuses)
                ..where((b) => b.purchaseInvoiceId.equals(outcome.invoice.id)))
              .get();
      expect(bonuses, hasLength(3));
    });

    test('historical batch cost is immutable after later purchases (§8)',
        () async {
      final supplierId = await insertSupplier(db);
      final itemId = await insertItem(db);
      final now = DateTime.now().millisecondsSinceEpoch;
      final expiry = now + 365 * 24 * 60 * 60 * 1000;

      final first = await insertBatch(db, itemId,
          quantityBase: 10, expiryDays: 60, unitCostMicros: 5000);
      final second = await insertBatch(db, itemId,
          quantityBase: 10, expiryDays: 30, unitCostMicros: 7000);

      final service = PurchaseService();
      await service.recordPurchase(db, PurchaseRequest(
        invoiceNumber: 'PI-B2',
        supplierId: supplierId,
        invoiceDate: now,
        userId: 'user_admin',
        lines: [
          PurchaseLineRequest(
            itemId: itemId,
            quantityBase: 5,
            unitCostMicros: 8000,
            batchNumber: 'BNEW',
            expiryDate: expiry,
          ),
        ],
      ));

      // Later purchases never touch earlier batches (§8 rule 1).
      final b1 = await (db.select(db.batches)..where((b) => b.id.equals(first)))
          .getSingle();
      final b2 = await (db.select(db.batches)..where((b) => b.id.equals(second)))
          .getSingle();
      expect(b1.unitCostMicros, 5000);
      expect(b2.unitCostMicros, 7000);
      expect(b1.quantityBase, 10);
      // The new batch received its own stock, not mixed with the old ones.
      final bnew = await (db.select(db.batches)
                ..where((b) => b.itemId.equals(itemId)))
              .get();
      expect(bnew, hasLength(3));

      final item = await (db.select(db.items)
                ..where((i) => i.id.equals(itemId)))
              .getSingle();
      expect(item.currentStockBase, 10 + 10 + 5);
    });
  });
}