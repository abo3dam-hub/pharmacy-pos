import 'package:drift/drift.dart';

import '../../../core/data_grid/page_request.dart';
import '../../../core/util/smart_search.dart';
import '../../../data/daos/smart_search_dao.dart';
import '../../sales/domain/entities/pos_catalog_item.dart';
import '../../sales/domain/services/smart_alternatives_service.dart';
import '../../../shared/database/app_database.dart';

/// POS-facing catalog queries (§5 search panel). All filtering/counting stays
/// inside the database — the POS never loads the full item table. Barcode
/// lookup is index-backed (unique + unique secondary).
class PosCatalogDao {
  const PosCatalogDao(this._db);

  final AppDatabase _db;

  /// Paginated POS search across name (ar), name (en), scientific name,
  /// active ingredient, both barcodes, plus supplier/ingredient/indication
  /// names — Arabic-normalized (§P16). Optionally restricted to items that
  /// currently have sellable stock.
  Future<PageResult<PosCatalogItem>> search(
    PageRequest request, {
    bool? inStockOnly,
  }) async {
    final q = request.search.trim();
    final filter = <Expression<bool>>[];

    if (q.isNotEmpty) {
      final like = SmartSearch.likePattern(q);
      final textMatches = <Expression<bool>>[
        SmartSearch.normalizeExpr(_db.items.tradeName).like(like),
        SmartSearch.normalizeExpr(_db.items.tradeNameEn).like(like),
        SmartSearch.normalizeExpr(_db.items.scientificName).like(like),
        SmartSearch.normalizeExpr(_db.items.activeIngredient).like(like),
        SmartSearch.normalizeExpr(_db.items.equivalentDrug).like(like),
        SmartSearch.normalizeExpr(_db.items.primaryBarcode).like(like),
        SmartSearch.normalizeExpr(_db.items.secondaryBarcode).like(like),
      ];
      final related = await SmartSearchDao(_db).matchingItemIds(q);
      if (related.isNotEmpty) {
        textMatches.add(_db.items.id.isIn(related));
      }
      filter.add(textMatches.reduce((a, b) => a | b));
    }
    if (inStockOnly == true) {
      filter.add(_db.items.currentStockBase.isBiggerThanValue(0));
    }

    final composite =
        filter.isEmpty ? null : filter.reduce((a, b) => a & b);

    final countExpr = _db.items.id.count();
    final countQuery = _db.selectOnly(_db.items)..addColumns([countExpr]);
    if (composite != null) countQuery.where(composite);
    final total = (await countQuery.getSingle()).read(countExpr) ?? 0;

    // SQLite numeric IDs (TEXT ids sort lexicographically); order by trade name.
final orderCol = switch (request.orderBy) {
  'tradeNameEn' => _db.items.tradeNameEn,
  'scientificName' => _db.items.scientificName,
  'currentStockBase' => _db.items.currentStockBase,
  _ => _db.items.tradeName,
};

final query = _db.select(_db.items);
    // Relevance-first ordering when searching by default order: exact name →
    // prefix → contains → everything else, so the best matches lead the page.
    if (q.isNotEmpty && request.orderBy == null) {
      query.orderBy([
        (i) => OrderingTerm.asc(_relevance(q)),
        (i) => OrderingTerm.asc(_db.items.tradeName),
      ]);
    } else {
      query.orderBy([
        (i) => request.ascending
            ? OrderingTerm.asc(orderCol)
            : OrderingTerm.desc(orderCol),
      ]);
    }
    query.limit(request.pageSize, offset: request.offset);
    if (composite != null) {
      query.where((i) => composite);
    }
    final rows = await query.get();

    final items = await hydrate(rows);
    return PageResult(items: items, total: total, request: request);
  }

  /// Relevance tier for a query, evaluated in SQL: 0 = exact normalized
  /// trade-name match, 1 = prefix, 2 = contains, 3 = any other field.
  Expression<int> _relevance(String query) {
    final normalized = SmartSearch.normalize(query);
    final name = SmartSearch.normalizeExpr(_db.items.tradeName);
    return CaseWhenExpression<int>(
      cases: [
        CaseWhen(name.equals(normalized), then: const Constant(0)),
        CaseWhen(name.like('$normalized%'), then: const Constant(1)),
        CaseWhen(name.like('%$normalized%'), then: const Constant(2)),
      ],
      orElse: const Constant(3),
    );
  }

  /// Indexed barcode lookup: primary barcode (unique) then secondary (unique).
  Future<PosCatalogItem?> byBarcode(String barcode) async {
    final code = barcode.trim();
    if (code.isEmpty) return null;
    final primary = await (_db.select(_db.items)
          ..where((i) => i.primaryBarcode.equals(code)))
        .getSingleOrNull();
    if (primary != null) {
      return (await hydrate([primary])).isEmpty
          ? null
          : (await hydrate([primary])).first;
    }
    final secondary = await (_db.select(_db.items)
          ..where((i) => i.secondaryBarcode.equals(code)))
        .getSingleOrNull();
    if (secondary == null) return null;
    return (await hydrate([secondary])).isEmpty
        ? null
        : (await hydrate([secondary])).first;
  }

