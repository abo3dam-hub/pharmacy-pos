import '../../../../shared/models/enums.dart';
import '../usecases/payment_calculator.dart';
import 'pos_cart.dart';

/// Pure invoice/line views served to the invoice/receipt and return panels.
/// Built by the sales data layer by joining the persisted sales documents.
class PosInvoiceLineView {
  const PosInvoiceLineView({
    required this.id,
    required this.invoiceId,
    required this.itemId,
    required this.itemName,
    required this.batchId,
    required this.batchNumber,
    required this.unitTypeId,
    required this.unitTypeName,
    required this.quantityBaseSigned,
    required this.unitPriceMicros,
    required this.vatRateBasisPoints,
    required this.lineDiscountBasisPoints,
    required this.lineSubtotalMicros,
    required this.lineDiscountMicros,
    required this.lineTotalMicros,
    required this.unitCostMicros,
    required this.costTotalMicros,
    required this.profitMicros,
    this.prescriptionItemId,
    required this.returnQuantityBase,
  });

  final String id;
  final String invoiceId;
  final String itemId;
  final String itemName;
  final String batchId;
  final String batchNumber;
  final String unitTypeId;
  final String unitTypeName;
  final int quantityBaseSigned;
  final int unitPriceMicros;
  final int vatRateBasisPoints;
  final int lineDiscountBasisPoints;
  final int lineSubtotalMicros;
  final int lineDiscountMicros;
  final int lineTotalMicros;
  final int unitCostMicros;
  final int costTotalMicros;
  final int profitMicros;
  final String? prescriptionItemId;
  final int returnQuantityBase;

  /// What can still be returned on this line (over-return is prevented).
  int get returnableBase => (quantityBaseSigned - returnQuantityBase).clamp(0, quantityBaseSigned);
}

/// Immutable, persisted sale invoice view (header + customer + lines).
class PosInvoiceView {
  const PosInvoiceView({
    required this.id,
    required this.invoiceNumber,
    required this.invoiceType,
    required this.saleStatus,
    required this.paymentMethod,
    required this.customerId,
    required this.customerName,
    required this.userId,
    required this.subtotalMicros,
    required this.discountTotalMicros,
    required this.vatTotalMicros,
    required this.totalMicros,
    required this.totalCostMicros,
    required this.profitMicros,
    required this.paidMicros,
    required this.changeMicros,
    required this.createdAt,
    this.notes,
    this.prescriptionId,
    required this.lines,
  });

  final String id;
  final String invoiceNumber;
  final InvoiceType invoiceType;
  final SaleStatus saleStatus;
  final PaymentMethod paymentMethod;
  final String? customerId;
  final String customerName;
  final String userId;
  final int subtotalMicros;
  final int discountTotalMicros;
  final int vatTotalMicros;
  final int totalMicros;
  final int totalCostMicros;
  final int profitMicros;
  final int paidMicros;
  final int changeMicros;
  final int createdAt;
  final String? notes;
  final String? prescriptionId;
  final List<PosInvoiceLineView> lines;

  bool get isReturnable =>
      saleStatus == SaleStatus.completed && lines.isNotEmpty;
}

/// Outcome of a completed POS checkout — the receipt / invoice data.
class PosSaleOutcome {
  const PosSaleOutcome({
    required this.invoice,
    required this.lines,
    required this.movements,
  });

  final PosInvoiceView invoice;
  final List<PosInvoiceLineView> lines;
  final int movements;
}

/// Outcome of a completed sale return.
class PosReturnOutcome {
  const PosReturnOutcome({
    required this.returnId,
    required this.returnNumber,
    required this.reversalMicros,
    required this.restoredQuantityBase,
  });

  final String returnId;
  final String returnNumber;
  final int reversalMicros;
  final int restoredQuantityBase;
}

/// Pure checkout command built by the workspace controller; converted to the
/// sale engine's request inside the data layer.
class PosCheckoutCommand {
  const PosCheckoutCommand({
    required this.invoiceNumber,
    required this.lines,
    required this.paymentMethod,
    required this.paidMicros,
    required this.userId,
    this.customerId,
    this.prescriptionId,
    this.notes,
  });

  final String invoiceNumber;
  final List<PosSaleLineInput> lines;
  final PosPaymentMethod paymentMethod;
  final int paidMicros;
  final String userId;
  final String? customerId;
  final String? prescriptionId;
  final String? notes;
}

/// Local alias so the checkout command stays free of data-layer types.