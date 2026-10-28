import 'package:clinic_schedule/core/result.dart';
import 'package:cloud_functions/cloud_functions.dart' show FirebaseFunctions, FirebaseFunctionsException, HttpsCallable;
import 'package:firebase_auth/firebase_auth.dart';

/// The one door to server-side changes: the `api` callable Cloud Function
/// (functions/src/index.js). Every booking, cancellation and admin change goes here,
/// so the app and the website follow exactly the same rules.
abstract interface class ClinicApi {
  Future<Result<Map<String, Object?>>> call(String op, [Map<String, Object?> data = const {}]);
}

final class FunctionsClinicApi implements ClinicApi {
  FunctionsClinicApi(FirebaseFunctions functions) : _callable = functions.httpsCallable('api');

  final HttpsCallable _callable;

  @override
  Future<Result<Map<String, Object?>>> call(String op, [Map<String, Object?> data = const {}]) async {
    try {
      final result = await _callable.call<Object?>({'op': op, 'data': data});
      final value = result.data;
      return Ok(value is Map ? value.cast<String, Object?>() : {'value': value});
    } on FirebaseFunctionsException catch (e) {
      return Err(Failure(_codeOf(e.code), e.message ?? 'Something went wrong. Please try again.'));
    } on Exception {
      return const Err(Failure(FailureCode.network, 'No connection. Please check your internet and try again.'));
    }
  }

  static FailureCode _codeOf(String code) => switch (code) {
    'invalid-argument' => FailureCode.invalidInput,
    'already-exists' => FailureCode.conflict,
    'not-found' => FailureCode.notFound,
    'permission-denied' || 'failed-precondition' => FailureCode.notAllowed,
    'unauthenticated' => FailureCode.notSignedIn,
    'resource-exhausted' => FailureCode.tooManyRequests,
    'unavailable' || 'deadline-exceeded' => FailureCode.network,
    _ => FailureCode.unknown,
  };
}

/// Maps Firebase Auth errors to readable failures.
Failure authFailure(FirebaseAuthException e) => switch (e.code) {
  'invalid-credential' ||
  'wrong-password' ||
  'user-not-found' ||
  'invalid-login-credentials' => const Failure(FailureCode.wrongCredentials, 'Wrong email or password.'),
  'email-already-in-use' => const Failure(
    FailureCode.emailInUse,
    'An account with this email already exists. Please log in.',
  ),
  'weak-password' => const Failure(FailureCode.invalidInput, 'Please choose a password of at least 8 characters.'),
  'invalid-email' => const Failure(FailureCode.invalidInput, 'Please enter a valid email address.'),
  'too-many-requests' => const Failure(
    FailureCode.tooManyRequests,
    'Too many attempts. Please wait a few minutes and try again.',
  ),
  'network-request-failed' => const Failure(
    FailureCode.network,
    'No connection. Please check your internet and try again.',
  ),
  _ => Failure(FailureCode.unknown, e.message ?? 'Something went wrong. Please try again.'),
};
