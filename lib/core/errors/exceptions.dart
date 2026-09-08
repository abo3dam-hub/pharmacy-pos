import 'failures.dart';

/// Marker interface for domain/service exceptions that carry a [Failure].
abstract interface class AppException {
  Failure get failure;
}

class DomainException implements AppException {
  const DomainException(this.failure);

  @override
  final Failure failure;

  @override
  String toString() => failure.message;
}

class ValidationException extends DomainException {
  ValidationException(String message)
      : super(ValidationFailure(message));
}

class NotEnoughStockException extends DomainException {
  NotEnoughStockException(String message)
      : super(InsufficientStockFailure(message));
}

class ExpiredBatchException extends DomainException {
  ExpiredBatchException(String message)
      : super(ExpiredBatchFailure(message));
}

class UnauthorizedException extends DomainException {
  UnauthorizedException([String message = 'غير مصرح به'])
      : super(UnauthorizedFailure(message));
}

class NotFoundException extends DomainException {
  NotFoundException(String message) : super(NotFoundFailure(message));
}

class InvalidOperationException extends DomainException {
  InvalidOperationException(String message)
      : super(InvalidOperationFailure(message));
}

class DuplicateException extends DomainException {
  DuplicateException(String message)
      : super(DuplicateFailure(message));
}

class DatabaseException extends DomainException {
  DatabaseException(String message, {Object? cause})
      : super(DatabaseFailure(message, cause: cause));
}