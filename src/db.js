import { DatabaseSync } from 'node:sqlite';

export const DEFAULT_SETTINGS = {
  clinic_name: 'My Online Clinic',
  doctor_name: 'Dr. Your Name',
  slot_minutes: '20',
  timezone: 'Asia/Karachi',
  booking_window_days: '30',
  min_notice_minutes: '60',
  // 'weekly': the weekly timetable opens days automatically.
  // 'daily':  a day is closed until the admin activates it in the calendar.
  schedule_mode: 'weekly',
  instructions: 'You will receive the video-call link on your phone before your appointment.',
};

// Minutes since midnight. Sunday closed; Mon–Sat 10:00–13:00 and 17:00–20:00.
const DEFAULT_WEEKLY = [
  [],
  [[600, 780], [1020, 1200]],
  [[600, 780], [1020, 1200]],
  [[600, 780], [1020, 1200]],
  [[600, 780], [1020, 1200]],
  [[600, 780], [1020, 1200]],
  [[600, 780], [1020, 1200]],
];

export function openDb(file) {
  const db = new DatabaseSync(file);
  db.exec(`
    PRAGMA journal_mode = WAL;
    PRAGMA busy_timeout = 5000;
    PRAGMA foreign_keys = ON;

    CREATE TABLE IF NOT EXISTS settings (
      key   TEXT PRIMARY KEY,
      value TEXT NOT NULL
    );

    CREATE TABLE IF NOT EXISTS weekly_hours (
      weekday   INTEGER PRIMARY KEY CHECK (weekday BETWEEN 0 AND 6),
      intervals TEXT NOT NULL            -- JSON [[startMin, endMin], ...]
    );

    -- Hours set for one specific date; replaces the weekly timetable for that date.
    -- intervals '[]' means closed that day.
    CREATE TABLE IF NOT EXISTS day_overrides (
      date      TEXT PRIMARY KEY,
      intervals TEXT NOT NULL
    );

    CREATE TABLE IF NOT EXISTS appointments (
      id           INTEGER PRIMARY KEY,
      ref          TEXT NOT NULL UNIQUE,
      date         TEXT NOT NULL,
      start_min    INTEGER NOT NULL,
      end_min      INTEGER NOT NULL,
      patient_name TEXT NOT NULL,
      phone        TEXT NOT NULL,
      email        TEXT NOT NULL DEFAULT '',
      reason       TEXT NOT NULL DEFAULT '',
      status       TEXT NOT NULL DEFAULT 'booked'
                   CHECK (status IN ('booked', 'completed', 'no_show', 'cancelled')),
      booked_by    TEXT NOT NULL DEFAULT 'patient',
      created_at   TEXT NOT NULL DEFAULT (datetime('now'))
    );
    CREATE INDEX IF NOT EXISTS appointments_date ON appointments (date, start_min);
    -- Last line of defence against double booking.
    CREATE UNIQUE INDEX IF NOT EXISTS appointments_one_per_start
      ON appointments (date, start_min) WHERE status != 'cancelled';

    CREATE TABLE IF NOT EXISTS sessions (
      token      TEXT PRIMARY KEY,
      expires_at INTEGER NOT NULL
    );
  `);

  const insertSetting = db.prepare('INSERT OR IGNORE INTO settings (key, value) VALUES (?, ?)');
  for (const [k, v] of Object.entries(DEFAULT_SETTINGS)) insertSetting.run(k, v);

  const insertWeekly = db.prepare('INSERT OR IGNORE INTO weekly_hours (weekday, intervals) VALUES (?, ?)');
  DEFAULT_WEEKLY.forEach((iv, day) => insertWeekly.run(day, JSON.stringify(iv)));

  return db;
}
