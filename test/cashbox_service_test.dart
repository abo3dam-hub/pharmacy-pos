/// Phase 8 Cash Box service: open/close/deposit/withdraw/adjust lifecycle,
/// RBAC (`cashbox.operate`), validation and the immutable audit trail.
library;

import 'dart:convert';

import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:flutter_test/flutter_test.dart';
import 'package:pharmacy_pos/core/errors/exceptions.dart';
import 'package:pharmacy_pos/domain/services/cashbox_service.dart';
import 'package:pharmacy_pos/features/accounts/data/cashbox_dao.dart';
import 'package:pharmacy_pos/features/accounts/domain/entities/cashbox_session.dart';
import 'package:pharmacy_pos/shared/database/app_database.dart';
import 'package:pharmacy_pos/shared/models/enums.dart';

import 'auth_harness.dart';
import 'helpers.dart';

void main() {
  const service = CashboxService();

  late AppDatabase db;
  late CashboxDao dao;

  setUp(() async {
    db = newDatabase();
    dao = CashboxDao(db);
  });

  tearDown(() async => db.close());

  Future<CashboxSession> session() => dao.currentSession();

  group('CashboxService open (§41 Phase 8)', () {
    test('opens a fresh drawer and reports an open session', () async {
      final row = await service.openDrawer(
        db,
        openingMicros: 50000,
        userId: 'user_admin',
        note: 'نوبة صباحية',
      );

      expect(row.type, CashboxTransactionType.open);
      expect(row.amountMicros, 50000);
      expect(row.remainingMicros, 50000);

      final s = await session();
      expect(s.status, CashboxStatus.open);
      expect(s.openingMicros, 50000);
      expect(s.openedByUserName, 'مدير النظام');
      expect(s.openedAtMillis, isNotNull);
      expect(s.expectedClosingMicros, 50000);
    });

    test('a zero opening float is rejected (ledger forbids zero amounts)',
        () async {
      await expectLater(
        service.openDrawer(
          db,
          openingMicros: 0,
          userId: 'user_admin',
        ),
        throwsA(isA<ValidationException>()),
      );
      expect((await session()).status, CashboxStatus.notOpened);
    });

    test('negative opening float is rejected', () async {
      await expectLater(
        service.openDrawer(
          db,
          openingMicros: -100,
          userId: 'user_admin',
        ),
        throwsA(isA<ValidationException>()),
      );
      expect((await session()).status, CashboxStatus.notOpened);
    });

    test('opening while already open is rejected', () async {
      await service.openDrawer(db, openingMicros: 50000, userId: 'user_admin');
      await expectLater(
        service.openDrawer(db, openingMicros: 10000, userId: 'user_admin'),
        throwsA(isA<InvalidOperationException>()),
      );
    });

    test('reopening after a close starts a new shift', () async {
      await service.openDrawer(db, openingMicros: 50000, userId: 'user_admin');
      await service.closeDrawer(
        db,
        declaredCloseMicros: 50000,
        reason: 'نهاية النوبة',
        userId: 'user_admin',
      );
      final second = await service
          .openDrawer(db, openingMicros: 80000, userId: 'user_admin');
      expect(second.type, CashboxTransactionType.open);
      expect(second.amountMicros, 80000);
      final s = await session();
      expect(s.status, CashboxStatus.open);
      expect(s.openingMicros, 80000);
    });

    test('cashier (view only) is denied by RBAC', () async {
      await seedExtraUser(db);
      await expectLater(
        service.openDrawer(db, openingMicros: 50000, userId: 'user_cashier'),
        throwsA(isA<UnauthorizedException>()),
      );
      // cash box.operate is required for every mutation.
      await expectLater(
        service.deposit(
            db,
            amountMicros: 1000,
            reason: 'سند',
            userId: 'user_cashier'),
        throwsA(isA<UnauthorizedException>()),
      );
    });
  });

  group('CashboxService close', () {
    test('close declares counted cash and reconciles a clean drawer',
        () async {
      await service.openDrawer(db, openingMicros: 50000, userId: 'user_admin');
      await service.deposit(
        db,
        amountMicros: 30000,
        reason: 'تحصيل سند',
        userId: 'user_admin',
      );
      final row = await service.closeDrawer(
        db,
        declaredCloseMicros: 80000,
        reason: 'نهاية النوبة',
        userId: 'user_admin',
      );

      expect(row.type, CashboxTransactionType.close);
      // The close is a declaration snapshot, never a cash move.
      expect(row.amountMicros, 80000);
      expect(row.remainingMicros, 80000);

      final s = await session();
      expect(s.status, CashboxStatus.closed);
      expect(s.declaredCloseMicros, 80000);
      expect(s.differenceMicros, 0);
      expect(s.closedByUserName, 'مدير النظام');
    });

    test('surplus/shortage surfaces in the reconciled session', () async {
      await service.openDrawer(db, openingMicros: 50000, userId: 'user_admin');
      await service.closeDrawer(
        db,
        declaredCloseMicros: 47500,
        reason: 'عجز 2500',
        userId: 'user_admin',
      );
      final s = await session();
      expect(s.expectedClosingMicros, 50000);
      expect(s.declaredCloseMicros, 47500);
      expect(s.differenceMicros, -2500);
      expect(s.hasDifference, isTrue);
    });

    test('close requires a reason', () async {
      await service.openDrawer(db, openingMicros: 50000, userId: 'user_admin');
      await expectLater(
        service.closeDrawer(
          db,
          declaredCloseMicros: 50000,
          reason: '   ',
          userId: 'user_admin',
        ),
        throwsA(isA<ValidationException>()),
      );
    });

    test('double close is rejected', () async {
      await service.openDrawer(db, openingMicros: 50000, userId: 'user_admin');
      await service.closeDrawer(
        db,
        declaredCloseMicros: 50000,
        reason: 'أولى',
        userId: 'user_admin',
      );
      await expectLater(
        service.closeDrawer(
          db,
          declaredCloseMicros: 50000,
          reason: 'ثانية',
          userId: 'user_admin',
        ),
        throwsA(isA<InvalidOperationException>()),
      );
    });

    test('close without opening is rejected', () async {
      await expectLater(
        service.closeDrawer(
          db,
          declaredCloseMicros: 100,
          reason: 'بدون فتح',
          userId: 'user_admin',
        ),
        throwsA(isA<InvalidOperationException>()),
      );
    });
  });

  group('CashboxService deposits & withdrawals', () {
    test('deposit adds to and withdrawal subtracts from the drawer',
        () async {
      await service.openDrawer(db, openingMicros: 10000, userId: 'user_admin');
      await service.deposit(
        db,
        amountMicros: 25000,
        reason: 'تحصيل سند',
        userId: 'user_admin',
      );
      await service.withdraw(
        db,
        amountMicros: 5000,
        reason: 'مصروف نثري',
        userId: 'user_admin',
      );

      final s = await session();
      expect(s.expectedClosingMicros, 30000);
      expect(s.depositsMicros, 25000);
      expect(s.withdrawalsMicros, -5000);
      expect(s.netMovesMicros, 20000);
      expect(s.inflowsMicros, 25000);
      expect(s.outflowsMicros, 5000);
    });

    test('withdrawal is stored negative and is rejected when zero',
        () async {
      await service.openDrawer(db, openingMicros: 10000, userId: 'user_admin');
      final row = await service.withdraw(
        db,
        amountMicros: 70000,
        reason: 'نقل للخزينة',
        userId: 'user_admin',
      );
      expect(row.amountMicros, -70000);
      await expectLater(
        service.deposit(
            db, amountMicros: 0, reason: 'صفر', userId: 'user_admin'),
        throwsA(isA<ValidationException>()),
      );
    });

    test('moves require an open session and a reason', () async {
      await expectLater(
        service.deposit(
            db, amountMicros: 1000, reason: 'بدون', userId: 'user_admin'),
        throwsA(isA<InvalidOperationException>()),
      );
      await service.openDrawer(db, openingMicros: 10000, userId: 'user_admin');
      await expectLater(
        service.deposit(
            db, amountMicros: 1000, reason: '  ', userId: 'user_admin'),
        throwsA(isA<ValidationException>()),
      );
    });
  });

  group('CashboxService adjustments', () {
    test('signed adjustment books through the financial engine', () async {
      await service.openDrawer(db, openingMicros: 50000, userId: 'user_admin');
      final row = await service.adjustCash(
        db,
        amountMicros: -2000,
        reason: 'نقص في التلف',
        userId: 'user_admin',
      );
      expect(row.type, CashboxTransactionType.adjustment);
      expect(row.amountMicros, -2000);
      final s = await session();
      expect(s.adjustmentsMicros, -2000);
      expect(s.expectedClosingMicros, 48000);
    });

    test('adjustments require an open session', () async {
      await expectLater(
        service.adjustCash(
            db, amountMicros: 100, reason: 'بدون', userId: 'user_admin'),
        throwsA(isA<InvalidOperationException>()),
      );
    });
  });

  group('CashboxService audit trail', () {
    test('every operation writes an immutable cashbox audit entry', () async {
      await service.openDrawer(db, openingMicros: 50000, userId: 'user_admin');
      await service.deposit(
        db,
        amountMicros: 10000,
        reason: 'سند',
        userId: 'user_admin',
      );
      await service.closeDrawer(
        db,
        declaredCloseMicros: 60000,
        reason: 'نهاية',
        userId: 'user_admin',
      );

      final audits = await (db.select(db.auditLogs)
            ..where((a) => a.entityType.equals('cashbox'))
            ..orderBy([(a) => OrderingTerm.asc(a.createdAt)]))
          .get();

      expect(audits.length, 3);
      expect(audits.map((a) => a.action).toSet(), {'create', 'update'});
      expect(audits.every((a) => a.userId == 'user_admin'), isTrue);
      final decoded = audits.map((a) => jsonDecode(a.afterData!)).toList();
      expect(decoded[0], contains('opening_micros'));
      expect(decoded[1], contains('amount_micros'));
      expect(decoded[2], contains('declared_close_micros'));
      expect(decoded[2], contains('expected_close_micros'));
      expect(decoded[2], contains('difference_micros'));
    });
  });
}