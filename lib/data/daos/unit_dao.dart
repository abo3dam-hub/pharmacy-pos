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

  /// `conversionToBase` for an item's unit, or null when unlinked.
  Future<int?> conversionToBase(String itemId, String unitId) async {
    final row = await (_db.select(_db.itemUnits)
          ..where((u) =>
              u.itemId.equals(itemId) &
              u.unitId.equals(unitId)))
        .getSingleOrNull();
    return row?.conversionToBase;
  }

  static String newUnitId() => newId('unit');
}