/// Canonical `app_settings` keys (§4 appendix settings, Phase 12).
///
/// Keys are stable strings persisted in the `app_settings.key` text column;
/// values are stored as TEXT (`setInt`/`getInt` serialize whole decimal
/// numbers). Old keys (e.g. Phase 6 `partial_sale_markup_basis_points`) are
/// untouched by Phase 12 — additive keys only.
abstract final class SettingsKeys {
  SettingsKeys._();

  /// Pharmacy/business display name. This is the same key the POS documents
  /// already read (`pharmacyNameSettingKey` in `pdf_arabic.dart`), so editing
  /// it here immediately propagates to receipts/invoices/Z-report headers.
  static const String businessName = 'pharmacy_name';

  /// VAT/sales-tax rate as integer basis points (100 bp = 1%). Integer-only
  /// per §23 — rates are never floats. `'0'` = no tax.
  static const String taxRateBasisPoints = 'tax_rate_basis_points';

  /// ISO-4217 currency code (e.g. `SAR`). Display/config only; the financial
  /// engine remains integer micro-units (§23) with no exchange conversion.
  static const String currencyCode = 'currency_code';

  /// Default tax rate used when the key is absent (0 = no tax).
  static const int defaultTaxRateBasisPoints = 0;

  /// Default currency code used when the key is absent.
  static const String defaultCurrencyCode = 'SAR';
}