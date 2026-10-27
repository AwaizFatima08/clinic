import { createServer } from 'node:http';
import { readFile, mkdir } from 'node:fs/promises';
import { dirname, join } from 'node:path';
import { fileURLToPath } from 'node:url';
import { openDb } from './db.js';
import { Clinic, ConflictError, NotFoundError } from './clinic.js';
import { ValidationError } from './slots.js';
import { addDays, isValidDate } from './time.js';

const ROOT = join(dirname(fileURLToPath(import.meta.url)), '..');
const PUBLIC = join(ROOT, 'public');
const COOKIE = 'clinic_admin';
const MAX_BODY = 16 * 1024;

const STATIC = {
  '/': ['index.html', 'text/html; charset=utf-8'],
  '/admin': ['admin.html', 'text/html; charset=utf-8'],
  '/styles.css': ['styles.css', 'text/css; charset=utf-8'],
  '/common.js': ['common.js', 'text/javascript; charset=utf-8'],
  '/app.js': ['app.js', 'text/javascript; charset=utf-8'],
  '/admin.js': ['admin.js', 'text/javascript; charset=utf-8'],
};

class HttpError extends Error {
  constructor(status, message) {
    super(message);
    this.status = status;
  }
}

/** Fixed-window counter per key, e.g. max 5 failed logins per IP per 15 minutes. */
function rateLimiter(max, windowMs) {
  const hits = new Map();
  return {
    blocked(key) {
      const h = hits.get(key);
      if (!h || h.until < Date.now()) return false;
      return h.n >= max;
    },
    hit(key) {
      const h = hits.get(key);
      if (!h || h.until < Date.now()) hits.set(key, { n: 1, until: Date.now() + windowMs });
      else h.n++;
      if (hits.size > 10_000) hits.clear();
    },
  };
}

