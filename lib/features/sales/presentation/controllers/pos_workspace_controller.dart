import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/data_grid/page_request.dart';
import '../../../../core/constants/permission_codes.dart';
import '../../../../core/errors/exceptions.dart';
import '../../../../core/util/ids.dart';
import '../../domain/entities/pos_cart.dart';
import '../../domain/entities/pos_catalog_item.dart';
import '../../domain/entities/pos_customer.dart';
import '../../domain/entities/pos_invoice.dart';
import '../../domain/entities/pos_hold.dart';
import '../../domain/repositories/sales_repository.dart';
import '../../domain/usecases/payment_calculator.dart';
import '../../domain/usecases/pos_cart_totals.dart';
import 'pos_workspace_state.dart';

/// Per-tab POS workspace controller (§5 customer tabs — independent Riverpod
/// state per tab). All business rules are enforced here (application layer);
/// the presentation only renders.
class PosWorkspaceController extends StateNotifier<PosWorkspaceState> {
  PosWorkspaceController({
    required int tabIndex,
    required this._repository,
    PosCartTotalsBuilder? totalsBuilder,
    PaymentCalculator? paymentCalculator,
  })  : _totalsBuilder = totalsBuilder ?? const PosCartTotalsBuilder(),
        _paymentCalculator = paymentCalculator ?? const PaymentCalculator(),
        super(PosWorkspaceState(tabIndex: tabIndex));

  final SalesRepository _repository;
  final PosCartTotalsBuilder _totalsBuilder;
  final PaymentCalculator _paymentCalculator;

  static const _pageSize = 40;

  /// Read-only snapshot for external (presentation-layer) reads; using `state`
  /// directly trips the StateNotifier "visible for testing" lints.
  PosWorkspaceState get currentState => state;

  // ── Search / scan ─────────────────────────────────────────────────────

  Future<void> search(String query) async {
    final q = query.trim();
    state = state.copyWith(
      searchQuery: q,
      loading: true,
      clearError: true,
    );
    try {
      final results = q.isEmpty
          ? null
          : await _repository.searchCatalog(
              PageRequest(page: 1, pageSize: _pageSize, search: q),
              inStockOnly: true,
            );
      state = state.copyWith(searchResults: results, loading: false);
    } on AppException catch (e) {
      state = state.copyWith(
        loading: false,
        errorMessage: e.failure.message,
      );
    }
  }

  /// Central scan entrypoint: receives completed barcode codes only (the
  /// [BarcodeBuffer] decides when a scan is complete).
  Future<void> handleScannedBarcode(String code) async {
    if (code.trim().isEmpty) return;
    try {
      final item = await _repository.itemByBarcode(code);
      if (item == null) {
        state = state.copyWith(
          errorMessage: 'تعذر العثور على المنتج: $code',
        );
        await _suggestLostSale(code);
        return;
      }
      await addToCart(item, quantity: 1);
    } on AppException catch (e) {
      state = state.copyWith(errorMessage: e.failure.message);
    }
  }

  Future<void> _suggestLostSale(String barcode) async {
    // The UI prompts the cashier; state holds the suggestion so the "capture"
    // flow can prefill the product name.
    state = state.copyWith(errorMessage: null, searchQuery: barcode);
  }

  // ── Cart ──────────────────────────────────────────────────────────────

  Future<void> addToCart(
    PosCatalogItem item, {
    int quantity = 1,
    PosLineUnitMode? unitMode,
  }) async {
    if (quantity <= 0) {
      state = state.copyWith(errorMessage: 'الكمية يجب أن تكون أكبر من صفر');
      return;
    }

    String? rxItemId;
    int? rxRemaining;
    if (item.requiresPrescription || item.isControlledDrug) {
      final rx = state.activePrescription;
      PosRxItemSummary? match;
      if (rx != null) {
        for (final it in rx.items) {
          if (it.itemId == item.id && it.remainingBase > 0) {
            match = it;
            break;
          }
        }
      }
      if (match == null) {
        state = state.copyWith(
          errorMessage:
              '${item.tradeName} يتطلب ارتباطاً بوصفة طبية نشطة (أدوية مقيّدة)',
        );
        return;
      }
      rxItemId = match.id;
      rxRemaining = match.remainingBase;
    }

    final mode = unitMode ?? _defaultMode(item);
    final line = PosCartLine(
      item: item,
      quantity: quantity,
      unitMode: mode,
      prescriptionItemId: rxItemId,
      rxRemainingBase: rxRemaining,
    );

    final quantityBase = _cartValidator().baseUnitsFor(line, quantity);
    _requireEnoughStock(item, quantityBase);
    if (rxItemId != null) {
      requireWithinRxRemaining(
        item: item,
        quantityBase: quantityBase,
        rxRemainingBase: rxRemaining!,
      );
    }

    final cart = List<PosCartLine>.from(state.cart);
    final index = cart.indexWhere((l) => l.cartKey == line.cartKey);
    if (index >= 0) {
      final merged = cart[index].copyWith(
        quantity: cart[index].quantity + quantity,
      );
      final mergedQtyBase = _cartValidator()
          .baseUnitsFor(merged, merged.quantity);
      _requireEnoughStock(item, mergedQtyBase);
      cart[index] = merged;
    } else {
      cart.add(line);
    }
    state = state.copyWith(
      cart: cart,
      paymentOpen: false,
      clearError: true,
    );
  }

