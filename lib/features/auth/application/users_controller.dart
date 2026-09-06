import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/data_grid/page_request.dart';
import '../../../core/errors/exceptions.dart';
import '../../../core/errors/failures.dart';
import '../../../domain/services/audit_service.dart';
import '../../../shared/database/app_database.dart';
import '../../../shared/models/enums.dart';
import '../domain/entities/user.dart';
import '../domain/usecases/change_password.dart';
import '../domain/usecases/create_user.dart';
import '../domain/usecases/deactivate_user.dart';
import '../domain/usecases/list_users.dart';
import '../domain/usecases/reactivate_user.dart';
import '../domain/usecases/update_user.dart';

enum UsersStatus { initial, loading, ready, error }

class UsersViewState {
  const UsersViewState({
    this.status = UsersStatus.initial,
    this.items = const PageResult(items: [], total: 0, request: PageRequest()),
    this.roles = const [],
    this.error,
    this.busy = false,
  });

  final UsersStatus status;
  final PageResult<AppUser> items;
  final List<RoleInfo> roles;

  /// Non-null after a failed mutation (mapped by the UI to a localized message).
  final Failure? error;
  final bool busy;

  String get search => items.request.search;
  int get page => items.request.page;

  UsersViewState copyWith({
    UsersStatus? status,
    PageResult<AppUser>? items,
    List<RoleInfo>? roles,
    Failure? Function()? error,
    bool? busy,
  }) {
    return UsersViewState(
      status: status ?? this.status,
      items: items ?? this.items,
      roles: roles ?? this.roles,
      error: error != null ? error() : this.error,
      busy: busy ?? this.busy,
    );
  }
}

/// Admin user-management controller: loads the paged list (DB-side), assignment
/// roles, and runs create/update/activate/deactivate/password flows — each
/// guarded by the domain `users.*` permissions and audited on success.
class UsersViewController extends StateNotifier<UsersViewState> {
  UsersViewController(
    this._listUsers,
    this._listRoles,
    this._createUser,
    this._updateUser,
    this._deactivateUser,
    this._reactivateUser,
    this._changePassword,
    this._audit,
    this._db,
  ) : super(const UsersViewState());

  final ListUsersUseCase _listUsers;
  final ListRolesUseCase _listRoles;
  final CreateUserUseCase _createUser;
  final UpdateUserUseCase _updateUser;
  final DeactivateUserUseCase _deactivateUser;
  final ReactivateUserUseCase _reactivateUser;
  final ChangePasswordUseCase _changePassword;
  final AuditService _audit;
  final AppDatabase _db;

  Future<void> load({String search = '', int page = 1}) async {
    state = state.copyWith(status: UsersStatus.loading, error: () => null);
    try {
      final request = PageRequest(page: page, search: search);
      final results = await Future.wait([
        _listUsers.call(request),
        _listRoles.call(),
      ]);
      state = UsersViewState(
        status: UsersStatus.ready,
        items: results[0] as PageResult<AppUser>,
        roles: results[1] as List<RoleInfo>,
      );
    } on AppException catch (e) {
      state = state.copyWith(status: UsersStatus.error, error: () => e.failure);
    }
  }

  void clearError() => state = state.copyWith(error: () => null);

  Future<void> reload() =>
      load(search: state.search, page: state.page);

  /// Returns a [Failure] on error, else null (success + in-memory reload).
  Future<Failure?> create({
    required String username,
    required String displayName,
    required String roleId,
    required String password,
    String? phone,
    String? notes,
    required String? actingUserId,
    required String? actingRoleId,
  }) async {
    final failure = await _runMutation(() => _createUser.call(
          username: username,
          displayName: displayName,
          roleId: roleId,
          password: password,
          phone: phone,
          notes: notes,
          actingRoleId: actingRoleId,
        ));
    if (failure == null) {
      await _auditWrite(
        actingUserId: actingUserId,
        action: AuditAction.create,
        entityId: 'user',
        note: 'user_created',
      );
    }
    return failure;
  }

  Future<Failure?> update({
    required String id,
    required String displayName,
    required String roleId,
    String? phone,
    String? notes,
    required String? actingUserId,
    required String? actingRoleId,
  }) async {
    final failure = await _runMutation(() => _updateUser.call(
          id: id,
          displayName: displayName,
          roleId: roleId,
          phone: phone,
          notes: notes,
          actingRoleId: actingRoleId,
        ));
    if (failure == null) {
      await _auditWrite(
        actingUserId: actingUserId,
        action: AuditAction.update,
        entityId: id,
        note: 'user_updated',
      );
    }
    return failure;
  }

  Future<Failure?> setActive({
    required String id,
    required bool active,
    required String? actingUserId,
    required String? actingRoleId,
  }) async {
    final call = active
        ? () => _reactivateUser.call(id, actingRoleId: actingRoleId)
        : () => _deactivateUser.call(
            id,
            actingUserId: actingUserId,
            actingRoleId: actingRoleId,
          );
    final failure = await _runMutation(call);
    if (failure == null) {
      await _auditWrite(
        actingUserId: actingUserId,
        action: active ? AuditAction.restore : AuditAction.delete,
        entityId: id,
        note: active ? 'user_activated' : 'user_deactivated',
      );
    }
    return failure;
  }

  Future<Failure?> changePassword({
    required String id,
    required String newPassword,
    required String? actingUserId,
    required String? actingRoleId,
  }) async {
    final failure = await _runMutation(
        () => _changePassword.call(id, newPassword, actingRoleId: actingRoleId));
    if (failure == null) {
      await _auditWrite(
        actingUserId: actingUserId,
        action: AuditAction.update,
        entityId: id,
        note: 'password_changed',
      );
    }
    return failure;
  }

  Future<Failure?> _runMutation(Future<Object?> Function() action) async {
    state = state.copyWith(busy: true, error: () => null);
    try {
      await action();
      await reload();
      return null;
    } on AppException catch (e) {
      state = state.copyWith(
        busy: false,
        error: () => e.failure,
      );
      return e.failure;
    } on Exception {
      state = state.copyWith(busy: false);
      return const DatabaseFailure('حدث خطأ غير متوقع أثناء العملية');
    }
  }

  Future<void> _auditWrite({
    required String? actingUserId,
    required AuditAction action,
    required String entityId,
    required String note,
  }) async {
    if (actingUserId == null) return;
    try {
      await _audit.write(
        _db,
        userId: actingUserId,
        action: action,
        entityType: 'user',
        entityId: entityId,
        note: note,
      );
    } catch (_) {
      // Audit must never break the primary operation.
    }
  }
}