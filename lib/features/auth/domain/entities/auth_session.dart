import 'user.dart';

/// The authenticated session — the only identity state held by the app.
///
/// Contains the domain [user] (with its bcrypt hash only) plus the login
/// timestamp. A plaintext password is **never** part of a session.
class AuthSession {
  const AuthSession({required this.user, required this.loggedInAt});

  final AppUser user;
  final int loggedInAt;

  bool get isAdmin => user.isAdmin;
}