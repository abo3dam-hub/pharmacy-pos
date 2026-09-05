import 'package:drift/drift.dart';
import '../../models/enums.dart';
import 'batches.dart';
import 'items.dart';
import 'purchase_invoice_items.dart';
import 'purchase_invoices.dart';

/// Bonus quantities granted with a purchase (e.g. buy 100 strips get 10).
@DataClassName('PurchaseBonusRow')
@TableIndex(name: 'idx_purchase_bonuses_invoice', columns: {#purchaseInvoiceId})
class PurchaseBonuses extends Table {
  TextColumn get id => text()();
  TextColumn get purchaseInvoiceId =>
      text().references(PurchaseInvoices, #id)();
  TextColumn get purchaseInvoiceItemId =>
      text().references(PurchaseInvoiceItems, #id)();
  TextColumn get itemId => text().references(Items, #id)();
  TextColumn get batchId => text().nullable().references(Batches, #id)();
  IntColumn get bonusQuantityBase => integer()();
  IntColumn get unitCostMicros => integer()();
  TextColumn get bonusType => textEnum<PurchaseBonusType>()();
  TextColumn get note => text().nullable()();
  IntColumn get createdAt => integer()();

  @override
  Set<Column> get primaryKey => {id};

  @override
  List<String> get customConstraints => [
        'CHECK (bonus_quantity_base > 0)',
      ];
}