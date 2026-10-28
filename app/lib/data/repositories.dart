import 'package:clinic_schedule/core/clinic_time.dart';
import 'package:clinic_schedule/core/result.dart';
import 'package:clinic_schedule/core/slot_rules.dart';
import 'package:clinic_schedule/data/api_service.dart';
import 'package:clinic_schedule/data/models.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

// Reads are live Firestore streams (security rules decide what each user may see).
// Writes go only through [ClinicApi] — the single write path shared with the website.

Result<T> _map<T>(Result<Map<String, Object?>> r, T Function(Map<String, Object?>) f) => switch (r) {
  Ok(:final value) => Ok(f(value)),
  Err(:final failure) => Err(failure),
};

Result<void> _void(Result<Map<String, Object?>> r) => _map(r, (_) {});

/// Accounts: Firebase Auth plus the users/{uid} document.
class AccountRepository {
  AccountRepository(this._auth, this._db, this._api);

  final FirebaseAuth _auth;
  final FirebaseFirestore _db;
  final ClinicApi _api;

  Stream<User?> authChanges() => _auth.authStateChanges();

  Stream<AppUser?> watchUser(String uid) =>
      _db.doc('users/$uid').snapshots().map((s) => s.exists ? AppUser.fromMap(uid, s.data()!) : null);

  Future<Result<void>> signIn(String email, String password) =>
      _guard(() => _auth.signInWithEmailAndPassword(email: email.trim(), password: password));

  /// Creates the login, then the users/{uid} profile (role 'patient').
  Future<Result<void>> signUp({
    required String name,
    required String phone,
    required String email,
    required String password,
  }) async {
    final created = await _guard(() => _auth.createUserWithEmailAndPassword(email: email.trim(), password: password));
    if (created is Err<void>) return created;
    return saveProfile(name: name, phone: phone);
  }

  Future<Result<void>> saveProfile({required String name, required String phone}) async =>
      _void(await _api.call('saveProfile', {'name': name.trim(), 'phone': phone.trim()}));

  Future<Result<void>> resetPassword(String email) async {
    final r = await _guard(() => _auth.sendPasswordResetEmail(email: email.trim()));
    // Do not reveal whether an account exists.
    return r is Err<void> && r.failure.code == FailureCode.wrongCredentials ? const Ok(null) : r;
  }

  Future<void> signOut() => _auth.signOut();

  /// Deletes the account on the server (data, then login) and signs out here.
  Future<Result<void>> deleteMyAccount() async {
    final r = _void(await _api.call('deleteMyAccount'));
    if (r is Ok<void>) await _auth.signOut();
    return r;
  }

  /// Records the login; returns the current role.
  Future<Result<UserRole?>> touch() async => _map(await _api.call('touch'), (m) => _role(m['role']));

  /// First-time admin for an email on the clinic's admin list.
  Future<Result<UserRole?>> claimAdmin() async => _map(await _api.call('claimAdmin'), (m) => _role(m['role']));

  static UserRole? _role(Object? r) => switch (r) {
    'admin' => UserRole.admin,
    'patient' => UserRole.patient,
    _ => null,
  };

  Future<Result<void>> _guard(Future<Object?> Function() action) async {
    try {
      await action();
      return const Ok(null);
    } on FirebaseAuthException catch (e) {
      return Err(authFailure(e));
    }
  }
}

/// Clinic settings, days and opening hours.
class ClinicRepository {
  ClinicRepository(this._db, this._api);

  final FirebaseFirestore _db;
  final ClinicApi _api;

  Stream<ClinicSettings> watchSettings() =>
      _db.doc('settings/clinic').snapshots().map((s) => ClinicSettings.fromMap(s.data()));

  /// Admin only: adds the private alert email.
  Future<ClinicSettings> loadAdminSettings() async {
    final pub = await _db.doc('settings/clinic').get();
    final priv = await _db.doc('settings/private').get();
    return ClinicSettings.fromMap(pub.data()).withAdminEmail((priv.data()?['adminEmail'] as String?) ?? '');
  }

