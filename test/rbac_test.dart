import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pharmacy_pos/core/config/app_config.dart';
import 'package:pharmacy_pos/core/di/providers.dart';
import 'package:pharmacy_pos/core/errors/exceptions.dart';
import 'package:pharmacy_pos/core/theme/app_theme.dart';
import 'package:pharmacy_pos/domain/services/audit_service.dart';
import 'package:pharmacy_pos/domain/services/permission_service.dart';
import 'package:pharmacy_pos/features/auth/data/daos/rbac_dao.dart';
import 'package:pharmacy_pos/features/auth/domain/usecases/rbac_use_cases.dart';
import 'package:pharmacy_pos/features/auth/presentation/pages/admin_hub_page.dart';
import 'package:pharmacy_pos/features/auth/presentation/pages/roles_page.dart';
import 'package:pharmacy_pos/l10n/app_localizations.dart';
import 'package:pharmacy_pos/shared/database/app_database.dart';

import 'auth_harness.dart';
import 'helpers.dart';

void main() {
  group('RbacDao', () {
    test('createRole enforces a unique name and returns the row', () async {
      final db = newDatabase();
      addTearDown(db.close);
      final dao = RbacDao(db);

      final role = await dao.createRole(name: 'auditor', nameAr: 'مدقق');
      expect(role.isSystem, isFalse);
      expect(role.nameAr, 'مدقق');

      await expectLater(
        dao.createRole(name: 'auditor', nameAr: 'مدقق آخر'),
        throwsA(isA<DuplicateException>()),
      );
      expect(await dao.listRoles(), hasLength(5));
    });

    test('updateRole renames the Arabic label', () async {
      final db = newDatabase();
      addTearDown(db.close);
      final dao = RbacDao(db);

      await dao.updateRole(id: 'role_cashier', nameAr: 'موظف الصندوق');
      final roles = await dao.listRoles();
      final cashier = roles.firstWhere((r) => r.id == 'role_cashier');
      expect(cashier.nameAr, 'موظف الصندوق');
      expect(cashier.name, 'cashier');
    });

    test('setRolePermissions replaces the grant set', () async {
      final db = newDatabase();
      addTearDown(db.close);
      final dao = RbacDao(db);

      await dao.setRolePermissions(
        roleId: 'role_cashier',
        codes: {'roles.view', 'sales.view'},
      );
      final codes = await dao.getRolePermissionCodes('role_cashier');
      expect(codes, {'roles.view', 'sales.view'});

      await dao.setRolePermissions(roleId: 'role_cashier', codes: {});
      expect(await dao.getRolePermissionCodes('role_cashier'), isEmpty);
      final counts = await dao.listRoles();
      expect(counts.firstWhere((r) => r.id == 'role_cashier').permissionCount, 0);
    });

    test('deleteRole removes the role and its permission memberships',
        () async {
      final db = newDatabase();
      addTearDown(db.close);
      final dao = RbacDao(db);

      final role = await dao.createRole(name: 'temp', nameAr: 'مؤقت');
      await dao.setRolePermissions(
        roleId: role.id,
        codes: {'roles.view'},
      );
      await dao.deleteRole(role.id);

      final roles = await dao.listRoles();
      expect(roles.any((r) => r.id == role.id), isFalse);
    });
  });

  group('RBAC use cases', () {
    test('admin loads the roles snapshot; others are denied', () async {
      final db = newDatabase();
      addTearDown(db.close);
      final dao = RbacDao(db);
      const perms = PermissionService();

      final load = LoadRolesSnapshotUseCase(dao, perms);
      final snapshot = await load.call(db, 'role_admin');
      expect(snapshot.roles, hasLength(4));
      expect(snapshot.permissions, isNotEmpty);

      await expectLater(
        load.call(db, 'role_cashier'),
        throwsA(isA<UnauthorizedException>()),
      );
    });

    test('creating a role is audited and the role is listed', () async {
      final db = newDatabase();
      addTearDown(db.close);
      final dao = RbacDao(db);
      const perms = PermissionService();
      const audit = AuditService();

      await CreateRoleUseCase(dao, perms, audit).call(
        db,
        name: 'auditor',
        nameAr: 'مدقق',
        actingUserId: 'user_admin',
        actingRoleId: 'role_admin',
      );

      final roles = await db.select(db.roles).get();
      expect(roles.any((r) => r.name == 'auditor'), isTrue);
      final rows = await db.select(db.auditLogs).get();
      expect(rows.single.action, 'create');
      expect(rows.single.entityType, 'role');
    });

    test('admin role can never lose the minimum permission set', () async {
      final db = newDatabase();
      addTearDown(db.close);
      final dao = RbacDao(db);
      const perms = PermissionService();
      const audit = AuditService();

      final codes = await SetRolePermissionsUseCase(dao, perms, audit).call(
        db,
        roleId: 'role_admin',
        codes: const {},
        isSystemRole: true,
        actingUserId: 'user_admin',
        actingRoleId: 'role_admin',
      );

      for (final code in kAdminRoleMinimumPermissions) {
        expect(codes.contains(code), isTrue, reason: code);
      }
      // A role that still administers itself can keep appearing in admin UIs.
      expect(codes.contains('roles.view'), isTrue);
    });

    test('system roles keep roles.view even with an empty set', () async {
      final db = newDatabase();
      addTearDown(db.close);
      final dao = RbacDao(db);
      const perms = PermissionService();
      const audit = AuditService();

      final codes = await SetRolePermissionsUseCase(dao, perms, audit).call(
        db,
        roleId: 'role_cashier',
        codes: const {},
        isSystemRole: true,
        actingUserId: 'user_admin',
        actingRoleId: 'role_admin',
      );
      expect(codes, unorderedEquals({'roles.view'}));

      // Audited as a permission bulk operation.
      final rows = await db.select(db.auditLogs).get();
      expect(rows.single.action, 'bulk_op');
      expect(rows.single.entityType, 'permission');
    });

    test('delete is blocked for system roles and roles assigned to users',
        () async {
      final db = newDatabase();
      addTearDown(db.close);
      final dao = RbacDao(db);
      const perms = PermissionService();
      const audit = AuditService();
      final del = DeleteRoleUseCase(dao, perms, audit);

      // A system role is never deletable.
      await expectLater(
        del.call(
          db,
          id: 'role_viewer',
          actingUserId: 'user_admin',
          actingRoleId: 'role_admin',
        ),
        throwsA(isA<InvalidOperationException>()),
      );

      // A custom role with an assigned user is not deletable either.
      final now = DateTime.now().millisecondsSinceEpoch;
      await db.into(db.roles).insert(RoleRow(
            id: 'role_used',
            name: 'used',
            nameAr: 'دور مستخدم',
            isSystem: false,
            isActive: true,
            createdAt: now,
            updatedAt: now,
          ));
      await seedExtraUser(db, username: 'used_user', roleId: 'role_used');
      await expectLater(
        del.call(
          db,
          id: 'role_used',
          actingUserId: 'user_admin',
          actingRoleId: 'role_admin',
        ),
        throwsA(isA<InvalidOperationException>()),
      );

      // An unused custom role deletes cleanly and is audited.
      final role = await dao.createRole(name: 'spare', nameAr: 'احتياطي');
      await del.call(
        db,
        id: role.id,
        actingUserId: 'user_admin',
        actingRoleId: 'role_admin',
      );
      final roles = await db.select(db.roles).get();
      expect(roles.any((r) => r.id == role.id), isFalse);
      final deletes = await (db.select(db.auditLogs)
            ..where((a) => a.action.equals('delete')))
          .get();
      expect(deletes, hasLength(1));
    });
  });

  group('RolesPage (admin, Arabic)', () {
    Widget harness(ProviderContainer container) {
      return UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          theme: AppTheme.light(),
          locale: const Locale(AppConfig.defaultLocale),
          supportedLocales: AppLocalizations.supportedLocales,
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          home: const Scaffold(body: RolesPage()),
        ),
      );
    }

    testWidgets('lists seeded roles with their Arabic labels', (tester) async {
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

      expect(find.text('مدير النظام'), findsOneWidget);
      expect(find.text('صيدلي'), findsOneWidget);
      expect(find.text('كاشير'), findsOneWidget);
      expect(find.text('مشاهد'), findsOneWidget);
      expect(find.text('إضافة دور'), findsOneWidget);
    });

    testWidgets('creates a custom role from the dialog', (tester) async {
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

      await tester.tap(find.text('إضافة دور'));
      await tester.pumpAndSettle();

      await tester.enterText(
          find.widgetWithText(TextFormField, 'اسم الدور'), 'صيدلي مختص');
      await tester.tap(find.text('حفظ'));
      await tester.pumpAndSettle();

      expect(find.text('تم إنشاء الدور'), findsOneWidget);
      expect(find.text('صيدلي مختص'), findsOneWidget);
    });

    testWidgets('permission dialog opens for a role and shows its name',
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

      await tester.tap(find.byTooltip('الصلاحيات').first);
      await tester.pumpAndSettle();

      expect(find.text('صلاحيات مدير النظام'), findsOneWidget);
      expect(find.byType(CheckboxListTile), findsWidgets);
    });
  });

  group('AdminHubPage (tabs)', () {
    Widget harness(ProviderContainer container, {AdminTab tab = AdminTab.users}) {
      return UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          theme: AppTheme.light(),
          locale: const Locale(AppConfig.defaultLocale),
          supportedLocales: AppLocalizations.supportedLocales,
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          home: Scaffold(body: AdminHubPage(initialTab: tab)),
        ),
      );
    }

    testWidgets('admin sees all three tabs and can open the roles tab',
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

      await tester.pumpWidget(harness(h.container, tab: AdminTab.roles));
      await tester.pumpAndSettle();

      expect(find.text('المستخدمون'), findsOneWidget);
      expect(find.text('الأدوار'), findsWidgets);
      expect(find.text('الصلاحيات'), findsOneWidget);
      expect(find.text('إضافة دور'), findsOneWidget);
    });

    testWidgets('a role with no admin permissions sees the access-denied note',
        (tester) async {
      tester.view.physicalSize = const Size(1280, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      final db = newDatabase();
      addTearDown(db.close);
      final now = DateTime.now().millisecondsSinceEpoch;
      await db.into(db.roles).insert(RoleRow(
            id: 'role_noaccess',
            name: 'noaccess',
            nameAr: 'بدون وصول',
            isSystem: false,
            isActive: true,
            createdAt: now,
            updatedAt: now,
          ));
      await seedExtraUser(
        db,
        username: 'noaccess',
        password: 'No@12345',
        roleId: 'role_noaccess',
      );

      final h = attachAuthTo(db);
      addTearDown(h.container.dispose);
      await h.container.read(authControllerProvider.notifier).login(
            'noaccess',
            'No@12345',
          );

      await tester.pumpWidget(harness(h.container));
      await tester.pumpAndSettle();

      expect(find.text('ليس لديك صلاحية للوصول إلى هذه الصفحة'), findsOneWidget);
    });
  });
}