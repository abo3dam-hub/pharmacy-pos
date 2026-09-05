import 'package:drift/drift.dart';
import '../../models/enum_value_converter.dart';
import '../../models/enums.dart';
import 'customers.dart';
import 'users.dart';

/// Sales invoice header (§4.14, §11). `userId` (the cashier) is NOT NULL;
/// `customerId` is nullable so walk-in cash sales proceed without a customer.
@DataClassName('SalesInvoiceRow')
@TableIndex(name: 'idx_sales_invoices_customer', columns: {#customerId})
@TableIndex(name: 'idx_sales_invoices_user', columns: {#userId})
@TableIndex(name: 'idx_sales_invoices_date', columns: {#createdAt})
@TableIndex(name: 'idx_sales_invoices_status', columns: {#saleStatus})
class SalesInvoices extends Table {
  TextColumn get id => text()();
  TextColumn get invoiceNumber => text().unique()();

  /// Stored plan values: 'sale' | 'hybrid' | 'return' (§4.14).
  TextColumn get invoiceType =>
      text().map(invoiceTypeValues)();
  TextColumn get saleStatus => textEnum<SaleStatus>()();

  /// Source invoice when this is a return / hybrid-of-an-invoice.
  TextColumn get originalInvoiceId =>
      text().nullable().references(SalesInvoices, #id)();
  TextColumn get customerId =>
      text().nullable().references(Customers, #id)();
  TextColumn get userId => text().references(Users, #id)();

  IntColumn get subtotalMicros => integer().withDefault(const Constant(0))();
  IntColumn get discountTotalMicros => integer().withDefault(const Constant(0))();
  IntColumn get vatTotalMicros => integer().withDefault(const Constant(0))();
  IntColumn get totalMicros => integer().withDefault(const Constant(0))();
  IntColumn get totalCostMicros => integer().withDefault(const Constant(0))();
  IntColumn get profitMicros => integer().withDefault(const Constant(0))();

  TextColumn get paymentMethod => textEnum<PaymentMethod>()();
  IntColumn get paidMicros => integer().withDefault(const Constant(0))();
  IntColumn get changeMicros => integer().withDefault(const Constant(0))();

  /// Remaining balance (credit customers) = total − paid, §4.14.
  IntColumn get remainingMicros => integer().withDefault(const Constant(0))();

  TextColumn get notes => text().nullable()();
  TextColumn get voidReason => text().nullable()();
  IntColumn get createdAt => integer()();
  IntColumn get updatedAt => integer()();

  @override
  Set<Column> get primaryKey => {id};
}