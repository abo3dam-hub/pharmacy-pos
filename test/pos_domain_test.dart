import 'package:flutter_test/flutter_test.dart';
import 'package:pharmacy_pos/core/constants/permission_codes.dart';
import 'package:pharmacy_pos/core/data_grid/page_request.dart';
import 'package:pharmacy_pos/core/errors/exceptions.dart';
import 'package:pharmacy_pos/core/shortcuts/barcode_buffer.dart';
import 'package:pharmacy_pos/features/sales/domain/entities/pos_cart.dart';
import 'package:pharmacy_pos/features/sales/domain/entities/pos_catalog_item.dart';
import 'package:pharmacy_pos/features/sales/domain/entities/pos_customer.dart';
import 'package:pharmacy_pos/features/sales/domain/entities/pos_invoice.dart';
import 'package:pharmacy_pos/features/sales/domain/repositories/sales_repository.dart';
import 'package:pharmacy_pos/features/sales/domain/usecases/payment_calculator.dart';
import 'package:pharmacy_pos/features/sales/domain/usecases/pos_pricing.dart';
import 'package:pharmacy_pos/features/sales/presentation/controllers/pos_workspace_controller.dart';
import 'package:pharmacy_pos/shared/models/enums.dart';

// ── Catalog item fixtures ───────────────────────────────────────────────

/// Partial-sale box item: $10/box, 100 base units/box, 10 sellable parts/box,
/// 10 base units/part, +10% partial markup.
PosCatalogItem _makePartialItem() => const PosCatalogItem(
      id: 'item_partial',
      tradeName: 'بانادول',
      tradeNameEn: 'Panadol',
      scientificName: 'Paracetamol',
      activeIngredient: 'Paracetamol',
      therapeuticGroupId: 'tg_1',
      primaryBarcode: '6291041500213',
      isOtc: true,
      isControlledDrug: false,
      requiresPrescription: false,
      isActive: true,
      sellingPriceMicros: 100000,
      vatRateBasisPoints: 1000,
      currentStockBase: 300,
      availableStockBase: 300,
      baseUnitId: 'unit_base',
      baseUnitName: 'حبة',
      largeUnitId: 'unit_box',
      largeUnitName: 'علبة',
      unitsPerLarge: 100,
      partialSaleEnabled: true,
      sellablePartUnitId: 'unit_strip',
      sellablePartUnitName: 'شرائط',
      partsPerFullProduct: 10,
      sellablePartBaseQuantity: 10,
      partialSaleMarkupBasisPoints: 1000,
    );

/// Non-partial OTC item: $5/box, 1 base/box, no fractions.
PosCatalogItem _makeOtcItem() => const PosCatalogItem(
      id: 'item_otc',
      tradeName: 'فيتامين سي',
      tradeNameEn: 'Vitamin C',
      scientificName: 'Ascorbic acid',
      primaryBarcode: '1111111111111',
      isOtc: true,
      isControlledDrug: false,
      requiresPrescription: false,
      isActive: true,
      sellingPriceMicros: 50000,
      vatRateBasisPoints: 1000,
      currentStockBase: 50,
      availableStockBase: 50,
      baseUnitId: 'unit_base',
      baseUnitName: 'قطعة',
      largeUnitId: 'unit_box',
      largeUnitName: 'علبة',
      unitsPerLarge: 1,
      partialSaleEnabled: false,
    );

/// Restricted item (requires prescription).
PosCatalogItem _makeRxItem() => const PosCatalogItem(
      id: 'item_rx',
      tradeName: 'كورتيزون',
      scientificName: 'Cortisone',
      isOtc: false,
      isControlledDrug: false,
      requiresPrescription: true,
      isActive: true,
      sellingPriceMicros: 30000,
      vatRateBasisPoints: 1000,
      currentStockBase: 100,
      availableStockBase: 100,
      baseUnitId: 'unit_base',
      baseUnitName: 'قطعة',
      largeUnitId: 'unit_box',
      largeUnitName: 'علبة',
      unitsPerLarge: 1,
      partialSaleEnabled: false,
    );

// ── _FakeSalesRepository ────────────────────────────────────────────────

class _FakeSalesRepository implements SalesRepository {
  _FakeSalesRepository({Map<String, PosCatalogItem>? items})
      : _items = items ?? {};

