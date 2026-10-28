import 'package:clinic_schedule/core/result.dart';
import 'package:clinic_schedule/data/providers.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// State of the login / sign-up / reset / profile forms.
final class AuthFormState {
  const AuthFormState({this.busy = false, this.error, this.info});

  final bool busy;
  final String? error;
  final String? info;
}

class AuthFormNotifier extends Notifier<AuthFormState> {
  @override
  AuthFormState build() => const AuthFormState();

  Future<void> signIn(String email, String password) =>
      _run(() => ref.read(accountRepositoryProvider).signIn(email, password));

  Future<void> signUp({required String name, required String phone, required String email, required String password}) =>
      _run(
        () => ref.read(accountRepositoryProvider).signUp(name: name, phone: phone, email: email, password: password),
      );

  Future<void> saveProfile({required String name, required String phone}) =>
      _run(() => ref.read(accountRepositoryProvider).saveProfile(name: name, phone: phone));

  Future<void> resetPassword(String email, {required String sentMessage}) =>
      _run(() => ref.read(accountRepositoryProvider).resetPassword(email), successInfo: sentMessage);

  void clear() => state = const AuthFormState();

  Future<void> _run(Future<Result<void>> Function() action, {String? successInfo}) async {
    state = const AuthFormState(busy: true);
    final result = await action();
    if (!ref.mounted) return;
    state = switch (result) {
      Ok() => AuthFormState(info: successInfo),
      Err(:final failure) => AuthFormState(error: failure.message),
    };
  }
}

final NotifierProvider<AuthFormNotifier, AuthFormState> authFormProvider =
    NotifierProvider.autoDispose<AuthFormNotifier, AuthFormState>(AuthFormNotifier.new);
