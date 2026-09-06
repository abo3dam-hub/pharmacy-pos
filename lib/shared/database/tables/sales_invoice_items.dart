import 'package:drift/drift.dart';
import 'batches.dart';
import 'items.dart';
import 'prescription_items.dart';
import 'sales_invoices.dart';
import 'units.dart';

/// Sales / hybrid return line (§4.15, §14).
///
/// quantity_base_signed > 0 for sold goods, < 0 for returned goods within the
/// same invoice (hybrid invoice). Every positive line is linked to the exact
/// batch sold from (FEFO); a return line additionally references the original
/// invoice line via [originalInvoiceItemId].
@DataClassName('SalesInvoiceItemRow')
@TableIndex(name: 'idx_sales_items_invoice', columns: {#invoiceId})
@TableIndex(name: 'idx_sales_items_item', columns: {#itemId})
@TableIndex(name: 'idx_sales_items_batch', columns: {#batchId})
@TableIndex(name: 'idx_sales_items_original', columns: {#originalInvoiceItemId})
class SalesInvoiceItems extends Table {
  TextColumn get id => text()();
  TextColumn get invoiceId => text().references(SalesInvoices, #id)();
  TextColumn get itemId => text().references(Items, #id)();

  /// The batch sold from (FEFO); also the restoration target for returns.
  TextColumn get batchId => text().references(Batches, #id)();

  /// Unit type at sell time (box/strip/…), §4.15.
  TextColumn get unitTypeId => text().references(Units, #id)();

  /// For return lines, the original sold line being reversed.
  TextColumn get originalInvoiceItemId =>
      text().nullable().references(SalesInvoiceItems, #id)();

  /// Linked prescription item when dispensed from RX (Phase 6 §4.15).
  TextColumn get prescriptionItemId =>
      text().nullable().references(PrescriptionItems, #id)();

  IntColumn get quantityBaseSigned => integer()();
  IntColumn get unitPriceMicros => integer()();
  IntColumn get vatRateBasisPoints => integer().withDefault(const Constant(0))();
  IntColumn get lineDiscountBasisPoints =>
      integer().withDefault(const Constant(0))();
  IntColumn get lineSubtotalMicros => integer().withDefault(const Constant(0))();
  IntColumn get lineDiscountMicros => integer().withDefault(const Constant(0))();

  /// VAT amount in money units for this line.
  IntColumn get taxMicros => integer().withDefault(const Constant(0))();
  IntColumn get lineTotalMicros => integer().withDefault(const Constant(0))();

  IntColumn get unitCostMicros => integer().withDefault(const Constant(0))();
  IntColumn get costTotalMicros => integer().withDefault(const Constant(0))();
  IntColumn get profitMicros => integer().withDefault(const Constant(0))();

  /// Cumulative quantity (base units) already returned against this line.
  IntColumn get returnQuantityBase => integer().withDefault(const Constant(0))();
  TextColumn get notes => text().nullable()();
  IntColumn get createdAt => integer()();

  @override
  Set<Column> get primaryKey => {id};
}