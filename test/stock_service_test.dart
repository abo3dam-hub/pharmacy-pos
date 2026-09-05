import 'package:drift/drift.dart' hide isNull;
import 'package:flutter_test/flutter_test.dart';
import 'package:pharmacy_pos/core/errors/exceptions.dart';
import 'package:pharmacy_pos/domain/services/stock_service.dart';
import 'package:pharmacy_pos/shared/database/app_database.dart';
import 'package:pharmacy_pos/shared/models/enums.dart';

import 'helpers.dart';

void main() {
  const stock = StockService();

  late AppDatabase db;

  setUp(() {
    db = newDatabase();
  });

  tearDown(() async {
    await db.close();
  });

  group('FEFO allocation', () {
    test('picks soonest-expiring, skips expired and empty', () async {
      final itemId = await insertItem(db);
      final far = await insertBatch(db, itemId,
          quantityBase: 10, expiryDays: 365, unitCostMicros: 9000);
      final near = await insertBatch(db, itemId,
          quantityBase: 7, expiryDays: 30, unitCostMicros: 8000);
      await insertBatch(db, itemId,
          quantityBase: 50, expiryDays: -5, unitCostMicros: 1000); // expired

      final allocated = await stock.allocateFefo(
          db, itemId, 12,
          atMillis: DateTime.now().millisecondsSinceEpoch);

      expect(allocated, hasLength(2));
      expect(allocated.first.batch.id, near, reason: 'expiring soonest first');
      expect(allocated.first.quantityBase, 7);
      expect(allocated.last.batch.id, far);
      expect(allocated.last.quantityBase, 5);
    });

    test('throws when available (non-expired) stock is insufficient', () async {
      final itemId = await insertItem(db);
      await insertBatch(db, itemId, quantityBase: 5, expiryDays: 10);
      await insertBatch(db, itemId, quantityBase: 30, expiryDays: -1);

      expect(
        () => stock.allocateFefo(db, itemId, 6),
        throwsA(isA<NotEnoughStockException>()),
      );
    });

    test('availableQuantity ignores expired batches', () async {
      final itemId = await insertItem(db);
      await insertBatch(db, itemId, quantityBase: 5, expiryDays: 10);
      await insertBatch(db, itemId, quantityBase: 50, expiryDays: -1);
      expect(await stock.availableQuantity(db, itemId), 5);
    });

    test('non-expiring batches are eligible and sort last (FEFO→FIFO)',
        () async {
      final itemId = await insertItem(db);
      // Expiring batch expiring late + non-expiring (NULL expiry) batch.
      final expiring = await insertBatch(db, itemId,
          quantityBase: 20, expiryDays: 365, unitCostMicros: 8000);
      final noExpiry = await insertBatch(db, itemId,
          quantityBase: 30, unitCostMicros: 7000);

      final allocated = await stock.allocateFefo(db, itemId, 25);
      expect(allocated, hasLength(2));
      expect(allocated.first.batch.id, expiring,
          reason: 'expiring batches precede non-expiring ones');
      expect(allocated.last.batch.id, noExpiry);
      // Non-expiring stock also counts as available.
      expect(await stock.availableQuantity(db, itemId), 50);
    });
  });

  group('stock ledger', () {
    test('applyMovement updates ledger, batch and item cache atomically',
        () async {
      final itemId = await insertItem(db);
      final batchId = await insertBatch(db, itemId,
          quantityBase: 10, expiryDays: 60, unitCostMicros: 8000);

      await stock.applyMovement(
        db,
        itemId: itemId,
        batchId: batchId,
        movementType: MovementType.sale,
        quantityBaseSigned: -3,
        unitCostMicros: 8000,
        refType: 'sale_line',
        refId: 'line1',
        userId: 'user_admin',
      );

      final batch = await (db.select(db.batches)
                ..where((b) => b.id.equals(batchId)))
              .getSingle();
      expect(batch.quantityBase, 7);

      final item = await (db.select(db.items)
                ..where((i) => i.id.equals(itemId)))
              .getSingle();
      expect(item.currentStockBase, 7);

final movs = await (db.select(db.stockMovements)
          ..where((m) => m.itemId.equals(itemId)))
        .get();
      final saleMov =
          movs.firstWhere((m) => m.movementType == MovementType.sale);
      expect(saleMov.quantityBaseSigned, -3);
      expect(saleMov.quantityBaseAfter, 7);
      expect(saleMov.batchId, batchId);
    });

    test('rejects overselling below zero', () async {
      final itemId = await insertItem(db);
      final batchId =
          await insertBatch(db, itemId, quantityBase: 2, expiryDays: 10);

      await db.transaction(() async {
        await stock.applyMovement(
            db,
            itemId: itemId,
            batchId: batchId,
            movementType: MovementType.sale,
            quantityBaseSigned: -1,
            unitCostMicros: 100,
            userId: 'user_admin');
      });

      expect(
        () => db.transaction(() => stock.applyMovement(
            db,
            itemId: itemId,
            batchId: batchId,
            movementType: MovementType.sale,
            quantityBaseSigned: -2,
            unitCostMicros: 100,
            userId: 'user_admin')),
        throwsA(isA<NotEnoughStockException>()),
      );
    });

    test('reconcileItems rebuilds cache from the ledger', () async {
      final itemId = await insertItem(db);
      final batchId = await insertBatch(db, itemId,
          quantityBase: 10, expiryDays: 30, unitCostMicros: 100);

      await stock.applyMovement(
          db,
          itemId: itemId,
          batchId: batchId,
          movementType: MovementType.purchase,
          quantityBaseSigned: 4,
          unitCostMicros: 100,
          userId: 'user_admin');

      await (db.update(db.items)..where((i) => i.id.equals(itemId)))
          .write(ItemsCompanion(currentStockBase: const Value(999)));
      await stock.reconcileItems(db);

      final item = await (db.select(db.items)
                ..where((i) => i.id.equals(itemId)))
              .getSingle();
      expect(item.currentStockBase, 14);
    });
  });
}