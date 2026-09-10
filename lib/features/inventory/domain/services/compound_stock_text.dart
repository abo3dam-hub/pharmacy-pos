import '../../../../core/quantity/quantity.dart';

/// Phase 17 business-term inventory display ("9 علب / 2 ظرف").
///
/// When an item is partial-sale configured, stock is presented in commercial
/// units (التعبئة التجارية) plus the sellable parts remaining (الأجزاء)
/// instead of a raw base-unit number. Arabic count rules are applied to the
/// *default* seed unit names (علبة→علب، ظرف→ظروف); any other unit name is
/// shown as authored so pharmacy-authored unit names are never mangled.
String compoundStockText({
  required int baseUnits,
  required Quantity quantity,
  String? largeUnitName,
  String? partUnitName,
  int? unitsPerLarge,
  int? partsPerFullProduct,
  int? sellablePartBaseQuantity,
}) {
  final partCount = partsPerFullProduct;
  final baseQty = (sellablePartBaseQuantity ?? 1).clamp(1, 1 << 31);
  final large = largeUnitName ?? '';
  final part = partUnitName ?? '';

  if (partCount == null || partCount <= 0 || large.isEmpty) {
    return '$baseUnits';
  }

  final boxes = quantity.boxes;
  final parts =
      (quantity.fractions < 0 || baseQty <= 0) ? 0 : quantity.fractions ~/ baseQty;

  String word(String name, int count) => _plural(name, count);
  String largeWord(int count) => word(large, count);

  if (boxes > 0 && parts > 0) {
    return '$boxes ${largeWord(boxes)} / '
        '$parts ${word(part, parts)}';
  }
  if (boxes > 0) {
    return '$boxes ${largeWord(boxes)}';
  }
  if (parts > 0) {
    return '0 ${largeWord(0)} / $parts ${word(part, parts)}';
  }
  return '0 ${largeWord(0)}';
}

/// Arabic count-based form: 3..10 take the plural form, anything else the
/// singular form. Only the default seed names get an explicit plural; arbitrary
/// unit names are returned unchanged.
String _plural(String name, int count) {
  if (count >= 3 && count <= 10) {
    const plural = <String, String>{
      'علبة': 'علب',
      'ظرف': 'ظروف',
      'Box': 'Boxes',
      'Sachet': 'Sachets',
    };
    return plural[name] ?? name;
  }
  return name;
}