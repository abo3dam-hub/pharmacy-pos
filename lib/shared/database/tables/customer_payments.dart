import 'package:drift/drift.dart';
import '../../models/enums.dart';
import 'customers.dart';
import 'sales_invoices.dart';
import 'users.dart';

/// Customer payments / refunds on account (كشوف الحسابات, §13, §18). A
/// positive [amountMicros] money received from the customer (reduces their
/// balance); a negative one money refunded to the customer (increases the
/// balance back). The cash/card split mirrors the received/payable mix.
@DataClassName('CustomerPaymentRow')
@TableIndex(name: 'idx_customer_payments_customer', columns: {#customerId})
@TableIndex(name: 'idx_customer_payments_date', columns: {#createdAt})
class CustomerPayments extends Table {
  TextColumn get id => text()();
  TextColumn get paymentNumber => text().unique()();

  TextColumn get customerId => text().references(Customers, #id)();

  /// Optional invoice this payment is allocated against (§14.13). Nullable so
  /// open-account settlements are also supported.
  TextColumn get invoiceId =>
      text().nullable().references(SalesInvoices, #id)();

  /// Signed: positive = money received, negative = refund issued.
  IntColumn get amountMicros => integer()();

  IntColumn get cashMicros => integer().withDefault(const Constant(0))();
  IntColumn get cardMicros => integer().withDefault(const Constant(0))();
  TextColumn get paymentMethod => textEnum<PaymentMethod>()();

  TextColumn get note => text().nullable()();
  BoolColumn get isVoided => boolean().withDefault(const Constant(false))();
  TextColumn get voidReason => text().nullable()();
  TextColumn get userId => text().references(Users, #id)();
  IntColumn get createdAt => integer()();
  IntColumn get updatedAt => integer()();

  @override
  Set<Column> get primaryKey => {id};

  @override
  List<String> get customConstraints => [
        'CHECK (amount_micros != 0)',
      ];
}