import 'package:drift/drift.dart' as drift;
import '../../../../shared/database/app_database.dart';
import '../entities/expiry_alert.dart';

/// Finds batches nearing (or past) expiry with remaining stock.
class ExpiryAlertsService {
  ExpiryAlertsService(this._db);

  final AppDatabase _db;

  /// Warn about batches expiring within this many days.
  static const int warningDays = 180;

  /// Critical when expiring within this many days.
  static const int criticalDays = 90;

  Future<List<ExpiryAlert>> alerts() async {
    final now = DateTime.now();
    final horizonMs = now
        .add(const Duration(days: warningDays))
        .millisecondsSinceEpoch;

    final items = _db.items;
    final batches = _db.batches;
    final rows = await (_db.select(items).join([
              drift.innerJoin(batches, batches.itemId.equalsExp(items.id)),
            ])
          ..where(batches.expiryDate.isNotNull())
          ..where(batches.expiryDate.isSmallerOrEqualValue(horizonMs))
          ..where(batches.quantityBase.isBiggerThanValue(0))
          ..where(batches.isVoided.equals(false))
          ..orderBy([drift.OrderingTerm.asc(batches.expiryDate)]))
        .get();
    final out = <ExpiryAlert>[];
    for (final r in rows) {
      final item = r.readTable(items);
      final batch = r.readTable(batches);
      final expiry =
          DateTime.fromMillisecondsSinceEpoch(batch.expiryDate!);
      final daysRemaining = expiry.difference(now).inDays;
      final severity = daysRemaining < 0
          ? ExpirySeverity.expired
          : daysRemaining <= criticalDays
              ? ExpirySeverity.critical
              : ExpirySeverity.warning;
      out.add(ExpiryAlert(
        itemId: item.id,
        itemName: item.tradeName,
        batchNumber: batch.batchNumber,
        expiryDate: expiry,
        quantityBase: batch.quantityBase,
        daysRemaining: daysRemaining,
        severity: severity,
      ));
    }
    return out;
  }
}
