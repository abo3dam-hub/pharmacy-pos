/// COGS forensic trace (the accounting test matrix for the cost-of-goods-sold
/// chain).
///
/// Drives the FULL canonical pipeline — SaleService → ReturnService →
/// SaleService.voidInvoice (+ FEFO cost allocation) — then reconciles the
/// COGS figure from three independent sources and proves they agree:
///
///   1. the persisted invoice `totalCostMicros` chain
///      (Σ sold − Σ returned − Σ voided costs);
///   2. the GL running balance on the COGS account (5000, `balanceMicros`);
///   3. the Income Statement `costOfGoodsSoldMicros` (computed by re-reading
///      the journal lines — a second, independent projection).
///
/// All money is integer micro-units and every reversal is proportional to the
/// stored row money (never a reconstructed `quantity × unitPrice`).
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:pharmacy_pos/core/constants/account_codes.dart';
import 'package:pharmacy_pos/domain/services/return_service.dart';
import 'package:pharmacy_pos/domain/services/sale_service.dart';
import 'package:pharmacy_pos/features/reports/data/reports_dao.dart';
import 'package:pharmacy_pos/shared/database/app_database.dart';
import 'package:pharmacy_pos/shared/models/enums.dart';

import 'helpers.dart';

const _dayMillis = 24 * 60 * 60 * 1000;