export function createApp(clinic, { trustProxy = false, secureCookie = false } = {}) {
  const loginFails = rateLimiter(5, 15 * 60 * 1000);
  const bookings = rateLimiter(10, 60 * 60 * 1000);
  const lookups = rateLimiter(30, 15 * 60 * 1000);

  const clientIp = (req) =>
    (trustProxy && String(req.headers['x-forwarded-for'] ?? '').split(',')[0].trim()) || req.socket.remoteAddress || '';

  const cookieToken = (req) => {
    for (const part of String(req.headers.cookie ?? '').split(';')) {
      const [k, ...v] = part.trim().split('=');
      if (k === COOKIE) return v.join('=');
    }
    return null;
  };

  const requireAdmin = (req) => {
    if (!clinic.isValidSession(cookieToken(req))) throw new HttpError(401, 'Please log in');
  };

  const dateParam = (url, name) => {
    const v = url.searchParams.get(name);
    if (!isValidDate(v)) throw new HttpError(400, `Query parameter "${name}" must be a date (YYYY-MM-DD)`);
    return v;
  };

  const sessionCookie = (token, maxAge) =>
    `${COOKIE}=${token}; HttpOnly; SameSite=Strict; Path=/; Max-Age=${maxAge}${secureCookie ? '; Secure' : ''}`;

  async function route(req, res, url, body) {
    const { pathname } = url;
    const m = req.method;

    // ----- public -----
    if (m === 'GET' && pathname === '/api/public/info') {
      const s = clinic.settings();
      return {
        clinic_name: s.clinic_name,
        doctor_name: s.doctor_name,
        slot_minutes: s.slot_minutes,
        timezone: s.timezone,
        instructions: s.instructions,
        today: clinic.today().date,
      };
    }
    if (m === 'GET' && pathname === '/api/public/days') return clinic.publicDays();
    if (m === 'GET' && pathname === '/api/public/slots') return clinic.slots(dateParam(url, 'date')).map(fmtSlot);
    if (m === 'POST' && pathname === '/api/public/book') {
      const ip = clientIp(req);
      if (bookings.blocked(ip)) throw new HttpError(429, 'Too many bookings from this connection. Please try again later.');
      const a = clinic.book(body);
      bookings.hit(ip);
      return a;
    }
    if (m === 'POST' && (pathname === '/api/public/lookup' || pathname === '/api/public/cancel')) {
      const ip = clientIp(req);
      if (lookups.blocked(ip)) throw new HttpError(429, 'Too many attempts. Please try again later.');
      lookups.hit(ip);
      return pathname.endsWith('lookup') ? clinic.lookup(body?.ref, body?.phone) : clinic.cancelByPatient(body?.ref, body?.phone);
    }

    // ----- admin auth -----
    if (m === 'POST' && pathname === '/api/admin/login') {
      const ip = clientIp(req);
      if (loginFails.blocked(ip)) throw new HttpError(429, 'Too many failed attempts. Try again in 15 minutes.');
      if (!clinic.checkPassword(body?.password)) {
        loginFails.hit(ip);
        throw new HttpError(401, 'Wrong password');
      }
      res.setHeader('Set-Cookie', sessionCookie(clinic.createSession(), 12 * 3600));
      return { ok: true };
    }
    if (m === 'POST' && pathname === '/api/admin/logout') {
      clinic.endSession(cookieToken(req));
      res.setHeader('Set-Cookie', sessionCookie('', 0));
      return { ok: true };
    }

    if (!pathname.startsWith('/api/admin/')) return undefined;
    requireAdmin(req);

    // ----- admin -----
    if (m === 'GET' && pathname === '/api/admin/me') return { ok: true, today: clinic.today().date };
    if (m === 'GET' && pathname === '/api/admin/settings') return clinic.settings();
    if (m === 'PUT' && pathname === '/api/admin/settings') return clinic.updateSettings(body);
    if (m === 'GET' && pathname === '/api/admin/weekly') return clinic.weekly().map((d) => d.map(([s, e]) => ({ start: hhmm(s), end: hhmm(e) })));
    if (m === 'PUT' && pathname === '/api/admin/weekly') return clinic.setWeekly(body);
    if (m === 'GET' && pathname === '/api/admin/days') {
      return clinic.adminDays(dateParam(url, 'from'), url.searchParams.get('count') ?? 14);
    }
    const dayMatch = /^\/api\/admin\/days\/(\d{4}-\d{2}-\d{2})$/.exec(pathname);
    if (dayMatch && m === 'PUT') return clinic.setDay(dayMatch[1], body?.intervals);
    if (dayMatch && m === 'DELETE') return clinic.clearDay(dayMatch[1]);
    if (m === 'GET' && pathname === '/api/admin/slots') return clinic.slots(dateParam(url, 'date'), { forAdmin: true }).map(fmtSlot);
    if (m === 'GET' && pathname === '/api/admin/appointments') {
      const from = dateParam(url, 'from');
      const to = url.searchParams.get('to') ? dateParam(url, 'to') : from;
      if (to < from || to > addDays(from, 366)) throw new HttpError(400, 'Date range is too long or reversed');
      return clinic.listAppointments({ from, to, status: url.searchParams.get('status') || undefined });
    }
    if (m === 'POST' && pathname === '/api/admin/appointments') return clinic.book(body, { byAdmin: true });
    const apptMatch = /^\/api\/admin\/appointments\/(\d+)$/.exec(pathname);
    if (apptMatch && m === 'PATCH') return clinic.setStatus(apptMatch[1], body?.status);
    if (m === 'GET' && pathname === '/api/admin/outside-hours') return clinic.appointmentsOutsideHours();
    if (m === 'POST' && pathname === '/api/admin/password') {
      clinic.changePassword(body?.current, body?.next);
      res.setHeader('Set-Cookie', sessionCookie('', 0));
      return { ok: true };
    }
    return undefined;
  }

  return async function handler(req, res) {
    res.setHeader('X-Content-Type-Options', 'nosniff');
    res.setHeader('Referrer-Policy', 'same-origin');
    res.setHeader('X-Frame-Options', 'DENY');
    res.setHeader('Content-Security-Policy', "default-src 'self'; style-src 'self'; script-src 'self'; img-src 'self' data:; frame-ancestors 'none'");
    const url = new URL(req.url, 'http://localhost');

    try {
      if (!url.pathname.startsWith('/api/')) {
        const file = STATIC[url.pathname];
        if (!file || req.method !== 'GET') return send(res, 404, 'text/plain; charset=utf-8', 'Not found');
        res.setHeader('Cache-Control', 'no-cache');
        return send(res, 200, file[1], await readFile(join(PUBLIC, file[0])));
      }

      let body;
      if (req.method === 'POST' || req.method === 'PUT' || req.method === 'PATCH') {
        if (!String(req.headers['content-type'] ?? '').startsWith('application/json')) throw new HttpError(415, 'Send JSON');
        body = await readJson(req);
      }
      const result = await route(req, res, url, body);
      if (result === undefined) throw new HttpError(404, 'Not found');
      res.setHeader('Cache-Control', 'no-store');
      send(res, 200, 'application/json; charset=utf-8', JSON.stringify(result));
    } catch (e) {
      const status =
        e instanceof HttpError ? e.status
        : e instanceof ValidationError ? 400
        : e instanceof NotFoundError ? 404
        : e instanceof ConflictError ? 409
        : /UNIQUE constraint failed: appointments/.test(e?.message ?? '') ? 409
        : 500;
      if (status === 500) console.error(e);
      const message = status === 500 ? 'Something went wrong. Please try again.'
        : status === 409 && !(e instanceof ConflictError) ? 'Sorry, that time slot was just taken. Please choose another.'
        : e.message;
      send(res, status, 'application/json; charset=utf-8', JSON.stringify({ error: message }));
    }
  };
}

