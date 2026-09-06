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
  bool verify(String password, String hash) =>
      BCrypt.checkpw(password, hash);

  bool isValidLength(String password) => password.length >= minLength;
}