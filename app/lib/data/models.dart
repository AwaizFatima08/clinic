import 'package:clinic_schedule/core/slot_rules.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

// Immutable views of the Firestore documents written by the Cloud Functions
// (see functions/src). Parsing is total: missing fields get safe defaults.

String _str(Object? v, [String fallback = '']) => v is String ? v : fallback;
int _int(Object? v, int fallback) => v is num ? v.toInt() : fallback;
bool _bool(Object? v, {required bool fallback}) => v is bool ? v : fallback;
DateTime? _time(Object? v) => v is Timestamp ? v.toDate() : (v is String ? DateTime.tryParse(v) : null);
List<TimeRange> _ranges(Object? v) => [
  if (v is List)
    for (final r in v) ?TimeRange.fromMap(r),
];

enum ScheduleMode { weekly, daily }

/// settings/clinic (+ settings/private for admins).
final class ClinicSettings {
  const ClinicSettings({
    required this.clinicName,
    required this.doctorName,
    required this.slotMinutes,
    required this.timezone,
    required this.bookingWindowDays,
    required this.minNoticeMinutes,
    required this.scheduleMode,
    required this.requireLogin,
    required this.maxUpcomingPerPatient,
    required this.emailNotifications,
    required this.instructions,
    this.adminEmail = '',
  });

  factory ClinicSettings.fromMap(Map<String, Object?>? m) {
    final d = m ?? const {};
    return ClinicSettings(
      clinicName: _str(d['clinicName'], 'Clinic'),
      doctorName: _str(d['doctorName']),
      slotMinutes: _int(d['slotMinutes'], 20),
      timezone: _str(d['timezone'], 'Asia/Karachi'),
      bookingWindowDays: _int(d['bookingWindowDays'], 30),
      minNoticeMinutes: _int(d['minNoticeMinutes'], 60),
      scheduleMode: d['scheduleMode'] == 'daily' ? ScheduleMode.daily : ScheduleMode.weekly,
      requireLogin: _bool(d['requireLogin'], fallback: true),
      maxUpcomingPerPatient: _int(d['maxUpcomingPerPatient'], 3),
      emailNotifications: _bool(d['emailNotifications'], fallback: true),
      instructions: _str(d['instructions']),
      adminEmail: _str(d['adminEmail']),
    );
  }

  static const fallback = ClinicSettings(
    clinicName: 'Clinic',
    doctorName: '',
    slotMinutes: 20,
    timezone: 'Asia/Karachi',
    bookingWindowDays: 30,
    minNoticeMinutes: 60,
    scheduleMode: ScheduleMode.weekly,
    requireLogin: true,
    maxUpcomingPerPatient: 3,
    emailNotifications: true,
    instructions: '',
  );

  final String clinicName;
  final String doctorName;
  final int slotMinutes;
  final String timezone;
  final int bookingWindowDays;
  final int minNoticeMinutes;
  final ScheduleMode scheduleMode;
  final bool requireLogin;
  final int maxUpcomingPerPatient;
  final bool emailNotifications;
  final String instructions;
  final String adminEmail;

  ClinicSettings withAdminEmail(String email) => ClinicSettings(
    clinicName: clinicName,
    doctorName: doctorName,
    slotMinutes: slotMinutes,
    timezone: timezone,
    bookingWindowDays: bookingWindowDays,
    minNoticeMinutes: minNoticeMinutes,
    scheduleMode: scheduleMode,
    requireLogin: requireLogin,
    maxUpcomingPerPatient: maxUpcomingPerPatient,
    emailNotifications: emailNotifications,
    instructions: instructions,
    adminEmail: email,
  );

  Map<String, Object> toPatch() => {
    'clinicName': clinicName,
    'doctorName': doctorName,
    'slotMinutes': slotMinutes,
    'timezone': timezone,
    'bookingWindowDays': bookingWindowDays,
    'minNoticeMinutes': minNoticeMinutes,
    'scheduleMode': scheduleMode.name,
    'requireLogin': requireLogin,
    'maxUpcomingPerPatient': maxUpcomingPerPatient,
    'emailNotifications': emailNotifications,
    'adminEmail': adminEmail,
    'instructions': instructions,
  };
}

enum DaySource { weekly, hours, slots, notActivated }

/// days/{date}: the public view of one date (open slots and taken times).
final class ClinicDay {
  const ClinicDay({
    required this.date,
    required this.open,
    required this.source,
    required this.slots,
    required this.taken,
  });

