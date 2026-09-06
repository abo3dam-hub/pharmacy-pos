import '../../../../core/data_grid/page_request.dart';
import '../../../../data/daos/purchase_dao.dart';
import '../../../../shared/database/app_database.dart';
import '../../../../shared/models/enums.dart';

/// Bonus entry on a purchase line (§4.18, §13). `itemId` NULL = bonus for the
/// purchased item; set = Buy A Get B (different item → own batch + movement).
class PurchaseBonusDraft {
  const PurchaseBonusDraft({
    required this.bonusType,
    required this.quantityBase,
    this.itemId,
    this.note,
  });

  final PurchaseBonusType bonusType;
  final int quantityBase;
  final String? itemId;
  final String? note;
}

/// One purchase line (§4.17). `quantityBase` is the *paid* quantity in base
/// units; bonuses are modelled explicitly.
class PurchaseLineDraft {
  const PurchaseLineDraft({
    required this.itemId,
    required this.unitTypeId,
    required this.quantityBase,
    required this.unitCostMicros,
    this.discountBasisPoints = 0,
    this.bonuses = const [],
  });

  final String itemId;
  final String unitTypeId;
  final int quantityBase;
  final int unitCostMicros;
  final int discountBasisPoints;
  final List<PurchaseBonusDraft> bonuses;
}

/// Purchase header + lines for creating a **pending** invoice (§4.16). Totals
/// are computed by the repository (subtotal − discount; tax/shipping stay 0).
class PurchaseDraft {
  const PurchaseDraft({
    required this.invoiceNumber,
    required this.supplierId,
    required this.invoiceDate,
    required this.lines,
    required this.userId,
    this.expectedDate,
    this.paidMicros = 0,
    this.notes,
  });

  final String invoiceNumber;
  final String supplierId;
  final int invoiceDate;
  final List<PurchaseLineDraft> lines;
  final String userId;
  final int? expectedDate;
  final int paidMicros;
  final String? notes;
}

/// Batch inputs entered when receiving a purchase line (§4.17): the supplier's
/// batch number and its expiry. One entry per pending line.
class ReceiveLineInput {
  const ReceiveLineInput({
    required this.lineId,
    required this.batchNumber,
    this.expiryDate,
  });

  final String lineId;
  final String batchNumber;
  final int? expiryDate;
}

/// One returned quantity of a purchase line (> 0, base units).
class PurchaseReturnLineRequest {
  const PurchaseReturnLineRequest({
    required this.lineId,
    required this.quantityBase,
  });

  final String lineId;
  final int quantityBase;
}

/// Standalone purchase return (§4.19, §14): goods go back to the supplier, the
/// original batch/item are reduced and the supplier balance is re-derived.
class PurchaseReturnRequest {
  const PurchaseReturnRequest({
    required this.returnNumber,
    required this.invoiceId,
    required this.userId,
    required this.lines,
    this.reason,
    this.notes,
  });

  final String returnNumber;
  final String invoiceId;
  final String userId;
  final List<PurchaseReturnLineRequest> lines;
  final String? reason;
  final String? notes;
}

class PurchaseReturnOutcome {
  const PurchaseReturnOutcome({
    required this.returnOrder,
    required this.returnLines,
  });

  final ReturnRow returnOrder;
  final List<ReturnItemRow> returnLines;
}

/// Purchase feature repository (§12, §13, §26). All mutations are transactional
/// and audit every financial/stock change inside the same transaction.
abstract interface class PurchasesRepository {
  AppDatabase get database;

  /// Creates a **pending** purchase invoice (no batches/movements yet).
  Future<PurchaseInvoiceRow> createPending(
    PurchaseDraft draft, {
    required String actingUserId,
    required String actingRoleId,
  });

  /// Replaces the lines/bonuses of a pending invoice without touching stock.
  Future<PurchaseInvoiceRow> updatePending(
    String invoiceId,
    PurchaseDraft draft, {
    required String actingUserId,
    required String actingRoleId,
  });

  /// Receives an invoice (§12): validates each line, creates batches, applies
  /// bonuses (effective qty/cost), posts `purchase` movements, optionally
  /// updates master pricing (audited) and syncs the supplier balance.
  Future<PurchaseInvoiceRow> receive(
    String invoiceId, {
    required List<ReceiveLineInput> inputs,
    required String actingUserId,
    required String actingRoleId,
  });

  /// Cancels a pending invoice (`purchases.void`) — soft-deleted via status.
  Future<PurchaseInvoiceRow> cancel(
    String invoiceId, {
    required String actingUserId,
    required String actingRoleId,
    String? reason,
  });

  /// Paginated invoice list (filtering in SQL).
  Future<PageResult<PurchaseInvoiceView>> search(
    PageRequest page, {
    String? supplierId,
    PurchaseStatus? status,
    DateTime? fromDate,
    DateTime? toDate,
  });

  Future<PurchaseDetailView> detail(String invoiceId);

  /// Still-returnable base quantity of a received purchase line.
  Future<int> availableToReturn(String lineId);

  /// Records a purchase return transactionally (stock, ledger, balance, audit).
  Future<PurchaseReturnOutcome> recordReturn(PurchaseReturnRequest request);
}