  final Map<String, PosCatalogItem> _items;
  PosCheckoutCommand? lastCheckout;
  PosSaleOutcome? checkoutOutcome;
  List<PosRxSummary> rxForCustomer = const [];

  @override
  Future<PageResult<PosCatalogItem>> searchCatalog(
    PageRequest request, {
    bool? inStockOnly,
  }) async {
    final q = request.search.trim().toLowerCase();
    var results = _items.values
        .where((i) =>
            q.isEmpty || i.tradeName.toLowerCase().contains(q))
        .toList();
    if (inStockOnly == true) {
      results = results.where((i) => i.availableStockBase > 0).toList();
    }
    return PageResult(items: results, total: results.length, request: request);
  }

  @override
  Future<PosCatalogItem?> itemByBarcode(String barcode) async {
    for (final i in _items.values) {
      if (i.primaryBarcode == barcode) return i;
    }
    return null;
  }

  @override
  Future<PosCatalogItem?> itemById(String id) async => _items[id];

  @override
  Future<List<PosCustomer>> findCustomers(String query,
      {int limit = 20}) async =>
      const [];

  @override
  Future<List<PosRxSummary>> activePrescriptionsForCustomer(
          String customerId) async =>
      rxForCustomer;

  @override
  Future<String> nextInvoiceNumber() async => 'SI-TEST';

  @override
  Future<String> nextReturnNumber() async => 'RT-TEST';

  @override
  Future<PosSaleOutcome> checkout(PosCheckoutCommand command) async {
    lastCheckout = command;
    if (checkoutOutcome != null) return checkoutOutcome!;
    final inv = PosInvoiceView(
      id: 'inv_test',
      invoiceNumber: 'SI-TEST',
      invoiceType: InvoiceType.sale,
      saleStatus: SaleStatus.completed,
      paymentMethod: PaymentMethod.cash,
      customerId: command.customerId,
      customerName: '',
      userId: command.userId,
      subtotalMicros: 100000,
      discountTotalMicros: 0,
      vatTotalMicros: 10000,
      totalMicros: 110000,
      totalCostMicros: 0,
      profitMicros: 0,
      paidMicros: command.paidMicros,
      changeMicros: 0,
      cashMicros: command.cashMicros ?? command.paidMicros,
      cardMicros: command.cardMicros ?? 0,
      creditMicros: 0,
      createdAt: DateTime.now().millisecondsSinceEpoch,
      lines: const [],
    );
    return PosSaleOutcome(invoice: inv, lines: const [], movements: 0);
  }

  @override
  Future<void> voidInvoice(
    String invoiceId, {
    required String userId,
    required String reason,
  }) async {}

  @override
  Future<PosReturnOutcome> returnSaleLine(PosReturnCommand command) async =>
      PosReturnOutcome(
        returnId: 'ret_test',
        returnNumber: 'RT-TEST',
        reversalMicros: 0,
        restoredQuantityBase: command.quantityBase,
      );

  @override
  Future<PageResult<PosInvoiceView>> searchSaleInvoices(
          PageRequest request) async =>
      PageResult(items: const [], total: 0, request: request);

  @override
  Future<PosInvoiceView?> invoiceViewById(String invoiceId) async => null;

  @override
  Future<List<PosCatalogItem>> smartAlternatives(PosCatalogItem item) async =>
      const [];

  @override
  Future<void> recordLostSale(PosLostSaleDraft draft) async {}

  @override
  Future<int> availableStock(String itemId) async => 0;
}

PosWorkspaceController _controller(_FakeSalesRepository fake) =>
    PosWorkspaceController(tabIndex: 0, repository: fake);

