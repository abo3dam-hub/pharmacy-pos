import 'package:drift/drift.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pharmacy_pos/core/config/app_config.dart';
import 'package:pharmacy_pos/core/constants/settings_keys.dart';
import 'package:pharmacy_pos/core/di/providers.dart';
import 'package:pharmacy_pos/core/errors/exceptions.dart';
import 'package:pharmacy_pos/core/theme/app_theme.dart';
import 'package:pharmacy_pos/domain/services/audit_service.dart';
import 'package:pharmacy_pos/domain/services/permission_service.dart';
import 'package:pharmacy_pos/features/settings/data/settings_repository_impl.dart';
import 'package:pharmacy_pos/features/settings/domain/entities/app_settings_entity.dart';
import 'package:pharmacy_pos/features/settings/domain/usecases/settings_use_cases.dart';
import 'package:pharmacy_pos/features/settings/presentation/pages/settings_page.dart';
import 'package:pharmacy_pos/l10n/app_localizations.dart';
import 'package:pharmacy_pos/shared/database/app_database.dart';
import 'package:pharmacy_pos/shared/database/settings_dao.dart';

import 'auth_harness.dart';
import 'helpers.dart';

void main() {
  group('SettingsDao + repository (persistence)', () {
    test('defaults are returned when no settings are stored', () async {
      final db = newDatabase();
      addTearDown(db.close);
      final repo = SettingsRepositoryImpl(SettingsDao(db), db);

      final settings = await repo.getSettings();

      expect(settings.businessName, AppConfig.appName);
      expect(settings.taxRate.basisPoints, 0);
      expect(settings.currencyCode, SettingsKeys.defaultCurrencyCode);
      expect(settings.isDefault, isTrue);
    });

    test('setAll upserts the three keys (business name, tax, currency)',
        () async {
      final db = newDatabase();
      addTearDown(db.close);
      final dao = SettingsDao(db);
      final now = DateTime.now().millisecondsSinceEpoch;

      await dao.setAll(
        {
          SettingsKeys.businessName: 'صيدلية الأمل',
          SettingsKeys.taxRateBasisPoints: '1500',
          SettingsKeys.currencyCode: 'USD',
        },
        updatedBy: 'settings',
        atMillis: now,
      );

      final all = await dao.getAll();
      expect(all[SettingsKeys.businessName], 'صيدلية الأمل');
      expect(all[SettingsKeys.taxRateBasisPoints], '1500');
      expect(all[SettingsKeys.currencyCode], 'USD');
      expect(await dao.getString(SettingsKeys.businessName), 'صيدلية الأمل');
      expect(await dao.getInt(SettingsKeys.taxRateBasisPoints), 1500);
    });

    test('saveSettings persists and reports the new aggregate', () async {
      final db = newDatabase();
      addTearDown(db.close);
      final repo = SettingsRepositoryImpl(SettingsDao(db), db);

      final saved = await repo.saveSettings(const AppSettingsDraft(
        businessName: 'صيدلية النور',
        taxRateBasisPoints: 1500,
        currencyCode: 'SAR',
      ));

      expect(saved.businessName, 'صيدلية النور');
      expect(saved.taxRate.basisPoints, 1500);
      expect(saved.currencyCode, 'SAR');
      expect(saved.updatedAt, isA<int>());

      final reloaded = await repo.getSettings();
      expect(reloaded.businessName, 'صيدلية النور');
      expect(reloaded.taxRate.basisPoints, 1500);
      expect(reloaded.updatedAt, isA<int>());
      expect(reloaded.isDefault, isFalse);
    });
  });

  group('Settings use cases', () {
    test('admin can load and save settings; audit row is written', () async {
      final db = newDatabase();
      addTearDown(db.close);
      final repo = SettingsRepositoryImpl(SettingsDao(db), db);
      const perms = PermissionService();
      const audit = AuditService();

      final get = GetAppSettingsUseCase(repo, perms);
      final before = await get.call(db, 'role_admin');
      expect(before.businessName, AppConfig.appName);

      final save = SaveAppSettingsUseCase(repo, perms, audit);
      final saved = await save.call(
        db,
        draft: const AppSettingsDraft(
          businessName: 'صيدلية الأمل',
          taxRateBasisPoints: 1500,
          currencyCode: 'SAR',
        ),
        actingUserId: 'user_admin',
        actingRoleId: 'role_admin',
      );
      expect(saved.businessName, 'صيدلية الأمل');

      final rows = await db.select(db.auditLogs).get();
      expect(rows, hasLength(1));
      expect(rows.single.action, 'audit_config');
      expect(rows.single.entityType, 'app_settings');
      expect(rows.single.entityId, 'settings');
      expect(rows.single.userId, 'user_admin');
    });

    test('roles without settings.edit are rejected and nothing persists',
        () async {
      final db = newDatabase();
      addTearDown(db.close);
      final repo = SettingsRepositoryImpl(SettingsDao(db), db);
      const perms = PermissionService();
      final save = SaveAppSettingsUseCase(repo, perms, const AuditService());

      await expectLater(
        save.call(
          db,
          draft: const AppSettingsDraft(
            businessName: 'غير مسموح',
            taxRateBasisPoints: 500,
            currencyCode: 'SAR',
          ),
          actingUserId: 'user_cashier',
          actingRoleId: 'role_cashier',
        ),
        throwsA(isA<UnauthorizedException>()),
      );

      final settings = await repo.getSettings();
      expect(settings.businessName, AppConfig.appName);
    });

    test('viewing settings requires settings.view', () async {
      final db = newDatabase();
      addTearDown(db.close);
      final repo = SettingsRepositoryImpl(SettingsDao(db), db);
      final get = GetAppSettingsUseCase(repo, const PermissionService());

      await expectLater(
        get.call(db, 'role_cashier'),
        throwsA(isA<UnauthorizedException>()),
      );
    });

    test('validation rejects empty name, out-of-range tax and bad currency',
        () async {
      final db = newDatabase();
      addTearDown(db.close);
      final repo = SettingsRepositoryImpl(SettingsDao(db), db);
      const perms = PermissionService();
      final save = SaveAppSettingsUseCase(repo, perms, const AuditService());

      await expectLater(
        save.call(
          db,
          draft: const AppSettingsDraft(
            businessName: '   ',
            taxRateBasisPoints: 0,
            currencyCode: 'SAR',
          ),
          actingUserId: 'user_admin',
          actingRoleId: 'role_admin',
        ),
        throwsA(isA<ValidationException>()),
      );
      await expectLater(
        save.call(
          db,
          draft: const AppSettingsDraft(
            businessName: 'صيدلية',
            taxRateBasisPoints: 10001,
            currencyCode: 'SAR',
          ),
          actingUserId: 'user_admin',
          actingRoleId: 'role_admin',
        ),
        throwsA(isA<ValidationException>()),
      );
      await expectLater(
        save.call(
          db,
          draft: const AppSettingsDraft(
            businessName: 'صيدلية',
            taxRateBasisPoints: 500,
            currencyCode: 'ريال',
          ),
          actingUserId: 'user_admin',
          actingRoleId: 'role_admin',
        ),
        throwsA(isA<ValidationException>()),
      );
    });
  });

  group('SettingsPage (admin, Arabic)', () {
    Widget harness(ProviderContainer container) {
      return UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          theme: AppTheme.light(),
          locale: const Locale(AppConfig.defaultLocale),
          supportedLocales: AppLocalizations.supportedLocales,
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          home: const Scaffold(body: SettingsPage()),
        ),
      );
    }

    testWidgets('loads defaults, saves new values and persists them',
        (tester) async {
      tester.view.physicalSize = const Size(1280, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      final h = await buildAuthHarness();
      addTearDown(h.db.close);
      addTearDown(h.container.dispose);
      await h.container.read(authControllerProvider.notifier).login(
            'admin',
            'Admin@123',
          );

      await tester.pumpWidget(harness(h.container));
      await tester.pumpAndSettle();

      expect(
        tester
            .widget<TextFormField>(
                find.widgetWithText(TextFormField, 'اسم النشاط التجاري'))
            .controller
            ?.text,
        AppConfig.appName,
      );

      await tester.enterText(
        find.widgetWithText(TextFormField, 'اسم النشاط التجاري'),
        'صيدلية الأمل',
      );
      await tester.enterText(
        find.widgetWithText(TextFormField, 'نسبة الضريبة'),
        '15',
      );
      await tester.tap(find.text('حفظ'));
      await tester.pumpAndSettle();

      expect(find.text('تم حفظ الإعدادات بنجاح'), findsOneWidget);

      final dao = SettingsDao(h.db);
      expect(await dao.getString(SettingsKeys.businessName), 'صيدلية الأمل');
      expect(await dao.getInt(SettingsKeys.taxRateBasisPoints), 1500);
      expect(await dao.getString(SettingsKeys.currencyCode), 'SAR');
    });
  });

  group('SettingsPage (view-only role)', () {
    Widget harness(ProviderContainer container) {
      return UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          theme: AppTheme.light(),
          locale: const Locale(AppConfig.defaultLocale),
          supportedLocales: AppLocalizations.supportedLocales,
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          home: const Scaffold(body: SettingsPage()),
        ),
      );
    }

    testWidgets('forms are read-only without settings.edit', (tester) async {
      tester.view.physicalSize = const Size(1280, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      final db = newDatabase();
      addTearDown(db.close);
      final now = DateTime.now().millisecondsSinceEpoch;
      await db.into(db.roles).insert(RoleRow(
            id: 'role_settings_view',
            name: 'settings_view',
            nameAr: 'مشاهد الإعدادات',
            isSystem: false,
            isActive: true,
            createdAt: now,
            updatedAt: now,
          ));
      await db.into(db.rolePermissions).insert(RolePermissionsCompanion.insert(
            id: 'rv_settings_view',
            roleId: 'role_settings_view',
            permissionId: 'perm_settings_view',
            granted: const Value(true),
            createdAt: now,
          ));
      await seedExtraUser(
        db,
        username: 'settings_viewer',
        password: 'View@12345',
        roleId: 'role_settings_view',
        fullName: 'مشاهد',
      );

      final h = attachAuthTo(db);
      addTearDown(h.container.dispose);
      await h.container.read(authControllerProvider.notifier).login(
            'settings_viewer',
            'View@12345',
          );

      await tester.pumpWidget(harness(h.container));
      await tester.pumpAndSettle();

      expect(find.text('حفظ'), findsNothing);
      final nameField = tester.widget<TextFormField>(
          find.widgetWithText(TextFormField, 'اسم النشاط التجاري'));
      expect(nameField.enabled, isFalse);
    });
  });
}