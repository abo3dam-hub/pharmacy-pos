import 'package:drift/drift.dart';
import '../../models/enums.dart';
import 'customers.dart';
import 'suppliers.dart';
import 'users.dart';

/// Standalone return documents (§4.19, §14). Hybrid return invoices
/// (sale + return in one invoice) additionally use signed
/// `sales_invoice_items`; both share the same batch-restore and reversal rules.
@DataClassName('ReturnRow')
@TableIndex(name: 'idx_returns_original', columns: {#originalInvoiceId})
@TableIndex(name: 'idx_returns_type', columns: {#type})
class Returns extends Table {
  TextColumn get id => text()();
  TextColumn get returnNumber => text().unique()();
  TextColumn get type => textEnum<ReturnType>()();

  /// The sale or purchase invoice being returned.
  TextColumn get originalInvoiceId => text()();

  /// 'sale' | 'purchase' — which invoice family the original belongs to.
  TextColumn get originalInvoiceType => text()();

  TextColumn get customerId =>
      text().nullable().references(Customers, #id)();
  TextColumn get supplierId =>
      text().nullable().references(Suppliers, #id)();
  TextColumn get userId => text().references(Users, #id)();

  /// Signed total; negative means money returned to the customer.
  IntColumn get totalMicros => integer().withDefault(const Constant(0))();

  /// Defaults to 'completed'; 'voided' on cancellation.
  TextColumn get status => text().withDefault(const Constant('completed'))();

  TextColumn get reason => text().nullable()();
  TextColumn get notes => text().nullable()();
  BoolColumn get isVoided => boolean().withDefault(const Constant(false))();
  IntColumn get createdAt => integer()();
  IntColumn get updatedAt => integer()();

  @override
  Set<Column> get primaryKey => {id};
}