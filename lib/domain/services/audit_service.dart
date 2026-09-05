import 'dart:convert';

import 'package:drift/drift.dart';

import '../../core/util/ids.dart';
import '../../shared/database/app_database.dart';
import '../../shared/models/enums.dart';

/// Writes the immutable, append-only audit trail (§17).
///
/// Rows are never updated or deleted. `beforeData` / `afterData` hold JSON
/// snapshots.
class AuditService {
  const AuditService();

  Future<void> write(
    AppDatabase db, {
    String? userId,
    required AuditAction action,
    required String entityType,
    String? entityId,
    Map<String, Object?>? before,
    Map<String, Object?>? after,
    String? note,
    int? atMillis,
  }) async {
    await db.into(db.auditLogs).insert(
          AuditLogsCompanion.insert(
            id: newId('audit'),
            userId: userId != null ? Value(userId) : const Value(null),
            action: action,
            entityType: entityType,
            entityId: entityId != null ? Value(entityId) : const Value(null),
            beforeData: before != null ? Value(jsonEncode(before)) : const Value(null),
            afterData: after != null ? Value(jsonEncode(after)) : const Value(null),
            note: note != null ? Value(note) : const Value(null),
            createdAt: atMillis ?? DateTime.now().millisecondsSinceEpoch,
          ),
        );
  }
}