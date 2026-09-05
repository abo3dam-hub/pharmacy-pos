import 'dart:ffi';

import 'package:drift/drift.dart';
import 'package:pharmacy_pos/domain/services/stock_service.dart';
import 'package:pharmacy_pos/shared/database/app_database.dart';
import 'package:pharmacy_pos/shared/models/enums.dart';
import 'package:sqlite3/open.dart' as sqlite3_open;
import 'package:uuid/uuid.dart';

final _uuid = const Uuid();

/// The CI/host image only ships `libsqlite3.so.0`; wire it up for VM tests.
void _useSystemSqlite() {
  sqlite3_open.open.overrideFor(sqlite3_open.OperatingSystem.linux, () {
    return DynamicLibrary.open('libsqlite3.so.0');
  });
}

AppDatabase newDatabase() {
  _useSystemSqlite();
  return AppDatabase.forTesting();
}

Future<String> insertItem(
  AppDatabase db, {
  String barcode = '6291041500213',
  String? id,
}) {
  final now = DateTime.now().millisecondsSinceEpoch;
  final itemId = id ?? 'item_${_uuid.v4()}';
  return db.into(db.items).insert(
        ItemsCompanion.insert(
          id: itemId,
          primaryBarcode: barcode,
          tradeName: 'بانادول',
          tradeNameEn: Value('Panadol'),
          scientificName: Value('Paracetamol'),
          createdAt: now,
          updatedAt: now,
        ),
      ).then((_) => itemId);
}

Future<String> insertSupplier(AppDatabase db, {String name = 'المورد الأساسي'}) {
  final now = DateTime.now().millisecondsSinceEpoch;
  final id = 'sup_${_uuid.v4()}';
  return db.into(db.suppliers).insert(
        SuppliersCompanion.insert(
          id: id,
          name: name,
          createdAt: now,
          updatedAt: now,
        ),
      ).then((_) => id);
}

/// Creates a batch for [itemId] with a quantity and expiry [expiryDays] from
/// today (negative = already expired) and a unit cost in micro-units. The
/// quantity is seeded through the stock ledger so caches stay consistent.
Future<String> insertBatch(
  AppDatabase db,
  String itemId, {
  int quantityBase = 10,
  required int expiryDays,
  int unitCostMicros = 10000,
  String? batchNumber,
}) async {
  final now = DateTime.now().millisecondsSinceEpoch;
  final id = 'bat_${_uuid.v4()}';
  final no = batchNumber ?? id.replaceAll('_', '');
  await db.into(db.batches).insert(
        BatchesCompanion.insert(
          id: id,
          itemId: itemId,
          batchNumber: no,
          expiryDate: now + expiryDays * 24 * 60 * 60 * 1000,
          originalQuantityBase: quantityBase,
          unitCostMicros: Value(unitCostMicros),
          createdAt: now,
          updatedAt: now,
        ),
      );
  await const StockService().applyMovement(
    db,
    itemId: itemId,
    batchId: id,
    movementType: MovementType.purchase,
    quantityBaseSigned: quantityBase,
    unitCostMicros: unitCostMicros,
    refType: 'test_seed',
    refId: id,
    note: 'seeded test batch',
    atMillis: now,
  );
  return id;
}