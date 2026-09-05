import 'package:flutter_test/flutter_test.dart';
import 'package:pharmacy_pos/core/constants/permission_codes.dart';
import 'package:pharmacy_pos/core/errors/exceptions.dart';
import 'package:pharmacy_pos/domain/services/permission_service.dart';
import 'package:pharmacy_pos/shared/database/app_database.dart';

import 'helpers.dart';

void main() {
  const permissions = PermissionService();

  late AppDatabase db;

  setUp(() {
    db = newDatabase();
  });

  tearDown(() async {
    await db.close();
  });

  group('PermissionService (§16)', () {
    test('admin has every permission', () async {
      final codes = await permissions.codesForRole(db, 'role_admin');
      for (final perm in kSeedPermissions) {
        expect(codes, contains(perm.code));
      }
      expect(codes, contains(Perm.sell));
      expect(codes, contains(Perm.managePermissions));
      expect(codes, contains(Perm.adjustStock));
    });

    test('cashier limited to sales, denied management', () async {
      final codes = await permissions.codesForRole(db, 'role_cashier');
      expect(codes, contains(Perm.salesCreate));
      expect(codes, contains(Perm.sell));
      expect(codes, isNot(contains(Perm.managePermissions)));
      expect(codes, isNot(contains(Perm.manageUsers)));
      expect(await permissions.hasRolePermission(db, 'role_cashier', Perm.sell),
          isTrue);
      expect(
          await permissions.hasRolePermission(
              db, 'role_cashier', Perm.managePermissions),
          isFalse);
    });

    test('pharmacist: allowed prices, denied invoice delete and audits',
        () async {
      final codes = await permissions.codesForRole(db, 'role_pharmacist');
      expect(codes, contains(Perm.changePrices));
      expect(codes, isNot(contains(Perm.changePurchaseCost)));
      expect(codes, isNot(contains(Perm.deleteInvoice)));
      expect(codes, isNot(contains(Perm.auditView)));
    });

    test('requireUserPermission enforced via the administrator user', () async {
      await permissions.requireUserPermission(db, 'user_admin', Perm.stockAdjust);
      await expectLater(
        permissions.requireUserPermission(db, 'user_admin', Perm.sell),
        completes,
      );
    });

    test('unknown user is denied', () async {
      await expectLater(
        permissions.requireUserPermission(db, 'nobody', Perm.sell),
        throwsA(isA<UnauthorizedException>()),
      );
    });
  });
}