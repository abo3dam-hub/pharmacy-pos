import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/errors/exceptions.dart';
import '../../../core/errors/failures.dart';
import '../../../shared/database/app_database.dart';
import '../domain/entities/rbac.dart';
import '../domain/usecases/rbac_use_cases.dart';

enum RbacStatus { initial, loading, ready, error }

class RbacViewState {
  const RbacViewState({
    this.status = RbacStatus.initial,
    this.roles = const [],
    this.permissions = const [],
    this.error,
  });

  final RbacStatus status;
  final List<RoleRecord> roles;
  final List<PermissionInfo> permissions;
  final Failure? error;

  RbacViewState copyWith({
    RbacStatus? status,
    List<RoleRecord>? roles,
    List<PermissionInfo>? permissions,
    Failure? Function()? error,
  }) {
    return RbacViewState(
      status: status ?? this.status,
      roles: roles ?? this.roles,
      permissions: permissions ?? this.permissions,
      error: error != null ? error() : this.error,
    );
  }
}

/// Roles & permissions management controller (Phase 12). Loads the roles
/// snapshot; create/update/delete/assign-permissions delegate to the gated
/// use cases and return a [Failure] (null = success) for the UI.
class RbacController extends StateNotifier<RbacViewState> {
  RbacController(
    this._load,
    this._getDetail,
    this._create,
    this._update,
    this._setPermissions,
    this._delete,
    this._db,
  ) : super(const RbacViewState());

  final LoadRolesSnapshotUseCase _load;
  final GetRoleDetailUseCase _getDetail;
  final CreateRoleUseCase _create;
  final UpdateRoleUseCase _update;
  final SetRolePermissionsUseCase _setPermissions;
  final DeleteRoleUseCase _delete;
  final AppDatabase _db;

  Future<void> reload(String? actingRoleId) async {
    try {
      final snapshot = await _load.call(_db, actingRoleId);
      state = RbacViewState(
        status: RbacStatus.ready,
        roles: snapshot.roles,
        permissions: snapshot.permissions,
      );
    } on AppException catch (e) {
      state = state.copyWith(status: RbacStatus.error, error: () => e.failure);
    } on Exception {
      state = state.copyWith(status: RbacStatus.error);
    }
  }

  Future<RoleDetail?> getDetail(
    String? actingRoleId,
    String roleId,
  ) async {
    try {
      return await _getDetail.call(_db, actingRoleId, roleId);
    } on AppException catch (e) {
      state = state.copyWith(error: () => e.failure);
      return null;
    }
  }

  Future<Failure?> create({
    required String name,
    required String nameAr,
    required String? actingUserId,
    required String? actingRoleId,
  }) async {
    try {
      await _create.call(
        _db,
        name: name,
        nameAr: nameAr,
        actingUserId: actingUserId,
        actingRoleId: actingRoleId,
      );
      await reload(actingRoleId);
      return null;
    } on AppException catch (e) {
      state = state.copyWith(error: () => e.failure);
      return e.failure;
    } on Exception {
      return const DatabaseFailure('حدث خطأ أثناء إنشاء الدور');
    }
  }

  Future<Failure?> update({
    required String id,
    required String nameAr,
    required String? actingUserId,
    required String? actingRoleId,
  }) async {
    try {
      await _update.call(
        _db,
        id: id,
        nameAr: nameAr,
        actingUserId: actingUserId,
        actingRoleId: actingRoleId,
      );
      await reload(actingRoleId);
      return null;
    } on AppException catch (e) {
      state = state.copyWith(error: () => e.failure);
      return e.failure;
    } on Exception {
      return const DatabaseFailure('حدث خطأ أثناء تعديل الدور');
    }
  }

  Future<Failure?> setRolePermissions({
    required String roleId,
    required Set<String> codes,
    required bool isSystemRole,
    required String? actingUserId,
    required String? actingRoleId,
  }) async {
    try {
      await _setPermissions.call(
        _db,
        roleId: roleId,
        codes: codes,
        isSystemRole: isSystemRole,
        actingUserId: actingUserId,
        actingRoleId: actingRoleId,
      );
      await reload(actingRoleId);
      return null;
    } on AppException catch (e) {
      state = state.copyWith(error: () => e.failure);
      return e.failure;
    } on Exception {
      return const DatabaseFailure('حدث خطأ أثناء حفظ الصلاحيات');
    }
  }

  Future<Failure?> delete({
    required String id,
    required String? actingUserId,
    required String? actingRoleId,
  }) async {
    try {
      await _delete.call(
        _db,
        id: id,
        actingUserId: actingUserId,
        actingRoleId: actingRoleId,
      );
      await reload(actingRoleId);
      return null;
    } on AppException catch (e) {
      state = state.copyWith(error: () => e.failure);
      return e.failure;
    } on Exception {
      return const DatabaseFailure('حدث خطأ أثناء حذف الدور');
    }
  }

  void clearError() => state = state.copyWith(error: () => null);
}