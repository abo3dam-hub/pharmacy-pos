/// Represents a domain or application failure. Used with [Result] and
/// [AppException] to avoid leaking raw exceptions into the UI layer.
class Failure {
  const Failure(this.message, {this.cause});

  final String message;
  final Object? cause;

  @override
  String toString() => 'Failure: $message';
}

class ValidationFailure extends Failure {
  const ValidationFailure(super.message);
}

class NotFoundFailure extends Failure {
  const NotFoundFailure(super.message);
}

class DuplicateFailure extends Failure {
  const DuplicateFailure(super.message);
}

class UnauthorizedFailure extends Failure {
  const UnauthorizedFailure([super.message = 'غير مصرح به']);
}

class InsufficientStockFailure extends Failure {
  const InsufficientStockFailure(super.message);
}

class ExpiredBatchFailure extends Failure {
  const ExpiredBatchFailure(super.message);
}

class InvalidOperationFailure extends Failure {
  const InvalidOperationFailure(super.message);
}

class DatabaseFailure extends Failure {
  const DatabaseFailure(super.message, {super.cause});
}