  Stream<Map<String, ClinicDay>> watchDays(ClinicDate from, ClinicDate to) => _db
      .collection('days')
      .where(FieldPath.documentId, isGreaterThanOrEqualTo: from)
      .where(FieldPath.documentId, isLessThanOrEqualTo: to)
      .snapshots()
      .map((q) => {for (final d in q.docs) d.id: ClinicDay.fromMap(d.id, d.data())});

  Stream<Map<String, DayOverride>> watchOverrides(ClinicDate from, ClinicDate to) => _db
      .collection('dayOverrides')
      .where(FieldPath.documentId, isGreaterThanOrEqualTo: from)
      .where(FieldPath.documentId, isLessThanOrEqualTo: to)
      .snapshots()
      .map((q) => {for (final d in q.docs) d.id: DayOverride.fromMap(d.data())});

  /// Weekly timetable, keyed 1 = Monday … 7 = Sunday.
  Stream<Map<int, List<TimeRange>>> watchWeekly() => _db.doc('settings/weekly').snapshots().map((s) {
    final days = (s.data()?['days'] as Map?) ?? const {};
    // Stored keys are 0 = Sunday … 6 = Saturday (JavaScript convention).
    return {
      for (var js = 0; js < 7; js++)
        js == 0 ? 7 : js: [
          if (days['$js'] is List)
            for (final r in days['$js']! as List) ?TimeRange.fromMap(r),
        ],
    };
  });

  Future<Result<List<Appointment>>> saveSettings(ClinicSettings s) async =>
      _outside(await _api.call('saveSettings', s.toPatch()));

  Future<Result<List<Appointment>>> saveWeekly(Map<int, List<TimeRange>> week) async => _outside(
    await _api.call('saveWeekly', {
      'days': {for (final e in week.entries) '${e.key % 7}': e.value.map((r) => r.toMap()).toList()},
    }),
  );

  /// Hours for dates ([intervals] empty = closed).
  Future<Result<List<Appointment>>> setHours(List<ClinicDate> dates, List<TimeRange> intervals) async => _outside(
    await _api.call('setDays', {
      'dates': dates,
      'override': {'mode': 'hours', 'intervals': intervals.map((r) => r.toMap()).toList()},
    }),
  );

  /// Only these slot starts open on the dates.
  Future<Result<List<Appointment>>> setPickedSlots(List<ClinicDate> dates, List<int> starts) async => _outside(
    await _api.call('setDays', {
      'dates': dates,
      'override': {'mode': 'slots', 'starts': starts.map(hhmm).toList()},
    }),
  );

  /// Back to the weekly timetable (or "not opened" in daily mode).
  Future<Result<List<Appointment>>> clearDays(List<ClinicDate> dates) async =>
      _outside(await _api.call('setDays', {'dates': dates, 'override': null}));

  Future<Result<List<Appointment>>> outsideHours() async =>
      _map(await _api.call('outsideHours'), (m) => _list(m['value']));

  /// Queues a test email to the signed-in admin; returns (mail id, recipient).
  Future<Result<(String, String)>> sendTestEmail() async =>
      _map(await _api.call('testEmail'), (m) => ('${m['id']}', '${m['to']}'));

  Future<Result<(String status, String? error)>> testEmailStatus(String id) async =>
      _map(await _api.call('mailStatus', {'id': id}), (m) => ('${m['status']}', m['error'] as String?));

  static Result<List<Appointment>> _outside(Result<Map<String, Object?>> r) => _map(r, (m) => _list(m['outsideHours']));

  static List<Appointment> _list(Object? v) => [
    if (v is List)
      for (final a in v)
        if (a is Map) Appointment.fromMap(a.cast<String, Object?>()),
  ];
}

/// Appointments.
class AppointmentRepository {
  AppointmentRepository(this._db, this._api);