  Future<void> updateQuantity(int index, int newQuantity) async {
    if (index < 0 || index >= state.cart.length) return;
    if (newQuantity <= 0) {
      await removeLine(index);
      return;
    }
    final line = state.cart[index];
    final updated = line.copyWith(quantity: newQuantity);
    final quantityBase = _cartValidator().baseUnitsFor(updated, newQuantity);
    try {
      _requireEnoughStock(line.item, quantityBase);
      if (line.rxRemainingBase != null) {
        requireWithinRxRemaining(
          item: line.item,
          quantityBase: quantityBase,
          rxRemainingBase: line.rxRemainingBase!,
        );
      }
    } on AppException catch (e) {
      state = state.copyWith(errorMessage: e.failure.message);
      return;
    }
    final cart = List<PosCartLine>.from(state.cart)..[index] = updated;
    state = state.copyWith(cart: cart, clearError: true);
  }

  Future<void> removeLine(int index) async {
    if (index < 0 || index >= state.cart.length) return;
    final cart = List<PosCartLine>.from(state.cart)..removeAt(index);
    state = state.copyWith(cart: cart, clearError: true);
  }

  void clearCart() => state = state.copyWith(cart: const [], clearError: true);

  /// F2 — toggle a line between box and fraction (sellable part or base unit).
  void toggleUnitMode(int index) {
    if (index < 0 || index >= state.cart.length) return;
    final line = state.cart[index];
    final nextMode = switch (line.unitMode) {
      PosLineUnitMode.largeUnit =>
        line.item.partialSaleConfigured
            ? PosLineUnitMode.sellablePart
            : PosLineUnitMode.baseUnit,
      PosLineUnitMode.sellablePart => PosLineUnitMode.largeUnit,
      PosLineUnitMode.baseUnit => PosLineUnitMode.largeUnit,
    };
    final cart = List<PosCartLine>.from(state.cart);
    cart[index] = line.copyWith(unitMode: nextMode);
    state = state.copyWith(cart: cart, clearError: true);
  }

  /// Authorized price override (`change_prices` gated in the application
  /// layer) — per-base override replacing the master-derived price.
  void setPriceOverride(
    int index, {
    required int? overrideMicros,
    required Set<String> permissions,
  }) {
    if (index < 0 || index >= state.cart.length) return;
    if (overrideMicros != null && !permissions.contains('change_prices')) {
      state = state.copyWith(errorMessage: 'غير مصرح لك بتغيير أسعار البيع');
      return;
    }
    final cart = List<PosCartLine>.from(state.cart);
    cart[index] = cart[index].copyWith(priceOverrideMicros: overrideMicros);
    state = state.copyWith(cart: cart, clearError: true);
  }

  // ── Customer / prescription ───────────────────────────────────────────

  Future<void> selectCustomer(PosCustomer customer) async {
    state = state.copyWith(
      customer: customer,
      clearPrescription: true,
      loading: true,
      clearError: true,
    );
    try {
      final rx = await _repository.activePrescriptionsForCustomer(customer.id);
      state = state.copyWith(activePrescriptions: rx, loading: false);
    } on AppException catch (e) {
      state = state.copyWith(
        loading: false,
        activePrescriptions: const [],
        errorMessage: e.failure.message,
      );
    }
  }

