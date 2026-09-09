/// Aggregated, real-data dashboard model (§16 P16 dashboard milestone).
///
/// One snapshot per render pulled straight from persisted tables: sales come
/// from the Z-Report window (canonical non-draft / non-voided semantics), stock
/// alerts from the items + batches tables, and the counters from id queries.
class DashboardSnapshot {
  const DashboardSnapshot({
    required this.generatedMillis,
    required this.todayInvoiceCount,
    required this.todayUnitsSold,
    required this.todayTotalMicros,
    required this.todayPaidMicros,
    required this.todayProfitMicros,
    required this.activeItems,
    required this.customers,
    required this.suppliers,
    required this.totalStockBase,
    required this.stockValueMicros,
    required this.lowStockCount,
    required this.outOfStockCount,
    required this.lowStockItems,
    required this.nearExpiryBatches,
    required this.recentSales,
    required this.recentPurchases,
  });

  final int generatedMillis;
  final int todayInvoiceCount;
  final int todayUnitsSold;
  final int todayTotalMicros;
  final int todayPaidMicros;
  final int todayProfitMicros;
  final int activeItems;
  final int customers;
  final int suppliers;
  final int totalStockBase;
  final int stockValueMicros;
  final int lowStockCount;
  final int outOfStockCount;
  final List<LowStockItem> lowStockItems;
  final List<NearExpiryBatch> nearExpiryBatches;
  final List<RecentInvoice> recentSales;
  final List<RecentInvoice> recentPurchases;
}

/// Product at or below its reorder point.
class LowStockItem {
  const LowStockItem({
    required this.itemId,
    required this.name,
    required this.barcode,
    required this.currentStockBase,
    required this.minimumStockBase,
  });

  final String itemId;
  final String name;
  final String? barcode;
  final int currentStockBase;
  final int minimumStockBase;
}

/// Batch expiring within the near-expiry window (90 days) with stock on hand.
class NearExpiryBatch {
  const NearExpiryBatch({
    required this.itemId,
    required this.itemName,
    required this.batchId,
    required this.batchNumber,
    required this.expiryDate,
    required this.quantityBase,
  });

  final String itemId;
  final String itemName;
  final String batchId;
  final String? batchNumber;
  final int expiryDate;
  final int quantityBase;
}

/// Most recent invoice (sale or purchase) for the activity feed.
class RecentInvoice {
  const RecentInvoice({
    required this.number,
    required this.atMillis,
    required this.totalMicros,
  });

  final String number;
  final int atMillis;
  final int totalMicros;
}