  factory ClinicDay.fromMap(String date, Map<String, Object?> d) => ClinicDay(
    date: date,
    open: _bool(d['open'], fallback: false),
    source: switch (d['source']) {
      'hours' => DaySource.hours,
      'slots' => DaySource.slots,
      'not_activated' => DaySource.notActivated,
      _ => DaySource.weekly,
    },
    slots: _ranges(d['slots']),
    taken: _ranges(d['taken']),
  );

  final String date;
  final bool open;
  final DaySource source;
  final List<TimeRange> slots;
  final List<TimeRange> taken;
}

/// dayOverrides/{date} (admin only).
final class DayOverride {
  const DayOverride({required this.isSlots, required this.intervals, required this.starts});

  factory DayOverride.fromMap(Map<String, Object?> d) => DayOverride(
    isSlots: d['mode'] == 'slots',
    intervals: _ranges(d['intervals']),
    starts: [
      if (d['starts'] is List)
        for (final s in d['starts']! as List) ?minutesFromHhmm(s),
    ],
  );

  final bool isSlots;
  final List<TimeRange> intervals;
  final List<int> starts;
}

enum AppointmentStatus { booked, completed, noShow, cancelled }

AppointmentStatus _status(Object? s) => switch (s) {
  'completed' => AppointmentStatus.completed,
  'no_show' => AppointmentStatus.noShow,
  'cancelled' => AppointmentStatus.cancelled,
  _ => AppointmentStatus.booked,
};

String statusKey(AppointmentStatus s) => switch (s) {
  AppointmentStatus.booked => 'booked',
  AppointmentStatus.completed => 'completed',
  AppointmentStatus.noShow => 'no_show',
  AppointmentStatus.cancelled => 'cancelled',
};

/// appointments/{ref}. Also built from the api's JSON replies.
final class Appointment {
  const Appointment({
    required this.ref,
    required this.date,
    required this.start,
    required this.end,
    required this.startAt,
    required this.patientName,
    required this.phone,
    required this.email,
    required this.reason,
    required this.status,
    required this.bookedByClinic,
    required this.cancelledBy,
    required this.patientUid,
  });

  factory Appointment.fromMap(Map<String, Object?> d) => Appointment(
    ref: _str(d['ref']),
    date: _str(d['date']),
    start: minutesFromHhmm(d['start']) ?? 0,
    end: minutesFromHhmm(d['end']) ?? 0,
    startAt: _time(d['startAt']),
    patientName: _str(d['patientName']),
    phone: _str(d['phone']),
    email: _str(d['email']),
    reason: _str(d['reason']),
    status: _status(d['status']),
    bookedByClinic: d['bookedBy'] == 'admin',
    cancelledBy: d['cancelledBy'] is String ? d['cancelledBy']! as String : null,
    patientUid: d['patientUid'] is String ? d['patientUid']! as String : null,
  );

  final String ref;
  final String date;
  final int start;
  final int end;
  final DateTime? startAt;
  final String patientName;
  final String phone;
  final String email;
  final String reason;
  final AppointmentStatus status;
  final bool bookedByClinic;
  final String? cancelledBy;
  final String? patientUid;

  bool isUpcoming(DateTime now) => status == AppointmentStatus.booked && (startAt?.isAfter(now) ?? false);
}

enum UserRole { patient, admin }

/// users/{uid}.
final class AppUser {
  const AppUser({
    required this.uid,
    required this.name,
    required this.phone,
    required this.email,
    required this.role,
    required this.createdAt,
    required this.lastLoginAt,
  });

  factory AppUser.fromMap(String uid, Map<String, Object?> d) => AppUser(
    uid: uid,
    name: _str(d['name']),
    phone: _str(d['phone']),
    email: _str(d['email']),
    role: d['role'] == 'admin' ? UserRole.admin : UserRole.patient,
    createdAt: _time(d['createdAt']),
    lastLoginAt: _time(d['lastLoginAt']),
  );

  final String uid;
  final String name;
  final String phone;
  final String email;
  final UserRole role;
  final DateTime? createdAt;
  final DateTime? lastLoginAt;

  bool get hasProfile => name.isNotEmpty && phone.isNotEmpty;
  bool get isAdmin => role == UserRole.admin;
}

/// notifications/{id}.
final class AppNotification {
  const AppNotification({
    required this.id,
    required this.title,
    required this.body,
    required this.read,
    required this.createdAt,
  });

  factory AppNotification.fromMap(String id, Map<String, Object?> d) => AppNotification(
    id: id,
    title: _str(d['title']),
    body: _str(d['body']),
    read: _bool(d['read'], fallback: false),
    createdAt: _time(d['createdAt']),
  );

  final String id;
  final String title;
  final String body;
  final bool read;
  final DateTime? createdAt;
}
