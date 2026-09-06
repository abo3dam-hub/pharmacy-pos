import 'package:flutter_test/flutter_test.dart';
import 'package:pharmacy_pos/core/money/money.dart';

void main() {
  group('Money arithmetic is integer-only and exact', () {
    test('add / subtract', () {
      expect(Money.fromMajor(12) + const Money.fromUnits(5000),
          const Money.fromUnits(12 * 10000 + 5000));
      expect(Money.fromMajor(5) - Money.fromMajor(3),
          Money.fromMajor(2));
    });

    test('multiply by integer factor', () {
      expect(Money.fromMajor(5) * 3, Money.fromMajor(15));
    });

    test('divideBy rounds half-up', () {
      expect(const Money.fromUnits(10000).divideBy(3), const Money.fromUnits(3333));
      expect(const Money.fromUnits(10005).divideBy(2), const Money.fromUnits(5003));
    });

    test('timesRatio rounds half-up without floating point', () {
      // 10% of 10,000 micros = 1,000.
      expect(const Money.fromUnits(10000).timesRatio(1000, 10000),
          const Money.fromUnits(1000));
      // 33.33% of 3,000 micros rounds to 1,000.
      expect(const Money.fromUnits(3000).timesRatio(3333, 10000),
          const Money.fromUnits(1000));
    });

    test('addPercent / minusPercent', () {
      expect(Money.fromMajor(100).addPercent(1500), Money.fromMajor(115));
      expect(Money.fromMajor(100).minusPercent(1000), Money.fromMajor(90));
    });
  });

  group('Money parsing and formatting', () {
    test('parse whole and decimal', () {
      expect(Money.parse('1250.50'), const Money.fromUnits(12505000));
      expect(Money.parse('1250'), Money.fromMajor(1250));
      expect(Money.parse('0'), Money.zero());
      expect(Money.parse('-12.5'), const Money.fromUnits(-125000));
    });

    test('parse rounds half-up beyond scale (4 digits max)', () {
      expect(Money.parse('1.12345'), const Money.fromUnits(11235));
      expect(Money.parse('1.12344'), const Money.fromUnits(11234));
    });

    test('format with grouping', () {
      expect(Money.parse('1250.50').format(), '1,250.50');
      expect(Money.parse('1250.50').format(0), '1,251');
    });

    test('formatArabicDigits renders Western/Latin glyphs per §23', () {
      expect(Money.parse('1234.50').formatArabicDigits(), '1,234.50');
      expect(Money.parse('1234.50').formatArabicDigits(4), '1,234.5000');
    });

    test('roundTo / floorTo', () {
      expect(Money.parse('10.005').roundTo(2), Money.parse('10.01'));
      expect(Money.parse('10.009').floorTo(2), Money.parse('10.00'));
    });

    test('exact cash amounts like 50 cents (spec §23)', () {
      expect(Money.fromMajor(0) + Money.parse('12.50'),
          Money.parse('12.50'));
      expect(Money.parse('12.50').units, 125000);
    });
  });

  group('comparisons', () {
    test('order and equality', () {
      expect(Money.parse('2.00') > Money.parse('1.99'), isTrue);
      expect(Money.parse('2.00') == Money.parse('2.0000'), isTrue);
      final m = Money.parse('0.10');
      expect(m * 3, Money.parse('0.30'));
    });
  });
}