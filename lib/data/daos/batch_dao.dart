import 'package:drift/drift.dart';

import '../../core/data_grid/page_request.dart';
import '../../core/util/ids.dart';
import '../../shared/database/app_database.dart';

/// DAO for batches (§4.8): FEFO queries, per-item balances, voiding.
class BatchDao {
  const BatchDao(this._db);

  final AppDatabase _db;

  Future<List<BatchRow>> byItem(String itemId) {
    final q = _db.select(_db.batches)
      ..where((b) => b.itemId.equals(itemId))
      ..orderBy([(b) => OrderingTerm.asc(b.expiryDate)]);
    return q.get();
  }

  Future<BatchRow?> byId(String id) => (_db.select(_db.batches)
        ..where((b) => b.id.equals(id)))
      .getSingleOrNull();

  Future<int> totalOnHand(String itemId) async {
    final rows = await (_db.select(_db.batches)
          ..where((b) => b.itemId.equals(itemId) & b.isVoided.equals(false)))
        .get();
    return rows.fold<int>(0, (sum, b) => sum + b.quantityBase);
  }

  Future<PageResult<BatchRow>> page(PageRequest page, String itemId) async {
    final totalExpr = _db.batches.id.count();
    final count = _db.selectOnly(_db.batches)
      ..addColumns([totalExpr])
      ..where(_db.batches.itemId.equals(itemId));
    final countRow = await count.getSingle();
    final q = _db.select(_db.batches)
      ..where((b) => b.itemId.equals(itemId))
      ..orderBy([(b) => OrderingTerm.asc(b.expiryDate)])
      ..limit(page.pageSize, offset: page.offset);
    return PageResult(
      items: await q.get(),
      total: countRow.read(totalExpr) ?? 0,
      request: page,
    );
  }

  Future<void> insert(BatchRow batch) => _db.into(_db.batches).insert(batch);

  /// Marks a batch as voided; used only through business logic.
  Future<void> voidBatch(String id) =>
      (_db.update(_db.batches)..where((b) => b.id.equals(id))).write(
        BatchesCompanion(
          isVoided: const Value(true),
          updatedAt: Value(DateTime.now().millisecondsSinceEpoch),
        ),
      );

  static String newBatchId() => newId('bat');
}