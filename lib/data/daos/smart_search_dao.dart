import 'package:drift/drift.dart';

import '../../core/util/smart_search.dart';
import '../../shared/database/app_database.dart';

/// Resolves item ids whose *related* straps match a search query — suppliers,
/// active ingredients and indications live in their own tables, so a query
/// like "باراسيتامول" must also find items linked to an ingredient named
/// exactly that. Only the matching master names are scanned; the junction
/// tables are hit with the (tiny) id set afterwards.
///
/// The four master-table scans are independent, so they run concurrently
/// (§search-perf): on a warm database this collapses ~8 sequential
/// round-trips into effectively one.
class SmartSearchDao {
  const SmartSearchDao(this._db);

  final AppDatabase _db;

  Future<Set<String>> matchingItemIds(String query) async {
    final q = query.trim();
    if (q.isEmpty) return const {};
    final like = SmartSearch.likePattern(q);

    final results = await Future.wait([
      _linkedItemIds(
        masterQuery: (_db.select(_db.suppliers)
              ..where((s) => SmartSearch.normalizeExpr(s.name).like(like)))
            .get(),
        linkQuery: (ids) => (_db.select(_db.itemSuppliers)
              ..where((r) => r.supplierId.isIn(ids)))
            .get(),
        masterIdOf: (SupplierRow r) => r.id,
        itemIdOf: (ItemSupplierRow l) => l.itemId,
      ),
      _linkedItemIds(
        masterQuery: (_db.select(_db.activeIngredients)
              ..where((a) => SmartSearch.normalizeExpr(a.name).like(like)))
            .get(),
        linkQuery: (ids) => (_db.select(_db.itemActiveIngredients)
              ..where((r) => r.activeIngredientId.isIn(ids)))
            .get(),
        masterIdOf: (ActiveIngredientRow r) => r.id,
        itemIdOf: (ItemActiveIngredientRow l) => l.itemId,
      ),
      _linkedItemIds(
        masterQuery: (_db.select(_db.indications)
              ..where((i) => SmartSearch.normalizeExpr(i.name).like(like)))
            .get(),
        linkQuery: (ids) => (_db.select(_db.itemIndications)
              ..where((r) => r.indicationId.isIn(ids)))
            .get(),
        masterIdOf: (IndicationRow r) => r.id,
        itemIdOf: (ItemIndicationRow l) => l.itemId,
      ),
      // Manufacturers are a direct FK on items (no junction table).
      _directItemIds(
        masterQuery: (_db.select(_db.manufacturers)
              ..where((m) => SmartSearch.normalizeExpr(m.name).like(like)))
            .get(),
        itemQuery: (ids) => (_db.select(_db.items)
              ..where((i) => i.manufacturerId.isIn(ids)))
            .get(),
        masterIdOf: (ManufacturerRow r) => r.id,
      ),
    ]);

    return {for (final set in results) ...set};
  }

  Future<Set<String>> _linkedItemIds<M, L>({
    required Future<List<M>> masterQuery,
    required Future<List<L>> Function(Set<String> ids) linkQuery,
    required String Function(M) masterIdOf,
    required String Function(L) itemIdOf,
  }) async {
    final masters = await masterQuery;
    if (masters.isEmpty) return const {};
    final ids = {for (final m in masters) masterIdOf(m)};
    final links = await linkQuery(ids);
    return {for (final l in links) itemIdOf(l)};
  }

  Future<Set<String>> _directItemIds<M>({
    required Future<List<M>> masterQuery,
    required Future<List<ItemRow>> Function(Set<String> ids) itemQuery,
    required String Function(M) masterIdOf,
  }) async {
    final masters = await masterQuery;
    if (masters.isEmpty) return const {};
    final ids = {for (final m in masters) masterIdOf(m)};
    final rows = await itemQuery(ids);
    return {for (final r in rows) r.id};
  }
}