  final FirebaseFirestore _db;
  final ClinicApi _api;

  Stream<List<Appointment>> watchMine(String uid) => _db
      .collection('appointments')
      .where('patientUid', isEqualTo: uid)
      .orderBy('startAt', descending: true)
      .snapshots()
      .map((q) => [for (final d in q.docs) Appointment.fromMap(d.data())]);

  /// Admin: all appointments between two dates (inclusive), sorted by time.
  Stream<List<Appointment>> watchRange(ClinicDate from, ClinicDate to) => _db
      .collection('appointments')
      .where('date', isGreaterThanOrEqualTo: from)
      .where('date', isLessThanOrEqualTo: to)
      .snapshots()
      .map(
        (q) =>
            [for (final d in q.docs) Appointment.fromMap(d.data())]
              ..sort((a, b) => a.date == b.date ? a.start.compareTo(b.start) : a.date.compareTo(b.date)),
      );

  Future<List<Appointment>> forPatient(String uid) async {
    final q = await _db
        .collection('appointments')
        .where('patientUid', isEqualTo: uid)
        .orderBy('startAt', descending: true)
        .get();
    return [for (final d in q.docs) Appointment.fromMap(d.data())];
  }

  Future<Result<Appointment>> book(ClinicDate date, int start, String reason) async =>
      _map(await _api.call('book', {'date': date, 'start': hhmm(start), 'reason': reason.trim()}), Appointment.fromMap);

  Future<Result<void>> cancelMine(String ref) async => _void(await _api.call('cancelMine', {'ref': ref}));

  Future<Result<Appointment>> claim(String ref, String phone) async =>
      _map(await _api.call('claimBooking', {'ref': ref.trim(), 'phone': phone.trim()}), Appointment.fromMap);

  Future<Result<Appointment>> adminBook({
    required ClinicDate date,
    required int start,
    required String name,
    required String phone,
    required String email,
    required String reason,
  }) async => _map(
    await _api.call('adminBook', {
      'date': date,
      'start': hhmm(start),
      'name': name,
      'phone': phone,
      'email': email,
      'reason': reason,
    }),
    Appointment.fromMap,
  );

  Future<Result<void>> setStatus(String ref, AppointmentStatus status) async =>
      _void(await _api.call('setStatus', {'ref': ref, 'status': statusKey(status)}));
}

/// In-app notifications.
class NotificationRepository {
  NotificationRepository(this._db);

  final FirebaseFirestore _db;

  Stream<List<AppNotification>> watch({required bool admin, String? uid}) {
    Query<Map<String, Object?>> q = _db.collection('notifications');
    q = admin
        ? q.where('audience', isEqualTo: 'admin')
        : q.where('audience', isEqualTo: 'patient').where('uid', isEqualTo: uid);
    return q
        .orderBy('createdAt', descending: true)
        .limit(40)
        .snapshots()
        .map((s) => [for (final d in s.docs) AppNotification.fromMap(d.id, d.data())]);
  }

  /// The only client write the rules allow: read → true.
  Future<void> markRead(Iterable<String> ids) async {
    if (ids.isEmpty) return;
    final batch = _db.batch();
    for (final id in ids) {
      batch.update(_db.doc('notifications/$id'), {'read': true});
    }
    await batch.commit();
  }
}

/// Admin: user accounts and roles.
class UserRepository {
  UserRepository(this._db, this._api);

  final FirebaseFirestore _db;
  final ClinicApi _api;

  Stream<List<AppUser>> watchAll() => _db
      .collection('users')
      .orderBy('createdAt', descending: true)
      .limit(1000)
      .snapshots()
      .map((q) => [for (final d in q.docs) AppUser.fromMap(d.id, d.data())]);

  Future<Result<void>> setRole(String uid, UserRole role) async =>
      _void(await _api.call('setRole', {'uid': uid, 'role': role.name}));
}
