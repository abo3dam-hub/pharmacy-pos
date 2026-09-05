import 'package:drift/drift.dart';

import '../../shared/database/app_database.dart';
import '../../shared/models/enums.dart';

/// DAO for the append-only stock movement ledger (§4.9, §10).
class StockMovementDao {
  const StockMovementDao(this._db);

  final AppDatabase _db;

  Future<List<StockMovementRow>> byItem(
    String itemId, {
    int limit = 50,
    int offset = 0,
  }) {
    final q = _db.select(_db.stockMovements)
      ..where((m) => m.itemId.equals(itemId))
      ..orderBy([(m) => OrderingTerm.desc(m.createdAt)])
      ..limit(limit, offset: offset);
    return q.get();
  }

  Future<List<StockMovementRow>> byItemAndType(
    String itemId,
    MovementType type,
  ) {
    final q = _db.select(_db.stockMovements)
      ..where((m) => m.itemId.equals(itemId) & m.movementType.equalsValue(type));
    return q.get();
  }

  /// Net signed quantity for an item (falls back to per-batch consistency).
  Future<int> netQuantity(String itemId) async {
    final rows = await _db.customSelect(
      'SELECT COALESCE(SUM(quantity_base_signed), 0) AS q '
      'FROM stock_movements WHERE item_id = ?',
      variables: [Variable.withString(itemId)],
    ).getSingle();
    return rows.read<int>('q');
  }

  Future<int> countForItem(String itemId) async {
    final rows = await _db.customSelect(
      'SELECT COUNT(*) AS c FROM stock_movements WHERE item_id = ?',
      variables: [Variable.withString(itemId)],
    ).getSingle();
    return rows.read<int>('c');
  }
}