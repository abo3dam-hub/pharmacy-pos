import '../util/smart_search.dart';

/// Precomputed, normalized item search text (§search-perf).
///
/// The item grid / tree / POS search used to apply `SmartSearch.normalizeExpr`
/// (a chain of ~10 SQL `replace()` calls) to 7 columns on every keystroke —
/// ~1.5M function evaluations per search over a 22k-row catalog. Instead, the
/// normalized concatenation is computed once in Dart at every write and
/// stored in `items.search_text`; searches become a single cheap
/// `LIKE '%q%'` on that column with the query normalized the same way.
class ItemSearchText {
  const ItemSearchText._();

  /// Builds the stored search text from the searchable item fields.
  /// Manufacturer/category names are intentionally excluded: the relational
  /// smart search (`SmartSearchDao`) still covers those on demand.
  static String build({
    String? tradeName,
    String? tradeNameEn,
    String? scientificName,
    String? activeIngredient,
    String? equivalentDrug,
    String? primaryBarcode,
    String? secondaryBarcode,
    String? dose,
    String? pharmaForm,
  }) {
    final parts = [
      tradeName,
      tradeNameEn,
      scientificName,
      activeIngredient,
      equivalentDrug,
      primaryBarcode,
      secondaryBarcode,
      dose,
      pharmaForm,
    ].where((p) => p != null && p.trim().isNotEmpty).cast<String>();
    return SmartSearch.normalize(parts.join(' '));
  }

  /// Normalized form of a user query, matching how [build] normalized the
  /// stored text.
  static String normalizeQuery(String query) => SmartSearch.normalize(query);
}
