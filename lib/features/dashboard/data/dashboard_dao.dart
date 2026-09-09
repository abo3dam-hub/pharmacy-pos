import 'package:drift/drift.dart';

import '../../../shared/database/app_database.dart';
import '../../../shared/models/enums.dart';
import '../domain/entities/dashboard_snapshot.dart';

/// Read-model queries behind the dashboard. All values come directly from the
/// persisted tables; sales totals are supplied by the caller from the Z-Report
/// window so draft/void semantics stay consistent with the sales module.
class DashboardDao {
  const DashboardDao(this._db);

  final AppDatabase _db;

  /// Near-expiry window in days (aligns with `nearExpiryDays` in the
  /// inventory domain).
  static const int nearExpiryDays = 90;

  Future<DashboardSnapshot> load({
    required int nowMillis,
    required int fromMillis,
    required int toMillis,
    required int todayInvoiceCount,
    required int todayUnitsSold,
    required int todayTotalMicros,
    required int todayPaidMicros,
    int lowStockLimit = 8,
    int nearExpiryLimit = 8,
    int recentLimit = 6,
  }) async {
    final activeItems = await _countActiveItems();
    final customers = await _countCustomers();
    final suppliers = await _countSuppliers();
    final totals = await _inventoryTotals();
    final lowStockCount = await _countLowStock();
    final outOfStockCount = await _countOutOfStock();
    final lowStockItems =
        await _lowStockItems(limit: lowStockLimit);
    final nearExpiryBatches =
        await _nearExpiry(now: nowMillis, limit: nearExpiryLimit);
    final recentSales = await _recentSales(limit: recentLimit);
    final recentPurchases = await _recentPurchases(limit: recentLimit);
    final todayProfitMicros =
        await _todayProfit(fromMillis: fromMillis, toMillis: toMillis);

    return DashboardSnapshot(
      generatedMillis: nowMillis,
      todayInvoiceCount: todayInvoiceCount,
      todayUnitsSold: todayUnitsSold,
      todayTotalMicros: todayTotalMicros,
      todayPaidMicros: todayPaidMicros,
      todayProfitMicros: todayProfitMicros,
      activeItems: activeItems,
      customers: customers,
      suppliers: suppliers,
      totalStockBase: totals.stockBase,
      stockValueMicros: totals.valueMicros,
      lowStockCount: lowStockCount,
      outOfStockCount: outOfStockCount,
      lowStockItems: lowStockItems,
      nearExpiryBatches: nearExpiryBatches,
      recentSales: recentSales,
      recentPurchases: recentPurchases,
    );
  }

  Future<int> _todayProfit({
    required int fromMillis,
    required int toMillis,
  }) async {
    final invoices = _db.salesInvoices;
    final row = await (_db.selectOnly(invoices)
          ..addColumns([invoices.profitMicros.sum()])
          ..where(invoices.createdAt.isBiggerOrEqualValue(fromMillis))
          ..where(invoices.createdAt.isSmallerOrEqualValue(toMillis))
          ..where(invoices.saleStatus.equals(SaleStatus.draft.name).not())
          ..where(invoices.voidedAt.isNull()))
        .getSingle();
    return (row.read(invoices.profitMicros.sum()) ?? 0);
  }

  Future<int> _countActiveItems() async {
    final row = await (_db.selectOnly(_db.items)
          ..addColumns([_db.items.id.count()])
          ..where(_db.items.isActive.equals(true)))
        .getSingle();
    return (row.read(_db.items.id.count()) ?? 0);
  }

  Future<int> _countCustomers() async {
    final row = await (_db.selectOnly(_db.customers)
          ..addColumns([_db.customers.id.count()])
          ..where(_db.customers.isActive.equals(true)))
        .getSingle();
    return (row.read(_db.customers.id.count()) ?? 0);
  }

  Future<int> _countSuppliers() async {
    final row = await (_db.selectOnly(_db.suppliers)
          ..addColumns([_db.suppliers.id.count()])
          ..where(_db.suppliers.isActive.equals(true)))
        .getSingle();
    return (row.read(_db.suppliers.id.count()) ?? 0);
  }

