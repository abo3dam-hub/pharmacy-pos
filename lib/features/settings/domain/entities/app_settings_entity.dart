import '../../../../core/money/percent.dart';

/// Phase 12 application settings aggregate (§B Application Settings).
///
/// - [businessName]: persistent pharmacy/business display name (the same key
///   the POS documents read as `pharmacy_name`).
/// - [taxRate]: VAT/sales-tax rate expressed in **integer basis points**
///   (`Percent` — 100 bp = 1%) per §23/§26 financial precision rules.
/// - [currencyCode]: ISO-4217 currency code. Display/config only; the money
///   engine stays integer micro-units without conversion.
class AppSettings {
  const AppSettings({
    required this.businessName,
    required this.taxRate,
    required this.currencyCode,
    this.updatedAt,
  });

  final String businessName;

  /// 0..10000 basis points (0%..100%).
  final Percent taxRate;

  final String currencyCode;

  /// Last write timestamp (absent on a fresh/default aggregate).
  final int? updatedAt;

  bool get isDefault => updatedAt == null;

  AppSettings copyWith({
    String? businessName,
    Percent? taxRate,
    String? currencyCode,
    int? Function()? updatedAt,
  }) {
    return AppSettings(
      businessName: businessName ?? this.businessName,
      taxRate: taxRate ?? this.taxRate,
      currencyCode: currencyCode ?? this.currencyCode,
      updatedAt: updatedAt != null ? updatedAt() : this.updatedAt,
    );
  }
}

/// Editable snapshot submitted by the settings UI. Validation happens in the
/// use-case layer; the repository only persists what it receives.
class AppSettingsDraft {
  const AppSettingsDraft({
    required this.businessName,
    required this.taxRateBasisPoints,
    required this.currencyCode,
  });

  final String businessName;
  final int taxRateBasisPoints;
  final String currencyCode;
}