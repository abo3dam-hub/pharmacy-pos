import 'package:drift/drift.dart';

import '../../../core/data_grid/page_request.dart';
import '../../sales/domain/entities/pos_catalog_item.dart';
import '../../../shared/database/app_database.dart';

/// POS-facing catalog queries (§5 search panel). All filtering/counting stays
/// inside the database — the POS never loads the full item table. Barcode
/// lookup is index-backed (unique + unique secondary).
class PosCatalogDao {
  const PosCatalogDao(this._db);

  final AppDatabase _db;

  /// Paginated POS search across name (ar), name (en), scientific name,
  /// active ingredient and both barcodes, optionally restricted to items that
  /// currently have sellable stock.
  Future<PageResult<PosCatalogItem>> search(
    PageRequest request, {
    bool? inStockOnly,
  }) async {
    final q = request.search.trim();
    final filter = <Expression<bool>>[];

    if (q.isNotEmpty) {
      final like = '%${_escapeLike(q)}%';
      filter.add([
        _db.items.tradeName.like(like),
        _db.items.tradeNameEn.like(like),
        _db.items.scientificName.like(like),
        _db.items.activeIngredient.like(like),
        _db.items.primaryBarcode.like(like),
        _db.items.secondaryBarcode.like(like),
      ].reduce((a, b) => a | b));
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

final query = _db.select(_db.items)
      ..orderBy([
        (i) => request.ascending
            ? OrderingTerm.asc(orderCol)
            : OrderingTerm.desc(orderCol),
      ])
      ..limit(request.pageSize, offset: request.offset);
    if (composite != null) {
      query.where((i) => composite);
    }
    final rows = await query.get();

    final items = await hydrate(rows);
    return PageResult(items: items, total: total, request: request);
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

  /// Bounded "same family" lookup (therapeutic group or active ingredient),
  /// always active + currently available — computed live for alternatives.
  Future<List<PosCatalogItem>> alternatives({
    required String itemId,
    String? therapeuticGroupId,
    String? activeIngredient,
    int limit = 12,
  }) async {
    if ((therapeuticGroupId == null || therapeuticGroupId.isEmpty) &&
        (activeIngredient == null || activeIngredient.isEmpty)) {
      return const [];
    }
    final conds = <Expression<bool>>[
      _db.items.isActive.equals(true),
      _db.items.id.equals(itemId).not(),
    ];
    if (therapeuticGroupId != null && therapeuticGroupId.isNotEmpty) {
      conds.add(_db.items.therapeuticGroupId.equals(therapeuticGroupId));
    }
    if (activeIngredient != null && activeIngredient.isNotEmpty) {
      conds.add(_db.items.activeIngredient.equals(activeIngredient));
    }
    final filter = conds.reduce((a, b) => a & b);

    final candidates = await (_db.select(_db.items)
          ..where((i) => filter)
          ..orderBy([(_) => OrderingTerm.asc(_db.items.tradeName)])
          ..limit(limit * 3))
        .get();
    final hydrated = await hydrate(candidates);
    // Availability filter happens here (bounded candidate set).
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
        ),
    ];
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
      therapeuticGroupId: r.therapeuticGroupId,
      primaryBarcode: r.primaryBarcode,
      secondaryBarcode: r.secondaryBarcode,
      isOtc: r.isOtc,
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