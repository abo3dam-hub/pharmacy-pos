import 'failures.dart';

/// A sealed result type: either a [Success] value or a [FailureResult].
sealed class Result<T> {
  const Result();

  factory Result.success(T value) => Success(value);

  factory Result.failure(Failure failure) => FailureResult(failure);

  /// Wraps [action], mapping thrown [Failure]s or arbitrary errors into a
  /// [Result].
  static Future<Result<T>> guard<T>(Future<T> Function() action) async {
    try {
      return Result.success(await action());
    } on Failure catch (f) {
      return Result.failure(f);
    } catch (e) {
      return Result.failure(DatabaseFailure('Unexpected error: $e', cause: e));
    }
  }

  R fold<R>(R Function(T value) onSuccess, R Function(Failure failure) onFailure);
}

class Success<T> extends Result<T> {
  const Success(this.value);

  final T value;

  @override
  R fold<R>(R Function(T value) onSuccess, R Function(Failure failure) onFailure) =>
      onSuccess(value);
}

class FailureResult<T> extends Result<T> {
  const FailureResult(this.failure);

  final Failure failure;

  @override
  R fold<R>(R Function(T value) onSuccess, R Function(Failure failure) onFailure) =>
      onFailure(failure);
}

/// Convenience accessors.
extension ResultExtension<T> on Result<T> {
  bool get isSuccess => this is Success<T>;
  bool get isFailure => this is FailureResult<T>;
  T? get valueOrNull => isSuccess ? (this as Success<T>).value : null;
  Failure? get failureOrNull =>
      isFailure ? (this as FailureResult<T>).failure : null;
}