import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pharmacy_pos/core/config/app_config.dart';
import 'package:pharmacy_pos/core/data_grid/page_request.dart';
import 'package:pharmacy_pos/core/di/providers.dart';
import 'package:pharmacy_pos/core/errors/exceptions.dart';
import 'package:pharmacy_pos/core/theme/app_theme.dart';
import 'package:pharmacy_pos/domain/services/audit_service.dart';
import 'package:pharmacy_pos/domain/services/permission_service.dart';
import 'package:pharmacy_pos/features/audit/data/audit_dao.dart';
import 'package:pharmacy_pos/features/audit/domain/entities/audit_entry.dart';
import 'package:pharmacy_pos/features/audit/domain/usecases/audit_use_cases.dart';
import 'package:pharmacy_pos/features/audit/presentation/pages/audit_log_page.dart';
import 'package:pharmacy_pos/l10n/app_localizations.dart';
import 'package:pharmacy_pos/shared/database/app_database.dart';
import 'package:pharmacy_pos/shared/models/enums.dart';

import 'auth_harness.dart';
import 'helpers.dart';

void main() {
  Future<void> seedRows(AppDatabase db) async {
    await seedExtraUser(db, username: 'cashier');
    const audit = AuditService();
    const base = 1_700_000_000_000;
    await audit.write(
      db,
      userId: 'user_admin',
      action: AuditAction.login,
      entityType: 'user',
      entityId: 'user_admin',
      note: 'login_from_test',
      atMillis: base,
    );
    await audit.write(
      db,
      userId: 'user_admin',
      action: AuditAction.create,
      entityType: 'role',
      entityId: 'role_new',
      after: {'nameAr': 'دور تجريبي'},
      note: 'role_created',
      atMillis: base + 60_000,
    );
    await audit.write(
      db,
      userId: 'user_cashier',
      action: AuditAction.auditConfig,
      entityType: 'app_settings',
      entityId: 'settings',
      before: {'taxRateBasisPoints': 0},
      after: {'taxRateBasisPoints': 1500},
      note: 'settings_updated',
      atMillis: base + 120_000,
    );
  }

  group('AuditDao (queries)', () {
    test('lists rows newest-first with paging and total', () async {
      final db = newDatabase();
      addTearDown(db.close);
      await seedRows(db);
      final dao = AuditDao(db);

      final first = await dao.listAudit(
        const PageRequest(page: 1, pageSize: 2),
      );
      expect(first.total, 3);
      expect(first.items, hasLength(2));
      expect(first.items.first.note, 'settings_updated');
      expect(first.items.first.action, 'audit_config');
      expect(first.items.first.username, 'cashier');

      final second = await dao.listAudit(
        const PageRequest(page: 2, pageSize: 2),
      );
      expect(second.items, hasLength(1));
      expect(second.items.single.action, 'login');
    });

    test('filters by action, actor, date range and search', () async {
      final db = newDatabase();
      addTearDown(db.close);
      await seedRows(db);
      final dao = AuditDao(db);
      const base = 1_700_000_000_000;

      final byAction = await dao.listAudit(
        const PageRequest(pageSize: 50),
        filters: const AuditFilters(action: 'audit_config'),
      );
      expect(byAction.total, 1);
      expect(byAction.items.single.entityType, 'app_settings');

      final byUser = await dao.listAudit(
        const PageRequest(pageSize: 50),
        filters: const AuditFilters(userId: 'user_admin'),
      );
      expect(byUser.total, 2);

      final byFrom = await dao.listAudit(
        const PageRequest(pageSize: 50),
        filters: AuditFilters(fromMillis: base + 61_000),
      );
      expect(byFrom.total, 1);
      expect(byFrom.items.single.action, 'audit_config');

      final bySearch = await dao.listAudit(
        const PageRequest(pageSize: 50),
        filters: const AuditFilters(search: 'settings'),
      );
      expect(bySearch.total, 1);
      expect(bySearch.items.single.note, 'settings_updated');
    });

    test('distinctActions and distinctActors reflect the trail', () async {
      final db = newDatabase();
      addTearDown(db.close);
      await seedRows(db);
      final dao = AuditDao(db);

      final actions = await dao.distinctActions();
      expect(actions, containsAll(['login', 'create', 'audit_config']));

      final actors = await dao.distinctActors();
      expect(actors.map((a) => a.username), containsAll(['admin', 'cashier']));
    });
  });

  group('Audit use cases (permission guard)', () {
    test('admin can list, others without audit.view are rejected', () async {
      final db = newDatabase();
      addTearDown(db.close);
      await seedRows(db);
      final dao = AuditDao(db);
      const perms = PermissionService();

      final list = ListAuditLogsUseCase(dao, perms);
      final result = await list.call(db, 'role_admin');
      expect(result.total, 3);

      await expectLater(
        list.call(db, 'role_cashier'),
        throwsA(isA<UnauthorizedException>()),
      );
      await expectLater(
        ListAuditActionsUseCase(dao, perms).call(db, 'role_cashier'),
        throwsA(isA<UnauthorizedException>()),
      );
    });
  });

  group('AuditLogPage (admin, Arabic)', () {
    Widget harness(ProviderContainer container) {
      return UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          theme: AppTheme.light(),
          locale: const Locale(AppConfig.defaultLocale),
          supportedLocales: AppLocalizations.supportedLocales,
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          home: const Scaffold(body: AuditLogPage()),
        ),
      );
    }

    testWidgets('lists the trail and opens the detail dialog', (tester) async {
      tester.view.physicalSize = const Size(1280, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      final h = await buildAuthHarness();
      addTearDown(h.db.close);
      addTearDown(h.container.dispose);
      await seedRows(h.db);
      await h.container.read(authControllerProvider.notifier).login(
            'admin',
            'Admin@123',
          );

      await tester.pumpWidget(harness(h.container));
      await tester.pumpAndSettle();

      expect(find.text('تغيير الإعدادات'), findsOneWidget);
      expect(find.text('إنشاء'), findsWidgets);
      expect(find.text('settings'), findsOneWidget);
      expect(find.text('cashier'), findsOneWidget);

      await tester.tap(find.text('تغيير الإعدادات'));
      await tester.pumpAndSettle();

      expect(find.text('تفاصيل العملية'), findsOneWidget);
      expect(find.text('settings_updated'), findsWidgets);
    });
  });
}