import 'pos_catalog_item.dart';

/// Smart-alternative tier. Ranks how close an alternative is to the
/// originally requested product — used for the green / yellow / blue badges.
enum SmartAlternativeTier {
  /// Same active-ingredient set with the same strength per ingredient —
  /// a true therapeutic equivalent (green, 100%).
  tier1,

  /// Same active-ingredient set but different strengths/concentrations
  /// (yellow).
  tier2,

  /// Partial overlap: at least one shared ingredient, with extras or missing
  /// components (blue).
  tier3,
}

/// A live, computed alternative for a requested catalog item. Produced at
/// request time by [SmartAlternativesService] — never persisted.
class SmartAlternative {
  const SmartAlternative({
    required this.item,
    required this.tier,
    required this.matchPercent,
    this.extraIngredients = const [],
    this.missingIngredients = const [],
    this.strengthDifferences = const [],
  });

  final PosCatalogItem item;
  final SmartAlternativeTier tier;

  /// 0–100: how close the composition is to the requested product.
  /// Tier1 is always 100.
  final int matchPercent;

  /// Normalized ingredient names present in the alternative but not in the
  /// requested product.
  final List<String> extraIngredients;

  /// Normalized ingredient names in the requested product but missing from
  /// the alternative.
  final List<String> missingIngredients;

  /// Normalized ingredient names whose strength differs between the two.
  final List<String> strengthDifferences;

  /// True when the alternative is actually available to dispense.
  bool get inStock => item.availableStockBase > 0;
}
