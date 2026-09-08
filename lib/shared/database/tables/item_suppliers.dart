import 'package:drift/drift.dart';
import 'items.dart';
import 'suppliers.dart';

/// Many-to-many link between an item and its preferred suppliers (§12).
///
/// A product can be procured from several suppliers; this junction keeps the
/// historical purchase chain (`batches.supplier_id`,
/// `purchase_invoices.supplier_id`) untouched and adds a per-item supplier
/// registry used by the product form. The composite `(itemId, supplierId)`
/// unique key prevents duplicates at the schema level.
@DataClassName('ItemSupplierRow')
@TableIndex(name: 'idx_item_suppliers_item', columns: {#itemId})
@TableIndex(name: 'idx_item_suppliers_supplier', columns: {#supplierId})
class ItemSuppliers extends Table {
  TextColumn get id => text()();
  TextColumn get itemId => text().references(Items, #id)();
  TextColumn get supplierId => text().references(Suppliers, #id)();

  @override
  Set<Column> get primaryKey => {id};

  @override
  List<Set<Column>> get uniqueKeys => [
        {itemId, supplierId},
      ];
}