function hhmm(m) {
  return `${String(Math.floor(m / 60)).padStart(2, '0')}:${String(m % 60).padStart(2, '0')}`;
}

function fmtSlot(s) {
  return { start: hhmm(s.start), end: hhmm(s.end) };
}

function send(res, status, type, body) {
  res.writeHead(status, { 'Content-Type': type });
  res.end(body);
}

function readJson(req) {
  return new Promise((resolve, reject) => {
    let size = 0;
    const chunks = [];
    req.on('data', (c) => {
      size += c.length;
      if (size > MAX_BODY) {
        reject(new HttpError(413, 'Request too large'));
        req.destroy();
      } else chunks.push(c);
    });
    req.on('end', () => {
      try {
        resolve(chunks.length ? JSON.parse(Buffer.concat(chunks).toString('utf8')) : {});
      } catch {
        reject(new HttpError(400, 'Invalid JSON'));
      }
    });
    req.on('error', reject);
  });
}

// ----- start when run directly -----
if (process.argv[1] === fileURLToPath(import.meta.url)) {
  const dbFile = process.env.DB_FILE ?? join(ROOT, 'data', 'clinic.db');
  await mkdir(dirname(dbFile), { recursive: true });
  const clinic = new Clinic(openDb(dbFile));
  if (process.env.CLINIC_TZ) clinic.updateSettings({ timezone: process.env.CLINIC_TZ });
  const firstPw = clinic.ensureAdminPassword(process.env.ADMIN_PASSWORD);
  if (firstPw && !process.env.ADMIN_PASSWORD) {
    console.log('\n  First run: admin password created ->', firstPw, '\n  (change it in Admin > Settings; it will not be shown again)\n');
  }
  const port = Number(process.env.PORT ?? 3000);
  const host = process.env.HOST ?? '127.0.0.1';
  const app = createApp(clinic, { trustProxy: process.env.TRUST_PROXY === '1', secureCookie: process.env.SECURE_COOKIE === '1' });
  createServer(app).listen(port, host, () => {
    console.log(`Clinic booking:  http://${host}:${port}/`);
    console.log(`Admin panel:     http://${host}:${port}/admin`);
  });
}
