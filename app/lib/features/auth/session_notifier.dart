import 'package:clinic_schedule/core/result.dart';
import 'package:clinic_schedule/data/models.dart';
import 'package:clinic_schedule/data/providers.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Runs once per login: records it and, for an email on the clinic's admin list,
/// grants admin the first time. The role itself is read live from users/{uid}.
class SessionNotifier extends AsyncNotifier<UserRole?> {
  @override
  Future<UserRole?> build() async {
    final uid = ref.watch(authUserProvider.select((a) => a.value?.uid));
    if (uid == null) return null;
    final accounts = ref.read(accountRepositoryProvider);
    final touched = await accounts.touch();
    final role = touched is Ok<UserRole?> ? touched.value : null;
    if (role == UserRole.admin) return role;
    // Not an admin yet: allowed only for emails on the admin list; otherwise refused quietly.
    final claimed = await accounts.claimAdmin();
    return claimed is Ok<UserRole?> ? claimed.value : role;
  }
}

final AsyncNotifierProvider<SessionNotifier, UserRole?> sessionProvider =
    AsyncNotifierProvider<SessionNotifier, UserRole?>(SessionNotifier.new);