  void clearCustomer() => state = state.copyWith(
        clearCustomer: true,
        clearPrescription: true,
        activePrescriptions: const [],
        clearError: true,
      );

  void selectPrescription(String prescriptionId) {
    state = state.copyWith(
      activePrescriptionId: prescriptionId,
      clearError: true,
    );
  }

  void clearPrescription() =>
      state = state.copyWith(clearPrescription: true, clearError: true);

  /// When an Rx is active, syncs cart lines' Rx-link against remaining
  /// quantities (call after checkout/dispense so already-dispensed lines
  /// cease to count).
  Future<void> refreshPrescription() async {
    final rxId = state.activePrescriptionId;
    if (rxId == null) return;
    try {
      final rxList = await _repository.activePrescriptionsForCustomer(
        state.customer?.id ?? '',
      );
      PosRxSummary? rx;
      for (final r in rxList) {
        if (r.id == rxId) {
          rx = r;
          break;
        }
      }
      state = state.copyWith(activePrescriptions: rxList);
      if (rx == null) {
        state = state.copyWith(clearPrescription: true);
      }
    } on AppException catch (e) {
      state = state.copyWith(errorMessage: e.failure.message);
    }
  }

  // ── Hold bill (F5) ────────────────────────────────────────────────────

  void holdBill() {
    if (state.cart.isEmpty) return;
    final held = PosHeldBill(
      id: newId('hold'),
      label: 'سلة محفوظة ${state.heldBills.length + 1}',
      customerId: state.customer?.id,
      customerName: state.customer?.name,
      prescriptionId: state.activePrescriptionId,
      cart: List<PosCartLine>.from(state.cart),
      heldAtMillis: DateTime.now().millisecondsSinceEpoch,
    );
    state = state.copyWith(
      heldBills: [...state.heldBills, held],
      cart: const [],
      clearPrescription: true,
      clearError: true,
    );
  }

  void restoreHeldBill(int index) {
    if (index < 0 || index >= state.heldBills.length) return;
    final holder = List<PosHeldBill>.from(state.heldBills);
    final bill = holder.removeAt(index);
    final rxStillActive = state.activePrescriptions
        .any((r) => r.id == (bill.prescriptionId ?? ''));
    state = state.copyWith(
      heldBills: holder,
      cart: List<PosCartLine>.from(bill.cart),
      activePrescriptionId: rxStillActive ? bill.prescriptionId : null,
      clearError: true,
    );
  }

  void deleteHeldBill(int index) {
    if (index < 0 || index >= state.heldBills.length) return;
    final holder = List<PosHeldBill>.from(state.heldBills)..removeAt(index);
    state = state.copyWith(heldBills: holder, clearError: true);
  }

  // ── Payment / checkout (F12) ──────────────────────────────────────────

  void openPayment() {
    if (state.cart.isEmpty) {
      state = state.copyWith(errorMessage: 'أضف أصنافاً قبل الدفع');
      return;
    }
    state = state.copyWith(paymentOpen: true, clearError: true);
  }

  void updatePaymentInputs({
    PosPaymentMethod? method,
    int? cashReceivedMicros,
    int? cardReceivedMicros,
  }) {
    state = state.copyWith(
      paymentMethod: method ?? state.paymentMethod,
      cashReceivedMicros: cashReceivedMicros ?? state.cashReceivedMicros,
      cardReceivedMicros: cardReceivedMicros ?? state.cardReceivedMicros,
    );
  }