  Future<({int stockBase, int valueMicros})> _inventoryTotals() async {
    final stock = await (_db.selectOnly(_db.items)
          ..addColumns([_db.items.currentStockBase.sum()])
          ..where(_db.items.currentStockBase.isBiggerThanValue(0)))
        .getSingle();
    final value = await (_db.selectOnly(_db.batches)
          ..addColumns([
            (_db.batches.quantityBase * _db.batches.unitCostMicros).sum()
          ])
          ..where(_db.batches.quantityBase.isBiggerThanValue(0))..where(
            _db.batches.isVoided.equals(false)))
        .getSingle();
    return (
      stockBase: (stock.read(_db.items.currentStockBase.sum()) ?? 0),
      valueMicros:
          (value.read((_db.batches.quantityBase * _db.batches.unitCostMicros)
                  .sum()) ??
              0),
    );
  }

  Future<int> _countLowStock() async {
    final row = await (_db.selectOnly(_db.items)
          ..addColumns([_db.items.id.count()])
          ..where(_db.items.isActive.equals(true))
          ..where(_db.items.minimumStockBase.isBiggerThanValue(0))
          ..where(
              _db.items.currentStockBase.isSmallerThan(_db.items.minimumStockBase)))
        .getSingle();
    return (row.read(_db.items.id.count()) ?? 0);
  }

  Future<int> _countOutOfStock() async {
    final row = await (_db.selectOnly(_db.items)
          ..addColumns([_db.items.id.count()])
          ..where(_db.items.isActive.equals(true))
          ..where(_db.items.currentStockBase.isSmallerOrEqualValue(0)))
        .getSingle();
    return (row.read(_db.items.id.count()) ?? 0);
  }

  Future<List<LowStockItem>> _lowStockItems({required int limit}) async {
    final rows = await (_db.select(_db.items)
          ..where((i) => i.isActive.equals(true))
          ..where((i) => i.minimumStockBase.isBiggerThanValue(0))
          ..where((i) => i.currentStockBase.isSmallerThan(i.minimumStockBase))
          ..orderBy([(i) => OrderingTerm.asc(i.currentStockBase)])
          ..limit(limit))
        .get();
    return [
      for (final row in rows)
        LowStockItem(
          itemId: row.id,
          name: row.tradeName,
          barcode: row.primaryBarcode,
          currentStockBase: row.currentStockBase,
          minimumStockBase: row.minimumStockBase,
        ),
    ];
  }

  Future<List<NearExpiryBatch>> _nearExpiry({
    required int now,
    required int limit,
  }) async {
    final horizon = now + nearExpiryDays * 24 * 60 * 60 * 1000;
    final items = _db.items;
    final batches = _db.batches;
    final rows = await (_db.select(items).join([
      innerJoin(batches, batches.itemId.equalsExp(items.id)),
    ])
          ..where(batches.expiryDate.isNotNull())
          ..where(batches.expiryDate.isBiggerOrEqualValue(now))
          ..where(batches.expiryDate.isSmallerOrEqualValue(horizon))
          ..where(batches.quantityBase.isBiggerThanValue(0))
          ..where(batches.isVoided.equals(false))
          ..orderBy([OrderingTerm.asc(batches.expiryDate)])
          ..limit(limit))
        .get();
    return [
      for (final r in rows)
        NearExpiryBatch(
          itemId: r.readTable(items).id,
          itemName: r.readTable(items).tradeName,
          batchId: r.readTable(batches).id,
          batchNumber: r.readTable(batches).batchNumber,
          expiryDate: r.readTable(batches).expiryDate!,
          quantityBase: r.readTable(batches).quantityBase,
        ),
    ];
  }

  Future<List<RecentInvoice>> _recentSales({required int limit}) async {
    final invoices = _db.salesInvoices;
    final rows = await (_db.select(invoices)
          ..where((i) => i.saleStatus.equals(SaleStatus.draft.name).not())
          ..where((i) => i.voidedAt.isNull())
          ..orderBy([(i) => OrderingTerm.desc(i.createdAt)])
          ..limit(limit))
        .get();
    return [
      for (final row in rows)
        RecentInvoice(
          number: row.invoiceNumber,
          atMillis: row.createdAt,
          totalMicros: row.totalMicros,
        ),
    ];
  }

  Future<List<RecentInvoice>> _recentPurchases({required int limit}) async {
    final invoices = _db.purchaseInvoices;
    final rows = await (_db.select(invoices)
          ..where((i) => i.isVoided.equals(false))
          ..orderBy([(i) => OrderingTerm.desc(i.createdAt)])
          ..limit(limit))
        .get();
    return [
      for (final row in rows)
        RecentInvoice(
          number: row.invoiceNumber,
          atMillis: row.createdAt,
          totalMicros: row.totalMicros,
        ),
    ];
  }
}