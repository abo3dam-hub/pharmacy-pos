/// System chart-of-account codes (§4.22) addressed by the posting engine.
/// The engine maps business events to these seeded codes; UI code never
/// addresses accounts directly.
class SystemAccountCode {
  const SystemAccountCode._();

  static const String cash = '1000';
  static const String bank = '1001';
  static const String accountsReceivable = '1100';
  static const String inventory = '1200';
  static const String accountsPayable = '2000';
  static const String capital = '3000';
  static const String salesRevenue = '4000';
  static const String salesReturns = '4001';
  static const String costOfGoodsSold = '5000';
  static const String operatingExpenses = '5100';
  static const String rent = '5101';
  static const String salaries = '5102';

  /// Cash over/short — used by cashbox adjustments (replaces Capital stand-in).
  static const String cashOverShort = '1099';

  /// Purchase returns — contra-inventory account for purchase return reversals.
  static const String purchaseReturns = '4002';
}