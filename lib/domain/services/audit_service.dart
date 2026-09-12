import 'dart:convert';

import 'package:drift/drift.dart';

import '../../core/util/ids.dart';
import '../../shared/database/app_database.dart';
import '../../shared/models/enums.dart';

/// Maps a Dart [AuditAction] to the canonical stored TEXT value from the plan
/// (§4.27, §17). `void` cannot be a Dart enum member, so the identifier
/// `voidOrder` persists the plan string `'void'`.
String auditActionToStored(AuditAction action) {
  switch (action) {
    case AuditAction.create:
      return 'create';
    case AuditAction.update:
      return 'update';
    case AuditAction.delete:
      return 'delete';
    case AuditAction.login:
      return 'login';
    case AuditAction.logout:
      return 'logout';
    case AuditAction.loginFailed:
      return 'login_failed';
    case AuditAction.voidOrder:
      return 'void';
    case AuditAction.restore:
      return 'restore';
    case AuditAction.priceChange:
      return 'price_change';
    case AuditAction.bulkOp:
      return 'bulk_op';
    case AuditAction.auditConfig:
      return 'audit_config';
    case AuditAction.backup:
      return 'backup';
    case AuditAction.restoreBackup:
      return 'restore_backup';
  }
}

/// Writes the immutable, append-only audit trail (§17).
///
/// Rows are never updated or deleted. `beforeData` / `afterData` hold JSON
/// snapshots. [userId] and [entityId] are mandatory (NOT NULL per §4.27).
class AuditService {
  const AuditService();

  Future<void> write(
    AppDatabase db, {
    required String userId,
    required AuditAction action,
    required String entityType,
    required String entityId,
    Map<String, Object?>? before,
    Map<String, Object?>? after,
    String? note,
    String? ipAddress,
    int? atMillis,
  }) async {
    await db.into(db.auditLogs).insert(
          AuditLogsCompanion.insert(
            id: newId('audit'),
            userId: userId,
            action: auditActionToStored(action),
            entityType: entityType,
            entityId: entityId,
            beforeData: before != null ? Value(jsonEncode(before)) : const Value(null),
            afterData: after != null ? Value(jsonEncode(after)) : const Value(null),
            ipAddress: ipAddress != null ? Value(ipAddress) : const Value(null),
            note: note != null ? Value(note) : const Value(null),
            createdAt: atMillis ?? DateTime.now().millisecondsSinceEpoch,
          ),
        );
  }

  /// Writes a whole batch of audit rows through a single prepared insert
  /// (§28 performance): the import path emits one row per item, so batching
  /// keeps an 11k-row catalog import from paying one transaction per row for
  /// the ledger on top of the inventory writes.
  Future<void> writeMany(AppDatabase db, List<AuditEntry> entries) async {
    if (entries.isEmpty) return;
    final now = DateTime.now().millisecondsSinceEpoch;
    await db.batch((batch) {
      for (final e in entries) {
        batch.insert(
          db.auditLogs,
          AuditLogsCompanion.insert(
            id: newId('audit'),
            userId: e.userId,
            action: auditActionToStored(e.action),
            entityType: e.entityType,
            entityId: e.entityId,
            beforeData:
                e.before != null ? Value(jsonEncode(e.before)) : const Value(null),
            afterData:
                e.after != null ? Value(jsonEncode(e.after)) : const Value(null),
            note: e.note != null ? Value(e.note) : const Value(null),
            createdAt: now,
          ),
        );
      }
    });
  }
}

/// One pending audit row, used to defer ledger writes into a single
/// transaction through [AuditService.writeMany].
class AuditEntry {
  const AuditEntry({
    required this.userId,
    required this.action,
    required this.entityType,
    required this.entityId,
    this.before,
    this.after,
    this.note,
  });

  final String userId;
  final AuditAction action;
  final String entityType;
  final String entityId;
  final Map<String, Object?>? before;
  final Map<String, Object?>? after;
  final String? note;
}