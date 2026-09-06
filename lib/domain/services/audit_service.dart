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
}