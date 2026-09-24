import '../entities/pos_catalog_item.dart';
import '../entities/smart_alternative.dart';

/// Smart-alternatives tier engine — a pure, UI-independent domain service that
/// ranks candidate products against a requested product.
///
/// Composition is compared strength-aware: each active ingredient maps to its
/// normalized strength (from `item_active_ingredients.strength`, falling back
/// to the item's flat `dose` when no relational strengths exist).
///
/// Tiers (closest → loosest):
///   * [SmartAlternativeTier.tier1] (green, 100%): same active-ingredient set
///     with the same strength per ingredient — a true therapeutic equivalent.
///   * [SmartAlternativeTier.tier2] (yellow): same active-ingredient set but
///     different strengths/concentrations.
///   * [SmartAlternativeTier.tier3] (blue): partial overlap — at least one
///     shared ingredient, with extras or missing components.
///
/// Every alternative also carries a [SmartAlternative.matchPercent] (0–100)
/// so the pharmacist sees *how* close it is, and the dialog shows an explicit
/// in-stock / out-of-stock status (not just a quantity).
///
/// Candidates are ranked by availability first (in-stock alternatives always
/// lead; out-of-stock equivalents still appear — sorted after, ordered by
/// tier), then by match percent, then by tier, then by available stock
/// (desc), then by same-manufacturer (tie-break), then alphabetically.
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

  /// Strength-aware composition: normalized ingredient name → normalized
  /// strength. Relational strengths win; when an item has relational
  /// ingredients but no strengths, the flat `dose` is used as the shared
  /// strength fallback; the legacy flat `activeIngredient` column feeds items
  /// without any relational rows.
  static Map<String, String> composition(PosCatalogItem item) {
    final out = <String, String>{};
    final doseFallback = _norm(item.dose);
    for (final name in item.relationalIngredientNames) {
      final key = _norm(name);
      if (key.isEmpty) continue;
      final strength = item.relationalIngredientStrengths[name]?.trim();
      out[key] = _norm(strength != null && strength.isNotEmpty
          ? strength
          : doseFallback.isNotEmpty
              ? doseFallback
              : null);
    }
    if (out.isEmpty) {
      for (final token in ingredientTokens(item.activeIngredient)) {
        out[token] = doseFallback;
      }
    }
    return out;
  }

  /// Ranks [candidates] against [requested] and keeps the closest [limit]
  /// alternatives. Non-active candidates are dropped; out-of-stock candidates
  /// are kept but always ranked after the available ones.
  List<SmartAlternative> rank(
    PosCatalogItem requested,
    List<PosCatalogItem> candidates, {
    int limit = 12,
  }) {
    final target = composition(requested);
    final scored = <SmartAlternative>[];
    for (final candidate in candidates) {
      if (candidate.id == requested.id) continue;
      if (!candidate.isActive) continue;
      final comp = composition(candidate);
      if (comp.isEmpty) continue;
      final alt = _score(requested, candidate, target: target, comp: comp);
      if (alt != null) scored.add(alt);
    }

    scored.sort((a, b) {
      // Availability is the primary grouping: in-stock first, then the
      // out-of-stock equivalents (stock is an ordering signal, never a drop
      // rule).
      final aInStock = a.item.availableStockBase > 0 ? 1 : 0;
      final bInStock = b.item.availableStockBase > 0 ? 1 : 0;
      final byAvailability = bInStock.compareTo(aInStock);
      if (byAvailability != 0) return byAvailability;
      final byPercent = b.matchPercent.compareTo(a.matchPercent);
      if (byPercent != 0) return byPercent;
      final byTier = a.tier.index.compareTo(b.tier.index);
      if (byTier != 0) return byTier;
      // Stock still breaks ties within the in-stock group; it adds no signal
      // inside the all-zero out-of-stock group.
      if (aInStock == 1) {
        final byStock =
            b.item.availableStockBase.compareTo(a.item.availableStockBase);
        if (byStock != 0) return byStock;
      }
      // Same manufacturer is preferred over the same tier + stock.
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

    return scored.take(limit).toList();
  }

  /// Scores one candidate. Returns null when there is no usable overlap.
  SmartAlternative? _score(
    PosCatalogItem requested,
    PosCatalogItem candidate, {
    required Map<String, String> target,
    required Map<String, String> comp,
  }) {
    if (target.isEmpty || comp.isEmpty) return null;
    final shared = target.keys.toSet().intersection(comp.keys.toSet());
    if (shared.isEmpty) return null;

    // Per-ingredient score: 1.0 for ingredient + strength match, 0.6 for
    // ingredient match with a different strength, 0 for missing/extra.
    // The denominator penalizes both missing and extra ingredients.
    var points = 0.0;
    for (final ing in shared) {
      final tStrength = target[ing] ?? '';
      final cStrength = comp[ing] ?? '';
      if (tStrength.isNotEmpty &&
          cStrength.isNotEmpty &&
          tStrength == cStrength) {
        points += 1.0;
      } else {
        points += 0.6;
      }
    }
    final denom = target.length > comp.length ? target.length : comp.length;
    final matchPercent = (100 * points / denom).round().clamp(0, 100);

    final sameSet = target.length == comp.length &&
        target.keys.toSet().containsAll(comp.keys);
    final SmartAlternativeTier tier;
    if (sameSet) {
      final strengthsMatch = target.keys.every(
        (ing) =>
            (target[ing] ?? '').isNotEmpty && target[ing] == comp[ing],
      );
      tier =
          strengthsMatch ? SmartAlternativeTier.tier1 : SmartAlternativeTier.tier2;
    } else {
      tier = SmartAlternativeTier.tier3;
    }

    // Difference summary for the dialog: which ingredients are extra or
    // missing, and which strengths differ.
    final extra = comp.keys.where((k) => !target.containsKey(k)).toList()
      ..sort();
    final missing = target.keys.where((k) => !comp.containsKey(k)).toList()
      ..sort();
    final strengthDiffs = [
      for (final ing in shared)
        if ((target[ing] ?? '').isNotEmpty &&
            (comp[ing] ?? '').isNotEmpty &&
            target[ing] != comp[ing])
          ing,
    ]..sort();

    return SmartAlternative(
      item: candidate,
      tier: tier,
      matchPercent: tier == SmartAlternativeTier.tier1 ? 100 : matchPercent,
      extraIngredients: extra,
      missingIngredients: missing,
      strengthDifferences: strengthDiffs,
    );
  }

  static String _norm(String? value) =>
      (value ?? '').trim().toLowerCase().replaceAll(RegExp(r'\s+'), ' ');
}
