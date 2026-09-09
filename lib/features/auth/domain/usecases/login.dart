import '../entities/user.dart';
import '../repositories/auth_repository.dart';
import '../services/password_service.dart';

/// Authentication outcome — success carries the authenticated [AppUser];
/// failure carries a UI-mappable [LoginFailure] code (never a raw exception).
class LoginResult {
  const LoginResult.success(this.user, {this.failure});

  const LoginResult.failure(this.failure, {this.user});

  final AppUser? user;
  final LoginFailure? failure;

  /// True only for successful authentication. Failure results may still carry
  /// the [subject] user (for inactive / wrong-password auditing).
  bool get isSuccess => failure == null;

  /// The account that failed to authenticate (present for inactive / wrong
  /// password); always null for unknown usernames.
  AppUser? get subject => user;
}

/// Authenticates a user against the stored bcrypt hash (§16).
///
/// Inactive accounts are rejected before verification. Login success/failure
/// auditing is performed by the application layer after this resolves.
class LoginUseCase {
  const LoginUseCase(this._repository, this._passwords);

  final AuthRepository _repository;
  final PasswordService _passwords;

  Future<LoginResult> call(String username, String password) async {
    final normalized = username.trim();
    if (normalized.isEmpty || password.isEmpty) {
      return const LoginResult.failure(LoginFailure.invalidCredentials);
    }
    final user = await _repository.findByUsername(normalized);
    if (user == null) {
      return const LoginResult.failure(LoginFailure.invalidCredentials);
    }
    if (!user.isActive) {
      return LoginResult.failure(LoginFailure.inactive, user: user);
    }
    if (!_passwords.verify(password, user.passwordHash)) {
      return LoginResult.failure(LoginFailure.invalidCredentials, user: user);
    }
    try {
      await _repository.recordLogin(
        user.id,
        atMillis: DateTime.now().millisecondsSinceEpoch,
      );
      // Re-read so the returned user reflects the recorded login timestamp.
      final fresh = await _repository.findById(user.id);
      return LoginResult.success(fresh ?? user);
    } on Exception {
      // A storage hiccup must never surface as an unhandled error on the login
      // screen; the attempt is rejected with the same generic credential
      // failure the UI already maps.
      return LoginResult.failure(LoginFailure.invalidCredentials, user: user);
    }
  }
}