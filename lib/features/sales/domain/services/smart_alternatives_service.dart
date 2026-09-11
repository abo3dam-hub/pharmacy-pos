import '../entities/pos_catalog_item.dart';
import '../entities/smart_alternative.dart';

/// Smart-alternatives tier engine (plan §18) — a pure, UI-independent domain
/// service that ranks candidate products against a requested product.
///
/// Tiers (closest → loosest):
///   * [SmartAlternativeTier.tier1] (green): same active ingredient set, same
///     strength (dose) and same pharmaceutical form.
///   * [SmartAlternativeTier.tier2] (yellow): same active ingredient set but a
///     different strength or form (formula strength difference).
///   * [SmartAlternativeTier.tier3] (blue): shares at least one active
///     ingredient with the requested product.
///
/// Candidates are ranked by tier first, then by available stock (desc), then
/// by same-manufacturer (tie-break), then alphabetically — so the pharmacist
/// picks a stocked, equivalent item from the same supplier family first.
class SmartAlternativesService {
  const SmartAlternativesService();

  /// Splits and normalizes an active-ingredient string into comparison tokens.
  ///
  /// Ingredient lists are frequently stored as `"A + B"`, `"A,B"`, `"A / B"`
  /// or `"A&B"`; tokens are lower-cased and stripped of non-letter characters
  /// so `"Paracetamol 500"` and `"paracetamol"` compare cleanly.
  static Set<String> ingredientTokens(String? value) {
    if (value == null || value.trim().isEmpty) return const {};
    return value
        .toLowerCase()
        .split(RegExp(r'[,+&/;]'))
        .map((t) => t.trim())
        .where((t) => t.isNotEmpty)
        .map((t) => t.replaceAll(RegExp(r'[^a-z0-9\u0600-\u06ff ]'), ''))
        .map((t) => t.trim())
        .where((t) => t.isNotEmpty)
        .toSet();
  }

  /// Composition tokens for comparison: the legacy flat `activeIngredient`
  /// column plus the relational `item_active_ingredients` names (§4.2b), so
  /// items that only carry relational ingredient rows still rank (Phase 18).
  static Set<String> compositionTokens(PosCatalogItem item) {
    final parts = <String>[];
    if (item.activeIngredient != null && item.activeIngredient!.trim().isNotEmpty) {
      parts.add(item.activeIngredient!);
    }
    parts.addAll(item.relationalIngredientNames);
    return ingredientTokens(parts.join(' + '));
  }

  /// Ranks [candidates] against [requested] and keeps the closest [limit]
  /// alternatives. Out-of-stock and non-active candidates are dropped.
  List<SmartAlternative> rank(
    PosCatalogItem requested,
    List<PosCatalogItem> candidates, {
    int limit = 12,
  }) {
    final targets = compositionTokens(requested);
    // Candidates that share no ingredient tokens are excluded.
    final scored = <({PosCatalogItem item, SmartAlternativeTier tier})>[];
    for (final candidate in candidates) {
      if (candidate.id == requested.id) continue;
      if (!candidate.isActive) continue;
      if (candidate.availableStockBase <= 0) continue;
      final tokens = compositionTokens(candidate);
      if (tokens.isEmpty) continue;
      final tier = _tierFor(requested, candidate, targets: targets, tokens: tokens);
      if (tier != null) scored.add((item: candidate, tier: tier));
    }

    scored.sort((a, b) {
      final byTier = a.tier.index.compareTo(b.tier.index);
      if (byTier != 0) return byTier;
      final byStock = b.item.availableStockBase.compareTo(a.item.availableStockBase);
      if (byStock != 0) return byStock;
      // Same manufacturer is preferred over the same tier + stock (§18.1).
      final aMfr = a.item.manufacturerId != null &&
              a.item.manufacturerId == requested.manufacturerId
          ? 1
          : 0;
      final bMfr = b.item.manufacturerId != null &&
              b.item.manufacturerId == requested.manufacturerId
          ? 1
          : 0;
      final byMfr = bMfr.compareTo(aMfr);
      if (byMfr != 0) return byMfr;
      return a.item.tradeName.compareTo(b.item.tradeName);
    });

    return [
      for (final s in scored.take(limit))
        SmartAlternative(item: s.item, tier: s.tier),
    ];
  }

  SmartAlternativeTier? _tierFor(
    PosCatalogItem requested,
    PosCatalogItem candidate, {
    required Set<String> targets,
    required Set<String> tokens,
  }) {
    if (targets.isEmpty || tokens.isEmpty) return null;
    final strong = _setsEqual(targets, tokens);
    if (!strong) {
      if (targets.intersection(tokens).isEmpty) return null;
      return SmartAlternativeTier.tier3;
    }
    final doseMatch = _norm(requested.dose).isNotEmpty &&
        _norm(requested.dose) == _norm(candidate.dose);
    final formMatch = _norm(requested.pharmaForm).isNotEmpty &&
        _norm(requested.pharmaForm) == _norm(candidate.pharmaForm);
    return doseMatch && formMatch
        ? SmartAlternativeTier.tier1
        : SmartAlternativeTier.tier2;
  }

  static bool _setsEqual(Set<String> a, Set<String> b) =>
      a.length == b.length && a.containsAll(b);

  static String _norm(String? value) =>
      (value ?? '').trim().toLowerCase();
}