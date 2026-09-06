import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/errors/exceptions.dart';
import '../domain/entities/auth_session.dart';
import '../domain/entities/user.dart';
import '../domain/usecases/check_permission.dart';
import '../domain/usecases/get_current_user.dart';
import '../domain/usecases/login.dart';
import '../domain/usecases/logout.dart';

/// Login error codes surfaced to the login form (UI maps them to l10n).
enum AuthError { invalidCredentials, inactive }

/// Session status. The app starts unauthenticated; success logins flip to
/// [authenticated]. In-memory only — no persistent session table exists, so a
/// restart requires logging in again (documented Phase-2 limitation).
enum AuthStatus { unauthenticated, authenticated }

class AuthState {
  const AuthState({
    this.session,
    this.permissions = const {},
    this.status = AuthStatus.unauthenticated,
    this.submitting = false,
    this.error = AuthError.invalidCredentials,
  });

  final AuthSession? session;
  final Set<String> permissions;
  final AuthStatus status;
  final bool submitting;
  final AuthError error;

  bool get isAuthenticated => status == AuthStatus.authenticated;

  AppUser? get user => session?.user;

  /// The acting role id for permission-guarded use cases.
  String? get actingRoleId => user?.roleId;

  AuthState copyWith({
    AuthSession? Function()? session,
    Set<String>? permissions,
    AuthStatus? status,
    bool? submitting,
    AuthError? error,
  }) {
    return AuthState(
      session: session != null ? session() : this.session,
      permissions: permissions ?? this.permissions,
      status: status ?? this.status,
      submitting: submitting ?? this.submitting,
      error: error ?? this.error,
    );
  }
}

/// Session + authentication controller (§16 session management).
///
/// Owns the current [AuthSession] in memory (bcrypt-hash only — no plaintext),
/// performs login/logout, loads the user's permission set at login, and writes
/// the audit trail (login success/failure, logout).
class AuthController extends StateNotifier<AuthState> {
  AuthController(
    this._login,
    this._logout,
    this._getCurrentUser,
    this._listPermissions,
  ) : super(const AuthState());

  final LoginUseCase _login;
  final LogoutUseCase _logout;
  final GetCurrentUserUseCase _getCurrentUser;
  final ListUserPermissionsUseCase _listPermissions;

  /// Where auth audit rows are written (set by the DI provider; audit is
  /// application-layer so the domain stays framework-free).
  Future<void> Function({required AppUser? user, required bool success, String note})? audit;

  Future<bool> login(String username, String password) async {
    state = state.copyWith(submitting: true, error: AuthError.invalidCredentials);
    final result = await _login(username, password);
    if (result.isSuccess) {
      final user = result.user!;
      final permissions = await _listPermissions.call(user.roleId);
      state = AuthState(
        session: AuthSession(
          user: user,
          loggedInAt: DateTime.now().millisecondsSinceEpoch,
        ),
        permissions: Set.unmodifiable(permissions),
        status: AuthStatus.authenticated,
      );
      await audit?.call(user: user, success: true, note: 'login_success');
      return true;
    }
    state = state.copyWith(
      submitting: false,
      error: result.failure == LoginFailure.inactive
          ? AuthError.inactive
          : AuthError.invalidCredentials,
    );
    await audit?.call(user: result.subject, success: false, note: 'login_failed');
    return false;
  }

  Future<void> logout() async {
    final user = state.user;
    await _logout.call();
    state = const AuthState();
    if (user != null) {
      await audit?.call(user: user, success: true, note: 'logout');
    }
  }

  /// Refreshes the stored user from the DB (e.g., after a role change).
  Future<void> reloadCurrentUser() async {
    final id = state.user?.id;
    if (id == null) return;
    try {
      final fresh = await _getCurrentUser.call(id);
      final permissions = await _listPermissions.call(fresh.roleId);
      state = state.copyWith(
        session: () => AuthSession(
          user: fresh,
          loggedInAt: state.session!.loggedInAt,
        ),
        permissions: Set.unmodifiable(permissions),
      );
    } on AppException {
      // The account may have been deactivated; keep the stale session.
    }
  }
}