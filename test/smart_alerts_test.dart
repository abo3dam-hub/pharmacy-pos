import 'package:drift/drift.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pharmacy_pos/features/reports/domain/entities/expiry_alert.dart';
import 'package:pharmacy_pos/features/reports/domain/entities/reorder_suggestion.dart';
import 'package:pharmacy_pos/features/reports/domain/services/expiry_alerts_service.dart';
import 'package:pharmacy_pos/features/reports/domain/services/reorder_suggestions_service.dart';
import 'package:pharmacy_pos/shared/database/app_database.dart';
import 'package:pharmacy_pos/shared/models/enums.dart';

import 'helpers.dart';

Future<String> _insertItem(AppDatabase db, String id, String name) async {
  final now = DateTime.now().millisecondsSinceEpoch;
  await db.into(db.items).insert(
        ItemsCompanion.insert(
          id: id,
          tradeName: name,
          createdAt: now,
          updatedAt: now,
        ),
      );
  return id;
}

Future<void> _insertBatch(
  AppDatabase db,
  String id,
  String itemId, {
  int quantityBase = 10,
  int? expiryDate,
}) async {
  final now = DateTime.now().millisecondsSinceEpoch;
  await db.into(db.batches).insert(
        BatchesCompanion.insert(
          id: id,
          itemId: itemId,
          batchNumber: 'B-$id',
          quantityBase: Value(quantityBase),
          originalQuantityBase: quantityBase,
          unitCostMicros: const Value(100),
          receivedDate: Value(now),
          expiryDate: Value(expiryDate),
          createdAt: now,
          updatedAt: now,
        ),
      );
}

Future<void> _insertSaleLine(
  AppDatabase db,
  String itemId,
  int qtyBase,
  int daysAgo,
) async {
  final now = DateTime.now().millisecondsSinceEpoch;
  final at = now - daysAgo * 24 * 60 * 60 * 1000;
  final invId = 'inv-$itemId-$daysAgo';
  await db.into(db.salesInvoices).insert(
        SalesInvoicesCompanion.insert(
          id: invId,
          invoiceNumber: 'S-TEST-$itemId-$daysAgo',
          invoiceType: InvoiceType.sale,
          saleStatus: SaleStatus.completed,
          paymentMethod: PaymentMethod.cash,
          userId: 'user-1',
          createdAt: at,
          updatedAt: at,
        ),
      );
  await db.into(db.salesInvoiceItems).insert(
        SalesInvoiceItemsCompanion.insert(
          id: 'line-$itemId-$daysAgo',
          invoiceId: invId,
          itemId: itemId,
          batchId: 'batch-$itemId',
          unitTypeId: 'unit_base',
          quantityBaseSigned: qtyBase,
          unitPriceMicros: 100,
          createdAt: at,
        ),
      );
}

void main() {
  late AppDatabase db;

  setUp(() {
    db = newDatabase();
  });

  tearDown(() async {
    await db.close();
  });

  group('ReorderSuggestionsService', () {
    test('flags item with high velocity and low stock as critical', () async {
      await _insertItem(db, 'item-fast', 'دواء سريع');
      // 10 base units/day for 30 days = 300 units sold
      for (var d = 1; d <= 30; d++) {
        await _insertSaleLine(db, 'item-fast', 10, d);
      }
      // Only 20 units on hand -> 2 days of cover -> critical
      await _insertBatch(db, 'batch-fast', 'item-fast', quantityBase: 20);

      final service = ReorderSuggestionsService(db);
      final out = await service.suggestions();

      expect(out, hasLength(1));
      expect(out.first.itemId, 'item-fast');
      expect(out.first.urgency, ReorderUrgency.critical);
      expect(out.first.avgDailySalesBase, closeTo(10.0, 0.5));
      expect(out.first.daysOfCover, lessThan(7.0));
      // Suggested to reach 30 days: (30 - 2) * 10 = 280
      expect(out.first.suggestedQtyBase, greaterThan(200));
    });

    test('ignores items with no sales velocity and no minimum stock',
        () async {
      await _insertItem(db, 'item-dead', 'دواء راكد');
      await _insertBatch(db, 'batch-dead', 'item-dead', quantityBase: 5);

      final service = ReorderSuggestionsService(db);
      final out = await service.suggestions();
      expect(out, isEmpty);
    });

    test('warning when cover is between 7 and 14 days', () async {
      await _insertItem(db, 'item-mid', 'دواء متوسط');
      for (var d = 1; d <= 30; d++) {
        await _insertSaleLine(db, 'item-mid', 10, d);
      }
      // 100 units = 10 days cover -> warning
      await _insertBatch(db, 'batch-mid', 'item-mid', quantityBase: 100);

      final service = ReorderSuggestionsService(db);
      final out = await service.suggestions();
      expect(out, hasLength(1));
      expect(out.first.urgency, ReorderUrgency.warning);
    });
  });

  group('ExpiryAlertsService', () {
    test('classifies expired, critical and warning batches', () async {
      await _insertItem(db, 'item-exp', 'دواء منتهي');
      final now = DateTime.now().millisecondsSinceEpoch;
      const day = 24 * 60 * 60 * 1000;
      await _insertBatch(db, 'b-expired', 'item-exp',
          expiryDate: now - 5 * day); // expired
      await _insertBatch(db, 'b-critical', 'item-exp',
          expiryDate: now + 30 * day); // critical (<=90)
      await _insertBatch(db, 'b-warning', 'item-exp',
          expiryDate: now + 150 * day); // warning (<=180)
      await _insertBatch(db, 'b-far', 'item-exp',
          expiryDate: now + 400 * day); // outside horizon
      await _insertBatch(db, 'b-empty', 'item-exp',
          quantityBase: 0, expiryDate: now + 10 * day); // zero qty ignored

      final service = ExpiryAlertsService(db);
      final out = await service.alerts();

      expect(out.map((a) => a.batchNumber),
          containsAll(['B-b-expired', 'B-b-critical', 'B-b-warning']));
      expect(out.map((a) => a.batchNumber), isNot(contains('B-b-far')));
      expect(out.map((a) => a.batchNumber), isNot(contains('B-b-empty')));

      final expired =
          out.firstWhere((a) => a.batchNumber == 'B-b-expired');
      expect(expired.severity, ExpirySeverity.expired);
      expect(expired.daysRemaining, lessThan(0));

      final critical =
          out.firstWhere((a) => a.batchNumber == 'B-b-critical');
      expect(critical.severity, ExpirySeverity.critical);

      final warning = out.firstWhere((a) => a.batchNumber == 'B-b-warning');
      expect(warning.severity, ExpirySeverity.warning);

      // Sorted: most overdue first
      expect(out.first.batchNumber, 'B-b-expired');
    });
  });
}
