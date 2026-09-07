import '../../../../core/errors/exceptions.dart';

/// POS payment methods surfaced by the workspace (§5 payment panel). The
/// business engine accepts the `credit` enum value and enforces the account
/// credit-limit rule (§11): the workspace exposes it since Phase 8 credit
/// sales, gated on a selected account customer in the payment sheet.
enum PosPaymentMethod { cash, card, mixed, credit }

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

/// Validates a cash/card/mixed/credit payment against the invoice total (§11).
///
/// Rules:
///  * no negative amounts anywhere;
///  * cash: received must cover the total (overpayment → change);
///  * card: amount must equal the total exactly;
///  * mixed: both components must be present (≥ 0) and their sum must cover
///    the total; change = sum − total;
///  * credit: the customer pays a down payment (cash + card ≤ total) and the
///    *remaining* becomes the open receivable. Requires a receivables customer
///    (checked by the sale engine) — the entered components must leave a
///    positive balance, change is always 0.
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
    int? remainingMicros;
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
      case PosPaymentMethod.credit:
        paidMicros = cashReceivedMicros + cardAmountMicros;
        final due = totalMicros - paidMicros;
        remainingMicros = due;
        if (due <= 0) {
          error = 'البيع الآجل يجب أن يترك مبلغاً مستحقاً على العميل '
              '(دفعة قدرها الإجمالي تُدفع عند الاستلام فقط)';
        } else {
          changeMicros = 0;
        }
    }

    remainingMicros ??= error == null ? 0 : (totalMicros - paidMicros) > 0
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