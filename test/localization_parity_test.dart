import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'package:pharmacy_pos/l10n/app_localizations.dart';

/// Phase 16 localization regression: Arabic (primary) and English
/// (secondary) catalogs must stay in exact key parity. Any new user-visible
/// string must be added to BOTH languages or this test fails (protects the
/// 'no avoidable hardcoded user-facing strings' release gate).
void main() {
  final root = Directory.current.path;

  Map<String, dynamic> readArb(String fileName) {
    final raw = File('$root/lib/l10n/$fileName').readAsStringSync();
    return jsonDecode(raw) as Map<String, dynamic>;
  }

  test('Arabic and English ARB catalogs are in exact key parity', () {
    final ar = readArb('app_ar.arb');
    final en = readArb('app_en.arb');

    final arKeys = ar.keys.where((k) => !k.startsWith('@')).toSet();
    final enKeys = en.keys.where((k) => !k.startsWith('@')).toSet();

    final missingInEn = arKeys.difference(enKeys);
    final missingInAr = enKeys.difference(arKeys);

    expect(missingInEn, isEmpty, reason: 'Keys present in Arabic but missing in English: $missingInEn');
    expect(missingInAr, isEmpty, reason: 'Keys present in English but missing in Arabic: $missingInAr');
    expect(arKeys.length, enKeys.length);
  });

  test('all supported locales resolve through the generated lookup', () {
    for (final locale in AppLocalizations.supportedLocales) {
      final l10n = lookupAppLocalizations(locale);
      expect(l10n, isNotNull, reason: 'lookupAppLocalizations($locale) must resolve');
    }
  });

  test('new Phase 16 POS/audit keys are present in both catalogs', () {
    const keys = [
      'posCashLabel',
      'posCardLabel',
      'posMixedLabel',
      'posClearCart',
      'posRx',
      'posReceiptFooter',
      'posItemCount',
      'posRestore',
      'posCustomerSearchHint',
      'posChooseActiveRx',
      'posReturnSelectInvoiceHint',
      'posVoidInvoice',
      'posInvoiceVoided',
      'posVoidInvoiceFailed',
      'auditLogDateFrom',
      'auditLogDateTo',
    ];
    final ar = readArb('app_ar.arb');
    final en = readArb('app_en.arb');
    for (final key in keys) {
      expect(ar.containsKey(key), isTrue, reason: 'Arabic missing $key');
      expect(en.containsKey(key), isTrue, reason: 'English missing $key');
      expect((ar[key] as String).trim(), isNotEmpty);
      expect((en[key] as String).trim(), isNotEmpty);
    }
  });
}