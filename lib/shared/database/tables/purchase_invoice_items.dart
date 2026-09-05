import 'package:drift/drift.dart';
import 'batches.dart';
import 'items.dart';
import 'purchase_invoices.dart';
import 'units.dart';

/// A purchase line's *paid* quantity and cost plus the bonus-adjusted
/// effective figures used to seed batches and costing (§4.17, §13).
/// `batchId` is NULL until the purchase is received.
@DataClassName('PurchaseInvoiceItemRow')
@TableIndex(name: 'idx_purchase_items_invoice', columns: {#invoiceId})
@TableIndex(name: 'idx_purchase_items_item', columns: {#itemId})
@TableIndex(name: 'idx_purchase_items_batch', columns: {#batchId})
class PurchaseInvoiceItems extends Table {
  TextColumn get id => text()();
  TextColumn get invoiceId => text().references(PurchaseInvoices, #id)();
  TextColumn get itemId => text().references(Items, #id)();

  /// Batch created on receive (§4.17); NULL while pending.
  TextColumn get batchId => text().nullable().references(Batches, #id)();

  /// Unit type at purchase time (box/strip/…).
  TextColumn get unitTypeId => text().references(Units, #id)();

  /// Paid (billed) quantity in base units.
  IntColumn get quantityBase => integer()();

  IntColumn get unitCostMicros => integer()();
  IntColumn get discountBasisPoints => integer().withDefault(const Constant(0))();
  IntColumn get lineDiscountMicros => integer().withDefault(const Constant(0))();

  /// VAT amount in money units for this line.
  IntColumn get taxMicros => integer().withDefault(const Constant(0))();

  /// (unit_cost*qty) − discount for the paid portion.
  IntColumn get lineTotalMicros => integer()();

  /// Paid + bonus quantity in base units (effective).
  IntColumn get effectiveQuantityBase => integer()();
  IntColumn get effectiveUnitCostMicros => integer()();
  IntColumn get bonusQuantityBase => integer().withDefault(const Constant(0))();
  TextColumn get notes => text().nullable()();
  IntColumn get createdAt => integer()();

  @override
  Set<Column> get primaryKey => {id};

  @override
  List<String> get customConstraints => [
        'CHECK (quantity_base > 0)',
        'CHECK (effective_quantity_base > 0)',
      ];
}