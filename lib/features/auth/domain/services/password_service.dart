import 'package:bcrypt/bcrypt.dart';

/// Password security service (bcrypt only).
///
/// Plaintext passwords must never be stored, logged, or placed in exceptions
/// (§32). Hashing happens here; verification through [verify]. The bcrypt salt
/// is generated per call so equal inputs never produce equal hashes.
class PasswordService {
  const PasswordService();

  static const int minLength = 6;

  String hash(String password) => BCrypt.hashpw(password, BCrypt.gensalt());

  /// Constant-time-safe bcrypt verification.
  ///
  /// A malformed or non-bcrypt stored hash (corrupt store / legacy data) must
  /// reject the attempt cleanly — never throw — so a bad row can't hang the
  /// login UI.
  bool verify(String password, String hash) {
    if (hash.isEmpty) return false;
    try {
      return BCrypt.checkpw(password, hash);
    } on ArgumentError {
      return false;
    }
  }

  bool isValidLength(String password) => password.length >= minLength;
}