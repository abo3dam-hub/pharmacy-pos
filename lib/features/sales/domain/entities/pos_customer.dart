/// Pure customer snapshot for the POS workspace (no Drift types leak into the
/// domain layer). Built from the customers master + ledger-derived balance.
class PosCustomer {
  const PosCustomer({
    required this.id,
    required this.name,
    this.phone,
    required this.hasAccount,
    required this.isActive,
    required this.balanceMicros,
  });

  final String id;
  final String name;
  final String? phone;
  final bool hasAccount;
  final bool isActive;
  final int balanceMicros;
}

/// One undispensed/partially dispensed prescription for the customer.
class PosRxSummary {
  const PosRxSummary({
    required this.id,
    required this.prescriptionNumber,
    required this.patientName,
    this.doctorName,
    required this.statusName,
    required this.createdAt,
    required this.items,
  });

  final String id;
  final String prescriptionNumber;
  final String patientName;
  final String? doctorName;
  final String statusName;
  final int createdAt;
  final List<PosRxItemSummary> items;

  int get totalRemainingBase =>
      items.fold<int>(0, (sum, i) => sum + i.remainingBase);
}

class PosRxItemSummary {
  const PosRxItemSummary({
    required this.id,
    required this.prescriptionId,
    required this.itemId,
    required this.itemName,
    required this.quantityBase,
    required this.dispensedQuantityBase,
  });

  final String id;
  final String prescriptionId;
  final String itemId;
  final String itemName;
  final int quantityBase;
  final int dispensedQuantityBase;

  int get remainingBase => quantityBase - dispensedQuantityBase;
}

/// Quick lost-sale capture draft (§15, lost_sales table).
class PosLostSaleDraft {
  const PosLostSaleDraft({
    required this.requestedItemName,
    required this.quantityRequested,
    required this.userId,
    this.barcode,
    this.scientificName,
    this.customerName,
    this.customerPhone,
    this.note,
  });

  final String requestedItemName;
  final int quantityRequested;
  final String userId;
  final String? barcode;
  final String? scientificName;
  final String? customerName;
  final String? customerPhone;
  final String? note;
}