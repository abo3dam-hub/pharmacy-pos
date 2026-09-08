import 'dart:io';

import 'package:drift/drift.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:pharmacy_pos/core/errors/exceptions.dart';
import 'package:pharmacy_pos/core/constants/permission_codes.dart';
import 'package:pharmacy_pos/domain/services/backup_archive_service.dart';
import 'package:pharmacy_pos/domain/services/data_export_service.dart';
import 'package:pharmacy_pos/domain/services/permission_service.dart';
import 'package:pharmacy_pos/domain/services/restore_service.dart';
import 'package:pharmacy_pos/features/backup/domain/usecases/backup_use_cases.dart';
import 'package:pharmacy_pos/shared/database/app_database.dart';

import 'helpers.dart';

/// Phase 13 RBAC: backup / backup.restore / export.data are seeded onto the
/// admin role on every open (idempotent), and the use cases enforce them.
void main() {
  late AppDatabase db;
  late Directory work;

  setUp(() {
    db = newDatabase();
    work = Directory.systemTemp.createTempSync('backup_rbac_');
  });

  tearDown(() async {
    await db.close();
    if (work.existsSync()) {
      work.deleteSync(recursive: true);
    }
  });

  test('admin role holds backup, backup.restore and export.data', () async {
    final codes = await const PermissionService()
        .codesForRole(db, 'role_admin');
    expect(codes, containsAll([
      Perm.backup,
      Perm.backupRestore,
      Perm.exportData,
    ]));
  });

  test('ensureBackupPermissions is idempotent across re-opens', () async {
    // Re-open the same underlying file twice; the seed must be idempotent.
    final dbFile = p.join(work.path, 'idem.sqlite');
    final a = AppDatabase.fromFilePath(dbFile);
    await a.close();
    final b = AppDatabase.fromFilePath(dbFile);
    final codes = await const PermissionService().codesForRole(b,
        'role_admin');
    expect(codes, containsAll([Perm.backup, Perm.backupRestore, Perm.exportData]));
    await b.close();
  });

  group('backup use cases', () {
    const archiver = BackupArchiveService();
    const restore = RestoreService();
    const exporter = DataExportService();
    const permissions = PermissionService();
    final createBackup = CreateBackupUseCase(archiver, permissions);
    final previewRestore = PreviewRestoreUseCase(restore, permissions);
    final restoreBackup = RestoreBackupUseCase(restore, permissions);
    final exportData = ExportDataUseCase(exporter, permissions);

    test('unauthorized role is rejected for create/restore/export', () async {
      // role_cashier has sell rights but none of the data-management perms.
      const role = 'role_cashier';
      await expectLater(
        createBackup(db,
            actingRoleId: role,
            databasePath: 'x.sqlite',
            receiptsDirectory: '-',
            destinationDirectory: '-'),
        throwsA(isA<UnauthorizedException>()),
      );
      await expectLater(
        previewRestore(db, actingRoleId: role, archivePath: 'x.zip'),
        throwsA(isA<UnauthorizedException>()),
      );
      await expectLater(
        restoreBackup(db,
            actingRoleId: role,
            archivePath: 'x.zip',
            liveDatabasePath: '-',
            receiptsDirectory: '-',
            emergencyDirectory: '-',
            userId: null),
        throwsA(isA<UnauthorizedException>()),
      );
      await expectLater(
        exportData(db, actingRoleId: role, destinationDirectory: '-'),
        throwsA(isA<UnauthorizedException>()),
      );
    });

    test('null actingRoleId is rejected', () async {
      await expectLater(
        createBackup(db,
            actingRoleId: null,
            databasePath: 'x.sqlite',
            receiptsDirectory: '-',
            destinationDirectory: '-'),
        throwsA(isA<UnauthorizedException>()),
      );
    });

    test('admin may create, preview and export', () async {
      await insertItem(db);
      // Admin presence is granted through the seeded role_permissions rows.
      final created = await createBackup(
        db,
        actingRoleId: 'role_admin',
        databasePath: 'unused.sqlite',
        receiptsDirectory: p.join(work.path, 'receipts'),
        destinationDirectory: p.join(work.path, 'b'),
        fileName: 'by_permission.zip',
      );
      expect(created.archivePath, endsWith('by_permission.zip'));

      final preview =
          await previewRestore(db, actingRoleId: 'role_admin',
              archivePath: created.archivePath);
      expect(preview.valid, isTrue);

      final exported = await exportData(
        db,
        actingRoleId: 'role_admin',
        destinationDirectory: p.join(work.path, 'e'),
      );
      expect(exported.files, isNotEmpty);
    });

    test('role granted archive only cannot preview (partial rights)', () async {
      // Grant exactly `backup` to a fresh operator role, nothing else.
      const roleId = 'role_backup_only';
      final now = DateTime.now().millisecondsSinceEpoch;
      await db.into(db.roles).insert(RolesCompanion.insert(
            id: roleId,
            name: 'role_backup_only',
            nameAr: 'نسخ فقط',
            isSystem: const Value(false),
            createdAt: now,
            updatedAt: now,
          ));
      final permId = 'perm_${Perm.backup.replaceAll('.', '_')}';
      await db.into(db.rolePermissions).insert(RolePermissionsCompanion.insert(
            id: 'rp_backup_only',
            roleId: roleId,
            permissionId: permId,
            granted: const Value(true),
            createdAt: now,
          ));

      final ok = await createBackup(
        db,
        actingRoleId: roleId,
        databasePath: 'unused.sqlite',
        receiptsDirectory: p.join(work.path, 'receipts'),
        destinationDirectory: p.join(work.path, 'b2'),
      );
      expect(ok.archivePath, isNotEmpty);

      await expectLater(
        previewRestore(db, actingRoleId: roleId, archivePath: ok.archivePath),
        throwsA(isA<UnauthorizedException>()),
      );
    });
  });
}