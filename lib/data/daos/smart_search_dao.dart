import 'package:drift/drift.dart';

import '../../core/util/smart_search.dart';
import '../../shared/database/app_database.dart';

/// Resolves item ids whose *related* straps match a search query — suppliers,
/// active ingredients and indications live in their own tables, so a query
/// like "باراسيتامول" must also find items linked to an ingredient named
/// exactly that. Only the matching master names are scanned; the junction
/// tables are hit with the (tiny) id set afterwards.
class SmartSearchDao {
  const SmartSearchDao(this._db);

  final AppDatabase _db;

  Future<Set<String>> matchingItemIds(String query) async {
    final q = query.trim();
    if (q.isEmpty) return const {};
    final like = SmartSearch.likePattern(q);
    final itemIds = <String>{};

    final supplierRows = await (_db.select(_db.suppliers)
          ..where((s) => SmartSearch.normalizeExpr(s.name).like(like)))
        .get();
    if (supplierRows.isNotEmpty) {
      final ids = {for (final r in supplierRows) r.id};
      final links = await (_db.select(_db.itemSuppliers)
            ..where((r) => r.supplierId.isIn(ids)))
          .get();
      itemIds.addAll({for (final l in links) l.itemId});
    }

    final ingredientRows = await (_db.select(_db.activeIngredients)
          ..where((a) => SmartSearch.normalizeExpr(a.name).like(like)))
        .get();
    if (ingredientRows.isNotEmpty) {
      final ids = {for (final r in ingredientRows) r.id};
      final links = await (_db.select(_db.itemActiveIngredients)
            ..where((r) => r.activeIngredientId.isIn(ids)))
          .get();
      itemIds.addAll({for (final l in links) l.itemId});
    }

    final indicationRows = await (_db.select(_db.indications)
          ..where((i) => SmartSearch.normalizeExpr(i.name).like(like)))
        .get();
    if (indicationRows.isNotEmpty) {
      final ids = {for (final r in indicationRows) r.id};
      final links = await (_db.select(_db.itemIndications)
            ..where((r) => r.indicationId.isIn(ids)))
          .get();
      itemIds.addAll({for (final l in links) l.itemId});
    }

    return itemIds;
  }
}