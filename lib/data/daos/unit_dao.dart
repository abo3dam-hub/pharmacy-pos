import 'package:drift/drift.dart';

import '../../core/util/ids.dart';
import '../../shared/database/app_database.dart';

/// DAO for the units registry (§4.5) and base/large unit relations.
class UnitDao {
  const UnitDao(this._db);

  final AppDatabase _db;

  Future<List<UnitRow>> all({bool? activeOnly}) async {
    final q = _db.select(_db.units);
    if (activeOnly != null) q.where((u) => u.isActive.equals(activeOnly));
    q.orderBy([(u) => OrderingTerm.asc(u.name)]);
    return q.get();
  }

  Future<UnitRow?> byId(String id) => (_db.select(_db.units)
        ..where((u) => u.id.equals(id)))
      .getSingleOrNull();

  Future<void> insert(UnitRow unit) => _db.into(_db.units).insert(unit);

  Future<void> update(UnitRow unit) =>
      (_db.update(_db.units)..where((u) => u.id.equals(unit.id)))
          .write(unit.toCompanion(true));

  /// `conversionToBase` for an item's unit, or null when unlinked. The base
  /// unit converts as 1; the large (box) unit converts by `unitsPerLarge`.
  Future<int?> conversionToBase(String itemId, String unitId) async {
    final row = await (_db.select(_db.itemUnits)
          ..where((u) => u.itemId.equals(itemId)))
        .getSingleOrNull();
    if (row == null) return null;
    if (row.baseUnitId == unitId) return 1;
    if (row.largeUnitId == unitId) return row.unitsPerLarge;
    return null;
  }

  /// Sets the item's base/large unit relation (`unitsPerLarge` base units per
  /// large unit), replacing any previous relation.
  Future<void> setBaseLargeRelation(
    String itemId, {
    required String baseUnitId,
    required String largeUnitId,
    required int unitsPerLarge,
  }) async {
    await _db.transaction(() async {
      await (_db.delete(_db.itemUnits)..where((u) => u.itemId.equals(itemId)))
          .go();
      final existing = await (_db.select(_db.itemUnits)
            ..where((u) =>
                u.itemId.equals(itemId) &
                u.baseUnitId.equals(baseUnitId) &
                u.largeUnitId.equals(largeUnitId)))
          .getSingleOrNull();
      if (existing != null) return;
      await _db.into(_db.itemUnits).insert(
            ItemUnitsCompanion.insert(
              id: newId('iu'),
              itemId: itemId,
              baseUnitId: baseUnitId,
              largeUnitId: largeUnitId,
              unitsPerLarge: Value(unitsPerLarge),
            ),
          );
    });
  }

  static String newUnitId() => newId('unit');
}