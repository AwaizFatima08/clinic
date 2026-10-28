import 'package:clinic_schedule/app_router.dart';
import 'package:clinic_schedule/data/models.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

AppUser user({UserRole role = UserRole.patient, String name = 'Sara', String phone = '+923001234567'}) => AppUser(
  uid: 'u1',
  name: name,
  phone: phone,
  email: 'sara@example.com',
  role: role,
  createdAt: null,
  lastLoginAt: null,
);

String? go(
  String location, {
  bool known = true,
  bool signedIn = true,
  AsyncValue<UserRole?> session = const AsyncData(UserRole.patient),
  AppUser? u,
}) => redirectFor(location: location, authKnown: known, signedIn: signedIn, session: session, user: u);

void main() {
  test('waits on the splash screen until login state is known', () {
    expect(go(Routes.book, known: false), Routes.splash);
    expect(go(Routes.splash, known: false), isNull);
  });

  test('signed out → login', () {
    expect(go(Routes.book, signedIn: false), Routes.login);
    expect(go(Routes.adminUsers, signedIn: false), Routes.login);
  });

  test('patient without a profile completes it first', () {
    expect(go(Routes.book, u: user(name: '')), Routes.profile);
  });

  test('patients stay out of the admin screens', () {
    expect(go(Routes.adminSettings, u: user()), Routes.book);
    expect(go(Routes.mine, u: user()), isNull);
  });

  test('admins land on admin appointments', () {
    final admin = user(role: UserRole.admin, name: '', phone: '');
    expect(go(Routes.book, u: admin), Routes.adminAppointments);
    expect(go(Routes.adminHours, u: admin), isNull);
  });

  test('stays on the splash screen while the session check runs', () {
    expect(go(Routes.book, session: const AsyncLoading(), u: user()), Routes.splash);
  });
}