  Future<PosCatalogItem?> byId(String id) async {
    final row = await (_db.select(_db.items)..where((i) => i.id.equals(id)))
        .getSingleOrNull();
    if (row == null) return null;
    final hydrated = await hydrate([row]);
    return hydrated.isEmpty ? null : hydrated.first;
  }

  /// Bounded candidate set for the smart-alternatives engine (§18): products
  /// sharing a relational active ingredient (`item_active_ingredients`) or
  /// indication (`item_indications`) with the requested item, OR matching a
  /// token of its legacy flat `activeIngredient` column (legacy fallback) —
  /// always active + currently available. The engine does the authoritative
  /// tier ranking afterwards (candidates here are a superset).
  Future<List<PosCatalogItem>> alternativeCandidates({
    required String itemId,
    int limit = 18,
  }) async {
    final requested = await (_db.select(_db.items)
          ..where((i) => i.id.equals(itemId)))
        .getSingleOrNull();
    if (requested == null) return const [];

    final clauses = <Expression<bool>>[];

    final ingredientIds = <String>{
      for (final r
          in await (_db.select(_db.itemActiveIngredients)
                ..where((r) => r.itemId.equals(itemId)))
              .get())
        r.activeIngredientId,
    };
    final indicationIds = <String>{
      for (final r
          in await (_db.select(_db.itemIndications)
                ..where((r) => r.itemId.equals(itemId)))
              .get())
        r.indicationId,
    };

    final relationalCandidates = <String>{};
    if (ingredientIds.isNotEmpty) {
      final shared = await (_db.select(_db.itemActiveIngredients)
            ..where((r) => r.activeIngredientId.isIn(ingredientIds)))
          .get();
      relationalCandidates.addAll(
          [for (final r in shared) if (r.itemId != itemId) r.itemId]);
    }
    if (indicationIds.isNotEmpty) {
      final shared = await (_db.select(_db.itemIndications)
            ..where((r) => r.indicationId.isIn(indicationIds)))
          .get();
      relationalCandidates.addAll(
          [for (final r in shared) if (r.itemId != itemId) r.itemId]);
    }

    if (relationalCandidates.isNotEmpty) {
      clauses.add(_db.items.id.isIn(relationalCandidates));
    }

    final tokens = SmartAlternativesService.ingredientTokens(
        requested.activeIngredient);
    if (tokens.isNotEmpty) {
      final likes = <Expression<bool>>[];
      for (final token in tokens) {
        likes.add(
            _db.items.activeIngredient.like('%${_escapeLike(token)}%'));
      }
      clauses.add(
          likes.length == 1 ? likes.first : likes.reduce((a, b) => a | b));
    }

    if (clauses.isEmpty) return const [];

    final filter = <Expression<bool>>[
      _db.items.isActive.equals(true),
      _db.items.id.equals(itemId).not(),
      clauses.reduce((a, b) => a | b),
    ].reduce((a, b) => a & b);

    final candidates = await (_db.select(_db.items)
          ..where((i) => filter)
          ..orderBy([(_) => OrderingTerm.asc(_db.items.tradeName)])
          ..limit(limit * 3))
        .get();
    final hydrated = await hydrate(candidates);
    return [for (final item in hydrated) if (item.availableStockBase > 0) item]
        .take(limit)
        .toList();
  }

  /// Builds [PosCatalogItem] snapshots for a page of item rows with minimal
  /// round-trips: one call for item_units, one for unit names, one aggregate
  /// query for FEFO-available quantity.
  Future<List<PosCatalogItem>> hydrate(List<ItemRow> rows) async {
    if (rows.isEmpty) return const [];

    final unitRows = await (_db.select(_db.itemUnits)
          ..where((u) => u.itemId.isIn({for (final r in rows) r.id})))
        .get();

    final unitIds = <String>{
      for (final u in unitRows) ...[u.baseUnitId, u.largeUnitId],
      for (final r in rows)
        if (r.sellablePartUnitId != null) r.sellablePartUnitId!,
    };
    final unitNames = <String, String>{};
    if (unitIds.isNotEmpty) {
      final units = await (_db.select(_db.units)
            ..where((u) => u.id.isIn(unitIds)))
          .get();
      for (final u in units) {
        unitNames[u.id] = u.name;
      }
    }

    final availability = await _availableByItem({for (final r in rows) r.id});
    final relationalIngredients =
        await _relationalIngredientNamesByItem({for (final r in rows) r.id});

    final unitByItem = <String, ItemUnitRow>{};
    for (final u in unitRows) {
      unitByItem[u.itemId] = u;
    }

    return [
      for (final r in rows)
        _toCatalogItem(
          r,
          unitRow: unitByItem[r.id],
          unitNames: unitNames,
          availableStockBase: availability[r.id] ?? 0,
          relationalIngredientNames: relationalIngredients[r.id] ?? const [],
        ),
    ];
  }

