import 'package:drift/drift.dart';

import '../../core/util/ids.dart';
import '../../shared/database/app_database.dart';

/// DAO for the `item_suppliers` junction (§12) — which suppliers a product is
/// preferred to be sourced from. The relation is replaced wholesale on save;
/// the composite unique key guards against duplicates.
class ItemSupplierDao {
  const ItemSupplierDao(this._db);

  final AppDatabase _db;

  /// Links for one item (empty when the product has no preferred suppliers).
  Future<List<ItemSupplierRow>> forItem(String itemId) =>
      (_db.select(_db.itemSuppliers)..where((r) => r.itemId.equals(itemId)))
          .get();

  /// Supplier ids for one item, in insertion order (deduplicated set).
  Future<List<String>> supplierIdsForItem(String itemId) async {
    final rows = await forItem(itemId);
    return [for (final row in rows) row.supplierId];
  }

  /// Item ids linked to one supplier (used to resolve bulk price scopes).
  Future<List<String>> itemIdsForSupplier(String supplierId) {
    return (_db.select(_db.itemSuppliers)
          ..where((r) => r.supplierId.equals(supplierId)))
        .map((r) => r.itemId)
        .get();
  }

  /// Replaces the item's supplier links inside one transaction. Input ids are
  /// de-duplicated; `INSERT OR IGNORE` keeps the schema's unique key intact.
  Future<void> setForItem(String itemId, List<String> supplierIds) async {
    final ids = supplierIds.toSet().toList();
    await _db.transaction(() async {
      await (_db.delete(_db.itemSuppliers)
            ..where((r) => r.itemId.equals(itemId)))
          .go();
      for (final supplierId in ids) {
        await _db.into(_db.itemSuppliers).insert(
              ItemSuppliersCompanion.insert(
                id: newId('is'),
                itemId: itemId,
                supplierId: supplierId,
              ),
              mode: InsertMode.insertOrIgnore,
            );
      }
    });
  }
}