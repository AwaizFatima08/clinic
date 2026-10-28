// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get appTitle => 'Clinic Schedule';

  @override
  String get loading => 'Loading';

  @override
  String get logIn => 'Log in';

  @override
  String get createAccount => 'Create account';

  @override
  String get forgotPassword => 'Forgot password';

  @override
  String get loginIntro => 'Log in to book appointments and see your bookings and notifications.';

  @override
  String get email => 'Email';

  @override
  String get password => 'Password';

  @override
  String get passwordHelp => 'At least 8 characters';

  @override
  String get errorEmail => 'Please enter a valid email address.';

  @override
  String get errorPasswordEmpty => 'Please enter your password.';

  @override
  String get fullName => 'Full name';

  @override
  String get phone => 'Phone / WhatsApp';

  @override
  String get phoneHint => '+92 300 1234567';

  @override
  String get errorName => 'Please enter the full name (2–80 characters).';

  @override
  String get errorPhone => 'Please enter a valid phone number (7–15 digits, + allowed).';

  @override
  String get resetIntro => 'We will email you a link to choose a new password.';

  @override
  String get sendResetLink => 'Send reset link';

  @override
  String get resetSent => 'If an account exists for this email, a reset link is on its way.';

  @override
  String get yourDetails => 'Your details';

  @override
  String get profileIntro => 'Please add your name and phone number so the clinic can reach you.';

  @override
  String get save => 'Save';

  @override
  String get logOut => 'Log out';

  @override
  String get notifications => 'Notifications';

  @override
  String notificationsUnread(int count) {
    return 'Notifications, $count unread';
  }

  @override
  String get markAllRead => 'Mark all as read';

  @override
  String get noNotifications => 'No notifications yet.';

  @override
  String get tabBook => 'Book';

  @override
  String get tabMyAppointments => 'My appointments';

  @override
  String get tabAppointments => 'Bookings';

  @override
  String get tabHours => 'Hours';

  @override
  String get tabUsers => 'Users';

  @override
  String get tabSettings => 'Settings';

  @override
  String get chooseDay => 'Choose a day';

  @override
  String get chooseTime => 'Choose a time';

  @override
  String clinicTimeNote(String timezone, int minutes) {
    return 'All times are clinic time ($timezone). Each appointment is $minutes minutes.';
  }

  @override
  String get noAppointmentsAvailable => 'No appointments are available at the moment. Please check again later.';

  @override
  String get closed => 'Closed';

  @override
  String get full => 'Full';

  @override
  String freeCount(int count) {
    return '$count free';
  }

  @override
  String get today => 'Today';

  @override
  String get noTimesLeft => 'No free times left on this day.';

  @override
  String get morning => 'Morning';

  @override
  String get afternoon => 'Afternoon';

  @override
  String get evening => 'Evening';

  @override
  String get confirm => 'Confirm';

  @override
  String bookingAs(String name, String phone) {
    return 'Booking as $name ($phone)';
  }

  @override
  String get reasonOptional => 'Reason for visit (optional)';

  @override
  String get confirmAppointment => 'Confirm appointment';

  @override
  String get bookedTitle => 'Your appointment is booked';

  @override
  String get bookingReference => 'Booking reference';

  @override
  String get bookedNote => 'You can see it under “My appointments”. We will remind you before it starts.';

  @override
  String get bookAnother => 'Book another';

  @override
  String get loadError => 'Could not load. Please check your connection.';

  @override
  String get upcomingAppointments => 'Upcoming appointments';

  @override
  String get noUpcoming => 'No upcoming appointments.';

  @override
  String get pastAppointments => 'Past appointments';

  @override
  String get nothingYet => 'Nothing here yet.';

  @override
  String cancelQuestion(String date, String time) {
    return 'Cancel your appointment on $date at $time?';
  }

  @override
  String get cancelAppointment => 'Cancel appointment';

  @override
  String get cancelled => 'Your appointment has been cancelled.';

  @override
  String refLabel(String ref) {
    return 'Ref $ref';
  }

  @override
  String get cancel => 'Cancel';

  @override
  String claimed(String date, String time) {
    return 'Added your appointment on $date at $time.';
  }

  @override
  String get claimTitle => 'Add a booking made by phone or without an account';

  @override
  String get errorRef => 'Enter the 6-character booking reference.';

  @override
  String get phoneUsed => 'Phone used for that booking';

  @override
  String get addToAccount => 'Add to my account';

  @override
  String get statusBooked => 'Booked';

  @override
  String get statusCompleted => 'Completed';

  @override
  String get statusMissed => 'Missed';

  @override
  String get statusCancelled => 'Cancelled';

  @override
  String get no => 'No';

  @override
  String get yes => 'Yes';

  @override
  String get newAppointment => 'New appointment';

  @override
  String get noAppointmentsInRange => 'No appointments in this range.';

  @override
  String get next7Days => 'Next 7 days';

  @override
  String get allStatuses => 'All statuses';

  @override
  String get byClinic => 'booked by clinic';

  @override
  String get hasAccount => 'has account';

  @override
  String cancelledBy(String who) {
    return 'cancelled by $who';
  }

  @override
  String get markDone => 'Done';

  @override
  String get markMissed => 'Missed';

  @override
  String adminCancelQuestion(String name) {
    return 'Cancel $name\'s appointment? The patient will be notified.';
  }

  @override
  String get setBackToBooked => 'Set back to booked';

  @override
  String outsideHoursTitle(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count booked appointments are outside the opening hours. The patients have been notified:',
      one: '1 booked appointment is outside the opening hours. The patient has been notified:',
    );
    return '$_temp0';
  }

  @override
  String get freeTime => 'Free time';

  @override
  String get patientName => 'Patient name';

  @override
  String get emailOptional => 'Email (optional — confirmation and reminders)';

  @override
  String get book => 'Book';

  @override
  String adminBooked(String name, String ref) {
    return 'Booked $name. Reference $ref.';
  }

  @override
  String get saved => 'Saved.';

  @override
  String savedWithOutside(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Saved. $count booked appointments are now outside the opening hours.',
      one: 'Saved. 1 booked appointment is now outside the opening hours.',
    );
    return '$_temp0';
  }

  @override
  String get to => 'to';

  @override
  String get remove => 'Remove';

  @override
  String get addRange => 'Add time range';

  @override
  String get alreadyBooked => 'Already booked';

  @override
  String get dailyHours => 'Daily hours';

  @override
  String get pickSlots => 'Pick slots';

  @override
  String get weeklyTimetable => 'Weekly timetable';

  @override
  String get modeDailyNote => 'Days are closed until you open them here or in “Pick slots”.';

  @override
  String get modeWeeklyNote => 'Days follow the weekly timetable. Change hours, pick single slots or close a day here.';

  @override
  String get twoWeeks => '2 weeks';

  @override
  String closeDayWithBookings(int count) {
    return '$count appointment(s) are booked on this day. Close it anyway? They stay booked until you cancel them, and the patients are notified.';
  }

  @override
  String get closeDayQuestion => 'Close this day?';

  @override
  String get sourceWeekly => 'Weekly timetable';

  @override
  String get sourceHours => 'Hours set for this day';

  @override
  String get sourceSlots => 'Picked slots';

  @override
  String get sourceNotOpened => 'Not opened';

  @override
  String bookedAndFree(int booked, int free) {
    return '$booked booked · $free free';
  }

  @override
  String get open => 'Open';

  @override
  String get editHours => 'Edit hours';

  @override
  String get openCustomHours => 'Open with custom hours';

  @override
  String get closeDay => 'Close day';

  @override
  String get useWeekly => 'Use weekly timetable';

  @override
  String get removeOpening => 'Remove opening';

  @override
  String get pickSlotsHelp => 'Tick the times to open. Only ticked slots can be booked on this day.';

  @override
  String get chooseAtLeastOneDay => 'Choose at least one day.';

  @override
  String get atMost62Days => 'Choose at most 62 days at a time.';

  @override
  String get pickSlotsIntro =>
      'Choose the days, tick the exact times to open, and apply. On those days only the ticked slots can be booked. Existing appointments are never removed.';

  @override
  String get days => 'Days';

  @override
  String get noDaysMatch => 'No days match.';

  @override
  String daysSelected(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count days selected',
      one: '1 day selected',
    );
    return '$_temp0';
  }

  @override
  String fromDate(String date) {
    return 'From $date';
  }

  @override
  String toDate(String date) {
    return 'To $date';
  }

  @override
  String timesWithLength(int minutes) {
    return 'Times ($minutes-minute slots)';
  }

  @override
  String slotsTicked(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count slots ticked',
      one: '1 slot ticked',
    );
    return '$_temp0';
  }

  @override
  String get showTimes => 'Show times from';

  @override
  String get selectAll => 'Select all';

  @override
  String get clear => 'Clear';

  @override
  String noSlotsTickedQuestion(int days) {
    return 'No slots are ticked, so $days day(s) will be closed. Continue?';
  }

  @override
  String openSlotsQuestion(int slots, int days) {
    return 'Open only $slots slot(s) on $days day(s)?';
  }

  @override
  String get openOnlyTheseSlots => 'Open only these slots';

  @override
  String closeDaysQuestion(int days) {
    return 'Close $days day(s)?';
  }

  @override
  String get closeTheseDays => 'Close these days';

  @override
  String resetDaysQuestion(int days) {
    return 'Return $days day(s) to the weekly timetable?';
  }

  @override
  String get backToWeekly => 'Back to weekly timetable';

  @override
  String get weeklyDailyModeNote => 'Daily opening mode: this timetable only fills in the hours when you open a day.';

  @override
  String get weeklyNote => 'These hours repeat every week. Remove all ranges to close that weekday.';

  @override
  String get saveWeekly => 'Save weekly timetable';

  @override
  String get usersIntro => 'Everyone with an account. Admins can manage appointments, hours, users and settings.';

  @override
  String get searchUsers => 'Search name, phone or email';

  @override
  String get all => 'All';

  @override
  String get patients => 'Patients';

  @override
  String get admins => 'Admins';

  @override
  String get noUsers => 'No users match.';

  @override
  String makeAdminQuestion(String name) {
    return 'Give $name full admin access (appointments, hours, users, settings)?';
  }

  @override
  String removeAdminQuestion(String name) {
    return 'Remove admin access from $name?';
  }

  @override
  String nowAdmin(String name) {
    return '$name is now an admin.';
  }

  @override
  String nowPatient(String name) {
    return '$name is now a patient.';
  }

  @override
  String lastLogin(String when) {
    return 'last login $when';
  }

  @override
  String get adminYou => 'Admin (you)';

  @override
  String get rolePatient => 'Patient';

  @override
  String get roleAdmin => 'Admin';

  @override
  String errorNumberRange(int min, int max) {
    return 'Enter a whole number from $min to $max.';
  }

  @override
  String get clinicSettings => 'Clinic settings';

  @override
  String get clinicName => 'Clinic name';

  @override
  String get required => 'Required';

  @override
  String get doctorName => 'Doctor name / title';

  @override
  String get slotLength => 'Appointment (slot) length';

  @override
  String get slotLengthHelp => 'Applies to new bookings. Existing appointments keep their time.';

  @override
  String minutes(int count) {
    return '$count minutes';
  }

  @override
  String get howDaysOpen => 'How days open';

  @override
  String get modeWeekly => 'Automatically from the weekly timetable';

  @override
  String get modeDaily => 'Only days I open';

  @override
  String get bookingWindow => 'Patients can book up to … days ahead';

  @override
  String get minNotice => 'Minimum notice before a slot (minutes)';

  @override
  String get requireLogin => 'Only patients with an account can book';

  @override
  String get maxUpcoming => 'Upcoming appointments allowed per patient';

  @override
  String get emailNotifications => 'Email notifications (confirmations, changes, reminders)';

  @override
  String get alertEmail => 'Send clinic alerts to (email)';

  @override
  String get timeZone => 'Clinic time zone';

  @override
  String get patientMessage => 'Message shown to patients after booking';

  @override
  String get saveSettings => 'Save settings';

  @override
  String sendingTo(String to) {
    return 'Sending to $to…';
  }

  @override
  String testEmailSent(String to) {
    return 'Sent to $to. Check the inbox (and the spam folder).';
  }

  @override
  String testEmailFailed(String status, String error) {
    return 'Email not sent ($status): $error';
  }

  @override
  String get testEmailTimeout => 'No answer from the mail service yet. Try again in a minute.';

  @override
  String get emailCheck => 'Email check';

  @override
  String get emailCheckHelp => 'Sends a test message to the email you are logged in with, through the clinic mailbox.';

  @override
  String get sendTestEmail => 'Send test email';
}
