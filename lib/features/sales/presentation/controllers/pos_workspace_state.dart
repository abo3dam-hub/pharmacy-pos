import '../../../../core/data_grid/page_request.dart';
import '../../domain/entities/pos_cart.dart';
import '../../domain/entities/pos_catalog_item.dart';
import '../../domain/entities/pos_customer.dart';
import '../../domain/entities/pos_hold.dart';
import '../../domain/entities/pos_invoice.dart';
import '../../domain/usecases/payment_calculator.dart';

/// The dedicated Return tab lives at index 10 (10 customer tabs + 1 return).
const int kReturnTabIndex = 10;
const int kPosCustomerTabCount = 10;
const int kPosTabCount = kPosCustomerTabCount + 1;

/// Immutable workspace state for ONE customer tab (§5 tabs) or the return tab.
/// Presentation-only; the controller applies all domain rules.
class PosWorkspaceState {
  const PosWorkspaceState({
    this.tabIndex = 0,
    this.loading = false,
    this.busy = false,
    this.errorMessage,
    this.searchQuery = '',
    this.searchResults,
    this.cart = const [],
    this.heldBills = const [],
    this.customer,
    this.activePrescriptions = const [],
    this.activePrescriptionId,
    this.paymentMethod = PosPaymentMethod.cash,
    this.cashReceivedMicros = 0,
    this.cardReceivedMicros = 0,
    this.paymentOpen = false,
    this.lastSale,
    this.returnSearchResults,
    this.returnLoading = false,
    this.returnedLinesNote,
    this.selectedReturnInvoice,
    this.returnQuantityByLine = const {},
  });

  final int tabIndex;
  final bool loading;
  final bool busy;
  final String? errorMessage;

  // ── Search / scan ──
  final String searchQuery;
  final PageResult<PosCatalogItem>? searchResults;

  // ── Cart ──
  final List<PosCartLine> cart;
  final List<PosHeldBill> heldBills;

  // ── Customer / prescription ──
  final PosCustomer? customer;
  final List<PosRxSummary> activePrescriptions;
  final String? activePrescriptionId;

  // ── Payment ──
  final PosPaymentMethod paymentMethod;
  final int cashReceivedMicros;
  final int cardReceivedMicros;
  final bool paymentOpen;

  /// Set after a successful checkout → the workspace shows the receipt.
  final PosSaleOutcome? lastSale;

  // ── Return tab ──
  final PageResult<PosInvoiceView>? returnSearchResults;
  final bool returnLoading;
  final String? returnedLinesNote;
  final PosInvoiceView? selectedReturnInvoice;
  final Map<String, int> returnQuantityByLine;

  bool get isReturnTab => tabIndex == kReturnTabIndex;

  bool get isEmptyCart => cart.isEmpty;

  PosRxSummary? get activePrescription {
    for (final rx in activePrescriptions) {
      if (rx.id == activePrescriptionId) return rx;
    }
    return null;
  }

  PosWorkspaceState copyWith({
    bool? loading,
    bool? busy,
    String? errorMessage,
    bool clearError = false,
    String? searchQuery,
    PageResult<PosCatalogItem>? searchResults,
    List<PosCartLine>? cart,
    List<PosHeldBill>? heldBills,
    PosCustomer? customer,
    bool clearCustomer = false,
    List<PosRxSummary>? activePrescriptions,
    String? activePrescriptionId,
    bool clearPrescription = false,
    PosPaymentMethod? paymentMethod,
    int? cashReceivedMicros,
    int? cardReceivedMicros,
    bool? paymentOpen,
    PosSaleOutcome? lastSale,
    bool clearLastSale = false,
    PageResult<PosInvoiceView>? returnSearchResults,
    bool? returnLoading,
    String? returnedLinesNote,
    bool clearReturnNote = false,
    PosInvoiceView? selectedReturnInvoice,
    bool clearSelectedReturnInvoice = false,
    Map<String, int>? returnQuantityByLine,
  }) {
    return PosWorkspaceState(
      tabIndex: tabIndex,
      loading: loading ?? this.loading,
      busy: busy ?? this.busy,
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
      searchQuery: searchQuery ?? this.searchQuery,
      searchResults: searchResults ?? this.searchResults,
      cart: cart ?? this.cart,
      heldBills: heldBills ?? this.heldBills,
      customer: clearCustomer ? null : (customer ?? this.customer),
      activePrescriptions: activePrescriptions ?? this.activePrescriptions,
      activePrescriptionId: clearPrescription
          ? null
          : (activePrescriptionId ?? this.activePrescriptionId),
      paymentMethod: paymentMethod ?? this.paymentMethod,
      cashReceivedMicros: cashReceivedMicros ?? this.cashReceivedMicros,
      cardReceivedMicros: cardReceivedMicros ?? this.cardReceivedMicros,
      paymentOpen: paymentOpen ?? this.paymentOpen,
      lastSale: clearLastSale ? null : (lastSale ?? this.lastSale),
      returnSearchResults: returnSearchResults ?? this.returnSearchResults,
      returnLoading: returnLoading ?? this.returnLoading,
      returnedLinesNote:
          clearReturnNote ? null : (returnedLinesNote ?? this.returnedLinesNote),
      selectedReturnInvoice: clearSelectedReturnInvoice
          ? null
          : (selectedReturnInvoice ?? this.selectedReturnInvoice),
      returnQuantityByLine: returnQuantityByLine ?? this.returnQuantityByLine,
    );
  }
}