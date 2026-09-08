import '../../../../core/data_grid/page_request.dart';
import '../../../../domain/services/permission_service.dart';
import '../../../../shared/database/app_database.dart';
import '../../data/audit_dao.dart';
import '../entities/audit_entry.dart';

/// List + search + filter the audit trail (read-only viewer). Requires
/// `audit.view`.
class ListAuditLogsUseCase {
  const ListAuditLogsUseCase(this._dao, this._permissions);

  final AuditDao _dao;
  final PermissionService _permissions;

  Future<PageResult<AuditEntry>> call(
    AppDatabase db,
    String? actingRoleId, {
    PageRequest request = const PageRequest(),
    AuditFilters filters = const AuditFilters(),
  }) async {
    await _permissions.requireRolePermission(db, actingRoleId, 'audit.view');
    return _dao.listAudit(request, filters: filters);
  }
}

/// Distinct actions for the filter dropdown (requires `audit.view`).
class ListAuditActionsUseCase {
  const ListAuditActionsUseCase(this._dao, this._permissions);

  final AuditDao _dao;
  final PermissionService _permissions;

  Future<List<String>> call(AppDatabase db, String? actingRoleId) async {
    await _permissions.requireRolePermission(db, actingRoleId, 'audit.view');
    return _dao.distinctActions();
  }
}

/// Distinct actors (users with audit rows) for the filter dropdown (requires
/// `audit.view`).
class ListAuditActorsUseCase {
  const ListAuditActorsUseCase(this._dao, this._permissions);

  final AuditDao _dao;
  final PermissionService _permissions;

  Future<List<AuditActorOption>> call(
    AppDatabase db,
    String? actingRoleId,
  ) async {
    await _permissions.requireRolePermission(db, actingRoleId, 'audit.view');
    return _dao.distinctActors();
  }
}