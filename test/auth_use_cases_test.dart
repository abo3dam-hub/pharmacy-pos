import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:flutter_test/flutter_test.dart';
import 'package:pharmacy_pos/core/constants/permission_codes.dart';
import 'package:pharmacy_pos/core/data_grid/page_request.dart';
import 'package:pharmacy_pos/core/errors/exceptions.dart';
import 'package:pharmacy_pos/features/auth/domain/entities/user.dart';
import 'package:pharmacy_pos/features/auth/domain/services/password_service.dart';
import 'package:pharmacy_pos/features/auth/domain/usecases/change_password.dart';
import 'package:pharmacy_pos/features/auth/domain/usecases/check_permission.dart';
import 'package:pharmacy_pos/features/auth/domain/usecases/create_user.dart';
import 'package:pharmacy_pos/features/auth/domain/usecases/deactivate_user.dart';
import 'package:pharmacy_pos/features/auth/domain/usecases/list_users.dart';
import 'package:pharmacy_pos/features/auth/domain/usecases/login.dart';
import 'package:pharmacy_pos/features/auth/domain/usecases/reactivate_user.dart';
import 'package:pharmacy_pos/features/auth/domain/usecases/update_user.dart';
import 'package:pharmacy_pos/shared/database/app_database.dart';

import 'auth_harness.dart';

