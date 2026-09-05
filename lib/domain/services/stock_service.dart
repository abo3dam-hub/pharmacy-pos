import 'package:drift/drift.dart' hide isNull;

import '../../core/errors/exceptions.dart';
import '../../core/util/ids.dart';
import '../../shared/database/app_database.dart';
import '../../shared/models/enums.dart';

/// One batch that must be consumed to cover a requested quantity, chosen by
/// First-Expiry-First-Out (§7 FEFO).
class FefoAllocation {
  const FefoAllocation(this.batch, this.quantityBase);

  final BatchRow batch;
  final int quantityBase;
}

/// Stock ledger + FEFO logic (§9, §10, §7).
///
/// Every stock-changing operation goes through [applyMovement] so the
/// append-only `stock_movements` ledger, the batch balance and the item cache
/// stay consistent. Callers wrap calls in a single transaction.
class StockService {
  const StockService();

  /// Selects batches covering [quantityBase] base units of [itemId] using
  /// FEFO: soonest expiry first, oldest received first on ties.
  ///
  /// Voided and zero/negative balance batches are skipped. Thrown
  /// [NotEnoughStockException] if available (expiry-valid) stock is
  /// insufficient.
  Future<List<FefoAllocation>> allocateFefo(
    AppDatabase db,
    String itemId,
    int quantityBase, {
    int? atMillis,
  }) async {
    if (quantityBase <= 0) {
      throw ValidationException('الكمية المطلوبة يجب أن تكون موجبة');
    }
    final now = atMillis ?? DateTime.now().millisecondsSinceEpoch;
    final candidates = await (db.select(db.batches)
          ..where((b) =>
              b.itemId.equals(itemId) &
              b.isVoided.equals(false) &
              b.quantityBase.isBiggerThanValue(0) &
              b.expiryDate.isBiggerOrEqualValue(now)))
        .get();

    candidates.sort((a, b) {
      final byExpiry = a.expiryDate.compareTo(b.expiryDate);
      if (byExpiry != 0) return byExpiry;
      return a.createdAt.compareTo(b.createdAt);
    });

    var remaining = quantityBase;
    final result = <FefoAllocation>[];
    for (final batch in candidates) {
      if (remaining <= 0) break;
      final take = remaining < batch.quantityBase ? remaining : batch.quantityBase;
      result.add(FefoAllocation(batch, take));
      remaining -= take;
    }
    if (remaining > 0) {
      throw NotEnoughStockException(
        'المخزون غير كافٍ للمنتج رقم $itemId (المطلوب $quantityBase، '
        'المتاح ${quantityBase - remaining})',
      );
    }
    return result;
  }

  /// Recent available balance (sum of non-voided, unexpired, positive batches).
  Future<int> availableQuantity(
    AppDatabase db,
    String itemId, {
    int? atMillis,
  }) async {
    final now = atMillis ?? DateTime.now().millisecondsSinceEpoch;
    final rows = await (db.select(db.batches)
          ..where((b) =>
              b.itemId.equals(itemId) &
              b.isVoided.equals(false) &
              b.quantityBase.isBiggerThanValue(0) &
              b.expiryDate.isBiggerOrEqualValue(now)))
        .get();
    var total = 0;
    for (final b in rows) {
      total += b.quantityBase;
    }
    return total;
  }

  /// Appends one movement to the ledger and updates [tab.Batches.quantityBase]
  /// and [tab.Items.currentStockBase] atomically.
  ///
  /// [quantityBaseSigned] is the signed delta applied to the batch/item.
  /// Must run inside a transaction.
  Future<void> applyMovement(
    AppDatabase db, {
    required String itemId,
    String? batchId,
    required MovementType movementType,
    required int quantityBaseSigned,
    required int unitCostMicros,
    String? refType,
    String? refId,
    String? userId,
    String? note,
    int? atMillis,
  }) async {
    if (quantityBaseSigned == 0) {
      throw ValidationException('حركة مخزون صفرية غير مسموحة');
    }
    final now = atMillis ?? DateTime.now().millisecondsSinceEpoch;
    final movementId = newId('mov');

    final item = await (db.select(db.items)
          ..where((i) => i.id.equals(itemId)))
        .getSingleOrNull();
    if (item == null) {
      throw NotFoundException('المنتج رقم $itemId غير موجود');
    }

    int? batchAfter;
    if (batchId != null) {
      final batch = await (db.select(db.batches)
            ..where((b) => b.id.equals(batchId)))
          .getSingleOrNull();
      if (batch == null) {
        throw NotFoundException('الدفعة رقم $batchId غير موجودة');
      }
      batchAfter = batch.quantityBase + quantityBaseSigned;
      if (batchAfter < 0) {
        throw NotEnoughStockException(
            'الرصيد غير كافٍ في الدفعة $batchId للحركة المطلوبة');
      }
      await (db.update(db.batches)..where((b) => b.id.equals(batchId))).write(
        BatchesCompanion(
          quantityBase: Value(batchAfter),
          updatedAt: Value(now),
        ),
      );
    }

    final itemAfter = item.currentStockBase + quantityBaseSigned;
    if (itemAfter < 0) {
      throw NotEnoughStockException('الرصيد الإجمالي للمنتج غير كافٍ');
    }
    await (db.update(db.items)..where((i) => i.id.equals(itemId))).write(
      ItemsCompanion(
        currentStockBase: Value(itemAfter),
        updatedAt: Value(now),
      ),
    );

    await db.into(db.stockMovements).insert(
          StockMovementsCompanion.insert(
            id: movementId,
            itemId: itemId,
            batchId: batchId != null ? Value(batchId) : const Value(null),
            movementType: movementType,
            quantityBaseSigned: quantityBaseSigned,
            quantityBaseAfter: batchAfter ?? itemAfter,
            unitCostMicros: unitCostMicros,
            totalMicros: Value(quantityBaseSigned * unitCostMicros),
            refType: refType != null ? Value(refType) : const Value(null),
            refId: refId != null ? Value(refId) : const Value(null),
            userId: userId != null ? Value(userId) : const Value(null),
            note: note != null ? Value(note) : const Value(null),
            createdAt: now,
          ),
        );
  }

  /// Re-syncs `items.current_stock_base` from the ledger (§10 reconciliation).
  Future<void> reconcileItems(AppDatabase db) async {
    final rows = await db.customSelect(
      'SELECT item_id AS id, SUM(quantity_base_signed) AS q '
      'FROM stock_movements GROUP BY item_id',
    ).get();
    for (final row in rows) {
      final id = row.read<String>('id');
      final q = row.read<int>('q');
      await (db.update(db.items)..where((i) => i.id.equals(id))).write(
        ItemsCompanion(
          currentStockBase: Value(q),
          updatedAt: Value(DateTime.now().millisecondsSinceEpoch),
        ),
      );
    }
  }
}