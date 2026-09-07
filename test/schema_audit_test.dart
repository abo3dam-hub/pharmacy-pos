import 'package:drift/drift.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pharmacy_pos/shared/database/app_database.dart';
import 'package:pharmacy_pos/shared/models/enums.dart';

import 'helpers.dart';

/// Schema audit against §4: every reference table exists, critical columns are
/// NOT NULL, the helper indexes are created, and enum/new columns round-trip.
///
/// This test pins the *physical* schema the report claims — if it starts
/// passing/failing, the schema contract has changed.
void main() {
  const expectedTables = {
    'manufacturers',
    'therapeutic_groups',
    'categories',
    'sub_categories',
    'units',
    'item_units',
    'items',
    'batches',
    'stock_movements',
    'suppliers',
    'customers',
    'customer_payments',
    'prescriptions',
    'prescription_items',
    'sales_invoices',
    'sales_invoice_items',
    'purchase_invoices',
    'purchase_invoice_items',
    'purchase_bonuses',
    'returns',
    'return_items',
    'expenses',
    'expense_categories',
    'cashbox_transactions',
    'accounts',
    'journal_entries',
    'journal_entry_lines',
    'users',
    'roles',
    'permissions',
    'role_permissions',
    'audit_logs',
    'lost_sales',
    'backups',
  };

  /// Column -> must be NOT NULL.
  const notNullColumns = <String, Map<String, bool>>{
    'items': {'category_id': true, 'trade_name': true},
    'batches': {'item_id': true, 'batch_number': true},
    'item_units': {'units_per_large': true},
    'stock_movements': {
      'movement_type': true,
      'user_id': true,
      'quantity_base_signed': true,
    },
    'sales_invoices': {'invoice_number': true, 'user_id': true},
    'sales_invoice_items': {'batch_id': true, 'unit_type_id': true},
    'purchase_invoices': {'supplier_id': true, 'user_id': true},
    'purchase_invoice_items': {'unit_type_id': true, 'quantity_base': true},
    'purchase_bonuses': {'bonus_type': true},
    'returns': {
      'original_invoice_id': true,
      'original_invoice_type': true,
      'user_id': true,
    },
    'return_items': {'original_invoice_item_id': true, 'batch_id': true},
    'expenses': {'description': true, 'user_id': true},
    'cashbox_transactions': {'user_id': true},
    'customer_payments': {
      'customer_id': true,
      'user_id': true,
      'amount_micros': true,
      'payment_method': true,
      'payment_number': true,
    },
    'journal_entries': {'is_posted': true, 'created_by': true},
    'users': {'role_id': true},
    'roles': {'name_ar': true},
    'permissions': {'name_ar': true},
    'role_permissions': {'granted': true},
    'audit_logs': {
      'user_id': true,
      'action': true,
      'entity_id': true,
    },
    'lost_sales': {'requested_item_name': true, 'user_id': true},
    'backups': {'file_name': true, 'schema_version': true},
  };

  late AppDatabase db;

  setUp(() {
    db = newDatabase();
  });

  tearDown(() async {
    await db.close();
  });

  Future<Map<String, bool>> notNullFlags(String table) async {
    final info = await db.customSelect('PRAGMA table_info("$table")').get();
    return {
      for (final row in info)
        row.data['name'] as String: (row.data['notnull'] as int) != 0,
    };
  }

  test('every §4 table exists', () async {
    final rows = await db
        .customSelect("SELECT name FROM sqlite_master WHERE type='table'")
        .get();
    final names = rows.map((r) => r.data['name'] as String).toSet();
    expect(names, containsAll(expectedTables));
  });

  test('critical columns are NOT NULL per §4', () async {
    for (final entry in notNullColumns.entries) {
      final flags = await notNullFlags(entry.key);
      for (final column in entry.value.keys) {
        expect(flags[column],
            isTrue,
            reason: '${entry.key}.$column must be NOT NULL (§4)');
      }
    }
  });

  test('required helper indexes exist', () async {
    final rows = await db
        .customSelect(
            "SELECT name FROM sqlite_master WHERE type='index'")
        .get();
    final names = rows.map((r) => r.data['name'] as String).toSet();
    expect(names, contains('idx_batches_item_expiry'));
    expect(names, contains('idx_stock_movements_item_created'));
    expect(names, contains('idx_stock_movements_batch_created'));
    expect(names, contains('idx_sales_items_invoice'));
    expect(names, contains('idx_sales_items_original'));
    expect(names, contains('idx_returns_original'));
    expect(names, contains('idx_audit_entity'));
    expect(names, contains('idx_backups_created'));
  });

  test('enum persistence round-trips snake_case stored values', () async {
    final itemId = await insertItem(db);
    final now = DateTime.now().millisecondsSinceEpoch;
    await db.into(db.stockMovements).insert(StockMovementsCompanion.insert(
          id: 'mov_r1',
          itemId: itemId,
          movementType: MovementType.opening_balance,
          quantityBaseSigned: 5,
          quantityBaseAfter: 5,
          unitCostMicros: 100,
          userId: 'user_admin',
          createdAt: now,
        ));
    final row = await (db.select(db.stockMovements)
          ..where((m) => m.id.equals('mov_r1')))
        .getSingle();
    expect(row.movementType, MovementType.opening_balance);
    expect(row.movementType.name, 'opening_balance');
    final raw = await db
        .customSelect(
            "SELECT movement_type FROM stock_movements WHERE id='mov_r1'")
        .getSingle();
    expect(raw.data['movement_type'], 'opening_balance');
  });

  test('invoice_type persists the plan literal return for return invoices',
      () async {
    final now = DateTime.now().millisecondsSinceEpoch;
    await db.into(db.salesInvoices).insert(SalesInvoicesCompanion.insert(
          id: 'inv_r1',
          invoiceNumber: 'SI-RET',
          invoiceType: InvoiceType.return_invoice,
          saleStatus: SaleStatus.completed,
          paymentMethod: PaymentMethod.cash,
          userId: 'user_admin',
          paidMicros: const Value(0),
          createdAt: now,
          updatedAt: now,
        ));
    final raw = await db
        .customSelect(
            "SELECT invoice_type FROM sales_invoices WHERE id='inv_r1'")
        .getSingle();
    expect(raw.data['invoice_type'], 'return');
    final readBack = await (db.select(db.salesInvoices)
          ..where((i) => i.id.equals('inv_r1')))
        .getSingle();
    expect(readBack.invoiceType, InvoiceType.return_invoice);
  });
}