void main() {
  late AppDatabase db;
  final sale = SaleService();
  final returns = ReturnService();
  late ReportsDao reports;

  setUp(() {
    db = newDatabase();
    reports = ReportsDao(db);
  });

  tearDown(() async {
    await db.close();
  });

  Future<int> cogsAccountBalance() async {
    final account =
        await (db.select(db.accounts)
              ..where((a) => a.code.equals(SystemAccountCode.costOfGoodsSold)))
            .getSingle();
    return account.balanceMicros;
  }

  Future<int> sumInvoiceCosts() async {
    final rows = await db.select(db.salesInvoices).get();
    return rows.fold<int>(0, (s, i) => s + i.totalCostMicros);
  }

  Future<int> sumReturnedCosts() async {
    final rows = await db.select(db.returnItems).get();
    return rows.fold<int>(
      0,
      (s, r) => s + r.unitCostMicros * r.quantityBaseSigned,
    );
  }

  Future<int> sumVoidedInvoiceCosts() async {
    final rows = await (db.select(
      db.salesInvoices,
    )..where((i) => i.saleStatus.equalsValue(SaleStatus.voided))).get();
    return rows.fold<int>(0, (s, i) => s + i.totalCostMicros);
  }

  test(
    'COGS reconciles across sale + partial return + void from 3 sources',
    () async {
      final itemId = await insertItem(db);
      // Batch A: 5 × 1,000 = 5,000 · Batch B: 4 × 2,000 = 8,000.
      await insertBatch(db, itemId, quantityBase: 5, unitCostMicros: 1000);
      await insertBatch(db, itemId, quantityBase: 4, unitCostMicros: 2000);

      // SI-1: 6 base @ 4,000, VAT 10% → FEFO 5@1,000 (5,000) + 1@2,000 (2,000).
      final sale1 = await sale.recordSale(
        db,
        SaleRequest(
          invoiceNumber: 'SI-COGS-1',
          userId: 'user_admin',
          paymentMethod: PaymentMethod.cash,
          paidMicros: 26400,
          lines: [
            SaleLineRequest(
              itemId: itemId,
              quantityBase: 6,
              unitPriceMicros: 4000,
              unitTypeId: 'unit_strip',
              vatRateBasisPoints: 1000,
            ),
          ],
        ),
      );
      expect(sale1.invoice.totalCostMicros, 7000); // 5,000 + 2,000
      expect(sale1.invoice.subtotalMicros, 24000);
      expect(sale1.invoice.vatTotalMicros, 2400);
      expect(sale1.invoice.totalMicros, 26400);

      // SI-2: 2 base @ 4,000 (batch B remaining 3) → COGS 2 × 2,000 = 4,000.
      final sale2 = await sale.recordSale(
        db,
        SaleRequest(
          invoiceNumber: 'SI-COGS-2',
          userId: 'user_admin',
          paymentMethod: PaymentMethod.cash,
          paidMicros: 8000,
          lines: [
            SaleLineRequest(
              itemId: itemId,
              quantityBase: 2,
              unitPriceMicros: 4000,
              unitTypeId: 'unit_strip',
            ),
          ],
        ),
      );
      expect(sale2.invoice.totalCostMicros, 4000);

      // Partial return: 1 of SI-2's 2 units reverses 4,000 revenue / 2,000 cost
      // (proportional to the stored row money — never quantity × unitPrice).
      final si2Row = await (db.select(
        db.salesInvoiceItems,
      )..where((i) => i.invoiceId.equals(sale2.invoice.id))).getSingle();
      final returned = await returns.recordSaleReturn(
        db,
        SaleReturnRequest(
          returnNumber: 'RET-COGS-1',
          originalInvoiceItemId: si2Row.id,
          quantityBase: 1,
          userId: 'user_admin',
          reason: 'فحص دقيق لتكلفة المرتجع',
        ),
      );
      expect(returned.returnItem.amountMicros, -4000);
      expect(returned.returnItem.unitCostMicros, 2000);

      // Void SI-1 entirely → COGS reversed in full (7,000).
      await sale.voidInvoice(
        db,
        invoiceId: sale1.invoice.id,
        userId: 'user_admin',
        reason: 'إلغاء للفحص المالي',
      );
      final voided = await (db.select(
        db.salesInvoices,
      )..where((i) => i.id.equals(sale1.invoice.id))).getSingle();
      expect(voided.saleStatus, SaleStatus.voided);

      // ── Three-source reconciliation ─────────────────────────────────────
      final fromInvoices =
          await sumInvoiceCosts() -
          await sumReturnedCosts() -
          await sumVoidedInvoiceCosts();
      final fromGl = await cogsAccountBalance();
      final now = DateTime.now().millisecondsSinceEpoch;
      final report = await reports.incomeStatement(
        fromMillis: 0,
        toMillis: now + _dayMillis,
      );
      final fromIs = report.costOfGoodsSoldMicros;

      expect(fromInvoices, 2000); // 11,000 − 2,000 − 7,000
      expect(fromGl, 2000);
      expect(fromIs, 2000);
      expect(fromGl, fromInvoices);
      expect(fromIs, fromGl);

      // Income statement composition of the residual profit.
      expect(report.salesRevenueMicros, 24000 - 24000 + 8000);
      expect(report.salesReturnsMicros, 4000);
    },
  );

  test('sales-only COGS posts once and reconciles exactly', () async {
    final itemId = await insertItem(db);
    await insertBatch(db, itemId, quantityBase: 5, unitCostMicros: 1000);

    final sale1 = await sale.recordSale(
      db,
      SaleRequest(
        invoiceNumber: 'SI-COGS-3',
        userId: 'user_admin',
        paymentMethod: PaymentMethod.cash,
        paidMicros: 12000,
        lines: [
          SaleLineRequest(
            itemId: itemId,
            quantityBase: 3,
            unitPriceMicros: 4000,
            unitTypeId: 'unit_strip',
          ),
        ],
      ),
    );
    expect(sale1.invoice.totalCostMicros, 3000);
    expect(sale1.invoice.profitMicros, 12000 - 3000);

    final fromInvoices =
        await sumInvoiceCosts() -
        await sumReturnedCosts() -
        await sumVoidedInvoiceCosts();
    final fromGl = await cogsAccountBalance();
    final report = await reports.incomeStatement(
      fromMillis: 0,
      toMillis: DateTime.now().millisecondsSinceEpoch + _dayMillis,
    );

    expect(fromInvoices, 3000);
    expect(fromGl, 3000);
    expect(report.costOfGoodsSoldMicros, 3000);
    expect(report.salesRevenueMicros, 12000);
  });
}
