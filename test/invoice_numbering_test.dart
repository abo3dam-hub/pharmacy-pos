import 'package:drift/drift.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pharmacy_pos/features/sales/data/pos_catalog_dao.dart';
import 'package:pharmacy_pos/shared/database/app_database.dart';
import 'package:pharmacy_pos/shared/models/enums.dart';

import 'helpers.dart';

Future<void> _insertInvoice(
  AppDatabase db,
  String invoiceNumber, {
  int? createdAt,
}) async {
  final now = createdAt ?? DateTime.now().millisecondsSinceEpoch;
  await db.into(db.salesInvoices).insert(
        SalesInvoicesCompanion.insert(
          id: 'inv-$invoiceNumber',
          invoiceNumber: invoiceNumber,
          invoiceType: InvoiceType.sale,
          saleStatus: SaleStatus.completed,
          paymentMethod: PaymentMethod.cash,
          customerId: const Value('cust-1'),
          userId: 'user-1',
          createdAt: now,
          updatedAt: now,
        ),
      );
}

void main() {
  late AppDatabase db;
  late PosCatalogDao dao;

  setUp(() {
    db = newDatabase();
    dao = PosCatalogDao(db);
  });

  tearDown(() async {
    await db.close();
  });

  String todayPrefix() {
    final now = DateTime.now();
    final y = (now.year % 100).toString().padLeft(2, '0');
    final m = now.month.toString().padLeft(2, '0');
    final d = now.day.toString().padLeft(2, '0');
    return 'S$y$m$d-';
  }

  group('nextInvoiceNumber (daily sequence)', () {
    test('first invoice of the day is sequence 1', () async {
      final n = await dao.nextInvoiceNumber();
      expect(n, '${todayPrefix()}1');
    });

    test('increments within the same day', () async {
      final first = await dao.nextInvoiceNumber();
      await _insertInvoice(db, first);
      final second = await dao.nextInvoiceNumber();
      expect(second, '${todayPrefix()}2');

      await _insertInvoice(db, second);
      final third = await dao.nextInvoiceNumber();
      expect(third, '${todayPrefix()}3');
    });

    test('ignores legacy/non-matching invoice numbers', () async {
      await _insertInvoice(db, 'SI-20250101-120000000');
      await _insertInvoice(db, 'RT-20250101-1');
      final n = await dao.nextInvoiceNumber();
      expect(n, '${todayPrefix()}1');
    });

    test('restarts at 1 on a new day', () async {
      final yesterday = DateTime.now()
          .subtract(const Duration(days: 1))
          .millisecondsSinceEpoch;
      final y = DateTime.now().subtract(const Duration(days: 1));
      final prefix =
          'S${(y.year % 100).toString().padLeft(2, '0')}${y.month.toString().padLeft(2, '0')}${y.day.toString().padLeft(2, '0')}-';
      await _insertInvoice(db, '${prefix}5', createdAt: yesterday);
      final n = await dao.nextInvoiceNumber();
      expect(n, '${todayPrefix()}1');
    });
  });
}
