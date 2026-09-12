import 'package:flutter_test/flutter_test.dart';
import 'package:pharmacy_pos/core/util/bilingual_name.dart';
import 'package:pharmacy_pos/features/sales/domain/entities/pos_catalog_item.dart';

/// Lock the shared "AR (English)" display rule used on every item/product
/// surface (item names rendered together; single name only when forced).
void main() {
  group('bilingualName', () {
    test('both names render together as "عربي (English)"', () {
      expect(bilingualName('بانادول', 'Panadol'), 'بانادول (Panadol)');
    });

    test('missing English falls back to the Arabic name', () {
      expect(bilingualName('بانادول', ''), 'بانادول');
    });

    test('missing Arabic falls back to the English name', () {
      expect(bilingualName('', 'Panadol'), 'Panadol');
    });

    test('both empty', () {
      expect(bilingualName('', ''), '');
    });

    test('surrounding whitespace is trimmed', () {
      expect(bilingualName('  بانادول ', '  Panadol  '), 'بانادول (Panadol)');
    });
  });

  group('PosCatalogItem.displayName', () {
    const item = PosCatalogItem(
      id: 'item_x',
      tradeName: 'بانادول',
      tradeNameEn: 'Panadol',
      isControlledDrug: false,
      requiresPrescription: false,
      isActive: true,
      sellingPriceMicros: 100000,
      vatRateBasisPoints: 0,
      currentStockBase: 10,
      availableStockBase: 10,
      baseUnitId: 'ub',
      baseUnitName: 'حبة',
      largeUnitId: 'ul',
      largeUnitName: 'علبة',
      unitsPerLarge: 10,
      partialSaleEnabled: false,
      primaryBarcode: '6291041500213',
    );

    test('both names shown together', () {
      expect(item.displayName, 'بانادول (Panadol)');
    });

    test('single Arabic name when there is no English one', () {
      const arOnly = PosCatalogItem(
        id: 'item_y',
        tradeName: 'بانادول',
        isControlledDrug: false,
        requiresPrescription: false,
        isActive: true,
        sellingPriceMicros: 100000,
        vatRateBasisPoints: 0,
        currentStockBase: 10,
        availableStockBase: 10,
        baseUnitId: 'ub',
        baseUnitName: 'حبة',
        largeUnitId: 'ul',
        largeUnitName: 'علبة',
        unitsPerLarge: 10,
        partialSaleEnabled: false,
      );
      expect(arOnly.displayName, 'بانادول');
    });

    test('falls back to barcode when no name exists', () {
      const bare = PosCatalogItem(
        id: 'item_z',
        tradeName: '',
        isControlledDrug: false,
        requiresPrescription: false,
        isActive: true,
        sellingPriceMicros: 100000,
        vatRateBasisPoints: 0,
        currentStockBase: 10,
        availableStockBase: 10,
        baseUnitId: 'ub',
        baseUnitName: 'حبة',
        largeUnitId: 'ul',
        largeUnitName: 'علبة',
        unitsPerLarge: 10,
        partialSaleEnabled: false,
        primaryBarcode: '6291041500213',
      );
      expect(bare.displayName, '6291041500213');
    });
  });
}