void main() {
  const passwords = PasswordService();
  final adminRole = UserRole.admin.roleId;
  final cashierRole = UserRole.cashier.roleId;

  group('PasswordService', () {
    test('hashes with bcrypt and never stores plaintext', () {
      final hash = passwords.hash('Secret@123');
      expect(hash.startsWith(r'$2'), isTrue);
      expect(hash.contains('Secret@123'), isFalse);
      expect(passwords.verify('Secret@123', hash), isTrue);
      expect(passwords.verify('Wrong!', hash), isFalse);
    });

    test('separate salt means equal inputs hash differently', () {
      expect(passwords.hash('same'), isNot(passwords.hash('same')));
    });

    test('enforces the 6-character minimum', () {
      expect(passwords.isValidLength('abc'), isFalse);
      expect(passwords.isValidLength('abcdef'), isTrue);
    });

    test('malformed stored hash rejects cleanly instead of throwing', () {
      expect(passwords.verify('Admin@123', ''), isFalse);
      expect(passwords.verify('Admin@123', 'legacy-plaintext'), isFalse);
      // Truncated bcrypt hashes used to make checkpw throw (invalid salt
      // revision), which hung the login spinner.
      final full = passwords.hash('Admin@123');
      expect(passwords.verify('Admin@123', full.substring(0, 20)), isFalse);
    });
  });

  group('LoginUseCase', () {
    test('success verifies bcrypt and records the last login', () async {
      final h = await buildAuthHarness();
      addTearDown(h.db.close);

      final result =
          await LoginUseCase(h.repository, passwords).call('admin', 'Admin@123');
      expect(result.isSuccess, isTrue);
      expect(result.user!.roleId, adminRole);
      expect(result.user!.lastLoginAt, isNotNull);
    });

    test('unknown username fails with no subject', () async {
      final h = await buildAuthHarness();
      addTearDown(h.db.close);

      final result =
          await LoginUseCase(h.repository, passwords).call('nobody', 'x');
      expect(result.isSuccess, isFalse);
      expect(result.failure, LoginFailure.invalidCredentials);
      expect(result.subject, isNull);
    });

    test('wrong password reports invalid credentials without last login',
        () async {
      final h = await buildAuthHarness();
      addTearDown(h.db.close);

      final before = await h.repository.findByUsername('admin');
      final result =
          await LoginUseCase(h.repository, passwords).call('admin', 'wrong');
      expect(result.isSuccess, isFalse);
      expect(result.failure, LoginFailure.invalidCredentials);
      expect(result.subject, isNotNull);
      final after = await h.repository.findByUsername('admin');
      expect(after!.lastLoginAt, before!.lastLoginAt);
    });

    test('malformed stored hash rejects cleanly instead of throwing', () async {
      final h = await buildAuthHarness();
      addTearDown(h.db.close);

      final now = DateTime.now().millisecondsSinceEpoch;
      await h.db.into(h.db.users).insert(
            UsersCompanion.insert(
              id: 'user_corrupt',
              username: 'legacy',
              passwordHash: 'legacy-plaintext-not-bcrypt',
              fullName: 'مستخدم قديم',
              roleId: cashierRole,
              isActive: const Value(true),
              createdAt: now,
              updatedAt: now,
            ),
          );

      final result = await LoginUseCase(h.repository, passwords)
          .call('legacy', 'legacy-plaintext-not-bcrypt');
      expect(result.isSuccess, isFalse);
      expect(result.failure, LoginFailure.invalidCredentials);
      expect(result.subject?.username, 'legacy');
    });

    test('duplicate usernames from a restored store still log in', () async {
      final h = await buildAuthHarness();
      addTearDown(h.db.close);

      final now = DateTime.now().millisecondsSinceEpoch;
      final oldHash = passwords.hash('Repeat@123');
      // Two rows sharing one username: the oldest must win deterministically
      // instead of findByUsername throwing on multiple matches.
      await h.db.into(h.db.users).insert(
            UsersCompanion.insert(
              id: 'user_dup_old',
              username: 'dup',
              passwordHash: oldHash,
              fullName: 'الأقدم',
              roleId: cashierRole,
              isActive: const Value(true),
              createdAt: now - 100000,
              updatedAt: now - 100000,
            ),
          );
      await h.db.into(h.db.users).insert(
            UsersCompanion.insert(
              id: 'user_dup_new',
              username: 'DUP',
              passwordHash: passwords.hash('Repeat@123'),
              fullName: 'الأحدث',
              roleId: cashierRole,
              isActive: const Value(true),
              createdAt: now,
              updatedAt: now,
            ),
          );

      final result =
          await LoginUseCase(h.repository, passwords).call('dup', 'Repeat@123');
      expect(result.isSuccess, isTrue);
      expect(result.user!.id, 'user_dup_old');
    });

    test('inactive accounts are rejected before verification', () async {
      final h = await buildAuthHarness();
      addTearDown(h.db.close);

      await CreateUserUseCase(h.repository, passwords).call(
        username: 'joe',
        displayName: 'Joe',
        roleId: cashierRole,
        password: 'Passw0rd!',
        actingRoleId: adminRole,
      );
      final created = await h.repository.findByUsername('joe');
      await DeactivateUserUseCase(h.repository).call(
        created!.id,
        actingUserId: 'user_admin',
        actingRoleId: adminRole,
      );

      final result =
          await LoginUseCase(h.repository, passwords).call('joe', 'Passw0rd!');
      expect(result.isSuccess, isFalse);
      expect(result.failure, LoginFailure.inactive);
      expect(result.subject, isNotNull);
    });
  });

  group('CreateUserUseCase', () {
    test('persists the user with a bcrypt hash only', () async {
      final h = await buildAuthHarness();
      addTearDown(h.db.close);

      final created = await CreateUserUseCase(h.repository, passwords).call(
        username: 'pharmacist01',
        displayName: 'صيدلي أول',
        roleId: cashierRole,
        password: 'Passw0rd!',
        phone: '0599-123456',
        notes: 'بدوام صباحي',
        actingRoleId: adminRole,
      );

      expect(created.username, 'pharmacist01');
      expect(created.roleId, cashierRole);
      expect(created.passwordHash.startsWith(r'$2'), isTrue);
      expect(created.phone, '0599-123456');

      final stored = await h.repository.findByUsername('pharmacist01');
      expect(stored!.displayName, 'صيدلي أول');
      expect(passwords.verify('Passw0rd!', stored.passwordHash), isTrue);
    });

    test('rejects a duplicate username case-insensitively', () async {
      final h = await buildAuthHarness();
      addTearDown(h.db.close);

      final create = CreateUserUseCase(h.repository, passwords);
      await create.call(
        username: 'cashier01',
        displayName: 'كاشير',
        roleId: cashierRole,
        password: 'Passw0rd!',
        actingRoleId: adminRole,
      );

      expect(
        () => create.call(
          username: 'CASHIER01',
          displayName: 'مكرر',
          roleId: cashierRole,
          password: 'Passw0rd!',
          actingRoleId: adminRole,
        ),
        throwsA(isA<DuplicateException>()),
      );
    });

    test('rejects short passwords', () async {
      final h = await buildAuthHarness();
      addTearDown(h.db.close);

      expect(
        () => CreateUserUseCase(h.repository, passwords).call(
          username: 'shorty',
          displayName: 'س',
          roleId: cashierRole,
          password: '12345',
          actingRoleId: adminRole,
        ),
        throwsA(isA<ValidationException>()),
      );
    });

    test('denies without the users.create permission (acting role)', () async {
      final h = await buildAuthHarness();
      addTearDown(h.db.close);

      // Cashiers have no users.* permission.
      expect(
        () => CreateUserUseCase(h.repository, passwords).call(
          username: 'x',
          displayName: 'س',
          roleId: cashierRole,
          password: 'Passw0rd!',
          actingRoleId: cashierRole,
        ),
        throwsA(isA<UnauthorizedException>()),
      );
    });

    test('denies a null acting role', () async {
      final h = await buildAuthHarness();
      addTearDown(h.db.close);

      expect(
        () => CreateUserUseCase(h.repository, passwords).call(
          username: 'x',
          displayName: 'س',
          roleId: cashierRole,
          password: 'Passw0rd!',
        ),
        throwsA(isA<UnauthorizedException>()),
      );
    });
  });

  group('UpdateUserUseCase', () {
    test('updates the profile and role', () async {
      final h = await buildAuthHarness();
      addTearDown(h.db.close);

      final created = await CreateUserUseCase(h.repository, passwords).call(
        username: 'chemist',
        displayName: 'كيميائي',
        roleId: cashierRole,
        password: 'Passw0rd!',
        actingRoleId: adminRole,
      );

      final updated = await UpdateUserUseCase(h.repository).call(
        id: created.id,
        displayName: 'كيميائي أول',
        roleId: adminRole,
        actingRoleId: adminRole,
      );
      expect(updated.displayName, 'كيميائي أول');
      expect(updated.roleId, adminRole);
    });

    test('rejects missing users and missing permission', () async {
      final h = await buildAuthHarness();
      addTearDown(h.db.close);

      final useCase = UpdateUserUseCase(h.repository);
      expect(
        () => useCase.call(
          id: 'user_missing',
          displayName: 'x',
          roleId: cashierRole,
          actingRoleId: adminRole,
        ),
        throwsA(isA<NotFoundException>()),
      );
      expect(
        () => useCase.call(
          id: 'user_missing',
          displayName: 'x',
          roleId: cashierRole,
          actingRoleId: cashierRole,
        ),
        throwsA(isA<UnauthorizedException>()),
      );
    });
  });

  group('Deactivate / Reactivate use cases', () {
    test('soft-deactivates and reactivates a user', () async {
      final h = await buildAuthHarness();
      addTearDown(h.db.close);

      final created = await CreateUserUseCase(h.repository, passwords).call(
        username: 'night',
        displayName: 'وردية ليلية',
        roleId: cashierRole,
        password: 'Passw0rd!',
        actingRoleId: adminRole,
      );

      await DeactivateUserUseCase(h.repository).call(
        created.id,
        actingUserId: 'user_admin',
        actingRoleId: adminRole,
      );
      final deactivated = await h.repository.findById(created.id);
      expect(deactivated!.isActive, isFalse);

      await ReactivateUserUseCase(h.repository).call(
        created.id,
        actingRoleId: adminRole,
      );
      final reactivated = await h.repository.findById(created.id);
      expect(reactivated!.isActive, isTrue);
    });

    test('prevents deactivating your own account', () async {
      final h = await buildAuthHarness();
      addTearDown(h.db.close);

      expect(
        () => DeactivateUserUseCase(h.repository).call(
          'user_admin',
          actingUserId: 'user_admin',
          actingRoleId: adminRole,
        ),
        throwsA(isA<InvalidOperationException>()),
      );
    });

    test('requires users.edit permission', () async {
      final h = await buildAuthHarness();
      addTearDown(h.db.close);

      expect(
        () => DeactivateUserUseCase(h.repository).call(
          'user_admin',
          actingUserId: 'user_cashier',
          actingRoleId: cashierRole,
        ),
        throwsA(isA<UnauthorizedException>()),
      );
    });
  });

  group('ChangePasswordUseCase', () {
    test('replaces the hash so the old password stops working', () async {
      final h = await buildAuthHarness();
      addTearDown(h.db.close);

      await ChangePasswordUseCase(h.repository, passwords).call(
        'user_admin',
        'NewPass@9',
        actingRoleId: adminRole,
      );

      final old = await LoginUseCase(h.repository, passwords)
          .call('admin', 'Admin@123');
      expect(old.isSuccess, isFalse);
      final changed = await LoginUseCase(h.repository, passwords)
          .call('admin', 'NewPass@9');
      expect(changed.isSuccess, isTrue);
    });

    test('rejects short passwords and missing permission', () async {
      final h = await buildAuthHarness();
      addTearDown(h.db.close);

      expect(
        () => ChangePasswordUseCase(h.repository, passwords)
            .call('user_admin', '12345', actingRoleId: adminRole),
        throwsA(isA<ValidationException>()),
      );
      expect(
        () => ChangePasswordUseCase(h.repository, passwords)
            .call('user_admin', 'NewPass@9', actingRoleId: cashierRole),
        throwsA(isA<UnauthorizedException>()),
      );
    });
  });

  group('Permissions & roles', () {
    test('admin holds users.* while operational roles do not', () async {
      final h = await buildAuthHarness();
      addTearDown(h.db.close);

      final check = CheckPermissionUseCase(h.repository);
      expect(await check.call(adminRole, Perm.usersView), isTrue);
      expect(await check.call(adminRole, Perm.usersCreate), isTrue);
      expect(await check.call(adminRole, Perm.usersEdit), isTrue);
      for (final code in [Perm.usersView, Perm.usersCreate, Perm.usersEdit]) {
        expect(await check.call(cashierRole, code), isFalse);
        expect(await check.call(UserRole.viewer.roleId, code), isFalse);
        expect(await check.call(UserRole.pharmacist.roleId, code), isFalse);
      }
    });

    test('roles list includes the read-only viewer role', () async {
      final h = await buildAuthHarness();
      addTearDown(h.db.close);

      final roles = await h.repository.listRoles();
      expect(roles.map((r) => r.id), contains(UserRole.viewer.roleId));
      expect(roles.map((r) => r.nameAr), contains('مشاهد'));
      expect(roles.length, 4);
    });
  });

  group('ListUsersUseCase', () {
    test('paginates and searches in SQL, not in memory', () async {
      final h = await buildAuthHarness();
      addTearDown(h.db.close);

      final create = CreateUserUseCase(h.repository, passwords);
      for (var i = 0; i < 3; i++) {
        await create.call(
          username: 'cashier_$i',
          displayName: 'كاشير رقم $i',
          roleId: cashierRole,
          password: 'Passw0rd!',
          actingRoleId: adminRole,
        );
      }

      final all = await ListUsersUseCase(h.repository)
          .call(const PageRequest(pageSize: 10));
      expect(all.total, 4); // admin + 3 cashiers
      expect(all.items, hasLength(4));

      final firstPage = await ListUsersUseCase(h.repository)
          .call(const PageRequest(page: 1, pageSize: 2));
      expect(firstPage.items, hasLength(2));
      expect(firstPage.hasMore, isTrue);
      final secondPage = await ListUsersUseCase(h.repository)
          .call(const PageRequest(page: 2, pageSize: 2));
      expect(secondPage.items, hasLength(2));
      expect(secondPage.hasMore, isFalse);

      final search = await ListUsersUseCase(h.repository)
          .call(PageRequest(search: 'رقم 2'));
      expect(search.total, 1);
      expect(search.items.single.username, 'cashier_2');

      // Case-insensitive username matching.
      final upper = await ListUsersUseCase(h.repository)
          .call(PageRequest(search: 'CASHIER_1'));
      expect(upper.total, 1);
    });
  });
}