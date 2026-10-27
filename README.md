# Clinic Scheduler

Appointment booking for a single-doctor online clinic. Patients pick a free slot on a
day that suits them; the admin sets the slot length and the opening hours, day by day.

No third-party packages: Node.js 22.13+ with its built-in HTTP server and SQLite.

## Run

```bash
npm start
```

- Patient page: http://127.0.0.1:3000/
- Admin panel: http://127.0.0.1:3000/admin

On the first run the server creates an admin password and prints it once to the console.
Change it under **Admin › Settings**. To choose it yourself, start with `ADMIN_PASSWORD=...`.

| Variable | Default | Meaning |
|---|---|---|
| `PORT` | `3000` | HTTP port |
| `HOST` | `127.0.0.1` | Use `0.0.0.0` to serve on the network |
| `DB_FILE` | `data/clinic.db` | SQLite database (patient data — keep private) |
| `ADMIN_PASSWORD` | random | First-run admin password only |
| `CLINIC_TZ` | — | Overrides the clinic time zone setting at start-up |
| `TRUST_PROXY` | off | `1` behind a reverse proxy (uses `X-Forwarded-For` for rate limits) |
| `SECURE_COOKIE` | off | `1` when served over HTTPS |

## What the admin can do

- **Slot length**: 5–240 minutes (Settings). New bookings use the new length; existing
  appointments keep their times and still block any overlapping slot.
- **Weekly timetable**: one or more time ranges per weekday (e.g. 10:00–13:00 and
  17:00–20:00); no ranges = closed.
- **Daily hours**: for any date, change the hours, close the day, or go back to the
  weekly timetable.
- **How days open** (Settings):
  - *Automatically from the weekly timetable*: days open on their own; you only change exceptions.
  - *Only days I activate*: every day is closed until you press **Activate** in Daily hours
    (it fills in the weekly hours, which you can adjust).
- **Booking rules**: how many days ahead patients can book and the minimum notice before a slot.
- **Appointments**: list by date range and status, mark done / no-show / cancelled, and book on a
  patient's behalf (phone bookings; ignores minimum notice).
- If an hours change leaves booked appointments outside opening hours, the admin panel lists them
  so the patients can be contacted. Bookings are never cancelled automatically.

## Patients

- Choose a day → a free time → enter name, phone (required), email and reason (optional).
- They receive a 6-character booking reference. With the reference and phone number they
  can view or cancel the appointment under **My appointment**.
- One booking per phone number per day. All times are shown in clinic time.

## Safety

- Double booking is prevented by an `IMMEDIATE` transaction plus a unique index.
- Admin password stored as a scrypt hash; sessions in an HttpOnly, SameSite=Strict cookie, 12 h.
- Rate limits: 5 failed logins / 15 min, 10 bookings / hour, 30 lookups / 15 min per IP.
- Strict Content-Security-Policy; all user text is inserted as text, never as HTML.

## Tests

```bash
npm test
```

## Backup

```bash
bash scripts/backup.sh
```

Three layers: local (`/mnt/storage/project_backups/clinic_backup`), Google Drive and GitHub.
The database snapshot goes only to the two private layers. `data/` is gitignored because the
GitHub repo is public.

## Layout

```
src/time.js     date/time helpers (clinic time zone)
src/slots.js    pure slot logic
src/db.js       schema and defaults
src/clinic.js   booking rules, hours, admin auth
src/server.js   HTTP server and JSON API
public/         patient page (index.html, app.js) and admin panel (admin.html, admin.js)
test/           node:test unit tests
```
