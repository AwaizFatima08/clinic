# Clinic Schedule — Android app

Native Flutter app for the clinic (Play Store package `org.homilabs.clinicschedule`).
It uses the **same Firebase backend** as the website (`clinic-schedule-homilabs`): live
Firestore reads, and every change through the `api` Cloud Function, so the app and
https://clinic-schedule.homilabs.org always follow the same rules and see the same data.

- **Patients**: create an account / log in / reset password, book a free slot, My
  appointments (upcoming, past, cancel), add a phone booking by reference, notifications.
- **Admins** (role `admin` in `users/{uid}`): appointments (filter, done / missed / cancel /
  restore, book for a patient), daily hours, pick slots on chosen days, weekly timetable,
  users and roles, settings, test email.

## Layout

```
lib/core/       Result/Failure, clinic time zone, slot rules (Dart port of functions/src/core),
                validators, formatting
lib/data/       models, api (callable `api`), repositories, providers (composition root)
lib/features/   auth, booking, my_appointments, notifications, shell, admin
lib/l10n/       app_en.arb → generated AppLocalizations
test/           slot rules (same cases as the server tests), routing, booking notifier
tool/           make-icons.py (launcher + Play icons drawn in code)
```

## Develop

```bash
flutter pub get
flutter analyze            # very_good_analysis, must be clean
flutter test
```

## Release

Signing: `android/key.properties` + `android/upload-keystore.jks` (both gitignored; kept
only in the private local and Google Drive backups). Losing them means asking Google Play
support to reset the upload key.

```bash
flutter build apk --release          # for testing on a phone
flutter build appbundle --release    # for Play Console
cd android && ./gradlew --stop       # free the Gradle daemon afterwards
```

Bump `version:` in `pubspec.yaml` (`x.y.z+build`) before every Play upload.
Play listing icon: `assets/icon/play_store_512.png`.
