/// §18.4 exact-COGS regression for the two-mode (package + partial) pricing
/// lock.
///
/// Regression target: a box (3 base units @ box price 14,000) plus one sold
/// part (@ 5,600) is a 19,600 sale whose COGS must be derived from the
/// batched per-base-unit cost — never from the box unit cost applied to every
/// base unit (the historic 44,000 bug: 4 × 11,000 instead of 4 × 3,666.667).
///
/// Canonical money (integer micro-units, scale 4):
///    box line    gross = 140,000,000 (14,000 units × 1 sell unit)
///    part line   gross =  56,000,000 ( 5,600 units × 1 sell unit)
///    totalMicros =       196,000,000 → exactly 19,600 units, never 19,601.
///    batch cost  = Money.fromMajor(11,000).divideBy(3) = 36,666,667 /base unit
///    COGS        = 4 × 36,666,667 = 146,666,668  (≈ 14,666.667 units)
///    profit      = 196,000,000 − 146,666,668 = 49,333,332
///
/// The COGS figure is reconciled from three independent sources (invoice chain,
/// GL balance on account 5000, Income Statement projection) — same protocol as
/// the cogs forensic trace.
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:pharmacy_pos/core/constants/account_codes.dart';
import 'package:pharmacy_pos/core/money/money.dart';
import 'package:pharmacy_pos/domain/services/sale_service.dart';
import 'package:pharmacy_pos/features/reports/data/reports_dao.dart';
import 'package:pharmacy_pos/shared/database/app_database.dart';
import 'package:pharmacy_pos/shared/models/enums.dart';

import 'helpers.dart';

const _dayMillis = 24 * 60 * 60 * 1000;

void main() {
  late AppDatabase db;
  final sale = SaleService();
  late ReportsDao reports;

  setUp(() {
    db = newDatabase();
    reports = ReportsDao(db);
  });

  tearDown(() async {
    await db.close();
  });

  int perBaseCost() => Money.fromMajor(11000).divideBy(3).micros; // 36,666,667

  Future<int> cogsAccountBalance() async {
    final account =
        await (db.select(db.accounts)
              ..where((a) => a.code.equals(SystemAccountCode.costOfGoodsSold)))
            .getSingle();
    return account.balanceMicros;
  }

  test('box + part sale posts exact COGS (146,666,668) and profit (49,333,332) '
      '— never the 44,000 box-cost-per-unit bug', () async {
    final itemId = await insertItem(db);
    // One batch of 4 base units at the per-base cost (11,000 ÷ 3 half-up):
    // the box consumes its 3 parts and the extra part draws the 4th unit —
    // all at the same batched cost (4 × 36,666,667 on the way out).
    await insertBatch(
      db,
      itemId,
      quantityBase: 4,
      unitCostMicros: perBaseCost(),
    );

    final outcome = await sale.recordSale(
      db,
      SaleRequest(
        invoiceNumber: 'SI-COGS-MIXED',
        userId: 'user_admin',
        paymentMethod: PaymentMethod.cash,
        paidMicros: 196000000,
        lines: [
          // Box: 1 sell unit @ 14,000 units, consumes 3 base units for FEFO.
          SaleLineRequest(
            itemId: itemId,
            quantityBase: 3,
            quantity: 1,
            unitBaseQuantity: 3,
            unitPriceMicros: 140000000,
            unitTypeId: 'unit_box',
          ),
          // Part: 1 sell unit @ 5,600 units, consumes 1 base unit.
          SaleLineRequest(
            itemId: itemId,
            quantityBase: 1,
            quantity: 1,
            unitBaseQuantity: 1,
            unitPriceMicros: 56000000,
            unitTypeId: 'unit_part',
          ),
        ],
      ),
    );
    final invoice = outcome.invoice;

    // Sales side — the exact 19,600 / not-19,601 lock, carried to invoices.
    expect(invoice.totalMicros, 196000000); // exactly 19,600 units
    expect(invoice.totalMicros, isNot(196010000)); // never 19,601
    expect(invoice.subtotalMicros, 196000000);

    // Cost side — FEFO per-base cost, never full-box cost per unit.
    expect(invoice.totalCostMicros, 146666668);
    expect(
      invoice.totalCostMicros,
      isNot(440000000), // ¬ 4 × 11,000
      reason:
          'historic bug applied the box unit cost (11,000) to every '
          'base unit instead of the per-base cost (3,666.667)',
    );
    expect(invoice.profitMicros, 49333332);

    // Stored line money proves the two-mode lock end-to-end: the box line
    // prices per sell unit (14,000) despite consuming 3 base units.
    final stored = await (db.select(
      db.salesInvoiceItems,
    )..where((i) => i.invoiceId.equals(invoice.id))).get();
    final boxRow = stored.singleWhere((r) => r.unitTypeId == 'unit_box');
    expect(boxRow.quantityBaseSigned, 3);
    expect(boxRow.unitBaseQuantity, 3);
    expect(boxRow.unitPriceMicros, 140000000);
    expect(boxRow.lineTotalMicros, 140000000);
    final partRow = stored.singleWhere((r) => r.unitTypeId == 'unit_part');
    expect(partRow.quantityBaseSigned, 1);
    expect(partRow.unitPriceMicros, 56000000);
    expect(partRow.lineTotalMicros, 56000000);

    // ── Three-source reconciliation of COGS ─────────────────────────────
    final fromGl = await cogsAccountBalance();
    final now = DateTime.now().millisecondsSinceEpoch;
    final report = await reports.incomeStatement(
      fromMillis: 0,
      toMillis: now + _dayMillis,
    );

    expect(fromGl, 146666668);
    expect(report.costOfGoodsSoldMicros, 146666668);
    expect(fromGl, invoice.totalCostMicros);
    expect(report.costOfGoodsSoldMicros, fromGl);
    expect(report.salesRevenueMicros, 196000000);
    expect(report.salesRevenueMicros - report.costOfGoodsSoldMicros, 49333332);
  });
}
