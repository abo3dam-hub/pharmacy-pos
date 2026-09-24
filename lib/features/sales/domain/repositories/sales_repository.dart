import '../../../../core/data_grid/page_request.dart';
import '../../../../shared/models/enums.dart';
import '../entities/pos_catalog_item.dart';
import '../entities/pos_customer.dart';
import '../entities/pos_invoice.dart';
import '../entities/pos_return.dart';
import '../entities/smart_alternative.dart';

/// Return input for the return panel (references the ORIGINAL invoice line).
class PosReturnCommand {
  const PosReturnCommand({
    required this.returnNumber,
    required this.originalInvoiceItemId,
    required this.quantityBase,
    required this.userId,
    this.reason,
    this.notes,
  });

  final String returnNumber;
  final String originalInvoiceItemId;
  final int quantityBase;
  final String userId;
  final String? reason;
  final String? notes;
}

/// The POS data contract. The domain layer defines the types; the data layer
/// implements it over the existing engine (SaleService, ReturnService,
/// StockService, DAOs) — the presentation layer never touches Drift.
abstract interface class SalesRepository {
  /// Paginated, DB-side catalog search (§5 search panel) — trade name (ar/en),
  /// scientific name, active ingredient and both barcodes.
  Future<PageResult<PosCatalogItem>> searchCatalog(
    PageRequest request, {
    bool? inStockOnly,
  });

  /// Indexed barcode lookup (primary then secondary).
  Future<PosCatalogItem?> itemByBarcode(String barcode);

  Future<PosCatalogItem?> itemById(String id);

  Future<List<PosCustomer>> findCustomers(String query, {int limit = 20});

  /// Active (not yet dispensed) prescriptions for a customer, newest first.
  Future<List<PosRxSummary>> activePrescriptionsForCustomer(String customerId);

  /// Generates a collision-safe sequential sale invoice number.
  Future<String> nextInvoiceNumber();

  /// Generates the matching return-number space (RT-…).
  Future<String> nextReturnNumber();

  /// Executes the checkout through the sale engine as ONE atomic transaction.
  Future<PosSaleOutcome> checkout(PosCheckoutCommand command);

  /// Voids a completed, never-returned invoice (stock, drawer, journal,
  /// prescription and customer balance all reversed together).
  Future<void> voidInvoice(
    String invoiceId, {
    required String userId,
    required String reason,
  });

  /// Returns a sold line through the return engine (stock to original batch,
  /// financial + prescription reversal) — atomic and audited.
  Future<PosReturnOutcome> returnSaleLine(PosReturnCommand command);

  /// Paginated list of recorded return documents (sale returns), newest
  /// first — the clear, easy returns list inside sales.
  Future<PageResult<PosReturnView>> listReturns(PageRequest request);

  /// Full detail of one return document: header + lines.
  Future<({PosReturnView header, List<PosReturnLineView> lines})?>
      returnDetail(String returnId);

  /// Paginated search over persisted sales invoices. All filters are
  /// additive and applied DB-side (IN clause / range scan) — the page stays a
  /// LIMIT/OFFSET query. [request.search] matches invoice number or customer.
  Future<PageResult<PosInvoiceView>> searchSaleInvoices(
    PageRequest request, {
    SaleStatus? status,
    PaymentMethod? paymentMethod,
    String? userId,
    int? fromMillis,
    int? toMillis,
  });

  Future<PosInvoiceView?> invoiceViewById(String invoiceId);

  /// Smart alternatives for [item]: same therapeutic/ingredient group, active,
  /// available — computed at request time, never a stored table.
  /// Live smart alternatives (§18): ranks products that share the therapeutic
  /// group or an active ingredient with [item] into the green/yellow/blue
  /// tiers. Computed at request time — never persisted.
  Future<List<SmartAlternative>> smartAlternatives(PosCatalogItem item);

  Future<void> recordLostSale(PosLostSaleDraft draft);

  /// Live FEFO-available quantity (base units).
  Future<int> availableStock(String itemId);
}