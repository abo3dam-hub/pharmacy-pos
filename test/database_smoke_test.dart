import 'dart:ffi';

import 'package:flutter_test/flutter_test.dart';
import 'package:pharmacy_pos/shared/database/app_database.dart';
import 'package:sqlite3/open.dart' as sqlite3_open;

void _useSystemSqlite() {
  sqlite3_open.open.overrideFor(sqlite3_open.OperatingSystem.linux, () {
    return DynamicLibrary.open('libsqlite3.so.0');
  });
}

void main() {
  _useSystemSqlite();

  group('AppDatabase smoke', () {
    late AppDatabase db;

    setUp(() async {
      db = AppDatabase.forTesting();
    });

    tearDown(() async {
      await db.close();
    });

    test('migrates and seeds defaults', () async {
      final units = await db.select(db.units).get();
      expect(units, isNotEmpty);
      expect(units.every((u) => u.name.isNotEmpty), isTrue);

      final roles = await db.select(db.roles).get();
      expect(roles, hasLength(4));
      expect(roles.map((r) => r.id), containsAll([
        'role_admin',
        'role_pharmacist',
        'role_cashier',
        'role_viewer',
      ]));
    });

    test('seeds all permissions and admin role mapping', () async {
      final perms = await db.select(db.permissions).get();
      expect(perms, isNotEmpty);
      expect(perms.length, greaterThanOrEqualTo(30));

      final adminLinks = await (db.select(db.rolePermissions)
            ..where((rp) => rp.roleId.equals('role_admin')))
          .get();
      expect(adminLinks, hasLength(perms.length));
    });

    test('seeds admin user with hashed password', () async {
      final admin = await (db.select(db.users)
            ..where((u) => u.username.equals('admin')))
          .getSingle();
      expect(admin.passwordHash, isNotEmpty);
      expect(admin.passwordHash.startsWith(r'$2'), isTrue);
      expect(admin.roleId, 'role_admin');
    });

    test('seeds chart of accounts', () async {
      final accounts = await db.select(db.accounts).get();
      expect(accounts, hasLength(12));
    });
  });
}