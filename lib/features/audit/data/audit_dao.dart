import 'package:drift/drift.dart';

import '../../../../core/data_grid/page_request.dart';
import '../../../../shared/database/app_database.dart';
import '../domain/entities/audit_entry.dart';

/// Read-only projection DAO over `audit_logs` (LEFT JOIN `users`) for the
/// Phase 12 audit viewer. Never writes — the audit trail is append-only.
class AuditDao {
  const AuditDao(this._db);

  final AppDatabase _db;

  Future<PageResult<AuditEntry>> listAudit(
    PageRequest request, {
    AuditFilters filters = const AuditFilters(),
  }) async {
    final where = _whereClause(filters);
    final countRow = await _db.customSelect(
      'SELECT COUNT(*) AS n FROM audit_logs a'
      ' WHERE 1=1$where',
      variables: _whereVars(filters),
    ).getSingle();
    final total = countRow.read<int>('n');

    final rows = await _db.customSelect(
      'SELECT a.id, a.user_id AS userId, a.action, a.entity_type AS entityType,'
      ' a.entity_id AS entityId, a.before_data AS beforeData,'
      ' a.after_data AS afterData, a.ip_address AS ipAddress, a.note,'
      ' a.created_at AS createdAt, u.username, u.full_name AS fullName'
      ' FROM audit_logs a LEFT JOIN users u ON u.id = a.user_id'
      ' WHERE 1=1$where'
      ' ORDER BY a.created_at DESC, a.id DESC'
      ' LIMIT ? OFFSET ?',
      variables: _whereVars(filters)
        ..add(Variable(request.pageSize))
        ..add(Variable(request.offset)),
    ).get();

    final items = rows.map(_mapRow).toList();
    return PageResult(
      items: items,
      total: total,
      request: request,
    );
  }

  /// Distinct actions present in the trail (action filter dropdown).
  Future<List<String>> distinctActions() async {
    final rows = await _db.customSelect(
      'SELECT DISTINCT action FROM audit_logs ORDER BY action',
    ).get();
    return [for (final r in rows) r.read<String>('action')];
  }

  /// Distinct users that authored at least one audit row (actor filter).
  Future<List<AuditActorOption>> distinctActors() async {
    final rows = await _db.customSelect(
      'SELECT DISTINCT a.user_id AS userId, u.username, u.full_name AS fullName'
      ' FROM audit_logs a LEFT JOIN users u ON u.id = a.user_id'
      ' ORDER BY u.username',
    ).get();
    return [
      for (final r in rows)
        AuditActorOption(
          userId: r.read<String>('userId'),
          username: r.read<String?>('username') ?? r.read<String>('userId'),
        ),
    ];
  }

  AuditEntry _mapRow(QueryRow row) => AuditEntry(
        id: row.read<String>('id'),
        userId: row.read<String>('userId'),
        username: row.read<String?>('username'),
        userFullName: row.read<String?>('fullName'),
        action: row.read<String>('action'),
        entityType: row.read<String>('entityType'),
        entityId: row.read<String>('entityId'),
        beforeData: row.read<String?>('beforeData'),
        afterData: row.read<String?>('afterData'),
        ipAddress: row.read<String?>('ipAddress'),
        note: row.read<String?>('note'),
        createdAt: row.read<int>('createdAt'),
      );

  String _whereClause(AuditFilters filters) {
    final sb = StringBuffer();
    final search = filters.search.trim();
    if (search.isNotEmpty) {
      sb.write(
        " AND (LOWER(a.action) LIKE ? OR LOWER(a.entity_type) LIKE ?"
        " OR LOWER(a.entity_id) LIKE ? OR LOWER(a.note) LIKE ?)",
      );
    }
    if (filters.fromMillis != null) {
      sb.write(' AND a.created_at >= ?');
    }
    if (filters.toMillis != null) {
      sb.write(' AND a.created_at < ?');
    }
    if (filters.userId != null) {
      sb.write(' AND a.user_id = ?');
    }
    if (filters.action != null) {
      sb.write(" AND a.action = ?");
    }
    return sb.toString();
  }

  List<Variable> _whereVars(AuditFilters filters) {
    final vars = <Variable>[];
    final search = filters.search.trim();
    if (search.isNotEmpty) {
      final like = '%${search.toLowerCase()}%';
      for (var i = 0; i < 4; i++) {
        vars.add(Variable(like));
      }
    }
    if (filters.fromMillis != null) {
      vars.add(Variable(filters.fromMillis));
    }
    if (filters.toMillis != null) {
      vars.add(Variable(filters.toMillis));
    }
    if (filters.userId != null) {
      vars.add(Variable(filters.userId));
    }
    if (filters.action != null) {
      vars.add(Variable(filters.action));
    }
    return vars;
  }
}