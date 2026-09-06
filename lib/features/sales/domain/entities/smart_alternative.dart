import 'pos_catalog_item.dart';

/// Smart-alternative tier (plan §18). Ranks how close an alternative is to the
/// originally requested product — used for the green / yellow / blue badges.
enum SmartAlternativeTier {
  /// Same active ingredient + same strength (dose) + same pharmaceutical form.
  tier1,

  /// Same active ingredient but different strength or pharmaceutical form.
  tier2,

  /// Shares at least one active ingredient with the requested product.
  tier3,
}

/// A live, computed alternative for a requested catalog item. Produced at
/// request time by [SmartAlternativesService] — never persisted.
class SmartAlternative {
  const SmartAlternative({required this.item, required this.tier});

  final PosCatalogItem item;
  final SmartAlternativeTier tier;
}