  Future<PosSaleOutcome?> checkout({
    required String actingUserId,
    required Set<String> permissions,
  }) async {
    if (!permissions.contains(Perm.sell)) {
      state = state.copyWith(errorMessage: 'غير مصرح لك بالبيع');
      return null;
    }
    if (state.cart.isEmpty) {
      state = state.copyWith(errorMessage: 'سلة البيع فارغة');
      return null;
    }
    try {
      final totals = _totalsBuilder.totals(state.cart);
      final payment = _paymentCalculator.calculate(
        totalMicros: totals.totalMicros,
        method: state.paymentMethod,
        cashReceivedMicros: state.cashReceivedMicros,
        cardAmountMicros: state.cardReceivedMicros,
      );
      if (!payment.isValid) {
        state = state.copyWith(errorMessage: payment.error);
        return null;
      }

      final lines = _totalsBuilder.flatten(state.cart);
      final rxId = state.activePrescription?.id;
      final invoiceNumber = await _repository.nextInvoiceNumber();

      // Payment split: for cash the received amount (incl. overpayment) is the
      // cash component; card settles the paid amount on Bank; mixed keeps the
      // two entered components (drawerNet = cash − change in the engine).
      final (int?, int?) split = switch (state.paymentMethod) {
        PosPaymentMethod.cash => (payment.paidMicros, 0),
        PosPaymentMethod.card => (0, payment.paidMicros),
        PosPaymentMethod.mixed => (
            state.cashReceivedMicros,
            state.cardReceivedMicros,
          ),
      };

      final outcome = await _repository.checkout(PosCheckoutCommand(
        invoiceNumber: invoiceNumber,
        lines: lines,
        paymentMethod: state.paymentMethod,
        paidMicros: payment.paidMicros,
        userId: actingUserId,
        customerId: state.customer?.id,
        cashMicros: split.$1,
        cardMicros: split.$2,
        prescriptionId: rxId,
        notes: rxId != null ? 'صرف من وصفة $rxId' : null,
      ));

      state = state.copyWith(
        lastSale: outcome,
        cart: const [],
        paymentOpen: false,
        clearPrescription: true,
        clearError: true,
      );
      return outcome;
    } on AppException catch (e) {
      state = state.copyWith(paymentOpen: true, errorMessage: e.failure.message);
      return null;
    } catch (e) {
      state = state.copyWith(
        paymentOpen: true,
        errorMessage: 'فشل إتمام البيع: $e',
      );
      return null;
    }
  }

  void dismissLastSale() => state = state.copyWith(clearLastSale: true);

  // ── Return tab ────────────────────────────────────────────────────────

  Future<void> searchReturnInvoices(String query) async {
    state = state.copyWith(
      returnLoading: true,
      clearError: true,
      selectedReturnInvoice: null,
      returnQuantityByLine: const {},
    );
    try {
      final results = await _repository.searchSaleInvoices(
        PageRequest(page: 1, pageSize: 20, search: query),
      );
      state = state.copyWith(returnSearchResults: results, returnLoading: false);
    } on AppException catch (e) {
      state = state.copyWith(
        returnLoading: false,
        errorMessage: e.failure.message,
      );
    }
  }

  void selectReturnInvoice(PosInvoiceView invoice) {
    state = state.copyWith(
      selectedReturnInvoice: invoice,
      returnQuantityByLine: const {},
      clearReturnNote: true,
      clearError: true,
    );
  }

  void setReturnLineQty(String lineId, int qty) {
    final qtyByLine = Map<String, int>.from(state.returnQuantityByLine)
      ..[lineId] = qty.clamp(0, 1000000);
    state = state.copyWith(returnQuantityByLine: qtyByLine);
  }

  Future<bool> submitReturn({
    required String actingUserId,
    required Set<String> permissions,
    String? reason,
  }) async {
    if (!permissions.contains(Perm.salesReturnCreate) &&
        !permissions.contains(Perm.returnProducts)) {
      state = state.copyWith(errorMessage: 'غير مصرح لك بإنشاء المرتجعات');
      return false;
    }
    final invoice = state.selectedReturnInvoice;
    if (invoice == null) return false;
    var anySuccess = false;
    for (final line in invoice.lines) {
      final qty = state.returnQuantityByLine[line.id] ?? 0;
      if (qty <= 0) continue;
      final ok = await returnLine(
        line: line,
        quantityBase: qty,
        actingUserId: actingUserId,
        permissions: permissions,
        reason: reason,
      );
      anySuccess = anySuccess || ok;
    }
    if (anySuccess) await refreshReturnInvoice();
    return anySuccess;
  }

  Future<void> refreshReturnInvoice() async {
    final invoice = state.selectedReturnInvoice;
    if (invoice == null) return;
    final fresh = await _repository.invoiceViewById(invoice.id);
    state = state.copyWith(
      selectedReturnInvoice: fresh,
      clearReturnNote: fresh == null,
      clearError: true,
    );
  }

