import 'package:drift/drift.dart';
import '../../models/enums.dart';
import 'batches.dart';
import 'items.dart';
import 'purchase_invoice_items.dart';
import 'purchase_invoices.dart';

/// Bonus quantities granted with a purchase (§4.18, §13) — e.g. Bonus 1,
/// Bonus 2, Gift; more rows can be added without schema changes. `itemId` is
/// NULL when the bonus is for the *purchased* item; set it to model a future
/// Buy A Get B (different item).
@DataClassName('PurchaseBonusRow')
@TableIndex(name: 'idx_purchase_bonuses_line', columns: {#purchaseInvoiceItemId})
@TableIndex(name: 'idx_purchase_bonuses_type', columns: {#bonusType})
@TableIndex(name: 'idx_purchase_bonuses_item', columns: {#itemId})
class PurchaseBonuses extends Table {
  TextColumn get id => text()();
  TextColumn get purchaseInvoiceId =>
      text().references(PurchaseInvoices, #id)();
  TextColumn get purchaseInvoiceItemId =>
      text().references(PurchaseInvoiceItems, #id)();
  TextColumn get itemId => text().nullable().references(Items, #id)();
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