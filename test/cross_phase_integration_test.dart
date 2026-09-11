import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:flutter_test/flutter_test.dart';
import 'package:pharmacy_pos/core/errors/exceptions.dart';
import 'package:pharmacy_pos/domain/services/partial_price_calculator.dart';
import 'package:pharmacy_pos/domain/services/purchase_service.dart';
import 'package:pharmacy_pos/domain/services/return_service.dart';
import 'package:pharmacy_pos/domain/services/sale_service.dart';
import 'package:pharmacy_pos/shared/database/app_database.dart';
import 'package:pharmacy_pos/shared/models/enums.dart';

import 'helpers.dart';

/// Cross-phase integration tests (§31) verifying that Phases 1–5 + Phase 6
/// work as one coherent system end-to-end.
void main() {
  late AppDatabase db;
  final calc = const PartialPriceCalculator();

  setUp(() {
    db = newDatabase();
  });

  tearDown(() async {
    await db.close();
  });

  // ── TEST A: Purchase → Sale lifecycle (Phase 2 + Phase 11) ──────────

  group('TEST A — Purchase → Sale lifecycle', () {
    test('purchase then sale with FEFO deduction, ledger, and profit', () async {
      final itemId = await insertItem(db);
      final supplierId = await insertSupplier(db);

      // Purchase 10 units at cost 1.00 each.
      final purchaseNow = DateTime.now().millisecondsSinceEpoch;
      await PurchaseService().recordPurchase(
        db,
        PurchaseRequest(
          invoiceNumber: 'PI-A1',
          supplierId: supplierId,
          invoiceDate: purchaseNow,
          userId: 'user_admin',
          lines: [
            PurchaseLineRequest(
              itemId: itemId,
              quantityBase: 10,
              unitCostMicros: 10000,
              unitTypeId: 'unit_strip',
              batchNumber: 'BATCH-A1',
              expiryDate: purchaseNow + 365 * 86400000,
            ),
          ],
        ),
      );

      // Verify stock after purchase.
      var item = await (db.select(db.items)
            ..where((i) => i.id.equals(itemId)))
          .getSingle();
      expect(item.currentStockBase, 10);

      // Sell 3 units at 2.00 each.
      final saleOutcome = await SaleService().recordSale(
        db,
        SaleRequest(
          invoiceNumber: 'SI-A1',
          userId: 'user_admin',
          paymentMethod: PaymentMethod.cash,
          paidMicros: 60000,
          lines: [
            SaleLineRequest(
              itemId: itemId,
              quantityBase: 3,
              unitPriceMicros: 20000,
              unitTypeId: 'unit_strip',
            ),
          ],
        ),
      );

      // Verify invoice totals.
      expect(saleOutcome.invoice.totalMicros, 60000);
      expect(saleOutcome.invoice.totalCostMicros, 30000);
      expect(saleOutcome.invoice.profitMicros, 30000);
      expect(saleOutcome.lines, hasLength(1));
      expect(saleOutcome.lines.single.unitCostMicros, 10000);

      // Verify stock deduction.
      item = await (db.select(db.items)
            ..where((i) => i.id.equals(itemId)))
          .getSingle();
      expect(item.currentStockBase, 7);

      // Verify ledger has 2 movements (purchase + sale).
      final movs = await (db.select(db.stockMovements)
            ..where((m) => m.itemId.equals(itemId)))
          .get();
      expect(movs, hasLength(2));
      expect(movs.any((m) => m.movementType == MovementType.sale), isTrue);
    });

    test('purchase then sale cannot exceed available stock', () async {
      final itemId = await insertItem(db);
      final supplierId = await insertSupplier(db);

      await PurchaseService().recordPurchase(
        db,
        PurchaseRequest(
          invoiceNumber: 'PI-A2',
          supplierId: supplierId,
          invoiceDate: DateTime.now().millisecondsSinceEpoch,
          userId: 'user_admin',
          lines: [
            PurchaseLineRequest(
              itemId: itemId,
              quantityBase: 5,
              unitCostMicros: 10000,
              unitTypeId: 'unit_strip',
              batchNumber: 'BATCH-A2',
              expiryDate:
                  DateTime.now().millisecondsSinceEpoch + 365 * 86400000,
            ),
          ],
        ),
      );

      await expectLater(
        SaleService().recordSale(
          db,
          SaleRequest(
            invoiceNumber: 'SI-A2',
            userId: 'user_admin',
            paymentMethod: PaymentMethod.cash,
            paidMicros: 200000,
            lines: [
              SaleLineRequest(
                itemId: itemId,
                quantityBase: 10,
                unitPriceMicros: 20000,
                unitTypeId: 'unit_strip',
              ),
            ],
          ),
        ),
        throwsA(isA<NotEnoughStockException>()),
      );

      // Stock unchanged — atomic rollback.
      final item = await (db.select(db.items)
            ..where((i) => i.id.equals(itemId)))
          .getSingle();
      expect(item.currentStockBase, 5);
    });
  });

  // ── TEST B: Partial-sale pricing (Phase 6 domain) ──────────────────

  group('TEST B — Partial-sale pricing', () {
    test('partial sale decomposition and price computation', () {
      // Item: $10 box of 10 strips, 10% markup
      final partialPrice = calc.calculatePartialPrice(
        sellingPriceMicros: 100000,
        partsPerFullProduct: 10,
        markupBasisPoints: 1000,
      );
      expect(partialPrice, 11000); // $1.10

      // Sell 13 strips: 1 full box ($10) + 3 strips (3 × $1.10)
      final d = calc.decompose(
        quantityParts: 13,
        partsPerFullProduct: 10,
        sellablePartBaseQuantity: 10,
        fullRetailPriceMicros: 100000,
        partialSellingPriceMicros: 11000,
      );
      expect(d.completeProducts, 1);
      expect(d.remainingParts, 3);
      expect(d.totalPriceMicros, 133000);
      expect(d.totalBaseQuantity, 130);
    });

    test('consistency invariant: parts × base = unitsPerLarge', () {
      expect(
        () => calc.validate(
          partialSaleEnabled: true,
          sellablePartUnitId: 'unit_strip',
          partsPerFullProduct: 10,
          sellablePartBaseQuantity: 10,
          partialSaleMarkupBasisPoints: 1000,
          unitsPerLarge: 100,
        ),
        returnsNormally,
      );
    });
  });

  // ── TEST C: Partial-sale in actual sale flow ────────────────────────
  //
  // The SaleService API computes: unitPriceMicros × quantityBase.
  // For partial-sale items, the caller must decompose into lines, each with
  // the correct per-base-unit price. The decomposition is NOT bypassed.

  group('TEST C — Partial-sale actual business flow', () {
    late String itemId;
    late String supplierId;

    /// Helper: configure item for partial sale and purchase stock.
    Future<void> setupPartialSaleItem() async {
      itemId = await insertItem(db);
      supplierId = await insertSupplier(db);

      // Configure: Box = $10, 10 strips/box, 10 base/strip, 10% markup.
      await (db.update(db.items)..where((i) => i.id.equals(itemId))).write(
        ItemsCompanion(
          partialSaleEnabled: const Value(true),
          sellablePartUnitId: const Value('unit_strip'),
          partsPerFullProduct: const Value(10),
          sellablePartBaseQuantity: const Value(10),
          partialSaleMarkupBasisPoints: const Value(1000),
        ),
      );

      // Purchase 300 base units (= 30 boxes) to cover all test scenarios.
      final purchaseNow = DateTime.now().millisecondsSinceEpoch;
      await PurchaseService().recordPurchase(
        db,
        PurchaseRequest(
          invoiceNumber: 'PI-C',
          supplierId: supplierId,
          invoiceDate: purchaseNow,
          userId: 'user_admin',
          lines: [
            PurchaseLineRequest(
              itemId: itemId,
              quantityBase: 300,
              unitCostMicros: 10000,
              unitTypeId: 'unit_strip',
              batchNumber: 'BATCH-C',
              expiryDate: purchaseNow + 365 * 86400000,
            ),
          ],
        ),
      );
    }

    /// Decompose a strip quantity into sale lines with correct per-base-unit
    /// prices. This is the actual business flow: the POS layer decomposes
    /// the customer's strip request into full-box and partial-strips lines.
    List<SaleLineRequest> decomposeIntoSaleLines({
      required String itemId,
      required int quantityParts,
      required int partsPerFullProduct,
      required int sellablePartBaseQuantity,
      required int fullRetailPriceMicros,
      required int partialSellingPriceMicros,
    }) {
      final completeProducts = quantityParts ~/ partsPerFullProduct;
      final remainingParts = quantityParts % partsPerFullProduct;
      final lines = <SaleLineRequest>[];

      // Full-box portion: price per base = fullRetail / (parts × basePerPart).
      if (completeProducts > 0) {
        final fullBoxBaseQty =
            completeProducts * partsPerFullProduct * sellablePartBaseQuantity;
        final fullBoxPricePerBase =
            fullRetailPriceMicros ~/ (partsPerFullProduct * sellablePartBaseQuantity);
        lines.add(SaleLineRequest(
          itemId: itemId,
          quantityBase: fullBoxBaseQty,
          unitPriceMicros: fullBoxPricePerBase,
          unitTypeId: 'unit_strip',
        ));
      }

      // Partial-strips portion: price per base = partialPrice / basePerPart.
      if (remainingParts > 0) {
        final partialBaseQty = remainingParts * sellablePartBaseQuantity;
        final partialPricePerBase =
            partialSellingPriceMicros ~/ sellablePartBaseQuantity;
        lines.add(SaleLineRequest(
          itemId: itemId,
          quantityBase: partialBaseQty,
          unitPriceMicros: partialPricePerBase,
          unitTypeId: 'unit_strip',
        ));
      }

      return lines;
    }

    test('13 strips → 1 box + 3 strips → \$13.30 → 130 base units', () async {
      await setupPartialSaleItem();

      // Step 1: Compute partial price per strip.
      final partialPricePerStrip = calc.calculatePartialPrice(
        sellingPriceMicros: 100000, // $10.00
        partsPerFullProduct: 10,
        markupBasisPoints: 1000, // 10%
      );
      expect(partialPricePerStrip, 11000); // $1.10 per strip

      // Step 2: Decompose 13 strips.
      final decomposition = calc.decompose(
        quantityParts: 13,
        partsPerFullProduct: 10,
        sellablePartBaseQuantity: 10,
        fullRetailPriceMicros: 100000,
        partialSellingPriceMicros: partialPricePerStrip,
      );
      expect(decomposition.completeProducts, 1);
      expect(decomposition.remainingParts, 3);
      expect(decomposition.totalBaseQuantity, 130);
      expect(decomposition.totalPriceMicros, 133000); // $13.30

      // Step 3: Create sale lines via decomposition (actual business flow).
      final saleLines = decomposeIntoSaleLines(
        itemId: itemId,
        quantityParts: 13,
        partsPerFullProduct: 10,
        sellablePartBaseQuantity: 10,
        fullRetailPriceMicros: 100000,
        partialSellingPriceMicros: partialPricePerStrip,
      );
      expect(saleLines, hasLength(2)); // 1 full box + 1 partial

      // Step 4: Execute sale.
      final outcome = await SaleService().recordSale(
        db,
        SaleRequest(
          invoiceNumber: 'SI-C1',
          userId: 'user_admin',
          paymentMethod: PaymentMethod.cash,
          paidMicros: decomposition.totalPriceMicros,
          lines: saleLines,
        ),
      );

      // Step 5: Verify invoice total = $13.30.
      expect(outcome.invoice.totalMicros, 133000);

      // Step 6: Verify two lines created (full box + partial strips).
      expect(outcome.lines, hasLength(2));

      // Full box line: 100 base units at $0.10/base = $10.00.
      final fullBoxLine = outcome.lines.firstWhere(
          (l) => l.unitPriceMicros == 1000 && l.quantityBaseSigned == 100);
      expect(fullBoxLine.lineTotalMicros, 100000); // $10.00

      // Partial strips line: 30 base units at $0.11/base = $3.30.
      final partialLine = outcome.lines.firstWhere(
          (l) => l.unitPriceMicros == 1100 && l.quantityBaseSigned == 30);
      expect(partialLine.lineTotalMicros, 33000); // $3.30

      // Step 7: Verify stock deducted = 130 base units.
      final item = await (db.select(db.items)
            ..where((i) => i.id.equals(itemId)))
          .getSingle();
      expect(item.currentStockBase, 170); // 300 - 130

      // Step 8: Verify FEFO ledger.
      final movs = await (db.select(db.stockMovements)
            ..where((m) => m.itemId.equals(itemId)))
          .get();
      final saleMovs =
          movs.where((m) => m.movementType == MovementType.sale).toList();
      expect(saleMovs, hasLength(2)); // 2 batch allocations
      final totalDeducted =
          saleMovs.fold<int>(0, (sum, m) => sum + m.quantityBaseSigned);
      expect(totalDeducted, -130);
    });

    test('10 strips → 1 box → \$10.00 (NO cumulative markup)', () async {
      await setupPartialSaleItem();

      // 10 strips = exactly 1 box. Must be sold at full retail, NOT at
      // partial price with markup. The partial markup applies only to
      // quantities that don't fill a complete box.
      final partialPricePerStrip = calc.calculatePartialPrice(
        sellingPriceMicros: 100000,
        partsPerFullProduct: 10,
        markupBasisPoints: 1000,
      );

      final decomposition = calc.decompose(
        quantityParts: 10,
        partsPerFullProduct: 10,
        sellablePartBaseQuantity: 10,
        fullRetailPriceMicros: 100000,
        partialSellingPriceMicros: partialPricePerStrip,
      );
      expect(decomposition.completeProducts, 1);
      expect(decomposition.remainingParts, 0);
      expect(decomposition.totalPriceMicros, 100000); // $10.00, NOT $11.00

      final saleLines = decomposeIntoSaleLines(
        itemId: itemId,
        quantityParts: 10,
        partsPerFullProduct: 10,
        sellablePartBaseQuantity: 10,
        fullRetailPriceMicros: 100000,
        partialSellingPriceMicros: partialPricePerStrip,
      );
      expect(saleLines, hasLength(1)); // Only 1 full-box line

      final outcome = await SaleService().recordSale(
        db,
        SaleRequest(
          invoiceNumber: 'SI-C2',
          userId: 'user_admin',
          paymentMethod: PaymentMethod.cash,
          paidMicros: decomposition.totalPriceMicros,
          lines: saleLines,
        ),
      );

      // CRITICAL: 10 strips = $10.00, NOT $11.00.
      expect(outcome.invoice.totalMicros, 100000);

      final item = await (db.select(db.items)
            ..where((i) => i.id.equals(itemId)))
          .getSingle();
      expect(item.currentStockBase, 200); // 300 - 100
    });

    test('3 strips → 0 boxes + 3 strips → \$3.30 → 30 base units', () async {
      await setupPartialSaleItem();

      final partialPricePerStrip = calc.calculatePartialPrice(
        sellingPriceMicros: 100000,
        partsPerFullProduct: 10,
        markupBasisPoints: 1000,
      );

      final decomposition = calc.decompose(
        quantityParts: 3,
        partsPerFullProduct: 10,
        sellablePartBaseQuantity: 10,
        fullRetailPriceMicros: 100000,
        partialSellingPriceMicros: partialPricePerStrip,
      );
      expect(decomposition.completeProducts, 0);
      expect(decomposition.remainingParts, 3);
      expect(decomposition.totalPriceMicros, 33000); // $3.30

      final saleLines = decomposeIntoSaleLines(
        itemId: itemId,
        quantityParts: 3,
        partsPerFullProduct: 10,
        sellablePartBaseQuantity: 10,
        fullRetailPriceMicros: 100000,
        partialSellingPriceMicros: partialPricePerStrip,
      );
      expect(saleLines, hasLength(1)); // Only partial strips

      final outcome = await SaleService().recordSale(
        db,
        SaleRequest(
          invoiceNumber: 'SI-C3',
          userId: 'user_admin',
          paymentMethod: PaymentMethod.cash,
          paidMicros: decomposition.totalPriceMicros,
          lines: saleLines,
        ),
      );

      expect(outcome.invoice.totalMicros, 33000); // $3.30
      expect(outcome.lines, hasLength(1));
      expect(outcome.lines.single.quantityBaseSigned, 30);

      final item = await (db.select(db.items)
            ..where((i) => i.id.equals(itemId)))
          .getSingle();
      expect(item.currentStockBase, 270); // 300 - 30
    });

    test('27 strips → 2 boxes + 7 strips → \$27.70 → 270 base units', () async {
      await setupPartialSaleItem();

      final partialPricePerStrip = calc.calculatePartialPrice(
        sellingPriceMicros: 100000,
        partsPerFullProduct: 10,
        markupBasisPoints: 1000,
      );

      final decomposition = calc.decompose(
        quantityParts: 27,
        partsPerFullProduct: 10,
        sellablePartBaseQuantity: 10,
        fullRetailPriceMicros: 100000,
        partialSellingPriceMicros: partialPricePerStrip,
      );
      expect(decomposition.completeProducts, 2);
      expect(decomposition.remainingParts, 7);
      expect(decomposition.totalPriceMicros, 277000); // $27.70

      final saleLines = decomposeIntoSaleLines(
        itemId: itemId,
        quantityParts: 27,
        partsPerFullProduct: 10,
        sellablePartBaseQuantity: 10,
        fullRetailPriceMicros: 100000,
        partialSellingPriceMicros: partialPricePerStrip,
      );
      expect(saleLines, hasLength(2));

      final outcome = await SaleService().recordSale(
        db,
        SaleRequest(
          invoiceNumber: 'SI-C4',
          userId: 'user_admin',
          paymentMethod: PaymentMethod.cash,
          paidMicros: decomposition.totalPriceMicros,
          lines: saleLines,
        ),
      );

      expect(outcome.invoice.totalMicros, 277000); // $27.70

      final item = await (db.select(db.items)
            ..where((i) => i.id.equals(itemId)))
          .getSingle();
      expect(item.currentStockBase, 30); // 300 - 270
    });

    test('1 strip → 0 boxes + 1 strip → \$1.10 → 10 base units', () async {
      await setupPartialSaleItem();

      final partialPricePerStrip = calc.calculatePartialPrice(
        sellingPriceMicros: 100000,
        partsPerFullProduct: 10,
        markupBasisPoints: 1000,
      );

      final decomposition = calc.decompose(
        quantityParts: 1,
        partsPerFullProduct: 10,
        sellablePartBaseQuantity: 10,
        fullRetailPriceMicros: 100000,
        partialSellingPriceMicros: partialPricePerStrip,
      );
      expect(decomposition.completeProducts, 0);
      expect(decomposition.remainingParts, 1);
      expect(decomposition.totalPriceMicros, 11000); // $1.10

      final saleLines = decomposeIntoSaleLines(
        itemId: itemId,
        quantityParts: 1,
        partsPerFullProduct: 10,
        sellablePartBaseQuantity: 10,
        fullRetailPriceMicros: 100000,
        partialSellingPriceMicros: partialPricePerStrip,
      );
      expect(saleLines, hasLength(1));

      final outcome = await SaleService().recordSale(
        db,
        SaleRequest(
          invoiceNumber: 'SI-C5',
          userId: 'user_admin',
          paymentMethod: PaymentMethod.cash,
          paidMicros: decomposition.totalPriceMicros,
          lines: saleLines,
        ),
      );

      expect(outcome.invoice.totalMicros, 11000); // $1.10

      final item = await (db.select(db.items)
            ..where((i) => i.id.equals(itemId)))
          .getSingle();
      expect(item.currentStockBase, 290); // 300 - 10
    });
  });

  // ── TEST D: Prescription creation → dispensing → status tracking ────

  group('TEST D — Prescription dispensing lifecycle', () {
    test('full prescription dispensing updates status to dispensed', () async {
      final itemId = await insertItem(db);
      final supplierId = await insertSupplier(db);

      // Create a customer first.
      final custNow = DateTime.now().millisecondsSinceEpoch;
      await db.into(db.customers).insert(
            CustomersCompanion.insert(
              id: 'cust_rx_test',
              name: 'مريض اختبار',
              createdAt: custNow,
              updatedAt: custNow,
            ),
          );

      // Create prescription with 1 item, qty 10 base.
      final rxNow = DateTime.now().millisecondsSinceEpoch;
      final rxId = 'rx_test_001';
      await db.into(db.prescriptions).insert(
            PrescriptionsCompanion.insert(
              id: rxId,
              prescriptionNumber: 'RX-001',
              customerId: 'cust_rx_test',
              patientName: 'مريض اختبار',
              issuedAt: rxNow,
              status: PrescriptionStatus.active,
              createdBy: 'user_admin',
              createdAt: rxNow,
              updatedAt: rxNow,
            ),
          );
      final piId = 'pi_test_001';
      await db.into(db.prescriptionItems).insert(
            PrescriptionItemsCompanion.insert(
              id: piId,
              prescriptionId: rxId,
              itemId: itemId,
              quantityBase: 10,
              createdAt: rxNow,
            ),
          );

      // Purchase stock.
      final purchaseNow = DateTime.now().millisecondsSinceEpoch;
      await PurchaseService().recordPurchase(
        db,
        PurchaseRequest(
          invoiceNumber: 'PI-D1',
          supplierId: supplierId,
          invoiceDate: purchaseNow,
          userId: 'user_admin',
          lines: [
            PurchaseLineRequest(
              itemId: itemId,
              quantityBase: 20,
              unitCostMicros: 10000,
              unitTypeId: 'unit_strip',
              batchNumber: 'BATCH-D1',
              expiryDate: purchaseNow + 365 * 86400000,
            ),
          ],
        ),
      );

      // Dispense full prescription.
      final saleOutcome = await SaleService().recordSale(
        db,
        SaleRequest(
          invoiceNumber: 'SI-D1',
          userId: 'user_admin',
          paymentMethod: PaymentMethod.cash,
          paidMicros: 200000,
          prescriptionId: rxId,
          lines: [
            SaleLineRequest(
              itemId: itemId,
              quantityBase: 10,
              unitPriceMicros: 20000,
              unitTypeId: 'unit_strip',
              prescriptionItemId: piId,
            ),
          ],
        ),
      );

      // Verify invoice links to prescription.
      expect(saleOutcome.invoice.prescriptionId, rxId);

      // Verify line links to prescription item.
      expect(saleOutcome.lines.single.prescriptionItemId, piId);

      // Verify prescription item dispensed quantity.
      final pi = await (db.select(db.prescriptionItems)
            ..where((p) => p.id.equals(piId)))
          .getSingle();
      expect(pi.dispensedQuantityBase, 10);
      expect(pi.isDispensed, true);

      // Verify prescription status updated to dispensed.
      final rx = await (db.select(db.prescriptions)
            ..where((p) => p.id.equals(rxId)))
          .getSingle();
      expect(rx.status, PrescriptionStatus.dispensed);
    });

    test('partial dispensing updates status to partially_dispensed', () async {
      final itemId = await insertItem(db);
      final supplierId = await insertSupplier(db);

      final custNow = DateTime.now().millisecondsSinceEpoch;
      await db.into(db.customers).insert(
            CustomersCompanion.insert(
              id: 'cust_rx_partial',
              name: 'مريض جزئي',
              createdAt: custNow,
              updatedAt: custNow,
            ),
          );

      final rxNow = DateTime.now().millisecondsSinceEpoch;
      final rxId = 'rx_test_002';
      await db.into(db.prescriptions).insert(
            PrescriptionsCompanion.insert(
              id: rxId,
              prescriptionNumber: 'RX-002',
              customerId: 'cust_rx_partial',
              patientName: 'مريض جزئي',
              issuedAt: rxNow,
              status: PrescriptionStatus.active,
              createdBy: 'user_admin',
              createdAt: rxNow,
              updatedAt: rxNow,
            ),
          );
      final piId = 'pi_test_002';
      await db.into(db.prescriptionItems).insert(
            PrescriptionItemsCompanion.insert(
              id: piId,
              prescriptionId: rxId,
              itemId: itemId,
              quantityBase: 10,
              createdAt: rxNow,
            ),
          );

      // Purchase 10 units.
      final purchaseNow = DateTime.now().millisecondsSinceEpoch;
      await PurchaseService().recordPurchase(
        db,
        PurchaseRequest(
          invoiceNumber: 'PI-D2',
          supplierId: supplierId,
          invoiceDate: purchaseNow,
          userId: 'user_admin',
          lines: [
            PurchaseLineRequest(
              itemId: itemId,
              quantityBase: 10,
              unitCostMicros: 10000,
              unitTypeId: 'unit_strip',
              batchNumber: 'BATCH-D2',
              expiryDate: purchaseNow + 365 * 86400000,
            ),
          ],
        ),
      );

      // Dispense 6 out of 10.
      await SaleService().recordSale(
        db,
        SaleRequest(
          invoiceNumber: 'SI-D2',
          userId: 'user_admin',
          paymentMethod: PaymentMethod.cash,
          paidMicros: 120000,
          prescriptionId: rxId,
          lines: [
            SaleLineRequest(
              itemId: itemId,
              quantityBase: 6,
              unitPriceMicros: 20000,
              unitTypeId: 'unit_strip',
              prescriptionItemId: piId,
            ),
          ],
        ),
      );

      // Verify partial dispensing.
      final pi = await (db.select(db.prescriptionItems)
            ..where((p) => p.id.equals(piId)))
          .getSingle();
      expect(pi.dispensedQuantityBase, 6);
      expect(pi.isDispensed, false);

      // Prescription status is partially_dispensed.
      final rx = await (db.select(db.prescriptions)
            ..where((p) => p.id.equals(rxId)))
          .getSingle();
      expect(rx.status, PrescriptionStatus.partially_dispensed);
    });

    test('dispensing more than prescribed is rejected', () async {
      final itemId = await insertItem(db);
      final supplierId = await insertSupplier(db);

      final custNow = DateTime.now().millisecondsSinceEpoch;
      await db.into(db.customers).insert(
            CustomersCompanion.insert(
              id: 'cust_rx_over',
              name: 'مريض زائد',
              createdAt: custNow,
              updatedAt: custNow,
            ),
          );

      final rxNow = DateTime.now().millisecondsSinceEpoch;
      final rxId = 'rx_test_003';
      await db.into(db.prescriptions).insert(
            PrescriptionsCompanion.insert(
              id: rxId,
              prescriptionNumber: 'RX-003',
              customerId: 'cust_rx_over',
              patientName: 'مريض زائد',
              issuedAt: rxNow,
              status: PrescriptionStatus.active,
              createdBy: 'user_admin',
              createdAt: rxNow,
              updatedAt: rxNow,
            ),
          );
      final piId = 'pi_test_003';
      await db.into(db.prescriptionItems).insert(
            PrescriptionItemsCompanion.insert(
              id: piId,
              prescriptionId: rxId,
              itemId: itemId,
              quantityBase: 5,
              createdAt: rxNow,
            ),
          );

      final purchaseNow = DateTime.now().millisecondsSinceEpoch;
      await PurchaseService().recordPurchase(
        db,
        PurchaseRequest(
          invoiceNumber: 'PI-D3',
          supplierId: supplierId,
          invoiceDate: purchaseNow,
          userId: 'user_admin',
          lines: [
            PurchaseLineRequest(
              itemId: itemId,
              quantityBase: 20,
              unitCostMicros: 10000,
              unitTypeId: 'unit_strip',
              batchNumber: 'BATCH-D3',
              expiryDate: purchaseNow + 365 * 86400000,
            ),
          ],
        ),
      );

      // Try to dispense 10 when only 5 are prescribed.
      await expectLater(
        SaleService().recordSale(
          db,
          SaleRequest(
            invoiceNumber: 'SI-D3',
            userId: 'user_admin',
            paymentMethod: PaymentMethod.cash,
            paidMicros: 200000,
            prescriptionId: rxId,
            lines: [
              SaleLineRequest(
                itemId: itemId,
                quantityBase: 10,
                unitPriceMicros: 20000,
                unitTypeId: 'unit_strip',
                prescriptionItemId: piId,
              ),
            ],
          ),
        ),
        throwsA(isA<ValidationException>()),
      );
    });
  });

  // ── TEST E: Return reverses prescription dispensing ─────────────────

  group('TEST E — Return reverses prescription dispensing', () {
    test('return of prescription-linked sale reverts dispensed quantity and status',
        () async {
      final itemId = await insertItem(db);
      final supplierId = await insertSupplier(db);

      final custNow = DateTime.now().millisecondsSinceEpoch;
      await db.into(db.customers).insert(
            CustomersCompanion.insert(
              id: 'cust_ret_rx',
              name: 'مرتجع وصفة',
              createdAt: custNow,
              updatedAt: custNow,
            ),
          );

      final rxNow = DateTime.now().millisecondsSinceEpoch;
      final rxId = 'rx_ret_001';
      await db.into(db.prescriptions).insert(
            PrescriptionsCompanion.insert(
              id: rxId,
              prescriptionNumber: 'RX-RET-001',
              customerId: 'cust_ret_rx',
              patientName: 'مرتجع وصفة',
              issuedAt: rxNow,
              status: PrescriptionStatus.active,
              createdBy: 'user_admin',
              createdAt: rxNow,
              updatedAt: rxNow,
            ),
          );
      final piId = 'pi_ret_001';
      await db.into(db.prescriptionItems).insert(
            PrescriptionItemsCompanion.insert(
              id: piId,
              prescriptionId: rxId,
              itemId: itemId,
              quantityBase: 10,
              createdAt: rxNow,
            ),
          );

      // Purchase stock.
      final purchaseNow = DateTime.now().millisecondsSinceEpoch;
      await PurchaseService().recordPurchase(
        db,
        PurchaseRequest(
          invoiceNumber: 'PI-E1',
          supplierId: supplierId,
          invoiceDate: purchaseNow,
          userId: 'user_admin',
          lines: [
            PurchaseLineRequest(
              itemId: itemId,
              quantityBase: 20,
              unitCostMicros: 10000,
              unitTypeId: 'unit_strip',
              batchNumber: 'BATCH-E1',
              expiryDate: purchaseNow + 365 * 86400000,
            ),
          ],
        ),
      );

      // Dispense 8 of 10.
      final saleOutcome = await SaleService().recordSale(
        db,
        SaleRequest(
          invoiceNumber: 'SI-E1',
          userId: 'user_admin',
          paymentMethod: PaymentMethod.cash,
          paidMicros: 160000,
          prescriptionId: rxId,
          lines: [
            SaleLineRequest(
              itemId: itemId,
              quantityBase: 8,
              unitPriceMicros: 20000,
              unitTypeId: 'unit_strip',
              prescriptionItemId: piId,
            ),
          ],
        ),
      );

      // Verify partially_dispensed.
      var pi = await (db.select(db.prescriptionItems)
            ..where((p) => p.id.equals(piId)))
          .getSingle();
      expect(pi.dispensedQuantityBase, 8);
      var rx = await (db.select(db.prescriptions)
            ..where((p) => p.id.equals(rxId)))
          .getSingle();
      expect(rx.status, PrescriptionStatus.partially_dispensed);

      // Return 3 units.
      final saleLineId = saleOutcome.lines.single.id;
      await ReturnService().recordSaleReturn(
        db,
        SaleReturnRequest(
          returnNumber: 'RET-E1',
          originalInvoiceItemId: saleLineId,
          quantityBase: 3,
          userId: 'user_admin',
          reason: 'خطأ في الصرف',
        ),
      );

      // Verify dispensed quantity reverted.
      pi = await (db.select(db.prescriptionItems)
            ..where((p) => p.id.equals(piId)))
          .getSingle();
      expect(pi.dispensedQuantityBase, 5);

      // Status stays partially_dispensed (5 of 10 still dispensed).
      rx = await (db.select(db.prescriptions)
            ..where((p) => p.id.equals(rxId)))
          .getSingle();
      expect(rx.status, PrescriptionStatus.partially_dispensed);

      // Stock restored.
      final item = await (db.select(db.items)
            ..where((i) => i.id.equals(itemId)))
          .getSingle();
      expect(item.currentStockBase, 15); // 20 - 8 + 3
    });

    test('return all dispensed quantity reverts status to ACTIVE', () async {
      final itemId = await insertItem(db);
      final supplierId = await insertSupplier(db);

      final custNow = DateTime.now().millisecondsSinceEpoch;
      await db.into(db.customers).insert(
            CustomersCompanion.insert(
              id: 'cust_ret_all',
              name: 'مرتجع كامل',
              createdAt: custNow,
              updatedAt: custNow,
            ),
          );

      final rxNow = DateTime.now().millisecondsSinceEpoch;
      final rxId = 'rx_ret_all';
      await db.into(db.prescriptions).insert(
            PrescriptionsCompanion.insert(
              id: rxId,
              prescriptionNumber: 'RX-RET-ALL',
              customerId: 'cust_ret_all',
              patientName: 'مرتجع كامل',
              issuedAt: rxNow,
              status: PrescriptionStatus.active,
              createdBy: 'user_admin',
              createdAt: rxNow,
              updatedAt: rxNow,
            ),
          );
      final piId = 'pi_ret_all';
      await db.into(db.prescriptionItems).insert(
            PrescriptionItemsCompanion.insert(
              id: piId,
              prescriptionId: rxId,
              itemId: itemId,
              quantityBase: 10,
              createdAt: rxNow,
            ),
          );

      final purchaseNow = DateTime.now().millisecondsSinceEpoch;
      await PurchaseService().recordPurchase(
        db,
        PurchaseRequest(
          invoiceNumber: 'PI-E2',
          supplierId: supplierId,
          invoiceDate: purchaseNow,
          userId: 'user_admin',
          lines: [
            PurchaseLineRequest(
              itemId: itemId,
              quantityBase: 20,
              unitCostMicros: 10000,
              unitTypeId: 'unit_strip',
              batchNumber: 'BATCH-E2',
              expiryDate: purchaseNow + 365 * 86400000,
            ),
          ],
        ),
      );

      // Dispense 6 of 10.
      final saleOutcome = await SaleService().recordSale(
        db,
        SaleRequest(
          invoiceNumber: 'SI-E2',
          userId: 'user_admin',
          paymentMethod: PaymentMethod.cash,
          paidMicros: 120000,
          prescriptionId: rxId,
          lines: [
            SaleLineRequest(
              itemId: itemId,
              quantityBase: 6,
              unitPriceMicros: 20000,
              unitTypeId: 'unit_strip',
              prescriptionItemId: piId,
            ),
          ],
        ),
      );

      // Verify partially_dispensed.
      var pi = await (db.select(db.prescriptionItems)
            ..where((p) => p.id.equals(piId)))
          .getSingle();
      expect(pi.dispensedQuantityBase, 6);
      var rx = await (db.select(db.prescriptions)
            ..where((p) => p.id.equals(rxId)))
          .getSingle();
      expect(rx.status, PrescriptionStatus.partially_dispensed);

      // Return ALL 6 dispensed units.
      final saleLineId = saleOutcome.lines.single.id;
      await ReturnService().recordSaleReturn(
        db,
        SaleReturnRequest(
          returnNumber: 'RET-E2',
          originalInvoiceItemId: saleLineId,
          quantityBase: 6,
          userId: 'user_admin',
          reason: 'إلغاء الصرف بالكامل',
        ),
      );

      // Verify dispensed quantity is now 0.
      pi = await (db.select(db.prescriptionItems)
            ..where((p) => p.id.equals(piId)))
          .getSingle();
      expect(pi.dispensedQuantityBase, 0);
      expect(pi.isDispensed, false);

      // Status reverts to ACTIVE (nothing dispensed).
      rx = await (db.select(db.prescriptions)
            ..where((p) => p.id.equals(rxId)))
          .getSingle();
      expect(rx.status, PrescriptionStatus.active);

      // Stock fully restored.
      final item = await (db.select(db.items)
            ..where((i) => i.id.equals(itemId)))
          .getSingle();
      expect(item.currentStockBase, 20); // 20 - 6 + 6
    });
  });

  // ── TEST F: Prescription + OTC in same invoice ─────────────────────

  group('TEST F — Prescription + OTC in same invoice', () {
    test('prescription and OTC items can coexist in one invoice', () async {
    final rxItem = await insertItem(db, barcode: '6291041500214', id: 'item_rx');
    final otcItem = await insertItem(db, barcode: '6291041500215', id: 'item_otc');
    final supplierId = await insertSupplier(db);

    final custNow = DateTime.now().millisecondsSinceEpoch;
    await db.into(db.customers).insert(
          CustomersCompanion.insert(
            id: 'cust_mixed',
            name: 'عميل مختلط',
            createdAt: custNow,
            updatedAt: custNow,
          ),
        );

    final rxNow = DateTime.now().millisecondsSinceEpoch;
    final rxId = 'rx_mixed_001';
    await db.into(db.prescriptions).insert(
          PrescriptionsCompanion.insert(
            id: rxId,
            prescriptionNumber: 'RX-MIX-001',
            customerId: 'cust_mixed',
            patientName: 'عميل مختلط',
            issuedAt: rxNow,
            status: PrescriptionStatus.active,
            createdBy: 'user_admin',
            createdAt: rxNow,
            updatedAt: rxNow,
          ),
        );
    final piId = 'pi_mixed_001';
    await db.into(db.prescriptionItems).insert(
          PrescriptionItemsCompanion.insert(
            id: piId,
            prescriptionId: rxId,
            itemId: rxItem,
            quantityBase: 5,
            createdAt: rxNow,
          ),
        );

    final purchaseNow = DateTime.now().millisecondsSinceEpoch;
    await PurchaseService().recordPurchase(
      db,
      PurchaseRequest(
        invoiceNumber: 'PI-F1',
        supplierId: supplierId,
        invoiceDate: purchaseNow,
        userId: 'user_admin',
        lines: [
          PurchaseLineRequest(
            itemId: rxItem,
            quantityBase: 10,
            unitCostMicros: 10000,
            unitTypeId: 'unit_strip',
            batchNumber: 'BATCH-F1-RX',
            expiryDate: purchaseNow + 365 * 86400000,
          ),
          PurchaseLineRequest(
            itemId: otcItem,
            quantityBase: 10,
            unitCostMicros: 5000,
            unitTypeId: 'unit_strip',
            batchNumber: 'BATCH-F1-OTC',
            expiryDate: purchaseNow + 365 * 86400000,
          ),
        ],
      ),
    );

    // Invoice with RX item (linked) + OTC item (no linkage).
    final saleOutcome = await SaleService().recordSale(
      db,
      SaleRequest(
        invoiceNumber: 'SI-F1',
        userId: 'user_admin',
        paymentMethod: PaymentMethod.cash,
        paidMicros: 300000,
        prescriptionId: rxId,
        lines: [
          SaleLineRequest(
            itemId: rxItem,
            quantityBase: 5,
            unitPriceMicros: 20000,
            unitTypeId: 'unit_strip',
            prescriptionItemId: piId,
          ),
          SaleLineRequest(
            itemId: otcItem,
            quantityBase: 3,
            unitPriceMicros: 15000,
            unitTypeId: 'unit_strip',
          ),
        ],
      ),
    );

    expect(saleOutcome.invoice.prescriptionId, rxId);
    expect(saleOutcome.lines, hasLength(2));

    // One line has prescriptionItemId, the other doesn't.
    final rxLine =
        saleOutcome.lines.firstWhere((l) => l.prescriptionItemId != null);
    final otcLine =
        saleOutcome.lines.firstWhere((l) => l.prescriptionItemId == null);
    expect(rxLine.prescriptionItemId, piId);
    expect(otcLine.prescriptionItemId, isNull);

    // Prescription item fully dispensed.
    final pi = await (db.select(db.prescriptionItems)
          ..where((p) => p.id.equals(piId)))
        .getSingle();
    expect(pi.dispensedQuantityBase, 5);
    expect(pi.isDispensed, true);
    }); // test
  }); // group TEST F

  // ── TEST G: Invalid prescription linkage is rejected ────────────────

  group('TEST G — Invalid prescription linkage rejected', () {
    test('non-existent prescription ID is rejected', () async {
      final itemId = await insertItem(db);
      final supplierId = await insertSupplier(db);

      final purchaseNow = DateTime.now().millisecondsSinceEpoch;
      await PurchaseService().recordPurchase(
        db,
        PurchaseRequest(
          invoiceNumber: 'PI-G1',
          supplierId: supplierId,
          invoiceDate: purchaseNow,
          userId: 'user_admin',
          lines: [
            PurchaseLineRequest(
              itemId: itemId,
              quantityBase: 10,
              unitCostMicros: 10000,
              unitTypeId: 'unit_strip',
              batchNumber: 'BATCH-G1',
              expiryDate: purchaseNow + 365 * 86400000,
            ),
          ],
        ),
      );

      await expectLater(
        SaleService().recordSale(
          db,
          SaleRequest(
            invoiceNumber: 'SI-G1',
            userId: 'user_admin',
            paymentMethod: PaymentMethod.cash,
            paidMicros: 200000,
            prescriptionId: 'rx_nonexistent',
            lines: [
              SaleLineRequest(
                itemId: itemId,
                quantityBase: 3,
                unitPriceMicros: 20000,
                unitTypeId: 'unit_strip',
              ),
            ],
          ),
        ),
        throwsA(isA<NotFoundException>()),
      );
    });

    test('prescriptionItemId not belonging to prescription is rejected', () async {
      final itemId = await insertItem(db);
      final supplierId = await insertSupplier(db);

      final custNow = DateTime.now().millisecondsSinceEpoch;
      await db.into(db.customers).insert(
            CustomersCompanion.insert(
              id: 'cust_bad_link',
              name: 'ربط خاطئ',
              createdAt: custNow,
              updatedAt: custNow,
            ),
          );

      // Create two prescriptions.
      final rxNow = DateTime.now().millisecondsSinceEpoch;
      for (final entry in {'rx_bad1': 'RX-BAD-001', 'rx_bad2': 'RX-BAD-002'}
          .entries) {
        await db.into(db.prescriptions).insert(
              PrescriptionsCompanion.insert(
                id: entry.key,
                prescriptionNumber: entry.value,
                customerId: 'cust_bad_link',
                patientName: 'ربط خاطئ',
                issuedAt: rxNow,
                status: PrescriptionStatus.active,
                createdBy: 'user_admin',
                createdAt: rxNow,
                updatedAt: rxNow,
              ),
            );
      }
      // Prescription item belongs to rx_bad2.
      await db.into(db.prescriptionItems).insert(
            PrescriptionItemsCompanion.insert(
              id: 'pi_bad2',
              prescriptionId: 'rx_bad2',
              itemId: itemId,
              quantityBase: 10,
              createdAt: rxNow,
            ),
          );

      final purchaseNow = DateTime.now().millisecondsSinceEpoch;
      await PurchaseService().recordPurchase(
        db,
        PurchaseRequest(
          invoiceNumber: 'PI-G2',
          supplierId: supplierId,
          invoiceDate: purchaseNow,
          userId: 'user_admin',
          lines: [
            PurchaseLineRequest(
              itemId: itemId,
              quantityBase: 10,
              unitCostMicros: 10000,
              unitTypeId: 'unit_strip',
              batchNumber: 'BATCH-G2',
              expiryDate: purchaseNow + 365 * 86400000,
            ),
          ],
        ),
      );

      // Try to link pi_bad2 (from rx_bad2) to rx_bad1.
      await expectLater(
        SaleService().recordSale(
          db,
          SaleRequest(
            invoiceNumber: 'SI-G2',
            userId: 'user_admin',
            paymentMethod: PaymentMethod.cash,
            paidMicros: 200000,
            prescriptionId: 'rx_bad1',
            lines: [
              SaleLineRequest(
                itemId: itemId,
                quantityBase: 3,
                unitPriceMicros: 20000,
                unitTypeId: 'unit_strip',
                prescriptionItemId: 'pi_bad2',
              ),
            ],
          ),
        ),
        throwsA(isA<ValidationException>()),
      );
    });
  });

  // ── TEST H: Atomic transaction rollback on failure ──────────────────

  group('TEST H — Atomic transaction rollback on failure', () {
    test('failed sale leaves no partial state', () async {
      final itemId1 = await insertItem(db, barcode: '6291041500216', id: 'item_h1');
      final itemId2 = await insertItem(db, barcode: '6291041500217', id: 'item_h2');
      final supplierId = await insertSupplier(db);

      final purchaseNow = DateTime.now().millisecondsSinceEpoch;
      await PurchaseService().recordPurchase(
        db,
        PurchaseRequest(
          invoiceNumber: 'PI-H1',
          supplierId: supplierId,
          invoiceDate: purchaseNow,
          userId: 'user_admin',
          lines: [
            PurchaseLineRequest(
              itemId: itemId1,
              quantityBase: 5,
              unitCostMicros: 10000,
              unitTypeId: 'unit_strip',
              batchNumber: 'BATCH-H1',
              expiryDate: purchaseNow + 365 * 86400000,
            ),
          ],
        ),
      );

      // item_h2 has no stock — sale will fail on the second line.
      await expectLater(
        SaleService().recordSale(
          db,
          SaleRequest(
            invoiceNumber: 'SI-H1',
            userId: 'user_admin',
            paymentMethod: PaymentMethod.cash,
            paidMicros: 300000,
            lines: [
              SaleLineRequest(
                itemId: itemId1,
                quantityBase: 2,
                unitPriceMicros: 20000,
                unitTypeId: 'unit_strip',
              ),
              SaleLineRequest(
                itemId: itemId2,
                quantityBase: 3,
                unitPriceMicros: 20000,
                unitTypeId: 'unit_strip',
              ),
            ],
          ),
        ),
        throwsA(isA<NotEnoughStockException>()),
      );

      // No invoice was created.
      final invs = await db.select(db.salesInvoices).get();
      expect(invs, isEmpty);

      // item_h1 stock unchanged.
      final item1 = await (db.select(db.items)
            ..where((i) => i.id.equals(itemId1)))
          .getSingle();
      expect(item1.currentStockBase, 5);
    });
  });

  // ── TEST I: Schema v3 has all Phase 6 columns ──────────────────────

  group('TEST I — Schema integrity (Phase 6 columns)', () {
    test('sales_invoices has prescription_id column', () async {
      await insertItem(db);
      final customerNow = DateTime.now().millisecondsSinceEpoch;
      await db.into(db.customers).insert(
            CustomersCompanion.insert(
              id: 'cust_schema',
              name: 'اختبار المخطط',
              createdAt: customerNow,
              updatedAt: customerNow,
            ),
          );

      final now = DateTime.now().millisecondsSinceEpoch;
      await db.into(db.salesInvoices).insert(
            SalesInvoicesCompanion.insert(
              id: 'inv_schema_001',
              invoiceNumber: 'SI-SCHEMA-001',
              invoiceType: InvoiceType.sale,
              saleStatus: SaleStatus.completed,
              paymentMethod: PaymentMethod.cash,
              customerId: const Value('cust_schema'),
              userId: 'user_admin',
              prescriptionId: const Value('rx_test'),
              createdAt: now,
              updatedAt: now,
            ),
          );

      final inv = await (db.select(db.salesInvoices)
            ..where((i) => i.id.equals('inv_schema_001')))
          .getSingle();
      expect(inv.prescriptionId, 'rx_test');
    });

    test('prescription_items has dispensed_quantity_base column', () async {
      final now = DateTime.now().millisecondsSinceEpoch;
      await db.into(db.items).insert(
            ItemsCompanion.insert(
              id: 'item_pi_check',
              tradeName: 'اختبار',
              categoryId: const Value('cat_test_default'),
              createdAt: now,
              updatedAt: now,
            ),
          );
      await db.into(db.prescriptions).insert(
            PrescriptionsCompanion.insert(
              id: 'rx_pi_check',
              prescriptionNumber: 'RX-PI-CHECK',
              customerId: 'cust_schema',
              patientName: 'اختبار',
              issuedAt: now,
              status: PrescriptionStatus.active,
              createdBy: 'user_admin',
              createdAt: now,
              updatedAt: now,
            ),
          );
      await db.into(db.prescriptionItems).insert(
            PrescriptionItemsCompanion.insert(
              id: 'pi_schema_check',
              prescriptionId: 'rx_pi_check',
              itemId: 'item_pi_check',
              quantityBase: 10,
              dispensedQuantityBase: const Value(5),
              createdAt: now,
            ),
          );

      final pi = await (db.select(db.prescriptionItems)
            ..where((p) => p.id.equals('pi_schema_check')))
          .getSingle();
      expect(pi.dispensedQuantityBase, 5);
    });

    test('sales_invoice_items has prescription_item_id column', () async {
      final now = DateTime.now().millisecondsSinceEpoch;
      final itemId = await insertItem(db);
      final batchId = await insertBatch(db, itemId);

      // Create a minimal invoice first.
      await db.into(db.salesInvoices).insert(
            SalesInvoicesCompanion.insert(
              id: 'inv_pii_test',
              invoiceNumber: 'SI-PII-001',
              invoiceType: InvoiceType.sale,
              saleStatus: SaleStatus.completed,
              paymentMethod: PaymentMethod.cash,
              userId: 'user_admin',
              createdAt: now,
              updatedAt: now,
            ),
          );

      await db.into(db.salesInvoiceItems).insert(
            SalesInvoiceItemsCompanion.insert(
              id: 'sli_pii_test',
              invoiceId: 'inv_pii_test',
              itemId: itemId,
              batchId: batchId,
              unitTypeId: 'unit_strip',
              quantityBaseSigned: 5,
              unitPriceMicros: 20000,
              prescriptionItemId: const Value('pi_schema_check'),
              createdAt: now,
            ),
          );

      final line = await (db.select(db.salesInvoiceItems)
            ..where((l) => l.id.equals('sli_pii_test')))
          .getSingle();
      expect(line.prescriptionItemId, 'pi_schema_check');
    });
  });

  // ── TEST J: Multi-line FEFO across batches ──────────────────────────

  group('TEST J — Multi-line FEFO across batches', () {
    test('FEFO allocates from earliest-expiry batch first', () async {
      final itemId = await insertItem(db);
      final supplierId = await insertSupplier(db);

      final now = DateTime.now().millisecondsSinceEpoch;

      // Batch 1: expires in 30 days, qty 5.
      await PurchaseService().recordPurchase(
        db,
        PurchaseRequest(
          invoiceNumber: 'PI-J1',
          supplierId: supplierId,
          invoiceDate: now,
          userId: 'user_admin',
          lines: [
            PurchaseLineRequest(
              itemId: itemId,
              quantityBase: 5,
              unitCostMicros: 10000,
              unitTypeId: 'unit_strip',
              batchNumber: 'BATCH-J1-EARLY',
              expiryDate: now + 30 * 86400000,
            ),
          ],
        ),
      );

      // Batch 2: expires in 90 days, qty 5.
      await PurchaseService().recordPurchase(
        db,
        PurchaseRequest(
          invoiceNumber: 'PI-J2',
          supplierId: supplierId,
          invoiceDate: now,
          userId: 'user_admin',
          lines: [
            PurchaseLineRequest(
              itemId: itemId,
              quantityBase: 5,
              unitCostMicros: 12000,
              unitTypeId: 'unit_strip',
              batchNumber: 'BATCH-J2-LATE',
              expiryDate: now + 90 * 86400000,
            ),
          ],
        ),
      );

      // Sell 7 units — should consume all 5 from early batch + 2 from late.
      final outcome = await SaleService().recordSale(
        db,
        SaleRequest(
          invoiceNumber: 'SI-J1',
          userId: 'user_admin',
          paymentMethod: PaymentMethod.cash,
          paidMicros: 140000,
          lines: [
            SaleLineRequest(
              itemId: itemId,
              quantityBase: 7,
              unitPriceMicros: 20000,
              unitTypeId: 'unit_strip',
            ),
          ],
        ),
      );

      // Two lines: one for early batch (5), one for late batch (2).
      expect(outcome.lines, hasLength(2));

      final earlyLine = outcome.lines.firstWhere(
          (l) => l.batchId == 'batch_j1_early' || l.unitCostMicros == 10000);
      final lateLine = outcome.lines.firstWhere(
          (l) => l.batchId == 'batch_j2_late' || l.unitCostMicros == 12000);

      expect(earlyLine.quantityBaseSigned, 5);
      expect(lateLine.quantityBaseSigned, 2);

      // Stock is now 3 (5 + 5 - 7).
      final item = await (db.select(db.items)
            ..where((i) => i.id.equals(itemId)))
          .getSingle();
      expect(item.currentStockBase, 3);
    });
  });
}
