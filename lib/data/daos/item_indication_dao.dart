import 'package:drift/drift.dart';

import '../../core/util/ids.dart';
import '../../shared/database/app_database.dart';

/// DAO for the `item_indications` junction — the per-product therapeutic-use
/// tags. Replaced wholesale on save; composite unique key guards duplicates.
class ItemIndicationDao {
  const ItemIndicationDao(this._db);

  final AppDatabase _db;

  Future<List<ItemIndicationRow>> forItem(String itemId) =>
      (_db.select(_db.itemIndications)..where((r) => r.itemId.equals(itemId)))
          .get();

  Future<List<String>> indicationIdsForItem(String itemId) async {
    final rows = await forItem(itemId);
    return [for (final row in rows) row.indicationId];
  }

  Future<void> setForItem(String itemId, List<String> indicationIds) async {
    final ids = indicationIds.toSet().toList();
    await _db.transaction(() async {
      await (_db.delete(_db.itemIndications)
            ..where((r) => r.itemId.equals(itemId)))
          .go();
      for (final indicationId in ids) {
        await _db.into(_db.itemIndications).insert(
              ItemIndicationsCompanion.insert(
                id: newId('iind'),
                itemId: itemId,
                indicationId: indicationId,
              ),
              mode: InsertMode.insertOrIgnore,
            );
      }
    });
  }
}