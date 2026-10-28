import 'package:clinic_schedule/core/clinic_time.dart';
import 'package:clinic_schedule/data/api_service.dart';
import 'package:clinic_schedule/data/models.dart';
import 'package:clinic_schedule/data/repositories.dart';
import 'package:clock/clock.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart' show FirebaseFunctions;
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

// Composition root for data access. Tests override the repositories with fakes.

const functionsRegion = 'asia-south1';

final Provider<Clock> clockProvider = Provider<Clock>((ref) => const Clock());

final Provider<FirebaseFirestore> firestoreProvider = Provider<FirebaseFirestore>((ref) => FirebaseFirestore.instance);
final Provider<FirebaseAuth> firebaseAuthProvider = Provider<FirebaseAuth>((ref) => FirebaseAuth.instance);
final Provider<ClinicApi> clinicApiProvider = Provider<ClinicApi>(
  (ref) => FunctionsClinicApi(FirebaseFunctions.instanceFor(region: functionsRegion)),
);

final Provider<AccountRepository> accountRepositoryProvider = Provider<AccountRepository>(
  (ref) =>
      AccountRepository(ref.watch(firebaseAuthProvider), ref.watch(firestoreProvider), ref.watch(clinicApiProvider)),
);
final Provider<ClinicRepository> clinicRepositoryProvider = Provider<ClinicRepository>(
  (ref) => ClinicRepository(ref.watch(firestoreProvider), ref.watch(clinicApiProvider)),
);
final Provider<AppointmentRepository> appointmentRepositoryProvider = Provider<AppointmentRepository>(
  (ref) => AppointmentRepository(ref.watch(firestoreProvider), ref.watch(clinicApiProvider)),
);
final Provider<NotificationRepository> notificationRepositoryProvider = Provider<NotificationRepository>(
  (ref) => NotificationRepository(ref.watch(firestoreProvider)),
);
final Provider<UserRepository> userRepositoryProvider = Provider<UserRepository>(
  (ref) => UserRepository(ref.watch(firestoreProvider), ref.watch(clinicApiProvider)),
);

/// Firebase login state (null = signed out).
final StreamProvider<User?> authUserProvider = StreamProvider<User?>(
  (ref) => ref.watch(accountRepositoryProvider).authChanges(),
);

/// The signed-in user's users/{uid} document (null = signed out or no profile yet).
final StreamProvider<AppUser?> currentUserProvider = StreamProvider<AppUser?>((ref) {
  final uid = ref.watch(authUserProvider).value?.uid;
  if (uid == null) return Stream.value(null);
  return ref.watch(accountRepositoryProvider).watchUser(uid);
});

/// Public clinic settings, live.
final StreamProvider<ClinicSettings> settingsProvider = StreamProvider<ClinicSettings>(
  (ref) => ref.watch(clinicRepositoryProvider).watchSettings(),
);

/// Today in clinic time, refreshed every minute by [clinicNowProvider].
final StreamProvider<ClinicNow> clinicNowProvider = StreamProvider<ClinicNow>((ref) async* {
  final clock = ref.watch(clockProvider);
  final tzName = ref.watch(settingsProvider).value?.timezone ?? ClinicSettings.fallback.timezone;
  yield clinicNow(clock.now(), tzName);
  yield* Stream<ClinicNow>.periodic(const Duration(minutes: 1), (_) => clinicNow(clock.now(), tzName));
});
