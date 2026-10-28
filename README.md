# Clinic Schedule

Online appointment booking for a single-doctor clinic: **https://clinic-schedule.homilabs.org**

- **Patients** create an account (or book as a guest if the clinic allows it), pick a day
  and a free slot, and see upcoming and past appointments with in-app and email notifications.
- **The admin** sets the slot length, the weekly timetable, hours per day, or **only selected
  slots on selected days**, and manages appointments and patients.

## Architecture

| Part | Where | What |
|---|---|---|
| Web pages | Hostinger, `public_html/clinic-schedule` | Static files built from `web/src` into `web/dist` |
| Database | Firestore `(default)`, asia-south1 (Mumbai) | Settings, days, appointments, patients, notifications |
| Login | Firebase Auth, email + password | Patients and the admin |
| Server logic | Cloud Functions (asia-south1) | Booking, cancelling, hours, notifications, email, reminders |

Firebase project: `clinic-schedule-homilabs` (account homilabs.smc@gmail.com; the Firebase CLI
uses that account in this folder only).

Clients only **read** Firestore (see `firestore.rules`). Every change goes through the `api`
Cloud Function, which checks the rules and runs bookings in a transaction, so a slot can never
be booked twice.

### Firestore collections

| Collection | Readable by | Content |
|---|---|---|
| `settings/clinic` | everyone | clinic name, slot length, booking window … |
| `settings/private`, `settings/weekly` | admin | alert email; weekly timetable |
| `days/{date}` | everyone | open slots and taken times for that date (no patient data) |
| `dayOverrides/{date}` | admin | hours or picked slots set for that date |
| `appointments/{ref}` | admin, the patient | one appointment; the document id is the booking reference |
| `patients/{uid}` | admin, the patient | name, phone, email |
| `notifications/{id}` | the recipient | in-app notifications |
| `mail/{id}` | nobody (functions only) | email outbox |
| `payments`, `prescriptions` | admin, the patient | reserved for extensions |

## Admin features

- **Slot length** 5–240 minutes. Existing appointments keep their times.
- **Weekly timetable**: several time ranges per weekday.
- **Daily hours**: per date — edit hours, pick slots, close, or go back to the weekly timetable.
- **Pick slots**: choose a date range and weekdays, tick exact times, apply — only those slots
  open on those days.
- **How days open**: automatically from the weekly timetable, or only days the admin opens.
- **Booking rules**: booking window, minimum notice, login required or not, upcoming
  appointments per patient.
- **Appointments**: done / missed / cancel / restore, book for a patient (phone bookings).
- **Patients**: list, search, appointment history.
- Hours changes that leave bookings outside the hours are shown to the admin and the
  patients are notified. Nothing is cancelled automatically.

## Notifications

| Event | Patient (in-app + email) | Admin (in-app + alert email) |
|---|---|---|
| Account created | Welcome | New patient |
| Booking | Confirmation with reference | New booking |
| Patient cancels | Cancellation | Patient cancelled |
| Clinic cancels / marks done / missed / restores | ✔ | |
| Hours change affects a booking | "may need to change" | summary |
| 24 h and 1 h before | Reminder | |

Guests get emails only (they have no inbox). Email goes out through an SMTP mailbox
(`clinic@homilabs.org` on Hostinger). Until the password is set, emails are marked `skipped`.

## Develop

```bash
npm install && npm --prefix functions install
npm test                  # unit tests (scheduling rules)
npm run test:emulator     # booking service + security rules on the Firestore emulator (Java 21)
npm run build             # web/dist
```

Run everything locally: start `scripts/dev-emulators.sh`, serve `web/dist` on
http://localhost:5180 (`python3 -m http.server 5180 --directory web/dist`). Pages on localhost
use the emulators automatically.

## Deploy

1. Functions config (gitignored): copy `functions/.env.example` to
   `functions/.env.clinic-schedule-homilabs` and fill it in.
2. SMTP password (Firebase secret): `firebase functions:secrets:set SMTP_PASSWORD`.
3. `npm run deploy:firebase` — rules, indexes and functions (needs the Blaze plan).
4. `npm run deploy:web` — build and upload to Hostinger over SSH.

First admin login: create an account on the patient page with an email listed in
`ADMIN_EMAILS`, then log in at `/admin.html`. Emails are not verified, so the first account
that claims admin is locked in (`settings/private.adminUids`); to hand admin over to a new
account, remove the old uid there in the Firebase console. Admin › Settings › “Send test email”
checks the mailbox.

## Extending

Payments, prescriptions and other channels plug in through hooks — see
[docs/EXTENDING.md](docs/EXTENDING.md).

## Backup

```bash
bash scripts/backup.sh
```

Code: local copy, Google Drive and GitHub (public — no secrets or patient data in git).
Patient data lives in Firestore; turn on Firestore backups in the Firebase console
(Firestore → Disaster recovery) once the project is on the Blaze plan.
