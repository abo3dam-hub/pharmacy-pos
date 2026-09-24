import 'package:drift/drift.dart';

import '../../../../shared/database/app_database.dart';
import '../entities/reorder_suggestion.dart';

/// Computes velocity-based reorder suggestions.
///
/// For each active item it measures the average daily sales over
/// [analysisDays], compares it with the current on-hand stock, and suggests
/// a purchase quantity that restores [targetDays] of cover.
class ReorderSuggestionsService {
  ReorderSuggestionsService(this._db);

  final AppDatabase _db;

  /// Days of sales history used to measure velocity.
  static const int analysisDays = 30;

  /// Suggest reordering when cover drops below this.
  static const double warningDays = 14;

  /// Critical when cover drops below this (or stock is zero).
  static const double criticalDays = 7;

  /// Suggested quantity restores this many days of cover.
  static const double targetDays = 30;

  Future<List<ReorderSuggestion>> suggestions() async {
    final sinceMs = DateTime.now()
        .subtract(const Duration(days: analysisDays))
        .millisecondsSinceEpoch;

    // Velocity per item: total base units sold in the window.
    final velocityQuery = _db.selectOnly(_db.salesInvoiceItems)
      ..addColumns([
        _db.salesInvoiceItems.itemId,
        _db.salesInvoiceItems.quantityBaseSigned.sum(),
      ])
      ..where(
        _db.salesInvoiceItems.createdAt.isBiggerOrEqualValue(sinceMs) &
            _db.salesInvoiceItems.quantityBaseSigned.isBiggerThanValue(0),
      )
      ..groupBy([_db.salesInvoiceItems.itemId]);
    final velocityRows = await velocityQuery.get();
    final velocity = <String, int>{};
    for (final row in velocityRows) {
      final itemId = row.read(_db.salesInvoiceItems.itemId)!;
      final total = row.read(_db.salesInvoiceItems.quantityBaseSigned.sum());
      velocity[itemId] = total ?? 0;
    }

    // Current on-hand per item (non-voided batches).
    final stockQuery = _db.selectOnly(_db.batches)
      ..addColumns([
        _db.batches.itemId,
        _db.batches.quantityBase.sum(),
      ])
      ..where(_db.batches.isVoided.equals(false))
      ..groupBy([_db.batches.itemId]);
    final stockRows = await stockQuery.get();
    final stock = <String, int>{};
    for (final row in stockRows) {
      final itemId = row.read(_db.batches.itemId)!;
      final total = row.read(_db.batches.quantityBase.sum());
      stock[itemId] = total ?? 0;
    }

    // Item names + static min stock for the low-velocity fallback.
    final items = await (_db.select(_db.items)
          ..where((i) => i.isActive.equals(true)))
        .get();
    final itemById = {for (final i in items) i.id: i};

    final out = <ReorderSuggestion>[];
    for (final entry in itemById.entries) {
      final item = entry.value;
      final onHand = stock[item.id] ?? 0;
      final soldTotal = velocity[item.id] ?? 0;
      final avgDaily = soldTotal / analysisDays;

      final double daysOfCover =
          avgDaily > 0 ? onHand / avgDaily : double.infinity;

      final ReorderUrgency? urgency;
      if (onHand <= 0 && soldTotal > 0) {
        urgency = ReorderUrgency.critical;
      } else if (avgDaily > 0 && daysOfCover < criticalDays) {
        urgency = ReorderUrgency.critical;
      } else if (avgDaily > 0 && daysOfCover < warningDays) {
        urgency = ReorderUrgency.warning;
      } else if (item.minimumStockBase > 0 &&
          onHand <= item.minimumStockBase) {
        urgency = ReorderUrgency.low;
      } else {
        continue;
      }

      final suggested = avgDaily > 0
          ? ((targetDays - daysOfCover.clamp(0, targetDays)) * avgDaily).ceil()
          : item.minimumStockBase;

      out.add(ReorderSuggestion(
        itemId: item.id,
        itemName: item.tradeName,
        currentStockBase: onHand,
        avgDailySalesBase: avgDaily,
        daysOfCover: daysOfCover,
        suggestedQtyBase: suggested < 0 ? 0 : suggested,
        urgency: urgency,
      ));
    }

    out.sort((a, b) {
      final urgencyOrder = a.urgency.index.compareTo(b.urgency.index);
      if (urgencyOrder != 0) return urgencyOrder;
      return a.daysOfCover.compareTo(b.daysOfCover);
    });
    return out;
  }
}
