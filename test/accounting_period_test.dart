import 'package:flutter_test/flutter_test.dart';
import 'package:pharmacy_pos/core/errors/exceptions.dart';
import 'package:pharmacy_pos/domain/services/accounting_period_service.dart';
import 'package:pharmacy_pos/shared/database/app_database.dart';

import 'helpers.dart';

/// Phase 10 Step 8 — Accounting period close feature: create/list/close with
/// the forward-only closing rule (must close the newest open period first).
void main() {
  final service = AccountingPeriodService();
  late AppDatabase db;

  setUp(() {
    db = newDatabase();
  });

  tearDown(() async => db.close());

  Future<List<AccountingPeriodRow>> list() => service.listPeriods(db);

  test('creates an open period and lists it newest first', () async {
    final id = await service.createPeriod(
      db,
      name: '2026-01',
      startDate: DateTime(2026, 1, 1).millisecondsSinceEpoch,
      endDate: DateTime(2026, 1, 31).millisecondsSinceEpoch,
      userId: 'user_admin',
    );

    final periods = await list();
    expect(periods, hasLength(1));
    expect(periods.first.id, id);
    expect(periods.first.name, '2026-01');
    expect(periods.first.isClosed, isFalse);
  });

  test('rejects a period whose end is not after its start', () async {
    await expectLater(
      service.createPeriod(
        db,
        name: 'bad',
        startDate: DateTime(2026, 2, 10).millisecondsSinceEpoch,
        endDate: DateTime(2026, 2, 10).millisecondsSinceEpoch,
        userId: 'user_admin',
      ),
      throwsA(isA<ValidationException>()),
    );
  });

  test('closes a period once and only newest-open-first', () async {
    final older = await service.createPeriod(
      db,
      name: '2026-01',
      startDate: DateTime(2026, 1, 1).millisecondsSinceEpoch,
      endDate: DateTime(2026, 1, 31).millisecondsSinceEpoch,
      userId: 'user_admin',
    );
    final newer = await service.createPeriod(
      db,
      name: '2026-02',
      startDate: DateTime(2026, 2, 1).millisecondsSinceEpoch,
      endDate: DateTime(2026, 2, 28).millisecondsSinceEpoch,
      userId: 'user_admin',
    );

    // Cannot close the older while the newer is still open.
    await expectLater(
      service.closePeriod(db, periodId: older, userId: 'user_admin'),
      throwsA(isA<InvalidOperationException>()),
    );

    // Close the newest first.
    await service.closePeriod(
        db, periodId: newer, userId: 'user_admin', closeReason: 'إقفال دوره');
    final periods = await list();
    expect(periods.firstWhere((p) => p.id == newer).isClosed, isTrue);
    expect(periods.firstWhere((p) => p.id == newer).closedBy, 'user_admin');

    // Double close is rejected.
    await expectLater(
      service.closePeriod(db, periodId: newer, userId: 'user_admin'),
      throwsA(isA<InvalidOperationException>()),
    );

    // Now the older can be closed.
    await service.closePeriod(db, periodId: older, userId: 'user_admin');
    final after = await list();
    expect(after.every((p) => p.isClosed), isTrue);
  });
}