void main() {
  group('PosLinePricer', () {
    const pricer = PosLinePricer();

    test('13 strips = 1 box + 3 strips, total = \$13.30 (133000 μ), baseQty 130',
        () {
      final p = pricer.priceLine(PosCartLine(
        item: _makePartialItem(),
        quantity: 13,
        unitMode: PosLineUnitMode.sellablePart,
      ));
      expect(p.grossMicros, 133000);
      expect(p.quantityBase, 130);
      expect(p.lines, hasLength(2));
    });

    test('10 strips = 1 full box, no markup, total \$10 (100000 μ), baseQty 100',
        () {
      final p = pricer.priceLine(PosCartLine(
        item: _makePartialItem(),
        quantity: 10,
        unitMode: PosLineUnitMode.sellablePart,
      ));
      expect(p.grossMicros, 100000);
      expect(p.quantityBase, 100);
      expect(p.lines, hasLength(1));
    });

    test('3 strips only, total \$3.30 (33000 μ), baseQty 30', () {
      final p = pricer.priceLine(PosCartLine(
        item: _makePartialItem(),
        quantity: 3,
        unitMode: PosLineUnitMode.sellablePart,
      ));
      expect(p.grossMicros, 33000);
      expect(p.quantityBase, 30);
    });

    test('single strip = \$1.10 (11000 μ), baseQty 10', () {
      final p = pricer.priceLine(PosCartLine(
        item: _makePartialItem(),
        quantity: 1,
        unitMode: PosLineUnitMode.sellablePart,
      ));
      expect(p.grossMicros, 11000);
      expect(p.quantityBase, 10);
      expect(pricer.partialSellingPricePerPart(_makePartialItem()), 11000);
    });

    test('box mode 2 boxes = \$20 (200000 μ), baseQty 200, no markup', () {
      final p = pricer.priceLine(PosCartLine(
        item: _makePartialItem(),
        quantity: 2,
        unitMode: PosLineUnitMode.largeUnit,
      ));
      expect(p.grossMicros, 200000);
      expect(p.quantityBase, 200);
    });

    test('non-partial item: base mode 5 units, box mode 2 boxes', () {
      final base = pricer.priceLine(PosCartLine(
        item: _makeOtcItem(),
        quantity: 5,
        unitMode: PosLineUnitMode.baseUnit,
      ));
      expect(base.grossMicros, 250000);
      expect(base.quantityBase, 5);

      final box = pricer.priceLine(PosCartLine(
        item: _makeOtcItem(),
        quantity: 2,
        unitMode: PosLineUnitMode.largeUnit,
      ));
      expect(box.grossMicros, 100000);
      expect(box.quantityBase, 2);
    });

    test('VAT 10% on gross: 1 box → vat = 10000', () {
      final p = pricer.priceLine(PosCartLine(
        item: _makePartialItem(),
        quantity: 1,
        unitMode: PosLineUnitMode.largeUnit,
      ));
      expect(p.grossMicros, 100000);
      expect(p.vatMicros, 10000);
      expect(p.netMicros, 100000);
    });

    test('line discount 5% on gross: 1 box → discount = 5000', () {
      final p = pricer.priceLine(PosCartLine(
        item: _makePartialItem(),
        quantity: 1,
        unitMode: PosLineUnitMode.largeUnit,
        discountBasisPoints: 500,
      ));
      expect(p.grossMicros, 100000);
      expect(p.discountMicros, 5000);
      expect(p.netMicros, 95000);
    });
  });

  group('PosCartValidator', () {
    const v = PosCartValidator();

    test('baseUnitsFor largeUnit: qty * unitsPerLarge', () {
      final line = PosCartLine(
        item: _makePartialItem(),
        quantity: 3,
        unitMode: PosLineUnitMode.largeUnit,
      );
      expect(v.baseUnitsFor(line, 3), 300);
    });

    test('baseUnitsFor baseUnit: qty directly', () {
      final line = PosCartLine(
        item: _makePartialItem(),
        quantity: 7,
        unitMode: PosLineUnitMode.baseUnit,
      );
      expect(v.baseUnitsFor(line, 7), 7);
    });

    test('baseUnitsFor sellablePart: qty * sellablePartBaseQuantity', () {
      final line = PosCartLine(
        item: _makePartialItem(),
        quantity: 4,
        unitMode: PosLineUnitMode.sellablePart,
      );
      expect(v.baseUnitsFor(line, 4), 40);
    });

    test('requirePositiveQuantity(0) throws ValidationException', () {
      expect(() => v.requirePositiveQuantity(0),
          throwsA(isA<ValidationException>()));
    });

    test('requireRxForRestrictedItem: restricted item without rx throws', () {
      expect(() => v.requireRxForRestrictedItem(_makeRxItem(), null),
          throwsA(isA<ValidationException>()));
    });

    test('requireRxForRestrictedItem: OTC item without rx OK', () {
      expect(() => v.requireRxForRestrictedItem(_makeOtcItem(), null),
          returnsNormally);
    });

    test('requireEnoughStock: qty > available throws', () {
      expect(
        () => v.requireEnoughStock(
          item: _makeOtcItem(),
          quantityBase: 5000,
        ),
        throwsA(isA<ValidationException>()),
      );
    });

    test('requireWithinRxRemaining: qty > rxRemaining throws', () {
      expect(
        () => v.requireWithinRxRemaining(
          item: _makeRxItem(),
          quantityBase: 30,
          rxRemainingBase: 20,
        ),
        throwsA(isA<ValidationException>()),
      );
    });
  });

  group('PaymentCalculator', () {
    const pc = PaymentCalculator();

    test('cash exact: paid=total, change=0', () {
      final r = pc.calculate(
        totalMicros: 100000,
        method: PosPaymentMethod.cash,
        cashReceivedMicros: 100000,
      );
      expect(r.isValid, isTrue);
      expect(r.paidMicros, 100000);
      expect(r.changeMicros, 0);
      expect(r.fullyPaid, isTrue);
    });

    test('cash over: paid>total, change = paid - total', () {
      final r = pc.calculate(
        totalMicros: 100000,
        method: PosPaymentMethod.cash,
        cashReceivedMicros: 150000,
      );
      expect(r.isValid, isTrue);
      expect(r.changeMicros, 50000);
    });

    test('cash under: paid<total, error set, remaining = total - paid', () {
      final r = pc.calculate(
        totalMicros: 100000,
        method: PosPaymentMethod.cash,
        cashReceivedMicros: 50000,
      );
      expect(r.isValid, isFalse);
      expect(r.error, isNotNull);
      expect(r.remainingMicros, 50000);
    });

    test('card exact: card == total, valid', () {
      final r = pc.calculate(
        totalMicros: 100000,
        method: PosPaymentMethod.card,
        cardAmountMicros: 100000,
      );
      expect(r.isValid, isTrue);
      expect(r.changeMicros, 0);
    });

    test('card mismatch: card != total, error', () {
      final r = pc.calculate(
        totalMicros: 100000,
        method: PosPaymentMethod.card,
        cardAmountMicros: 90000,
      );
      expect(r.isValid, isFalse);
      expect(r.error, isNotNull);
    });

    test('mixed exact: cash+card == total, valid, change=0', () {
      final r = pc.calculate(
        totalMicros: 100000,
        method: PosPaymentMethod.mixed,
        cashReceivedMicros: 60000,
        cardAmountMicros: 40000,
      );
      expect(r.isValid, isTrue);
      expect(r.paidMicros, 100000);
      expect(r.changeMicros, 0);
    });

    test('mixed cash only (card=0): error "أدخل مبلغين"', () {
      final r = pc.calculate(
        totalMicros: 100000,
        method: PosPaymentMethod.mixed,
        cashReceivedMicros: 0,
        cardAmountMicros: 0,
      );
      expect(r.isValid, isFalse);
      expect(r.error, contains('أدخل مبلغين'));
    });

    test('mixed under total: error, remaining', () {
      final r = pc.calculate(
        totalMicros: 100000,
        method: PosPaymentMethod.mixed,
        cashReceivedMicros: 30000,
        cardAmountMicros: 30000,
      );
      expect(r.isValid, isFalse);
      expect(r.error, isNotNull);
      expect(r.remainingMicros, 40000);
    });

    test('negative total throws', () {
      expect(
        () => pc.calculate(
          totalMicros: -1,
          method: PosPaymentMethod.cash,
          cashReceivedMicros: 0,
        ),
        throwsA(isA<ValidationException>()),
      );
    });

    test('negative cash throws', () {
      expect(
        () => pc.calculate(
          totalMicros: 100,
          method: PosPaymentMethod.cash,
          cashReceivedMicros: -50,
        ),
        throwsA(isA<ValidationException>()),
      );
    });
  });

  group('BarcodeBuffer', () {
    test('full scan with terminator calls onBarcode', () {
      final buffer = BarcodeBuffer();
      String? emitted;
      buffer.onBarcode = (b) => emitted = b;
      buffer.feedString('6291041500213\n');
      expect(emitted, '6291041500213');
    });

    test('hasPartial returns true while accumulating', () {
      final buffer = BarcodeBuffer();
      expect(buffer.hasPartial, isFalse);
      buffer.feed('6');
      buffer.feed('2');
      expect(buffer.hasPartial, isTrue);
      expect(buffer.partial, '62');
    });

    test('prefix stripped', () {
      final buffer = BarcodeBuffer(prefix: '!');
      String? emitted;
      buffer.onBarcode = (b) => emitted = b;
      buffer.feedString('!6291041500213\n');
      expect(emitted, '6291041500213');
    });

    test('suffix stripped', () {
      final buffer = BarcodeBuffer(suffix: '-');
      String? emitted;
      buffer.onBarcode = (b) => emitted = b;
      buffer.feedString('6291041500213-\n');
      expect(emitted, '6291041500213');
    });

    test('reset clears partial', () {
      final buffer = BarcodeBuffer();
      buffer.feed('6');
      buffer.feed('2');
      buffer.reset();
      expect(buffer.hasPartial, isFalse);
      expect(buffer.partial, isEmpty);
    });

    test('maxLength overflow completes scan', () {
      final buffer = BarcodeBuffer(maxLength: 4);
      String? emitted;
      buffer.onBarcode = (b) => emitted = b;
      buffer.feedString('12345');
      expect(emitted, '12345');
    });

    test('empty code not emitted', () {
      final buffer = BarcodeBuffer();
      String? emitted;
      buffer.onBarcode = (b) => emitted = b;
      buffer.feed('\n');
      expect(emitted, isNull);
    });
  });

  group('PosWorkspaceController (with fake repo)', () {
    test('addToCart merges by cartKey (same item+mode)', () async {
      final ctrl = _controller(_FakeSalesRepository());
      await ctrl.addToCart(_makeOtcItem(), quantity: 2);
      await ctrl.addToCart(_makeOtcItem(), quantity: 3);
      expect(ctrl.currentState.cart, hasLength(1));
      expect(ctrl.currentState.cart.first.quantity, 5);
    });

    test('addToCart separate lines for box vs strip (different cartKeys)',
        () async {
      final ctrl = _controller(_FakeSalesRepository());
      final item = _makePartialItem();
      await ctrl.addToCart(item, quantity: 1, unitMode: PosLineUnitMode.largeUnit);
      await ctrl.addToCart(item, quantity: 2, unitMode: PosLineUnitMode.sellablePart);
      expect(ctrl.currentState.cart, hasLength(2));
    });

    test('addToCart restricted item without active rx → error, cart unchanged',
        () async {
      final ctrl = _controller(_FakeSalesRepository());
      await ctrl.addToCart(_makeRxItem(), quantity: 1);
      expect(ctrl.currentState.errorMessage, isNotNull);
      expect(ctrl.currentState.cart, isEmpty);
    });

    test('addToCart restricted item with matching rx → rxItemId linked',
        () async {
      final fake = _FakeSalesRepository();
      fake.rxForCustomer = const [
        PosRxSummary(
          id: 'rx1',
          prescriptionNumber: 'RX-1',
          patientName: 'مريض',
          statusName: 'active',
          createdAt: 0,
          items: [
            PosRxItemSummary(
              id: 'pi1',
              prescriptionId: 'rx1',
              itemId: 'item_rx',
              itemName: 'كورتيزون',
              quantityBase: 20,
              dispensedQuantityBase: 0,
            ),
          ],
        ),
      ];
      final ctrl = _controller(fake);
      await ctrl.selectCustomer(const PosCustomer(
        id: 'cus1',
        name: 'عميل',
        hasAccount: true,
        isActive: true,
        balanceMicros: 0,
      ));
      ctrl.selectPrescription('rx1');
      await ctrl.addToCart(_makeRxItem(), quantity: 1);
      expect(ctrl.currentState.cart, hasLength(1));
      expect(ctrl.currentState.cart.first.isRxLinked, isTrue);
      expect(ctrl.currentState.cart.first.prescriptionItemId, 'pi1');
    });

    test('addToCart blocked when qty > availableStock', () async {
      final fake = _FakeSalesRepository(items: {'item_otc': _makeOtcItem()});
      final ctrl = _controller(fake);
      await expectLater(
        ctrl.addToCart(_makeOtcItem(), quantity: 100),
        throwsA(isA<ValidationException>()),
      );
      expect(ctrl.currentState.cart, isEmpty);
    });

    test('updateQuantity: beyond stock → error, cart unchanged', () async {
      final ctrl = _controller(_FakeSalesRepository());
      await ctrl.addToCart(_makeOtcItem(), quantity: 49);
      await ctrl.updateQuantity(0, 100);
      expect(ctrl.currentState.errorMessage, isNotNull);
      expect(ctrl.currentState.cart.first.quantity, 49);
    });

    test('removeLine: removes by index', () async {
      final ctrl = _controller(_FakeSalesRepository());
      await ctrl.addToCart(_makeOtcItem(), quantity: 1);
      expect(ctrl.currentState.cart, hasLength(1));
      await ctrl.removeLine(0);
      expect(ctrl.currentState.cart, isEmpty);
    });

    test('toggleUnitMode cycles large→part→large for partial items', () async {
      final ctrl = _controller(_FakeSalesRepository());
      await ctrl.addToCart(_makePartialItem(),
          quantity: 1, unitMode: PosLineUnitMode.largeUnit);
      ctrl.toggleUnitMode(0);
      expect(ctrl.currentState.cart.first.unitMode, PosLineUnitMode.sellablePart);
      ctrl.toggleUnitMode(0);
      expect(ctrl.currentState.cart.first.unitMode, PosLineUnitMode.largeUnit);
    });

    test('toggleUnitMode cycles large→base→large for non-partial items',
        () async {
      final ctrl = _controller(_FakeSalesRepository());
      await ctrl.addToCart(_makeOtcItem(),
          quantity: 1, unitMode: PosLineUnitMode.largeUnit);
      ctrl.toggleUnitMode(0);
      expect(ctrl.currentState.cart.first.unitMode, PosLineUnitMode.baseUnit);
      ctrl.toggleUnitMode(0);
      expect(ctrl.currentState.cart.first.unitMode, PosLineUnitMode.largeUnit);
    });

    test('setPriceOverride without change_prices perm → error', () async {
      final ctrl = _controller(_FakeSalesRepository());
      await ctrl.addToCart(_makeOtcItem(), quantity: 1);
      ctrl.setPriceOverride(0,
          overrideMicros: 9999, permissions: {'some_other_perm'});
      expect(ctrl.currentState.errorMessage, isNotNull);
      expect(ctrl.currentState.cart.first.priceOverrideMicros, isNull);
    });

    test('setPriceOverride with perm → applied', () async {
      final ctrl = _controller(_FakeSalesRepository());
      await ctrl.addToCart(_makeOtcItem(), quantity: 1);
      ctrl.setPriceOverride(0,
          overrideMicros: 9999,
          permissions: {Perm.changePrices});
      expect(ctrl.currentState.cart.first.priceOverrideMicros, 9999);
    });

    test('checkout no sell perm → null, error, cart untouched', () async {
      final fake = _FakeSalesRepository();
      final ctrl = _controller(fake);
      await ctrl.addToCart(_makeOtcItem(), quantity: 1);
      final outcome = await ctrl.checkout(
        actingUserId: 'user_admin',
        permissions: const {'some_other_perm'},
      );
      expect(outcome, isNull);
      expect(ctrl.currentState.errorMessage, isNotNull);
      expect(ctrl.currentState.cart, hasLength(1));
      expect(fake.lastCheckout, isNull);
    });

    test('checkout with sell perm but insufficient payment → null, '
        'paymentOpen stays true', () async {
      final fake = _FakeSalesRepository();
      final ctrl = _controller(fake);
      await ctrl.addToCart(_makeOtcItem(), quantity: 5); // total 275000
      ctrl.openPayment();
      ctrl.updatePaymentInputs(
        method: PosPaymentMethod.cash,
        cashReceivedMicros: 100000,
      );
      final outcome = await ctrl.checkout(
        actingUserId: 'user_admin',
        permissions: {Perm.sell},
      );
      expect(outcome, isNull);
      expect(ctrl.currentState.errorMessage, isNotNull);
      expect(ctrl.currentState.paymentOpen, isTrue);
      expect(fake.lastCheckout, isNull);
    });

    test('checkout success → lastSale set, cart cleared', () async {
      final fake = _FakeSalesRepository();
      final ctrl = _controller(fake);
      await ctrl.addToCart(_makeOtcItem(), quantity: 5);
      final total = ctrl.totals.totalMicros;
      ctrl.openPayment();
      ctrl.updatePaymentInputs(
        method: PosPaymentMethod.cash,
        cashReceivedMicros: total,
      );
      final outcome = await ctrl.checkout(
        actingUserId: 'user_admin',
        permissions: {Perm.sell},
      );
      expect(outcome, isNotNull);
      expect(ctrl.currentState.lastSale, isNotNull);
      expect(ctrl.currentState.cart, isEmpty);
      expect(fake.lastCheckout, isNotNull);
      expect(fake.lastCheckout!.invoiceNumber, 'SI-TEST');
    });

    test('holdBill: cart moved to heldBills, cart cleared', () async {
      final ctrl = _controller(_FakeSalesRepository());
      await ctrl.addToCart(_makeOtcItem(), quantity: 1);
      ctrl.holdBill();
      expect(ctrl.currentState.cart, isEmpty);
      expect(ctrl.currentState.heldBills, hasLength(1));
    });

    test('restoreHeldBill: restored to cart', () async {
      final ctrl = _controller(_FakeSalesRepository());
      await ctrl.addToCart(_makeOtcItem(), quantity: 1);
      ctrl.holdBill();
      ctrl.restoreHeldBill(0);
      expect(ctrl.currentState.heldBills, isEmpty);
      expect(ctrl.currentState.cart, hasLength(1));
      expect(ctrl.currentState.cart.first.quantity, 1);
    });

    test('deleteHeldBill: removed', () async {
      final ctrl = _controller(_FakeSalesRepository());
      await ctrl.addToCart(_makeOtcItem(), quantity: 1);
      ctrl.holdBill();
      await ctrl.addToCart(_makeOtcItem(), quantity: 1);
      ctrl.holdBill();
      expect(ctrl.currentState.heldBills, hasLength(2));
      ctrl.deleteHeldBill(0);
      expect(ctrl.currentState.heldBills, hasLength(1));
    });

    test('submitReturn no return perm → false', () async {
      final ctrl = _controller(_FakeSalesRepository());
      final ok = await ctrl.submitReturn(
        actingUserId: 'user_admin',
        permissions: const {'some_other_perm'},
      );
      expect(ok, isFalse);
      expect(ctrl.currentState.errorMessage, isNotNull);
    });

    test('captureLostSale no perm → false', () async {
      final ctrl = _controller(_FakeSalesRepository());
      final ok = await ctrl.captureLostSale(
        productName: 'منتج',
        quantity: 1,
        actingUserId: 'user_admin',
        permissions: const {'some_other_perm'},
      );
      expect(ok, isFalse);
      expect(ctrl.currentState.errorMessage, isNotNull);
    });

    test('captureLostSale with perm → true, state cleared', () async {
      final ctrl = _controller(_FakeSalesRepository());
      ctrl.updatePaymentInputs(cashReceivedMicros: 10);
      final ok = await ctrl.captureLostSale(
        productName: 'منتج',
        quantity: 2,
        actingUserId: 'user_admin',
        permissions: {Perm.lostSalesCreate},
      );
      expect(ok, isTrue);
      expect(ctrl.currentState.errorMessage, isNull);
    });

    test('handleScannedBarcode found item → added to cart', () async {
      final fake = _FakeSalesRepository(items: {
        'item_otc': _makeOtcItem(),
      });
      final ctrl = _controller(fake);
      await ctrl.handleScannedBarcode('1111111111111');
      expect(ctrl.currentState.cart, hasLength(1));
      expect(ctrl.currentState.cart.first.item.id, 'item_otc');
    });

    test('handleScannedBarcode not found → no item added, search seeded',
        () async {
      final fake = _FakeSalesRepository();
      final ctrl = _controller(fake);
      await ctrl.handleScannedBarcode('0000000000000');
      expect(ctrl.currentState.cart, isEmpty);
      expect(ctrl.currentState.searchQuery, '0000000000000');
    });
  });
}