import 'package:drift/drift.dart';
import '../../models/enums.dart';
import 'suppliers.dart';
import 'users.dart';

/// Purchase invoice header (§4.16, §12). `expectedDate` maps to the plan's
/// `expected_date`; `receivedDate` stores when goods were received.
@DataClassName('PurchaseInvoiceRow')
@TableIndex(name: 'idx_purchase_invoices_supplier', columns: {#supplierId})
@TableIndex(name: 'idx_purchase_invoices_user', columns: {#userId})
@TableIndex(name: 'idx_purchase_invoices_date', columns: {#invoiceDate})
@TableIndex(name: 'idx_purchase_invoices_status', columns: {#purchaseStatus})
class PurchaseInvoices extends Table {
  TextColumn get id => text()();
  TextColumn get invoiceNumber => text().unique()();
  TextColumn get purchaseStatus => textEnum<PurchaseStatus>()();
  TextColumn get supplierId => text().references(Suppliers, #id)();
  TextColumn get userId => text().references(Users, #id)();
  IntColumn get invoiceDate => integer()();
  IntColumn get expectedDate => integer().nullable()();
  IntColumn get receivedDate => integer().nullable()();
  IntColumn get subtotalMicros => integer().withDefault(const Constant(0))();
  IntColumn get discountTotalMicros => integer().withDefault(const Constant(0))();
  IntColumn get taxTotalMicros => integer().withDefault(const Constant(0))();
  IntColumn get shippingMicros => integer().withDefault(const Constant(0))();
  IntColumn get totalMicros => integer().withDefault(const Constant(0))();
  IntColumn get paidMicros => integer().withDefault(const Constant(0))();
  IntColumn get remainingMicros => integer().withDefault(const Constant(0))();
  TextColumn get notes => text().nullable()();
  BoolColumn get isVoided => boolean().withDefault(const Constant(false))();
  IntColumn get createdAt => integer()();
  IntColumn get updatedAt => integer()();

  @override
  Set<Column> get primaryKey => {id};
}