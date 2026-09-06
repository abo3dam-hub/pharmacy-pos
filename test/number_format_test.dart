import 'package:flutter_test/flutter_test.dart';
import 'package:pharmacy_pos/core/money/money.dart';

/// Number formatting policy (§23): Arabic-first UI + RTL layout, but numbers —
/// prices, quantities, percentages, invoice numbers, dates — are rendered with
/// Western/Latin digits only. The Arabic-Indic digit set (٠-٩) must never be
/// emitted by the display formatters.
const _arabicIndicDigits = '٠١٢٣٤٥٦٧٨٩';
const _arabicIndicDecimal = '٫';
const _arabicIndicThousand = '٬';

void main() {
  group('Latin-digit policy (§23)', () {
    test('formatArabicDigits never emits Arabic-Indic glyphs', () {
      final samples = [
        Money.zero(),
        Money.fromUnits(1),
        Money.parse('12345.00'),
        Money.parse('0.50'),
        Money.parse('1234.5678'),
        Money.fromUnits(-123456),
        Money.parse('99999999.99'),
      ];
      for (final m in samples) {
        final out = m.formatArabicDigits();
        expect(out.contains(_arabicIndicDecimal), isFalse, reason: out);
        expect(out.contains(_arabicIndicThousand), isFalse, reason: out);
        for (final c in _arabicIndicDigits.split('')) {
          expect(out.contains(c), isFalse, reason: out);
        }
      }
    });

    test('amounts format with Latin digits and comma groups', () {
      expect(Money.zero().formatArabicDigits(), '0.00');
      expect(const Money.fromUnits(1).formatArabicDigits(), '0.00');
      expect(Money.parse('1').formatArabicDigits(), '1.00');
      expect(Money.parse('12345').formatArabicDigits(), '12,345.00');
      expect(Money.parse('0.5').formatArabicDigits(), '0.50');
      expect(Money.parse('1234.5678').formatArabicDigits(4), '1,234.5678');
      expect(Money.parse('-10.25').formatArabicDigits(), '-10.25');
      expect(Money.fromUnits(-123456).formatArabicDigits(), '-12.35');
      expect(Money.parse('15593859').formatArabicDigits(), '15,593,859.00');
    });

    test('whole-number formatting as used for quantities and invoice numbers',
        () {
      expect(const Money.fromUnits(125000).formatArabicDigits(0), '13');
      expect(Money.parse('0').formatArabicDigits(0), '0');
      expect(Money.parse('100').formatArabicDigits(4), '100.0000');
    });

    test('ASCII punctuation separators are used, never Arabic ones', () {
      final out = Money.parse('1234.50').formatArabicDigits();
      expect(out, '1,234.50');
      expect(out.contains(','), isTrue);
      expect(out.contains('.'), isTrue);
    });

    test('parse still rejects the Arabic-Indic digit set', () {
      expect(() => Money.parse('١٢٣.٥٠'), throwsFormatException);
    });
  });
}