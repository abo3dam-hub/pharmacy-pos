/// Curated ISO-4217 currency options for the Phase 12 currency setting.
///
/// Display/config only — the money engine stays integer micro-units with no
/// exchange conversion (§23). Codes are stored verbatim in `app_settings`;
/// `arabicName` drives the dropdown, mirrored in app_en.arb by code lookup.
const List<CurrencyOption> kSupportedCurrencies = [
  CurrencyOption('SAR', 'ريال سعودي'),
  CurrencyOption('EGP', 'جنيه مصري'),
  CurrencyOption('AED', 'درهم إماراتي'),
  CurrencyOption('KWD', 'دينار كويتي'),
  CurrencyOption('QAR', 'ريال قطري'),
  CurrencyOption('BHD', 'دينار بحريني'),
  CurrencyOption('OMR', 'ريال عماني'),
  CurrencyOption('IQD', 'دينار عراقي'),
  CurrencyOption('LYD', 'دينار ليبي'),
  CurrencyOption('MAD', 'درهم مغربي'),
  CurrencyOption('TND', 'دينار تونسي'),
  CurrencyOption('SYP', 'ليرة سورية'),
  CurrencyOption('USD', 'دولار أمريكي'),
  CurrencyOption('EUR', 'يورو'),
  CurrencyOption('GBP', 'جنيه إسترليني'),
];

class CurrencyOption {
  const CurrencyOption(this.code, this.arabicName);

  final String code;
  final String arabicName;
}