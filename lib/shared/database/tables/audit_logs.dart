import 'package:drift/drift.dart';
import 'users.dart';

/// Immutable audit trail (§4.27, §17). Never updated or deleted; only appended
/// by the AuditService. `beforeData`/`afterData` hold JSON snapshots as TEXT;
/// `action` stores canonical plan strings ('create','update','delete','login',
/// 'logout','void','restore','price_change','bulk_op','audit_config','backup',
/// 'restore_backup').
@DataClassName('AuditLogRow')
@TableIndex(name: 'idx_audit_entity', columns: {#entityType, #entityId})
@TableIndex(name: 'idx_audit_user', columns: {#userId})
@TableIndex(name: 'idx_audit_created', columns: {#createdAt})
class AuditLogs extends Table {
  TextColumn get id => text()();
  TextColumn get userId => text().references(Users, #id)();
  TextColumn get action => text()();
  TextColumn get entityType => text()();
  TextColumn get entityId => text()();
  TextColumn get beforeData => text().nullable()();
  TextColumn get afterData => text().nullable()();
  TextColumn get ipAddress => text().nullable()();
  TextColumn get note => text().nullable()();
  IntColumn get createdAt => integer()();

  @override
  Set<Column> get primaryKey => {id};
}