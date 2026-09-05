import 'package:drift/drift.dart';
import 'items.dart';
import 'sales_invoices.dart';

/// Sales / hybrid return line.
///
/// quantity_base_signed > 0 for sold goods, < 0 for returned goods within the
/// same invoice (hybrid invoice). Never mixes signs within one line.
@DataClassName('SalesInvoiceItemRow')
@TableIndex(name: 'idx_sales_items_invoice', columns: {#invoiceId})
@TableIndex(name: 'idx_sales_items_item', columns: {#itemId})
class SalesInvoiceItems extends Table {
  TextColumn get id => text()();
  TextColumn get invoiceId => text().references(SalesInvoices, #id)();
  TextColumn get itemId => text().references(Items, #id)();

  /// For return lines, the original sold line being reversed.
  TextColumn get originalInvoiceItemId =>
      text().nullable().references(SalesInvoiceItems, #id)();

  IntColumn get quantityBaseSigned => integer()();
  IntColumn get unitPriceMicros => integer()();
  IntColumn get vatRateBasisPoints => integer().withDefault(const Constant(0))();
  IntColumn get lineDiscountBasisPoints =>
      integer().withDefault(const Constant(0))();
  IntColumn get lineSubtotalMicros => integer().withDefault(const Constant(0))();
  IntColumn get lineDiscountMicros => integer().withDefault(const Constant(0))();
  IntColumn get lineTotalMicros => integer().withDefault(const Constant(0))();

  IntColumn get unitCostMicros => integer().withDefault(const Constant(0))();
  IntColumn get costTotalMicros => integer().withDefault(const Constant(0))();
  IntColumn get profitMicros => integer().withDefault(const Constant(0))();

  /// Cumulative quantity (base units) already returned against this line.
  IntColumn get returnQuantityBase => integer().withDefault(const Constant(0))();
  IntColumn get createdAt => integer()();

  @override
  Set<Column> get primaryKey => {id};
}