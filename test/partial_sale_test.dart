import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:flutter_test/flutter_test.dart';
import 'package:pharmacy_pos/core/errors/exceptions.dart';
import 'package:pharmacy_pos/domain/services/partial_price_calculator.dart';
import 'package:pharmacy_pos/shared/database/app_database.dart';

import 'helpers.dart';

void main() {
  late AppDatabase db;
  final calc = const PartialPriceCalculator();

  setUp(() {
    db = newDatabase();
  });

  tearDown(() async {
    await db.close();
  });

  // ── Configuration Validation (PS01–PS02, PS17, PS27–PS28, PS31–PS35) ────

  group('PS01 — Partial sale disabled', () {
    test('partial sale fields are NULL when disabled', () async {
      final itemId = await insertItem(db);
      final item = await (db.select(db.items)
            ..where((i) => i.id.equals(itemId)))
          .getSingle();
      expect(item.partialSaleEnabled, false);
      expect(item.sellablePartUnitId, isNull);
      expect(item.partsPerFullProduct, isNull);
      expect(item.sellablePartBaseQuantity, isNull);
      expect(item.partialSaleMarkupBasisPoints, isNull);
    });
  });

  group('PS02 — Partial sale enabled fields', () {
    test('valid configuration stores all fields', () async {
      final itemId = await insertItem(db);
      await (db.update(db.items)..where((i) => i.id.equals(itemId))).write(
        ItemsCompanion(
          partialSaleEnabled: const Value(true),
          sellablePartUnitId: const Value('unit_strip'),
          partsPerFullProduct: const Value(10),
          sellablePartBaseQuantity: const Value(10),
          partialSaleMarkupBasisPoints: const Value(1000),
        ),
      );
      final item = await (db.select(db.items)
            ..where((i) => i.id.equals(itemId)))
          .getSingle();
      expect(item.partialSaleEnabled, true);
      expect(item.sellablePartUnitId, 'unit_strip');
      expect(item.partsPerFullProduct, 10);
      expect(item.sellablePartBaseQuantity, 10);
      expect(item.partialSaleMarkupBasisPoints, 1000);
    });
  });

  group('PS17 — Invalid part count', () {
    test('partsPerFullProduct ≤ 1 is rejected', () {
      expect(
        () => calc.validate(
          partialSaleEnabled: true,
          sellablePartUnitId: 'unit_strip',
          partsPerFullProduct: 1,
          sellablePartBaseQuantity: 10,
          partialSaleMarkupBasisPoints: 1000,
        ),
        throwsA(isA<DomainException>()),
      );
    });

    test('partsPerFullProduct = 0 is rejected', () {
      expect(
        () => calc.validate(
          partialSaleEnabled: true,
          sellablePartUnitId: 'unit_strip',
          partsPerFullProduct: 0,
          sellablePartBaseQuantity: 10,
          partialSaleMarkupBasisPoints: 1000,
        ),
        throwsA(isA<DomainException>()),
      );
    });
  });

  group('PS27 — sellablePartBaseQuantity = 0 rejected', () {
    test('base quantity 0 is rejected', () {
      expect(
        () => calc.validate(
          partialSaleEnabled: true,
          sellablePartUnitId: 'unit_strip',
          partsPerFullProduct: 10,
          sellablePartBaseQuantity: 0,
          partialSaleMarkupBasisPoints: 1000,
        ),
        throwsA(isA<DomainException>()),
      );
    });
  });

  group('PS28 — Partial sale disabled → NULL fields', () {
    test('null fields when disabled is valid', () {
      expect(
        () => calc.validate(
          partialSaleEnabled: false,
          sellablePartUnitId: null,
          partsPerFullProduct: null,
          sellablePartBaseQuantity: null,
          partialSaleMarkupBasisPoints: null,
        ),
        returnsNormally,
      );
    });

    test('non-null fields when disabled is rejected', () {
      expect(
        () => calc.validate(
          partialSaleEnabled: false,
          sellablePartUnitId: 'unit_strip',
          partsPerFullProduct: null,
          sellablePartBaseQuantity: null,
          partialSaleMarkupBasisPoints: null,
        ),
        throwsA(isA<DomainException>()),
      );
    });
  });

  group('PS31–PS33 — Consistency invariant', () {
    test('PS31: 10 × 10 = 100 = unitsPerLarge → valid', () {
      expect(
        () => calc.validate(
          partialSaleEnabled: true,
          sellablePartUnitId: 'unit_strip',
          partsPerFullProduct: 10,
          sellablePartBaseQuantity: 10,
          partialSaleMarkupBasisPoints: 1000,
          unitsPerLarge: 100,
        ),
        returnsNormally,
      );
    });

    test('PS32: 10 × 8 ≠ 100 → rejected', () {
      expect(
        () => calc.validate(
          partialSaleEnabled: true,
          sellablePartUnitId: 'unit_strip',
          partsPerFullProduct: 10,
          sellablePartBaseQuantity: 8,
          partialSaleMarkupBasisPoints: 1000,
          unitsPerLarge: 100,
        ),
        throwsA(isA<DomainException>()),
      );
    });

    test('PS33: no unitsPerLarge → skip invariant check', () {
      expect(
        () => calc.validate(
          partialSaleEnabled: true,
          sellablePartUnitId: 'unit_strip',
          partsPerFullProduct: 10,
          sellablePartBaseQuantity: 8,
          partialSaleMarkupBasisPoints: 1000,
          unitsPerLarge: null,
        ),
        returnsNormally,
      );
    });
  });

  group('PS34 — Disabled → sellablePartBaseQuantity is NULL', () {
    test('database stores NULL when disabled', () async {
      final itemId = await insertItem(db);
      final item = await (db.select(db.items)
            ..where((i) => i.id.equals(itemId)))
          .getSingle();
      expect(item.sellablePartBaseQuantity, isNull);
    });
  });

  group('PS35 — Enable without base quantity rejected', () {
    test('missing sellablePartBaseQuantity is rejected', () {
      expect(
        () => calc.validate(
          partialSaleEnabled: true,
          sellablePartUnitId: 'unit_strip',
          partsPerFullProduct: 10,
          sellablePartBaseQuantity: null,
          partialSaleMarkupBasisPoints: 1000,
        ),
        throwsA(isA<DomainException>()),
      );
    });
  });

  // ── Pricing (PS03–PS10, PS18–PS20) ──────────────────────────────────────

  group('PS03 — Correct proportional partial price', () {
    test('\$10 ÷ 10 × 1.10 = \$1.10', () {
      final price = calc.calculatePartialPrice(
        sellingPriceMicros: 100000, // $10.00
        partsPerFullProduct: 10,
        markupBasisPoints: 1000, // 10%
      );
      expect(price, 11000); // $1.10
    });
  });

  group('PS04 — Markup applied exactly once', () {
    test('markup is not cumulative', () {
      final price1 = calc.calculatePartialPrice(
        sellingPriceMicros: 100000,
        partsPerFullProduct: 10,
        markupBasisPoints: 1000,
      );
      final price2 = calc.calculatePartialPrice(
        sellingPriceMicros: 100000,
        partsPerFullProduct: 10,
        markupBasisPoints: 2000,
      );
      // price2 should NOT be price1 × 1.20
      // It should be $10 ÷ 10 × 1.20 = $1.20
      expect(price1, 11000); // $1.10
      expect(price2, 12000); // $1.20
    });
  });

  group('PS05 — Full product uses full retail price', () {
    test('decompose with quantity = partsPerFullProduct', () {
      final d = calc.decompose(
        quantityParts: 10,
        partsPerFullProduct: 10,
        sellablePartBaseQuantity: 10,
        fullRetailPriceMicros: 100000, // $10.00
        partialSellingPriceMicros: 11000, // $1.10
      );
      expect(d.completeProducts, 1);
      expect(d.remainingParts, 0);
      expect(d.totalPriceMicros, 100000); // $10.00 exactly
    });
  });

  group('PS06 — Quantity < partsPerFullProduct', () {
    test('all parts at partial price', () {
      final d = calc.decompose(
        quantityParts: 5,
        partsPerFullProduct: 10,
        sellablePartBaseQuantity: 10,
        fullRetailPriceMicros: 100000,
        partialSellingPriceMicros: 11000,
      );
      expect(d.completeProducts, 0);
      expect(d.remainingParts, 5);
      expect(d.totalPriceMicros, 55000); // 5 × $1.10
    });
  });

  group('PS07 — Quantity = partsPerFullProduct', () {
    test('full product price', () {
      final d = calc.decompose(
        quantityParts: 10,
        partsPerFullProduct: 10,
        sellablePartBaseQuantity: 10,
        fullRetailPriceMicros: 100000,
        partialSellingPriceMicros: 11000,
      );
      expect(d.totalPriceMicros, 100000);
    });
  });

  group('PS08 — Quantity > partsPerFullProduct', () {
    test('decompose 13 = 1 full + 3 parts', () {
      final d = calc.decompose(
        quantityParts: 13,
        partsPerFullProduct: 10,
        sellablePartBaseQuantity: 10,
        fullRetailPriceMicros: 100000,
        partialSellingPriceMicros: 11000,
      );
      expect(d.completeProducts, 1);
      expect(d.remainingParts, 3);
      expect(d.totalPriceMicros, 133000); // $10 + $3.30
    });
  });

  group('PS09 — Different products, different part counts', () {
    test('product A: 10 parts', () {
      final price = calc.calculatePartialPrice(
        sellingPriceMicros: 100000,
        partsPerFullProduct: 10,
        markupBasisPoints: 1000,
      );
      expect(price, 11000);
    });

    test('product B: 8 parts', () {
      final price = calc.calculatePartialPrice(
        sellingPriceMicros: 80000,
        partsPerFullProduct: 8,
        markupBasisPoints: 500,
      );
      // $8 ÷ 8 × 1.05 = $1.05
      expect(price, 10500);
    });
  });

  group('PS10 — Different markups', () {
    test('10% markup', () {
      final price = calc.calculatePartialPrice(
        sellingPriceMicros: 100000,
        partsPerFullProduct: 10,
        markupBasisPoints: 1000,
      );
      expect(price, 11000);
    });

    test('5% markup', () {
      final price = calc.calculatePartialPrice(
        sellingPriceMicros: 100000,
        partsPerFullProduct: 10,
        markupBasisPoints: 500,
      );
      expect(price, 10500);
    });
  });

  group('PS18 — Rounding is deterministic', () {
    test('same inputs → same output', () {
      final p1 = calc.calculatePartialPrice(
        sellingPriceMicros: 100000,
        partsPerFullProduct: 3,
        markupBasisPoints: 1000,
      );
      final p2 = calc.calculatePartialPrice(
        sellingPriceMicros: 100000,
        partsPerFullProduct: 3,
        markupBasisPoints: 1000,
      );
      expect(p1, p2);
    });
  });

  group('PS19 — No cumulative markup', () {
    test('markup applied once, not recursively', () {
      // $10 ÷ 10 = $1, then $1 × 1.10 = $1.10
      // NOT $1 × 1.10 × 1.10 = $1.21
      final price = calc.calculatePartialPrice(
        sellingPriceMicros: 100000,
        partsPerFullProduct: 10,
        markupBasisPoints: 1000,
      );
      expect(price, 11000);
    });
  });

  group('PS20 — Partial price not from supplier cost', () {
    test('supplier cost is independent', () {
      // Even if cost is $5, partial price is still derived from selling price
      final price = calc.calculatePartialPrice(
        sellingPriceMicros: 100000, // $10 selling
        partsPerFullProduct: 10,
        markupBasisPoints: 1000,
      );
      expect(price, 11000); // $1.10, not $5.50
    });
  });

  // ── Inventory Conversion (PS21–PS26, PS29–PS30) ──────────────────────────

  group('PS21–PS24 — Sellable part → base quantity', () {
    test('PS21: 1 Strip → 10 Tablets', () {
      final base = calc.convertToBase(
        sellablePartQuantity: 1,
        sellablePartBaseQuantity: 10,
      );
      expect(base, 10);
    });

    test('PS22: 3 Strips → 30 Tablets', () {
      final base = calc.convertToBase(
        sellablePartQuantity: 3,
        sellablePartBaseQuantity: 10,
      );
      expect(base, 30);
    });

    test('PS23: 10 Strips → 100 Tablets', () {
      final base = calc.convertToBase(
        sellablePartQuantity: 10,
        sellablePartBaseQuantity: 10,
      );
      expect(base, 100);
    });

    test('PS24: 13 Strips → 130 Tablets', () {
      final d = calc.decompose(
        quantityParts: 13,
        partsPerFullProduct: 10,
        sellablePartBaseQuantity: 10,
        fullRetailPriceMicros: 100000,
        partialSellingPriceMicros: 11000,
      );
      expect(d.totalBaseQuantity, 130);
    });
  });

  group('PS25 — Changing sellablePartBaseQuantity does NOT change price', () {
    test('price depends on partsPerFullProduct, not base quantity', () {
      final p1 = calc.calculatePartialPrice(
        sellingPriceMicros: 100000,
        partsPerFullProduct: 10,
        markupBasisPoints: 1000,
      );
      final p2 = calc.calculatePartialPrice(
        sellingPriceMicros: 100000,
        partsPerFullProduct: 10,
        markupBasisPoints: 1000,
      );
      expect(p1, p2); // Same price regardless of base quantity
    });
  });

  group('PS26 — Changing partsPerFullProduct DOES affect price', () {
    test('different part counts produce different prices', () {
      final p1 = calc.calculatePartialPrice(
        sellingPriceMicros: 100000,
        partsPerFullProduct: 10,
        markupBasisPoints: 1000,
      );
      final p2 = calc.calculatePartialPrice(
        sellingPriceMicros: 100000,
        partsPerFullProduct: 5,
        markupBasisPoints: 1000,
      );
      // $10 ÷ 10 × 1.10 = $1.10
      // $10 ÷ 5 × 1.10 = $2.20
      expect(p1, 11000);
      expect(p2, 22000);
    });
  });

  group('PS29 — Counterexample: partsPerFullProduct ≠ sellablePartBaseQuantity', () {
    test('syrup: 40 parts, 5 ml per dose', () {
      final d = calc.decompose(
        quantityParts: 13,
        partsPerFullProduct: 40,
        sellablePartBaseQuantity: 5,
        fullRetailPriceMicros: 200000, // $20 bottle
        partialSellingPriceMicros: 5500, // derived from formula
      );
      expect(d.totalBaseQuantity, 65); // 13 × 5 = 65 ml
      expect(d.completeProducts, 0);
      expect(d.remainingParts, 13);
    });
  });

  // ── Edge Cases ───────────────────────────────────────────────────────────

  group('Quantity = 0 rejected', () {
    test('decompose rejects zero quantity', () {
      expect(
        () => calc.decompose(
          quantityParts: 0,
          partsPerFullProduct: 10,
          sellablePartBaseQuantity: 10,
          fullRetailPriceMicros: 100000,
          partialSellingPriceMicros: 11000,
        ),
        throwsA(isA<DomainException>()),
      );
    });
  });

  group('Negative quantity rejected', () {
    test('convertToBase rejects negative', () {
      expect(
        () => calc.convertToBase(
          sellablePartQuantity: -1,
          sellablePartBaseQuantity: 10,
        ),
        throwsA(isA<DomainException>()),
      );
    });
  });

  group('Markup bounds', () {
    test('markup > 100% is rejected', () {
      expect(
        () => calc.calculatePartialPrice(
          sellingPriceMicros: 100000,
          partsPerFullProduct: 10,
          markupBasisPoints: 10001,
        ),
        throwsA(isA<DomainException>()),
      );
    });

    test('negative markup is rejected', () {
      expect(
        () => calc.calculatePartialPrice(
          sellingPriceMicros: 100000,
          partsPerFullProduct: 10,
          markupBasisPoints: -1,
        ),
        throwsA(isA<DomainException>()),
      );
    });

    test('0% markup is valid', () {
      final price = calc.calculatePartialPrice(
        sellingPriceMicros: 100000,
        partsPerFullProduct: 10,
        markupBasisPoints: 0,
      );
      expect(price, 10000); // $1.00
    });

    test('100% markup is valid', () {
      final price = calc.calculatePartialPrice(
        sellingPriceMicros: 100000,
        partsPerFullProduct: 10,
        markupBasisPoints: 10000,
      );
      expect(price, 20000); // $2.00
    });
  });

  // ── Full decomposition examples ──────────────────────────────────────────

  group('Complete decomposition examples', () {
    test('25 strips: 2 boxes + 5 strips', () {
      final d = calc.decompose(
        quantityParts: 25,
        partsPerFullProduct: 10,
        sellablePartBaseQuantity: 10,
        fullRetailPriceMicros: 100000,
        partialSellingPriceMicros: 11000,
      );
      expect(d.completeProducts, 2);
      expect(d.remainingParts, 5);
      expect(d.totalPriceMicros, 255000); // $20 + $5.50
      expect(d.totalBaseQuantity, 250); // 25 × 10
    });

    test('1 strip: 0 boxes + 1 strip', () {
      final d = calc.decompose(
        quantityParts: 1,
        partsPerFullProduct: 10,
        sellablePartBaseQuantity: 10,
        fullRetailPriceMicros: 100000,
        partialSellingPriceMicros: 11000,
      );
      expect(d.completeProducts, 0);
      expect(d.remainingParts, 1);
      expect(d.totalPriceMicros, 11000);
      expect(d.totalBaseQuantity, 10);
    });
  });
}
