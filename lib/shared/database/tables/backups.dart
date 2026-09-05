import 'package:drift/drift.dart';
import '../../models/enums.dart';

/// Backups ledger (§37). Every successful file backup registers one row and
/// an `AuditLogRow('backup')`; a restore round-trip is audited via
/// `'restore_backup'`. `checksumSha256` lets the restore path verify integrity.
@DataClassName('BackupRow')
@TableIndex(name: 'idx_backups_created', columns: {#createdAt})
@TableIndex(name: 'idx_backups_status', columns: {#status})
class Backups extends Table {
  TextColumn get id => text()();
  TextColumn get filePath => text()();
  TextColumn get fileName => text()();
  IntColumn get createdAt => integer()();
  TextColumn get appVersion => text().nullable()();
  IntColumn get schemaVersion => integer()();
  IntColumn get sizeBytes => integer()();
  TextColumn get checksumSha256 => text().nullable()();
  TextColumn get status => textEnum<BackupStatus>()();
  TextColumn get note => text().nullable()();

  @override
  Set<Column> get primaryKey => {id};
}