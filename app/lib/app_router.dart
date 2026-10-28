import 'package:clinic_schedule/data/models.dart';
import 'package:clinic_schedule/data/providers.dart';
import 'package:clinic_schedule/features/admin/admin_appointments_screen.dart';
import 'package:clinic_schedule/features/admin/admin_hours_screen.dart';
import 'package:clinic_schedule/features/admin/admin_settings_screen.dart';
import 'package:clinic_schedule/features/admin/admin_users_screen.dart';
import 'package:clinic_schedule/features/auth/login_screen.dart';
import 'package:clinic_schedule/features/auth/profile_screen.dart';
import 'package:clinic_schedule/features/auth/session_notifier.dart';
import 'package:clinic_schedule/features/booking/booking_screen.dart';
import 'package:clinic_schedule/features/my_appointments/my_appointments_screen.dart';
import 'package:clinic_schedule/features/shell/app_shell.dart';
import 'package:clinic_schedule/features/shell/splash_screen.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

abstract final class Routes {
  static const splash = '/';
  static const login = '/login';
  static const profile = '/profile';
  static const book = '/book';
  static const mine = '/mine';
  static const adminAppointments = '/admin/appointments';
  static const adminHours = '/admin/hours';
  static const adminUsers = '/admin/users';
  static const adminSettings = '/admin/settings';
}

/// Where a person should be, given their login, session check and users/{uid} document.
/// Pure, so it is tested directly (test/app_router_test.dart).
String? redirectFor({
  required String location,
  required bool authKnown,
  required bool signedIn,
  required AsyncValue<UserRole?> session,
  required AppUser? user,
}) {
  if (!authKnown) return location == Routes.splash ? null : Routes.splash;
  if (!signedIn) return location == Routes.login ? null : Routes.login;
  if (session.isLoading || user == null) return location == Routes.splash ? null : Routes.splash;
  if (user.isAdmin) return location.startsWith('/admin') ? null : Routes.adminAppointments;
  if (!user.hasProfile) return location == Routes.profile ? null : Routes.profile;
  if (location == Routes.book || location == Routes.mine) return null;
  return Routes.book;
}

final Provider<GoRouter> routerProvider = Provider<GoRouter>((ref) {
  final refresh = ValueNotifier<int>(0);
  ref
    ..listen(authUserProvider, (_, _) => refresh.value++)
    ..listen(currentUserProvider, (_, _) => refresh.value++)
    ..listen(sessionProvider, (_, _) => refresh.value++)
    ..onDispose(refresh.dispose);

  final router = GoRouter(
    initialLocation: Routes.splash,
    refreshListenable: refresh,
    redirect: (context, state) {
      final auth = ref.read(authUserProvider);
      return redirectFor(
        location: state.matchedLocation,
        authKnown: auth.hasValue,
        signedIn: auth.value != null,
        session: ref.read(sessionProvider),
        user: ref.read(currentUserProvider).value,
      );
    },
    routes: [
      GoRoute(path: Routes.splash, builder: (_, _) => const SplashScreen()),
      GoRoute(path: Routes.login, builder: (_, _) => const LoginScreen()),
      GoRoute(path: Routes.profile, builder: (_, _) => const ProfileScreen()),
      StatefulShellRoute.indexedStack(
        builder: (_, _, shell) => AppShell(shell: shell, admin: false),
        branches: [
          StatefulShellBranch(
            routes: [GoRoute(path: Routes.book, builder: (_, _) => const BookingScreen())],
          ),
          StatefulShellBranch(
            routes: [GoRoute(path: Routes.mine, builder: (_, _) => const MyAppointmentsScreen())],
          ),
        ],
      ),
      StatefulShellRoute.indexedStack(
        builder: (_, _, shell) => AppShell(shell: shell, admin: true),
        branches: [
          StatefulShellBranch(
            routes: [GoRoute(path: Routes.adminAppointments, builder: (_, _) => const AdminAppointmentsScreen())],
          ),
          StatefulShellBranch(
            routes: [GoRoute(path: Routes.adminHours, builder: (_, _) => const AdminHoursScreen())],
          ),
          StatefulShellBranch(
            routes: [GoRoute(path: Routes.adminUsers, builder: (_, _) => const AdminUsersScreen())],
          ),
          StatefulShellBranch(
            routes: [GoRoute(path: Routes.adminSettings, builder: (_, _) => const AdminSettingsScreen())],
          ),
        ],
      ),
    ],
  );
  ref.onDispose(router.dispose);
  return router;
});
