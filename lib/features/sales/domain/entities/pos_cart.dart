import '../../../../core/errors/exceptions.dart';
import '../entities/pos_catalog_item.dart';

/// The unit the cashier is selling the line in — the POS "box / fraction"
/// toggle (F2). For partial-sale items the fraction is the configured sellable
/// part (strip); otherwise it is the base unit (tablet/strip).
enum PosLineUnitMode { largeUnit, sellablePart, baseUnit }

/// One cart line — an immutable edit snapshot. Quantity is expressed in the
/// line's current [unitMode] (boxes, sellable parts or base units). All money
/// is integer micro-units; the [PosLinePricer] expands the line into the
/// actual sale input lines for the engine.
class PosCartLine {
  const PosCartLine({
    required this.item,
    required this.quantity,
    required this.unitMode,
    this.prescriptionItemId,
    this.rxRemainingBase,
    this.discountBasisPoints = 0,
    this.priceOverrideMicros,
  });

  final PosCatalogItem item;
  final int quantity;
  final PosLineUnitMode unitMode;

  /// Linked prescription item when dispensing from an Rx (§5 customer tabs).
  final String? prescriptionItemId;

  /// Remaining (not-yet-dispensed) base quantity on the linked Rx item.
  final int? rxRemainingBase;
  final int discountBasisPoints;

  /// Optional authorized price override: price per base unit used by the price
  /// engine instead of the master-derived price (guarded by `change_prices` in
  /// the controller — never in the UI layer).
  final int? priceOverrideMicros;

  bool get isRxLinked => prescriptionItemId != null;

  PosCartLine copyWith({
    int? quantity,
    PosLineUnitMode? unitMode,
    String? prescriptionItemId,
    bool clearRxLink = false,
    int? rxRemainingBase,
    int? discountBasisPoints,
    int? priceOverrideMicros,
    bool clearPriceOverride = false,
  }) {
    return PosCartLine(
      item: item,
      quantity: quantity ?? this.quantity,
      unitMode: unitMode ?? this.unitMode,
      prescriptionItemId:
          clearRxLink ? null : (prescriptionItemId ?? this.prescriptionItemId),
      rxRemainingBase: clearRxLink ? null : (rxRemainingBase ?? this.rxRemainingBase),
      discountBasisPoints: discountBasisPoints ?? this.discountBasisPoints,
      priceOverrideMicros: clearPriceOverride
          ? null
          : (priceOverrideMicros ?? this.priceOverrideMicros),
    );
  }

  /// One cart line per (item, unit) combination — box lines and strip lines of
  /// the same product coexist (e.g. box + 3 strips).
  String get cartKey => '${item.id}::${unitMode.name}';

  @override
  bool operator ==(Object other) =>
      other is PosCartLine &&
      other.item.id == item.id &&
      other.quantity == quantity &&
      other.unitMode == unitMode &&
      other.prescriptionItemId == prescriptionItemId &&
      other.discountBasisPoints == discountBasisPoints &&
      other.priceOverrideMicros == priceOverrideMicros;

  @override
  int get hashCode => Object.hash(
      item.id, quantity, unitMode, prescriptionItemId, priceOverrideMicros);
}

/// One engine-ready sale line expansion of a cart line (base units + integer
/// per-base-unit price). Mirrors `SaleLineRequest` semantics (§11 / Phase 6).
class PosSaleLineInput {
  const PosSaleLineInput({
    required this.itemId,
    required this.quantityBase,
    required this.unitPriceMicros,
    required this.unitTypeId,
    required this.vatRateBasisPoints,
    required this.discountBasisPoints,
    this.prescriptionItemId,
    this.partialSaleUnitPriceMicros,
  });

  final String itemId;
  final int quantityBase;

  /// Price per single base unit (integer micro-units).
  final int unitPriceMicros;

  /// Unit type at sell-time (large part/sellable part/base).
  final String unitTypeId;
  final int vatRateBasisPoints;
  final int discountBasisPoints;
  final String? prescriptionItemId;

