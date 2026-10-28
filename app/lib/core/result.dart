/// Outcome of a recoverable operation: [Ok] with a value or [Err] with a [Failure].
sealed class Result<T> {
  const Result();
}

final class Ok<T> extends Result<T> {
  const Ok(this.value);
  final T value;
}

final class Err<T> extends Result<T> {
  const Err(this.failure);
  final Failure failure;
}

/// Why something failed. [message] is already readable by people (the server writes
/// patient-friendly messages); [code] is stable for logic.
final class Failure {
  const Failure(this.code, this.message);

  final FailureCode code;
  final String message;

  @override
  String toString() => 'Failure($code, $message)';
}

enum FailureCode {
  invalidInput,
  conflict,
  notFound,
  notAllowed,
  notSignedIn,
  network,
  tooManyRequests,
  wrongCredentials,
  emailInUse,
  unknown,
}
