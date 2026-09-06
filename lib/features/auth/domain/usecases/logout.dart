/// Ends the session.
///
/// Session state lives in the application layer; [LogoutUseCase] is a no-op
/// business hook reserved for future session-end records (§16) — it exists so
/// the domain use-case layer stays symmetric with login.
class LogoutUseCase {
  const LogoutUseCase();

  Future<void> call() async {}
}