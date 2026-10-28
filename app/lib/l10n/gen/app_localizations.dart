import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_en.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of AppLocalizations
/// returned by `AppLocalizations.of(context)`.
///
/// Applications need to include `AppLocalizations.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'gen/app_localizations.dart';
///
/// return MaterialApp(
///   localizationsDelegates: AppLocalizations.localizationsDelegates,
///   supportedLocales: AppLocalizations.supportedLocales,
///   home: MyApplicationHome(),
/// );
/// ```
///
/// ## Update pubspec.yaml
///
/// Please make sure to update your pubspec.yaml to include the following
/// packages:
///
/// ```yaml
/// dependencies:
///   # Internationalization support.
///   flutter_localizations:
///     sdk: flutter
///   intl: any # Use the pinned version from flutter_localizations
///
///   # Rest of dependencies
/// ```
///
/// ## iOS Applications
///
/// iOS applications define key application metadata, including supported
/// locales, in an Info.plist file that is built into the application bundle.
/// To configure the locales supported by your app, you’ll need to edit this
/// file.
///
/// First, open your project’s ios/Runner.xcworkspace Xcode workspace file.
/// Then, in the Project Navigator, open the Info.plist file under the Runner
/// project’s Runner folder.
///
/// Next, select the Information Property List item, select Add Item from the
/// Editor menu, then select Localizations from the pop-up menu.
///
/// Select and expand the newly-created Localizations item then, for each
/// locale your application supports, add a new item and select the locale
/// you wish to add from the pop-up menu in the Value field. This list should
/// be consistent with the languages listed in the AppLocalizations.supportedLocales
/// property.
abstract class AppLocalizations {
  AppLocalizations(String locale) : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static AppLocalizations of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations)!;
  }

  static const LocalizationsDelegate<AppLocalizations> delegate = _AppLocalizationsDelegate();

  /// A list of this localizations delegate along with the default localizations
  /// delegates.
  ///
  /// Returns a list of localizations delegates containing this delegate along with
  /// GlobalMaterialLocalizations.delegate, GlobalCupertinoLocalizations.delegate,
  /// and GlobalWidgetsLocalizations.delegate.
  ///
  /// Additional delegates can be added by appending to this list in
  /// MaterialApp. This list does not have to be used at all if a custom list
  /// of delegates is preferred or required.
  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates = <LocalizationsDelegate<dynamic>>[
    delegate,
    GlobalMaterialLocalizations.delegate,
    GlobalCupertinoLocalizations.delegate,
    GlobalWidgetsLocalizations.delegate,
  ];

  /// A list of this localizations delegate's supported locales.
  static const List<Locale> supportedLocales = <Locale>[Locale('en')];

  /// No description provided for @appTitle.
  ///
  /// In en, this message translates to:
  /// **'Clinic Schedule'**
  String get appTitle;

  /// No description provided for @loading.
  ///
  /// In en, this message translates to:
  /// **'Loading'**
  String get loading;

  /// No description provided for @logIn.
  ///
  /// In en, this message translates to:
  /// **'Log in'**
  String get logIn;

  /// No description provided for @createAccount.
  ///
  /// In en, this message translates to:
  /// **'Create account'**
  String get createAccount;

  /// No description provided for @forgotPassword.
  ///
  /// In en, this message translates to:
  /// **'Forgot password'**
  String get forgotPassword;

  /// No description provided for @loginIntro.
  ///
  /// In en, this message translates to:
  /// **'Log in to book appointments and see your bookings and notifications.'**
  String get loginIntro;

  /// No description provided for @email.
  ///
  /// In en, this message translates to:
  /// **'Email'**
  String get email;

  /// No description provided for @password.
  ///
  /// In en, this message translates to:
  /// **'Password'**
  String get password;

  /// No description provided for @passwordHelp.
  ///
  /// In en, this message translates to:
  /// **'At least 8 characters'**
  String get passwordHelp;

  /// No description provided for @errorEmail.
  ///
  /// In en, this message translates to:
  /// **'Please enter a valid email address.'**
  String get errorEmail;

  /// No description provided for @errorPasswordEmpty.
  ///
  /// In en, this message translates to:
  /// **'Please enter your password.'**
  String get errorPasswordEmpty;

  /// No description provided for @fullName.
  ///
  /// In en, this message translates to:
  /// **'Full name'**
  String get fullName;

  /// No description provided for @phone.
  ///
  /// In en, this message translates to:
  /// **'Phone / WhatsApp'**
  String get phone;

  /// No description provided for @phoneHint.
  ///
  /// In en, this message translates to:
  /// **'+92 300 1234567'**
  String get phoneHint;

  /// No description provided for @errorName.
  ///
  /// In en, this message translates to:
  /// **'Please enter the full name (2–80 characters).'**
  String get errorName;

  /// No description provided for @errorPhone.
  ///
  /// In en, this message translates to:
  /// **'Please enter a valid phone number (7–15 digits, + allowed).'**
  String get errorPhone;

  /// No description provided for @resetIntro.
  ///
  /// In en, this message translates to:
  /// **'We will email you a link to choose a new password.'**
  String get resetIntro;

  /// No description provided for @sendResetLink.
  ///
  /// In en, this message translates to:
  /// **'Send reset link'**
  String get sendResetLink;

  /// No description provided for @resetSent.
  ///
  /// In en, this message translates to:
  /// **'If an account exists for this email, a reset link is on its way.'**
  String get resetSent;

  /// No description provided for @yourDetails.
  ///
  /// In en, this message translates to:
  /// **'Your details'**
  String get yourDetails;

  /// No description provided for @profileIntro.
  ///
  /// In en, this message translates to:
  /// **'Please add your name and phone number so the clinic can reach you.'**
  String get profileIntro;

  /// No description provided for @save.
  ///
  /// In en, this message translates to:
  /// **'Save'**
  String get save;

  /// No description provided for @logOut.
  ///
  /// In en, this message translates to:
  /// **'Log out'**
  String get logOut;

  /// No description provided for @notifications.
  ///
  /// In en, this message translates to:
  /// **'Notifications'**
  String get notifications;

  /// No description provided for @notificationsUnread.
  ///
  /// In en, this message translates to:
  /// **'Notifications, {count} unread'**
  String notificationsUnread(int count);

  /// No description provided for @markAllRead.
  ///
  /// In en, this message translates to:
  /// **'Mark all as read'**
  String get markAllRead;

  /// No description provided for @noNotifications.
  ///
  /// In en, this message translates to:
  /// **'No notifications yet.'**
  String get noNotifications;

  /// No description provided for @tabBook.
  ///
  /// In en, this message translates to:
  /// **'Book'**
  String get tabBook;

  /// No description provided for @tabMyAppointments.
  ///
  /// In en, this message translates to:
  /// **'My appointments'**
  String get tabMyAppointments;

  /// No description provided for @tabAppointments.
  ///
  /// In en, this message translates to:
  /// **'Bookings'**
  String get tabAppointments;

  /// No description provided for @tabHours.
  ///
  /// In en, this message translates to:
  /// **'Hours'**
  String get tabHours;

  /// No description provided for @tabUsers.
  ///
  /// In en, this message translates to:
  /// **'Users'**
  String get tabUsers;

  /// No description provided for @tabSettings.
  ///
  /// In en, this message translates to:
  /// **'Settings'**
  String get tabSettings;

  /// No description provided for @chooseDay.
  ///
  /// In en, this message translates to:
  /// **'Choose a day'**
  String get chooseDay;

  /// No description provided for @chooseTime.
  ///
  /// In en, this message translates to:
  /// **'Choose a time'**
  String get chooseTime;

  /// No description provided for @clinicTimeNote.
  ///
  /// In en, this message translates to:
  /// **'All times are clinic time ({timezone}). Each appointment is {minutes} minutes.'**
  String clinicTimeNote(String timezone, int minutes);

  /// No description provided for @noAppointmentsAvailable.
  ///
  /// In en, this message translates to:
  /// **'No appointments are available at the moment. Please check again later.'**
  String get noAppointmentsAvailable;

  /// No description provided for @closed.
  ///
  /// In en, this message translates to:
  /// **'Closed'**
  String get closed;

  /// No description provided for @full.
  ///
  /// In en, this message translates to:
  /// **'Full'**
  String get full;

  /// No description provided for @freeCount.
  ///
  /// In en, this message translates to:
  /// **'{count} free'**
  String freeCount(int count);

  /// No description provided for @today.
  ///
  /// In en, this message translates to:
  /// **'Today'**
  String get today;

  /// No description provided for @noTimesLeft.
  ///
  /// In en, this message translates to:
  /// **'No free times left on this day.'**
  String get noTimesLeft;

  /// No description provided for @morning.
  ///
  /// In en, this message translates to:
  /// **'Morning'**
  String get morning;

  /// No description provided for @afternoon.
  ///
  /// In en, this message translates to:
  /// **'Afternoon'**
  String get afternoon;

  /// No description provided for @evening.
  ///
  /// In en, this message translates to:
  /// **'Evening'**
  String get evening;

  /// No description provided for @confirm.
  ///
  /// In en, this message translates to:
  /// **'Confirm'**
  String get confirm;

  /// No description provided for @bookingAs.
  ///
  /// In en, this message translates to:
  /// **'Booking as {name} ({phone})'**
  String bookingAs(String name, String phone);

  /// No description provided for @reasonOptional.
  ///
  /// In en, this message translates to:
  /// **'Reason for visit (optional)'**
  String get reasonOptional;

  /// No description provided for @confirmAppointment.
  ///
  /// In en, this message translates to:
  /// **'Confirm appointment'**
  String get confirmAppointment;

  /// No description provided for @bookedTitle.
  ///
  /// In en, this message translates to:
  /// **'Your appointment is booked'**
  String get bookedTitle;

  /// No description provided for @bookingReference.
  ///
  /// In en, this message translates to:
  /// **'Booking reference'**
  String get bookingReference;

  /// No description provided for @bookedNote.
  ///
  /// In en, this message translates to:
  /// **'You can see it under “My appointments”. We will remind you before it starts.'**
  String get bookedNote;

  /// No description provided for @bookAnother.
  ///
  /// In en, this message translates to:
  /// **'Book another'**
  String get bookAnother;

  /// No description provided for @loadError.
  ///
  /// In en, this message translates to:
  /// **'Could not load. Please check your connection.'**
  String get loadError;

  /// No description provided for @upcomingAppointments.
  ///
  /// In en, this message translates to:
  /// **'Upcoming appointments'**
  String get upcomingAppointments;

  /// No description provided for @noUpcoming.
  ///
  /// In en, this message translates to:
  /// **'No upcoming appointments.'**
  String get noUpcoming;

  /// No description provided for @pastAppointments.
  ///
  /// In en, this message translates to:
  /// **'Past appointments'**
  String get pastAppointments;

  /// No description provided for @nothingYet.
  ///
  /// In en, this message translates to:
  /// **'Nothing here yet.'**
  String get nothingYet;

  /// No description provided for @cancelQuestion.
  ///
  /// In en, this message translates to:
  /// **'Cancel your appointment on {date} at {time}?'**
  String cancelQuestion(String date, String time);

  /// No description provided for @cancelAppointment.
  ///
  /// In en, this message translates to:
  /// **'Cancel appointment'**
  String get cancelAppointment;

  /// No description provided for @cancelled.
  ///
  /// In en, this message translates to:
  /// **'Your appointment has been cancelled.'**
  String get cancelled;

  /// No description provided for @refLabel.
  ///
  /// In en, this message translates to:
  /// **'Ref {ref}'**
  String refLabel(String ref);

  /// No description provided for @cancel.
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get cancel;

  /// No description provided for @claimed.
  ///
  /// In en, this message translates to:
  /// **'Added your appointment on {date} at {time}.'**
  String claimed(String date, String time);

  /// No description provided for @claimTitle.
  ///
  /// In en, this message translates to:
  /// **'Add a booking made by phone or without an account'**
  String get claimTitle;

  /// No description provided for @errorRef.
  ///
  /// In en, this message translates to:
  /// **'Enter the 6-character booking reference.'**
  String get errorRef;

  /// No description provided for @phoneUsed.
  ///
  /// In en, this message translates to:
  /// **'Phone used for that booking'**
  String get phoneUsed;

  /// No description provided for @addToAccount.
  ///
  /// In en, this message translates to:
  /// **'Add to my account'**
  String get addToAccount;

  /// No description provided for @statusBooked.
  ///
  /// In en, this message translates to:
  /// **'Booked'**
  String get statusBooked;

  /// No description provided for @statusCompleted.
  ///
  /// In en, this message translates to:
  /// **'Completed'**
  String get statusCompleted;

  /// No description provided for @statusMissed.
  ///
  /// In en, this message translates to:
  /// **'Missed'**
  String get statusMissed;

  /// No description provided for @statusCancelled.
  ///
  /// In en, this message translates to:
  /// **'Cancelled'**
  String get statusCancelled;

  /// No description provided for @no.
  ///
  /// In en, this message translates to:
  /// **'No'**
  String get no;

  /// No description provided for @yes.
  ///
  /// In en, this message translates to:
  /// **'Yes'**
  String get yes;

  /// No description provided for @newAppointment.
  ///
  /// In en, this message translates to:
  /// **'New appointment'**
  String get newAppointment;

  /// No description provided for @noAppointmentsInRange.
  ///
  /// In en, this message translates to:
  /// **'No appointments in this range.'**
  String get noAppointmentsInRange;

  /// No description provided for @next7Days.
  ///
  /// In en, this message translates to:
  /// **'Next 7 days'**
  String get next7Days;

  /// No description provided for @allStatuses.
  ///
  /// In en, this message translates to:
  /// **'All statuses'**
  String get allStatuses;

  /// No description provided for @byClinic.
  ///
  /// In en, this message translates to:
  /// **'booked by clinic'**
  String get byClinic;

  /// No description provided for @hasAccount.
  ///
  /// In en, this message translates to:
  /// **'has account'**
  String get hasAccount;

  /// No description provided for @cancelledBy.
  ///
  /// In en, this message translates to:
  /// **'cancelled by {who}'**
  String cancelledBy(String who);

  /// No description provided for @markDone.
  ///
  /// In en, this message translates to:
  /// **'Done'**
  String get markDone;

  /// No description provided for @markMissed.
  ///
  /// In en, this message translates to:
  /// **'Missed'**
  String get markMissed;

  /// No description provided for @adminCancelQuestion.
  ///
  /// In en, this message translates to:
  /// **'Cancel {name}\'s appointment? The patient will be notified.'**
  String adminCancelQuestion(String name);

  /// No description provided for @setBackToBooked.
  ///
  /// In en, this message translates to:
  /// **'Set back to booked'**
  String get setBackToBooked;

  /// No description provided for @outsideHoursTitle.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 booked appointment is outside the opening hours. The patient has been notified:} other{{count} booked appointments are outside the opening hours. The patients have been notified:}}'**
  String outsideHoursTitle(int count);

  /// No description provided for @freeTime.
  ///
  /// In en, this message translates to:
  /// **'Free time'**
  String get freeTime;

  /// No description provided for @patientName.
  ///
  /// In en, this message translates to:
  /// **'Patient name'**
  String get patientName;

  /// No description provided for @emailOptional.
  ///
  /// In en, this message translates to:
  /// **'Email (optional — confirmation and reminders)'**
  String get emailOptional;

  /// No description provided for @book.
  ///
  /// In en, this message translates to:
  /// **'Book'**
  String get book;

  /// No description provided for @adminBooked.
  ///
  /// In en, this message translates to:
  /// **'Booked {name}. Reference {ref}.'**
  String adminBooked(String name, String ref);

  /// No description provided for @saved.
  ///
  /// In en, this message translates to:
  /// **'Saved.'**
  String get saved;

  /// No description provided for @savedWithOutside.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{Saved. 1 booked appointment is now outside the opening hours.} other{Saved. {count} booked appointments are now outside the opening hours.}}'**
  String savedWithOutside(int count);

  /// No description provided for @to.
  ///
  /// In en, this message translates to:
  /// **'to'**
  String get to;

  /// No description provided for @remove.
  ///
  /// In en, this message translates to:
  /// **'Remove'**
  String get remove;

  /// No description provided for @addRange.
  ///
  /// In en, this message translates to:
  /// **'Add time range'**
  String get addRange;

  /// No description provided for @alreadyBooked.
  ///
  /// In en, this message translates to:
  /// **'Already booked'**
  String get alreadyBooked;

  /// No description provided for @dailyHours.
  ///
  /// In en, this message translates to:
  /// **'Daily hours'**
  String get dailyHours;

  /// No description provided for @pickSlots.
  ///
  /// In en, this message translates to:
  /// **'Pick slots'**
  String get pickSlots;

  /// No description provided for @weeklyTimetable.
  ///
  /// In en, this message translates to:
  /// **'Weekly timetable'**
  String get weeklyTimetable;

  /// No description provided for @modeDailyNote.
  ///
  /// In en, this message translates to:
  /// **'Days are closed until you open them here or in “Pick slots”.'**
  String get modeDailyNote;

  /// No description provided for @modeWeeklyNote.
  ///
  /// In en, this message translates to:
  /// **'Days follow the weekly timetable. Change hours, pick single slots or close a day here.'**
  String get modeWeeklyNote;

  /// No description provided for @twoWeeks.
  ///
  /// In en, this message translates to:
  /// **'2 weeks'**
  String get twoWeeks;

  /// No description provided for @closeDayWithBookings.
  ///
  /// In en, this message translates to:
  /// **'{count} appointment(s) are booked on this day. Close it anyway? They stay booked until you cancel them, and the patients are notified.'**
  String closeDayWithBookings(int count);

  /// No description provided for @closeDayQuestion.
  ///
  /// In en, this message translates to:
  /// **'Close this day?'**
  String get closeDayQuestion;

  /// No description provided for @sourceWeekly.
  ///
  /// In en, this message translates to:
  /// **'Weekly timetable'**
  String get sourceWeekly;

  /// No description provided for @sourceHours.
  ///
  /// In en, this message translates to:
  /// **'Hours set for this day'**
  String get sourceHours;

  /// No description provided for @sourceSlots.
  ///
  /// In en, this message translates to:
  /// **'Picked slots'**
  String get sourceSlots;

  /// No description provided for @sourceNotOpened.
  ///
  /// In en, this message translates to:
  /// **'Not opened'**
  String get sourceNotOpened;

  /// No description provided for @bookedAndFree.
  ///
  /// In en, this message translates to:
  /// **'{booked} booked · {free} free'**
  String bookedAndFree(int booked, int free);

  /// No description provided for @open.
  ///
  /// In en, this message translates to:
  /// **'Open'**
  String get open;

  /// No description provided for @editHours.
  ///
  /// In en, this message translates to:
  /// **'Edit hours'**
  String get editHours;

  /// No description provided for @openCustomHours.
  ///
  /// In en, this message translates to:
  /// **'Open with custom hours'**
  String get openCustomHours;

  /// No description provided for @closeDay.
  ///
  /// In en, this message translates to:
  /// **'Close day'**
  String get closeDay;

  /// No description provided for @useWeekly.
  ///
  /// In en, this message translates to:
  /// **'Use weekly timetable'**
  String get useWeekly;

  /// No description provided for @removeOpening.
  ///
  /// In en, this message translates to:
  /// **'Remove opening'**
  String get removeOpening;

  /// No description provided for @pickSlotsHelp.
  ///
  /// In en, this message translates to:
  /// **'Tick the times to open. Only ticked slots can be booked on this day.'**
  String get pickSlotsHelp;

  /// No description provided for @chooseAtLeastOneDay.
  ///
  /// In en, this message translates to:
  /// **'Choose at least one day.'**
  String get chooseAtLeastOneDay;

  /// No description provided for @atMost62Days.
  ///
  /// In en, this message translates to:
  /// **'Choose at most 62 days at a time.'**
  String get atMost62Days;

  /// No description provided for @pickSlotsIntro.
  ///
  /// In en, this message translates to:
  /// **'Choose the days, tick the exact times to open, and apply. On those days only the ticked slots can be booked. Existing appointments are never removed.'**
  String get pickSlotsIntro;

  /// No description provided for @days.
  ///
  /// In en, this message translates to:
  /// **'Days'**
  String get days;

  /// No description provided for @noDaysMatch.
  ///
  /// In en, this message translates to:
  /// **'No days match.'**
  String get noDaysMatch;

  /// No description provided for @daysSelected.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 day selected} other{{count} days selected}}'**
  String daysSelected(int count);

  /// No description provided for @fromDate.
  ///
  /// In en, this message translates to:
  /// **'From {date}'**
  String fromDate(String date);

  /// No description provided for @toDate.
  ///
  /// In en, this message translates to:
  /// **'To {date}'**
  String toDate(String date);

  /// No description provided for @timesWithLength.
  ///
  /// In en, this message translates to:
  /// **'Times ({minutes}-minute slots)'**
  String timesWithLength(int minutes);

  /// No description provided for @slotsTicked.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 slot ticked} other{{count} slots ticked}}'**
  String slotsTicked(int count);

  /// No description provided for @showTimes.
  ///
  /// In en, this message translates to:
  /// **'Show times from'**
  String get showTimes;

  /// No description provided for @selectAll.
  ///
  /// In en, this message translates to:
  /// **'Select all'**
  String get selectAll;

  /// No description provided for @clear.
  ///
  /// In en, this message translates to:
  /// **'Clear'**
  String get clear;

  /// No description provided for @noSlotsTickedQuestion.
  ///
  /// In en, this message translates to:
  /// **'No slots are ticked, so {days} day(s) will be closed. Continue?'**
  String noSlotsTickedQuestion(int days);

  /// No description provided for @openSlotsQuestion.
  ///
  /// In en, this message translates to:
  /// **'Open only {slots} slot(s) on {days} day(s)?'**
  String openSlotsQuestion(int slots, int days);

  /// No description provided for @openOnlyTheseSlots.
  ///
  /// In en, this message translates to:
  /// **'Open only these slots'**
  String get openOnlyTheseSlots;

  /// No description provided for @closeDaysQuestion.
  ///
  /// In en, this message translates to:
  /// **'Close {days} day(s)?'**
  String closeDaysQuestion(int days);

  /// No description provided for @closeTheseDays.
  ///
  /// In en, this message translates to:
  /// **'Close these days'**
  String get closeTheseDays;

  /// No description provided for @resetDaysQuestion.
  ///
  /// In en, this message translates to:
  /// **'Return {days} day(s) to the weekly timetable?'**
  String resetDaysQuestion(int days);

  /// No description provided for @backToWeekly.
  ///
  /// In en, this message translates to:
  /// **'Back to weekly timetable'**
  String get backToWeekly;

  /// No description provided for @weeklyDailyModeNote.
  ///
  /// In en, this message translates to:
  /// **'Daily opening mode: this timetable only fills in the hours when you open a day.'**
  String get weeklyDailyModeNote;

  /// No description provided for @weeklyNote.
  ///
  /// In en, this message translates to:
  /// **'These hours repeat every week. Remove all ranges to close that weekday.'**
  String get weeklyNote;

  /// No description provided for @saveWeekly.
  ///
  /// In en, this message translates to:
  /// **'Save weekly timetable'**
  String get saveWeekly;

  /// No description provided for @usersIntro.
  ///
  /// In en, this message translates to:
  /// **'Everyone with an account. Admins can manage appointments, hours, users and settings.'**
  String get usersIntro;

  /// No description provided for @searchUsers.
  ///
  /// In en, this message translates to:
  /// **'Search name, phone or email'**
  String get searchUsers;

  /// No description provided for @all.
  ///
  /// In en, this message translates to:
  /// **'All'**
  String get all;

  /// No description provided for @patients.
  ///
  /// In en, this message translates to:
  /// **'Patients'**
  String get patients;

  /// No description provided for @admins.
  ///
  /// In en, this message translates to:
  /// **'Admins'**
  String get admins;

  /// No description provided for @noUsers.
  ///
  /// In en, this message translates to:
  /// **'No users match.'**
  String get noUsers;

  /// No description provided for @makeAdminQuestion.
  ///
  /// In en, this message translates to:
  /// **'Give {name} full admin access (appointments, hours, users, settings)?'**
  String makeAdminQuestion(String name);

  /// No description provided for @removeAdminQuestion.
  ///
  /// In en, this message translates to:
  /// **'Remove admin access from {name}?'**
  String removeAdminQuestion(String name);

  /// No description provided for @nowAdmin.
  ///
  /// In en, this message translates to:
  /// **'{name} is now an admin.'**
  String nowAdmin(String name);

  /// No description provided for @nowPatient.
  ///
  /// In en, this message translates to:
  /// **'{name} is now a patient.'**
  String nowPatient(String name);

  /// No description provided for @lastLogin.
  ///
  /// In en, this message translates to:
  /// **'last login {when}'**
  String lastLogin(String when);

  /// No description provided for @adminYou.
  ///
  /// In en, this message translates to:
  /// **'Admin (you)'**
  String get adminYou;

  /// No description provided for @rolePatient.
  ///
  /// In en, this message translates to:
  /// **'Patient'**
  String get rolePatient;

  /// No description provided for @roleAdmin.
  ///
  /// In en, this message translates to:
  /// **'Admin'**
  String get roleAdmin;

  /// No description provided for @errorNumberRange.
  ///
  /// In en, this message translates to:
  /// **'Enter a whole number from {min} to {max}.'**
  String errorNumberRange(int min, int max);

  /// No description provided for @clinicSettings.
  ///
  /// In en, this message translates to:
  /// **'Clinic settings'**
  String get clinicSettings;

  /// No description provided for @clinicName.
  ///
  /// In en, this message translates to:
  /// **'Clinic name'**
  String get clinicName;

  /// No description provided for @required.
  ///
  /// In en, this message translates to:
  /// **'Required'**
  String get required;

  /// No description provided for @doctorName.
  ///
  /// In en, this message translates to:
  /// **'Doctor name / title'**
  String get doctorName;

  /// No description provided for @slotLength.
  ///
  /// In en, this message translates to:
  /// **'Appointment (slot) length'**
  String get slotLength;

  /// No description provided for @slotLengthHelp.
  ///
  /// In en, this message translates to:
  /// **'Applies to new bookings. Existing appointments keep their time.'**
  String get slotLengthHelp;

  /// No description provided for @minutes.
  ///
  /// In en, this message translates to:
  /// **'{count} minutes'**
  String minutes(int count);

  /// No description provided for @howDaysOpen.
  ///
  /// In en, this message translates to:
  /// **'How days open'**
  String get howDaysOpen;

  /// No description provided for @modeWeekly.
  ///
  /// In en, this message translates to:
  /// **'Automatically from the weekly timetable'**
  String get modeWeekly;

  /// No description provided for @modeDaily.
  ///
  /// In en, this message translates to:
  /// **'Only days I open'**
  String get modeDaily;

  /// No description provided for @bookingWindow.
  ///
  /// In en, this message translates to:
  /// **'Patients can book up to … days ahead'**
  String get bookingWindow;

  /// No description provided for @minNotice.
  ///
  /// In en, this message translates to:
  /// **'Minimum notice before a slot (minutes)'**
  String get minNotice;

  /// No description provided for @requireLogin.
  ///
  /// In en, this message translates to:
  /// **'Only patients with an account can book'**
  String get requireLogin;

  /// No description provided for @maxUpcoming.
  ///
  /// In en, this message translates to:
  /// **'Upcoming appointments allowed per patient'**
  String get maxUpcoming;

  /// No description provided for @emailNotifications.
  ///
  /// In en, this message translates to:
  /// **'Email notifications (confirmations, changes, reminders)'**
  String get emailNotifications;

  /// No description provided for @alertEmail.
  ///
  /// In en, this message translates to:
  /// **'Send clinic alerts to (email)'**
  String get alertEmail;

  /// No description provided for @timeZone.
  ///
  /// In en, this message translates to:
  /// **'Clinic time zone'**
  String get timeZone;

  /// No description provided for @patientMessage.
  ///
  /// In en, this message translates to:
  /// **'Message shown to patients after booking'**
  String get patientMessage;

  /// No description provided for @saveSettings.
  ///
  /// In en, this message translates to:
  /// **'Save settings'**
  String get saveSettings;

  /// No description provided for @sendingTo.
  ///
  /// In en, this message translates to:
  /// **'Sending to {to}…'**
  String sendingTo(String to);

  /// No description provided for @testEmailSent.
  ///
  /// In en, this message translates to:
  /// **'Sent to {to}. Check the inbox (and the spam folder).'**
  String testEmailSent(String to);

  /// No description provided for @testEmailFailed.
  ///
  /// In en, this message translates to:
  /// **'Email not sent ({status}): {error}'**
  String testEmailFailed(String status, String error);

  /// No description provided for @testEmailTimeout.
  ///
  /// In en, this message translates to:
  /// **'No answer from the mail service yet. Try again in a minute.'**
  String get testEmailTimeout;

  /// No description provided for @emailCheck.
  ///
  /// In en, this message translates to:
  /// **'Email check'**
  String get emailCheck;

  /// No description provided for @emailCheckHelp.
  ///
  /// In en, this message translates to:
  /// **'Sends a test message to the email you are logged in with, through the clinic mailbox.'**
  String get emailCheckHelp;

  /// No description provided for @sendTestEmail.
  ///
  /// In en, this message translates to:
  /// **'Send test email'**
  String get sendTestEmail;

  /// No description provided for @deleteAccountTitle.
  ///
  /// In en, this message translates to:
  /// **'Delete my account'**
  String get deleteAccountTitle;

  /// No description provided for @deleteAccountIntro.
  ///
  /// In en, this message translates to:
  /// **'Removes your login and your personal details from the clinic system. Upcoming appointments are cancelled.'**
  String get deleteAccountIntro;

  /// No description provided for @deleteAccountButton.
  ///
  /// In en, this message translates to:
  /// **'Delete my account'**
  String get deleteAccountButton;

  /// No description provided for @deleteAccountQuestion.
  ///
  /// In en, this message translates to:
  /// **'Delete your account permanently?'**
  String get deleteAccountQuestion;

  /// No description provided for @deleteAccountDetails.
  ///
  /// In en, this message translates to:
  /// **'• Your upcoming appointments will be cancelled and the clinic will be told.\n• Your name, phone, email and visit reasons are removed from past appointments. The clinic keeps only the date, time and whether the visit took place.\n• Your notifications and login are deleted.\n\nThis cannot be undone. You can create a new account later.'**
  String get deleteAccountDetails;

  /// No description provided for @deleteAccountConfirm.
  ///
  /// In en, this message translates to:
  /// **'Delete account'**
  String get deleteAccountConfirm;

  /// No description provided for @keepAccount.
  ///
  /// In en, this message translates to:
  /// **'Keep my account'**
  String get keepAccount;

  /// No description provided for @accountDeleted.
  ///
  /// In en, this message translates to:
  /// **'Your account has been deleted.'**
  String get accountDeleted;

  /// No description provided for @deleteAccountAdminNote.
  ///
  /// In en, this message translates to:
  /// **'If you are the only admin, make someone else an admin first.'**
  String get deleteAccountAdminNote;
}

class _AppLocalizationsDelegate extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  Future<AppLocalizations> load(Locale locale) {
    return SynchronousFuture<AppLocalizations>(lookupAppLocalizations(locale));
  }

  @override
  bool isSupported(Locale locale) => <String>['en'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'en':
      return AppLocalizationsEn();
  }

  throw FlutterError(
    'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
    'an issue with the localizations generation tool. Please file an issue '
    'on GitHub with a reproducible sample app and the gen-l10n configuration '
    'that was used.',
  );
}
