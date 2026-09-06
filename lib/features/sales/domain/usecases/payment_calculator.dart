import '../../../../core/errors/exceptions.dart';

/// POS payment methods surfaced by the workspace (§5 payment panel). The
/// business engine additionally accepts the `credit` enum value, but settled
/// sales require `paidMicros >= totalMicros` (approved Phase 6 rule), so the
/// POS workspace exposes immediate-settlement methods only.
enum PosPaymentMethod { cash, card, mixed }

/// Validated payment inputs + computed change/remaining, all integer micro-units.
class PosPaymentResult {
  const PosPaymentResult({
    required this.totalMicros,
    required this.paidMicros,
    required this.changeMicros,
    required this.remainingMicros,
    this.error,
  });

  final int totalMicros;
  final int paidMicros;
  final int changeMicros;
  final int remainingMicros;
  final String? error;

  bool get isValid => error == null;

  bool get fullyPaid =>
      error == null && paidMicros >= totalMicros && remainingMicros == 0;
}

/// Validates a cash/card/mixed payment against the invoice total (§11).
///
/// Rules:
///  * no negative amounts anywhere;
///  * cash: received must cover the total (overpayment → change);
///  * card: amount must equal the total exactly;
///  * mixed: both components must be present (≥ 0) and their sum must cover
///    the total; change = sum − total.
class PaymentCalculator {
  const PaymentCalculator();

  PosPaymentResult calculate({
    required int totalMicros,
    required PosPaymentMethod method,
    int cashReceivedMicros = 0,
    int cardAmountMicros = 0,
  }) {
    if (totalMicros < 0) {
      throw ValidationException('إجمالي الفاتورة لا يمكن أن يكون سالباً');
    }
    if (cashReceivedMicros < 0 || cardAmountMicros < 0) {
      throw ValidationException('المبالغ لا يمكن أن تكون سالبة');
    }

    final int paidMicros;
    int? changeMicros;
    String? error;

    switch (method) {
      case PosPaymentMethod.cash:
        paidMicros = cashReceivedMicros;
        if (cashReceivedMicros < totalMicros) {
          error = 'المبلغ المقبوض نقداً ($cashReceivedMicros) أقل من الإجمالي '
              '($totalMicros)';
        } else {
          changeMicros = cashReceivedMicros - totalMicros;
        }
      case PosPaymentMethod.card:
        paidMicros = cardAmountMicros;
        if (cardAmountMicros != totalMicros) {
          error = 'قيمة الدفع بالبطاقة يجب أن تساوي الإجمالي ($totalMicros)';
        } else {
          changeMicros = 0;
        }
      case PosPaymentMethod.mixed:
        paidMicros = cashReceivedMicros + cardAmountMicros;
        if (cashReceivedMicros == 0 && cardAmountMicros == 0) {
          error = 'أدخل مبلغين (نقدي وبطاقة) للدفع المختلط';
        } else if (paidMicros < totalMicros) {
          error = 'مجموع الدفع ($paidMicros) أقل من الإجمالي ($totalMicros)';
        } else {
          changeMicros = paidMicros - totalMicros;
        }
    }

    final remainingMicros = error == null ? 0 : (totalMicros - paidMicros) > 0
        ? totalMicros - paidMicros
        : 0;

    return PosPaymentResult(
      totalMicros: totalMicros,
      paidMicros: paidMicros,
      changeMicros: changeMicros ?? 0,
      remainingMicros: remainingMicros,
      error: error,
    );
  }
}