  Future<bool> returnLine({
    required PosInvoiceLineView line,
    required int quantityBase,
    required String actingUserId,
    required Set<String> permissions,
    String? reason,
  }) async {
    if (!permissions.contains(Perm.salesReturnCreate) &&
        !permissions.contains(Perm.returnProducts)) {
      state = state.copyWith(errorMessage: 'غير مصرح لك بإنشاء المرتجعات');
      return false;
    }
    try {
      final outcome = await _repository.returnSaleLine(PosReturnCommand(
        returnNumber: await _repository.nextReturnNumber(),
        originalInvoiceItemId: line.id,
        quantityBase: quantityBase,
        userId: actingUserId,
        reason: reason,
        notes: 'مرتجع من نقطة البيع',
      ));
      state = state.copyWith(
        returnedLinesNote:
            'تم إرجاع ${outcome.restoredQuantityBase} وحدة وإعادتها للدفعة الأصلية',
        clearError: true,
      );
      // Refresh the return panel results so over-return is impossible.
      await searchReturnInvoices(state.searchQuery);
      return true;
    } on AppException catch (e) {
      state = state.copyWith(errorMessage: e.failure.message);
      return false;
    }
  }

  /// Voids a completed, never-returned invoice (§19). Requires `sales.void` and
  /// a reason; the engine reverses stock, drawer, journal, prescription and the
  /// customer balance atomically.
  Future<bool> voidInvoice({
    required PosInvoiceView invoice,
    required String actingUserId,
    required Set<String> permissions,
    required String reason,
  }) async {
    if (reason.trim().isEmpty) {
      state = state.copyWith(errorMessage: 'سبب الإلغاء مطلوب');
      return false;
    }
    try {
      await _repository.voidInvoice(
        invoice.id,
        userId: actingUserId,
        reason: reason,
      );
      state = state.copyWith(
        returnedLinesNote: 'تم إلغاء الفاتورة ${invoice.invoiceNumber}',
        selectedReturnInvoice: null,
        clearError: true,
      );
      await searchReturnInvoices(state.searchQuery);
      return true;
    } on AppException catch (e) {
      state = state.copyWith(errorMessage: e.failure.message);
      return false;
    } catch (e) {
      state = state.copyWith(errorMessage: 'فشل إلغاء الفاتورة: $e');
      return false;
    }
  }

  Future<bool> captureLostSale({
    required String productName,
    required int quantity,
    required String actingUserId,
    required Set<String> permissions,
    String? barcode,
    String? scientificName,
    String? note,
  }) async {
    if (!permissions.contains(Perm.lostSalesCreate) &&
        !permissions.contains(Perm.salesCreate)) {
      state = state.copyWith(errorMessage: 'غير مصرح لك بتسجيل النواقص');
      return false;
    }
    try {
      await _repository.recordLostSale(PosLostSaleDraft(
        requestedItemName: productName.trim().isEmpty ? barcode ?? 'منتج غير معروف' : productName.trim(),
        quantityRequested: quantity,
        userId: actingUserId,
        barcode: barcode,
        scientificName:
            (scientificName == null || scientificName.trim().isEmpty)
                ? null
                : scientificName.trim(),
        customerName: state.customer?.name,
        customerPhone: state.customer?.phone,
        note:
            (note == null || note.trim().isEmpty)
                ? 'سجل من نقطة البيع (مسح لم يُعثر عليه)'
                : note.trim(),
      ));
      state = state.copyWith(
        searchQuery: '',
        returnSearchResults: null,
        clearError: true,
      );
      return true;
    } on AppException catch (e) {
      state = state.copyWith(errorMessage: e.failure.message);
      return false;
    }
  }

  // ── Shared helpers ────────────────────────────────────────────────────

  PosCartValidator _cartValidator() => const PosCartValidator();

  void _requireEnoughStock(PosCatalogItem item, int quantityBase) {
    const validator = PosCartValidator();
    validator.requireActiveItem(item);
    validator.requireEnoughStock(item: item, quantityBase: quantityBase);
  }

  void requireWithinRxRemaining({
    required PosCatalogItem item,
    required int quantityBase,
    required int rxRemainingBase,
  }) {
    const validator = PosCartValidator();
    validator.requireWithinRxRemaining(
      item: item,
      quantityBase: quantityBase,
      rxRemainingBase: rxRemainingBase,
    );
  }

  PosLineUnitMode _defaultMode(PosCatalogItem item) =>
      item.partialSaleConfigured
          ? PosLineUnitMode.sellablePart
          : PosLineUnitMode.largeUnit;

  PosCartTotals get totals => _totalsBuilder.totals(state.cart);

  void clearError() => state = state.copyWith(clearError: true);
}