  /// Names of the active ingredients linked through `item_active_ingredients`
  /// (§4.2b), per item — fetched in one aggregate each for the relations and
  /// the ingredient name map so the tier engine can compare relational
  /// compositions without per-row round trips.
  Future<Map<String, List<String>>> _relationalIngredientNamesByItem(
      Set<String> itemIds) async {
    if (itemIds.isEmpty) return const {};
    final relations = await (_db.select(_db.itemActiveIngredients)
          ..where((r) => r.itemId.isIn(itemIds)))
        .get();
    if (relations.isEmpty) return const {};
    final names = {
      for (final ai in await (_db.select(_db.activeIngredients)).get())
        ai.id: ai.name,
    };
    final out = <String, List<String>>{};
    for (final r in relations) {
      out.putIfAbsent(r.itemId, () => [])
          .add(names[r.activeIngredientId] ?? r.activeIngredientId);
    }
    for (final v in out.values) {
      v.sort();
    }
    return out;
  }

  /// FEFO-available base quantity per item (non-voided, positive, not yet
  /// expired batches) aggregated in SQL.
  Future<Map<String, int>> _availableByItem(Set<String> itemIds) async {
    if (itemIds.isEmpty) return const {};
    final now = DateTime.now().millisecondsSinceEpoch;
    final rows = await (_db.select(_db.batches)
          ..where((b) =>
              b.itemId.isIn(itemIds) &
              b.isVoided.equals(false) &
              b.quantityBase.isBiggerThanValue(0) &
              (b.expiryDate.isNull() |
                  b.expiryDate.isBiggerOrEqualValue(now))))
        .get();
    final totals = <String, int>{};
    for (final b in rows) {
      totals[b.itemId] = (totals[b.itemId] ?? 0) + b.quantityBase;
    }
    return totals;
  }

  PosCatalogItem _toCatalogItem(
    ItemRow r, {
    required ItemUnitRow? unitRow,
    required Map<String, String> unitNames,
    required int availableStockBase,
    List<String> relationalIngredientNames = const [],
  }) {
    final baseUnitId = unitRow?.baseUnitId ?? r.sellablePartUnitId ?? 'unit_strip';
    final largeUnitId = unitRow?.largeUnitId ?? baseUnitId;
    final unitsPerLarge = unitRow?.unitsPerLarge ?? 1;
    return PosCatalogItem(
      id: r.id,
      tradeName: r.tradeName,
      tradeNameEn: r.tradeNameEn,
      scientificName: r.scientificName,
      activeIngredient: r.activeIngredient,
      relationalIngredientNames: relationalIngredientNames,
      dose: r.dose,
      pharmaForm: r.pharmaForm,
      sizeVolume: r.sizeVolume,
      primaryBarcode: r.primaryBarcode,
      secondaryBarcode: r.secondaryBarcode,
      isControlledDrug: r.isControlledDrug,
      requiresPrescription: r.requiresPrescription,
      isActive: r.isActive,
      sellingPriceMicros: r.sellingPriceMicros,
      vatRateBasisPoints: r.vatRateBasisPoints,
      currentStockBase: r.currentStockBase,
      availableStockBase: availableStockBase,
      baseUnitId: baseUnitId,
      baseUnitName: unitNames[baseUnitId] ?? baseUnitId,
      largeUnitId: largeUnitId,
      largeUnitName: unitNames[largeUnitId] ?? largeUnitId,
      unitsPerLarge: unitsPerLarge,
      partialSaleEnabled: r.partialSaleEnabled,
      sellablePartUnitId: r.sellablePartUnitId,
      sellablePartUnitName:
          unitNames[r.sellablePartUnitId ?? ''] ?? r.sellablePartUnitId,
      partsPerFullProduct: r.partsPerFullProduct,
      sellablePartBaseQuantity: r.sellablePartBaseQuantity,
      partialSaleMarkupBasisPoints: r.partialSaleMarkupBasisPoints,
      partialSalePriceMicros: r.partialSalePriceMicros,
    );
  }

  /// Collision-safe sequential sale invoice number: `SI-YYYYMMDD-HHmmssSSS`.
  static String nextInvoiceNumber() {
    final now = DateTime.now();
    String p(int n, [int pad = 2]) =>
        n.toString().padLeft(pad, '0');
    return 'SI-${now.year}${p(now.month)}${p(now.day)}-'
        '${p(now.hour)}${p(now.minute)}${p(now.second)}${p(now.millisecond, 3)}';
  }

  /// Collision-safe sequential return number: `RT-YYYYMMDD-HHmmssSSS`.
  static String nextReturnNumber() {
    final now = DateTime.now();
    String p(int n, [int pad = 2]) =>
        n.toString().padLeft(pad, '0');
    return 'RT-${now.year}${p(now.month)}${p(now.day)}-'
        '${p(now.hour)}${p(now.minute)}${p(now.second)}${p(now.millisecond, 3)}';
  }

  // Convenience: item_units may not exist for a legacy item — treat as
  // single-base-unit sale.
  static String _escapeLike(String value) =>
      value.replaceAll(r'\', r'\\').replaceAll('%', r'\%').replaceAll('_', r'\_');
}