  /// Pre-computed per-base partial price — persisted on the line so historical
  /// invoices keep the partial rates (Phase 6). Null for full-product lines.
  final int? partialSaleUnitPriceMicros;
}

/// Financial summary for one [PosCartLine] after pricing expansion.
class PosLinePricing {
  const PosLinePricing({
    required this.line,
    required this.lines,
    required this.quantityBase,
    required this.grossMicros,
    required this.discountMicros,
    required this.vatMicros,
  });

  final PosCartLine line;

  /// Engine-ready sale lines (1 for normal, up to 2 for partial: box+strips).
  final List<PosSaleLineInput> lines;

  /// Total base units deducted from stock for this line.
  final int quantityBase;

  /// Gross (price × quantity), discount, VAT (on net) — all in micro-units.
  final int grossMicros;
  final int discountMicros;
  final int vatMicros;

  int get netMicros => grossMicros - discountMicros;
}

/// Aggregate money/quantity view of the whole cart.
class PosCartTotals {
  const PosCartTotals({
    required this.subtotalMicros,
    required this.discountTotalMicros,
    required this.vatTotalMicros,
    required this.totalMicros,
    required this.totalBaseQuantity,
  });

  final int subtotalMicros;
  final int discountTotalMicros;
  final int vatTotalMicros;
  final int totalMicros;
  final int totalBaseQuantity;

  /// True when every line satisfies the business rules (no zero quantities …).
  bool get isEmptyCart => totalBaseQuantity <= 0 || subtotalMicros <= 0;
}

/// Guards cart mutations (§5 POS cart rules). Pure Dart domain rule — the UI
/// only renders, the data layer only persists.
class PosCartValidator {
  const PosCartValidator();

  void requirePositiveQuantity(int quantity) {
    if (quantity <= 0) {
      throw ValidationException('الكمية يجب أن تكون أكبر من صفر');
    }
  }

  /// Quantity (in [unitMode] units) converts to at most [perUnit] base units.
  int baseUnitsFor(PosCartLine line, int quantity) {
    return switch (line.unitMode) {
      PosLineUnitMode.largeUnit =>
        quantity * (line.item.unitsPerLarge > 0 ? line.item.unitsPerLarge : 1),
      PosLineUnitMode.baseUnit => quantity,
      PosLineUnitMode.sellablePart =>
        quantity *
        (line.item.sellablePartBaseQuantity ?? line.item.unitsPerLarge),
    };
  }

  /// A requires-prescription / controlled item may only be sold via a linked
  /// prescription item (enforced here — never only at the UI layer).
  void requireRxForRestrictedItem(PosCatalogItem item, String? prescriptionItemId) {
    if ((item.requiresPrescription || item.isControlledDrug) &&
        prescriptionItemId == null) {
      throw ValidationException(
        '${item.displayName} يتطلب ربطه بوصفة طبية (الأدوية المقيّدة أو المخدرة)',
      );
    }
  }

  void requireEnoughStock({
    required PosCatalogItem item,
    required int quantityBase,
  }) {
    if (quantityBase > item.availableStockBase) {
      throw ValidationException(
        'المخزون المتاح غير كافٍ لـ ${item.displayName}: المطلوب $quantityBase '
        'والمتاح ${item.availableStockBase}',
      );
    }
  }

  void requireWithinRxRemaining({
    required PosCatalogItem item,
    required int quantityBase,
    required int rxRemainingBase,
  }) {
    if (quantityBase > rxRemainingBase) {
      throw ValidationException(
        'الكمية المطلوبة ($quantityBase) أكبر من المتبقي على الوصفة '
        '($rxRemainingBase) لـ ${item.displayName}',
      );
    }
  }

  void requireActiveItem(PosCatalogItem item) {
    if (!item.isActive) {
      throw ValidationException('${item.displayName} غير نشط ولا يمكن بيعه');
    }
  }
}