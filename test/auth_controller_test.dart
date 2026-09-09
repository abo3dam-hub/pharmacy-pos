import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:flutter_test/flutter_test.dart';
import 'package:pharmacy_pos/core/constants/permission_codes.dart';
import 'package:pharmacy_pos/core/di/providers.dart';
import 'package:pharmacy_pos/core/errors/failures.dart';
import 'package:pharmacy_pos/domain/services/audit_service.dart';
import 'package:pharmacy_pos/features/auth/application/auth_controller.dart';
import 'package:pharmacy_pos/features/auth/application/users_controller.dart';
import 'package:pharmacy_pos/features/auth/domain/entities/user.dart';
import 'package:pharmacy_pos/features/auth/domain/services/password_service.dart';
import 'package:pharmacy_pos/features/auth/domain/usecases/deactivate_user.dart';
import 'package:pharmacy_pos/features/auth/domain/usecases/login.dart';
import 'package:pharmacy_pos/shared/database/app_database.dart';
import 'package:pharmacy_pos/shared/models/enums.dart';

import 'auth_harness.dart';

void main() {
  const passwords = PasswordService();

  /// Wires a real audit writer onto the AuthController so audit rows are
  /// asserted against the testing DB (mirrors the DI wiring).
  void attachRealAudit(AuthController controller, AppDatabase db) {
    controller.audit = ({
      required user,
      required success,
      note = '',
    }) async {
      if (user == null) return;
      final action = switch (note) {
        'logout' => AuditAction.logout,
        _ when success => AuditAction.login,
        _ => AuditAction.loginFailed,
      };
      await const AuditService().write(
        db,
        userId: user.id,
        action: action,
        entityType: 'user',
        entityId: user.id,
        note: note,
      );
    };
  }

  group('AuthController', () {
    test('successful login loads permissions and writes the audit trail',
        () async {
      final h = await buildAuthHarness();
      addTearDown(h.db.close);
      addTearDown(h.container.dispose);

      final notifier = h.container.read(authControllerProvider.notifier);
      attachRealAudit(notifier, h.db);

      final ok = await notifier.login('admin', 'Admin@123');
      expect(ok, isTrue);

      final state = h.container.read(authControllerProvider);
      expect(state.status, AuthStatus.authenticated);
      expect(state.isAuthenticated, isTrue);
      expect(state.submitting, isFalse);
      expect(state.user!.username, 'admin');
      expect(state.permissions, contains(Perm.usersView));
      expect(state.permissions, contains(Perm.usersCreate));

      final logs = await h.db.select(h.db.auditLogs).get();
      final logins = logs.where((l) => l.action == 'login').toList();
      expect(logins, hasLength(1));
      expect(logins.single.userId, 'user_admin');
      expect(logins.single.note, 'login_success');
    });

    test('wrong password stays unauthenticated and audits login_failed',
        () async {
      final h = await buildAuthHarness();
      addTearDown(h.db.close);
      addTearDown(h.container.dispose);

      final notifier = h.container.read(authControllerProvider.notifier);
      attachRealAudit(notifier, h.db);

      final ok = await notifier.login('admin', 'wrong-password');
      expect(ok, isFalse);

      final state = h.container.read(authControllerProvider);
      expect(state.status, AuthStatus.unauthenticated);
      expect(state.error, AuthError.invalidCredentials);

      final logs = await h.db.select(h.db.auditLogs).get();
      final failures = logs.where((l) => l.action == 'login_failed').toList();
      expect(failures, hasLength(1));
      expect(failures.single.userId, 'user_admin');
    });

    test('inactive accounts surface the inactive error', () async {
      final h = await buildAuthHarness();
      addTearDown(h.db.close);
      addTearDown(h.container.dispose);
      await seedExtraUser(h.db, username: 'blocked');

      final target = await h.repository.findByUsername('blocked');
      await DeactivateUserUseCase(h.repository).call(
        target!.id,
        actingUserId: 'user_admin',
        actingRoleId: UserRole.admin.roleId,
      );

      final notifier = h.container.read(authControllerProvider.notifier);
      final ok = await notifier.login('blocked', 'Cashier@123');
      expect(ok, isFalse);
      final state = h.container.read(authControllerProvider);
      expect(state.error, AuthError.inactive);
    });

    test('unknown usernames never write an audit row (NOT NULL userId rule)',
        () async {
      final h = await buildAuthHarness();
      addTearDown(h.db.close);
      addTearDown(h.container.dispose);

      final notifier = h.container.read(authControllerProvider.notifier);
      attachRealAudit(notifier, h.db);

      final ok = await notifier.login('ghost', 'whatever');
      expect(ok, isFalse);
      final logs = await h.db.select(h.db.auditLogs).get();
      expect(logs, isEmpty);
    });

    test('logout clears the session and writes the logout audit row', () async {
      final h = await buildAuthHarness();
      addTearDown(h.db.close);
      addTearDown(h.container.dispose);

      final notifier = h.container.read(authControllerProvider.notifier);
      attachRealAudit(notifier, h.db);

      await notifier.login('admin', 'Admin@123');
      await notifier.logout();

      final state = h.container.read(authControllerProvider);
      expect(state.status, AuthStatus.unauthenticated);
      expect(state.user, isNull);

      final logs = await h.db.select(h.db.auditLogs).get();
      final logouts = logs.where((l) => l.action == 'logout').toList();
      expect(logouts, hasLength(1));
      expect(logouts.single.userId, 'user_admin');
    });

    test('malformed stored hash never hangs the login button', () async {
      final h = await buildAuthHarness();
      addTearDown(h.db.close);
      addTearDown(h.container.dispose);

      final now = DateTime.now().millisecondsSinceEpoch;
      await h.db.into(h.db.users).insert(
            UsersCompanion.insert(
              id: 'user_corrupt',
              username: 'legacy',
              passwordHash: 'legacy-plaintext-not-bcrypt',
              fullName: 'مستخدم قديم',
              roleId: UserRole.cashier.roleId,
              isActive: const Value(true),
              createdAt: now,
              updatedAt: now,
            ),
          );

      final notifier = h.container.read(authControllerProvider.notifier);
      final ok =
          await notifier.login('legacy', 'legacy-plaintext-not-bcrypt');

      expect(ok, isFalse);
      final state = h.container.read(authControllerProvider);
      expect(state.status, AuthStatus.unauthenticated);
      // The spinner must release: submitting came back down.
      expect(state.submitting, isFalse);
      expect(state.error, AuthError.invalidCredentials);
    });

    test('the real login pipeline records lastLoginAt', () async {
      final h = await buildAuthHarness();
      addTearDown(h.db.close);
      addTearDown(h.container.dispose);

      final result =
          await LoginUseCase(h.repository, passwords).call('admin', 'Admin@123');
      expect(result.isSuccess, isTrue);
      final after = await h.repository.findByUsername('admin');
      expect(after!.lastLoginAt, result.user!.lastLoginAt);
      expect(result.user!.lastLoginAt, isNotNull);
    });
  });

  group('UsersViewController', () {
    test('loads the paged list and assignment roles', () async {
      final h = await buildAuthHarness();
      addTearDown(h.db.close);
      addTearDown(h.container.dispose);

      final vc = h.container.read(usersViewControllerProvider.notifier);
      await vc.load();

      final state = h.container.read(usersViewControllerProvider);
      expect(state.status, UsersStatus.ready);
      expect(state.items.total, 1);
      expect(state.roles.length, 4);
      expect(
        state.roles.map((r) => r.id),
        containsAll(const [
          'role_admin',
          'role_pharmacist',
          'role_cashier',
          'role_viewer',
        ]),
      );
    });

    test('create persists a user and audits with the acting admin', () async {
      final h = await buildAuthHarness();
      addTearDown(h.db.close);
      addTearDown(h.container.dispose);

      final vc = h.container.read(usersViewControllerProvider.notifier);
      await vc.create(
        username: 'newcashier',
        displayName: 'كاشير جديد',
        roleId: UserRole.cashier.roleId,
        password: 'Cash@12345',
        actingUserId: 'user_admin',
        actingRoleId: UserRole.admin.roleId,
      );

      final created = await h.repository.findByUsername('newcashier');
      expect(created, isNotNull);
      expect(created!.displayName, 'كاشير جديد');

      final state = h.container.read(usersViewControllerProvider);
      expect(state.items.items.map((u) => u.username), contains('newcashier'));

      final logs = await h.db.select(h.db.auditLogs).get();
      final creates = logs.where((l) => l.action == 'create').toList();
      expect(creates, hasLength(1));
      expect(creates.single.note, 'user_created');
      expect(creates.single.userId, 'user_admin');
    });

    test('deactivating your own account returns an operation failure',
        () async {
      final h = await buildAuthHarness();
      addTearDown(h.db.close);
      addTearDown(h.container.dispose);

      final vc = h.container.read(usersViewControllerProvider.notifier);
      await vc.load();
      final failure = await vc.setActive(
        id: 'user_admin',
        active: false,
        actingUserId: 'user_admin',
        actingRoleId: UserRole.admin.roleId,
      );
      expect(failure, isA<InvalidOperationFailure>());
    });

    test('deactivate + reactivate updates the row and audits', () async {
      final h = await buildAuthHarness();
      addTearDown(h.db.close);
      addTearDown(h.container.dispose);
      await seedExtraUser(h.db, username: 'second');

      final vc = h.container.read(usersViewControllerProvider.notifier);
      final second = await h.repository.findByUsername('second');

      await vc.setActive(
        id: second!.id,
        active: false,
        actingUserId: 'user_admin',
        actingRoleId: UserRole.admin.roleId,
      );
      expect((await h.repository.findByUsername('second'))!.isActive, isFalse);

      await vc.setActive(
        id: second.id,
        active: true,
        actingUserId: 'user_admin',
        actingRoleId: UserRole.admin.roleId,
      );
      expect((await h.repository.findByUsername('second'))!.isActive, isTrue);

      final logs = await h.db.select(h.db.auditLogs).get();
      expect(logs.where((l) => l.action == 'delete'), hasLength(1));
      expect(logs.where((l) => l.action == 'restore'), hasLength(1));
    });

    test('change password replaces the hash and audits', () async {
      final h = await buildAuthHarness();
      addTearDown(h.db.close);
      addTearDown(h.container.dispose);

      final vc = h.container.read(usersViewControllerProvider.notifier);
      final failure = await vc.changePassword(
        id: 'user_admin',
        newPassword: 'NewPass@99',
        actingUserId: 'user_admin',
        actingRoleId: UserRole.admin.roleId,
      );
      expect(failure, isNull);

      expect(
        (await LoginUseCase(h.repository, passwords).call('admin', 'Admin@123'))
            .isSuccess,
        isFalse,
      );
      expect(
        (await LoginUseCase(h.repository, passwords)
                .call('admin', 'NewPass@99'))
            .isSuccess,
        isTrue,
      );

      final logs = await h.db.select(h.db.auditLogs).get();
      final pw = logs.where((l) => l.note == 'password_changed').toList();
      expect(pw, hasLength(1));
      expect(pw.single.entityId, 'user_admin');
    });

    test('non-admin acting role returns an authorization failure', () async {
      final h = await buildAuthHarness();
      addTearDown(h.db.close);
      addTearDown(h.container.dispose);
      await seedExtraUser(h.db, username: 'cashier');

      final vc = h.container.read(usersViewControllerProvider.notifier);
      final failure = await vc.create(
        username: 'sneaky',
        displayName: 'مخترق',
        roleId: UserRole.cashier.roleId,
        password: 'Cash@12345',
        actingUserId: 'user_cashier',
        actingRoleId: UserRole.cashier.roleId,
      );
      expect(failure, isA<UnauthorizedFailure>());
      final logs = await h.db.select(h.db.auditLogs).get();
      expect(logs.where((l) => l.action == 'create'), isEmpty);
    });
  });
}