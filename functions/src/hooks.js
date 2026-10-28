// Extension points for the rest of the app and for future modules (payments,
// prescriptions, SMS/WhatsApp/email delivery …). See docs/EXTENDING.md.
//
//   hooks.on(event, fn)            run fn(payload) after something happened
//   hooks.addFilter(name, fn)      let modules change a value: fn(value, ctx) -> value
//   hooks.addAction(spec)          add a callable action: {name, auth, handler} — reached
//                                  from the web app through the `ext` Cloud Function
//
// Listeners run after the database change is committed. A failing listener is
// logged and never undoes the action that triggered it.

export const EVENTS = Object.freeze({
  APPOINTMENT_BOOKED: 'appointment.booked', // {appointment, by: 'patient'|'admin'}
  APPOINTMENT_CANCELLED: 'appointment.cancelled', // {appointment, by: 'patient'|'admin'}
  APPOINTMENT_STATUS: 'appointment.status_changed', // {appointment, from, to}
  APPOINTMENT_CLAIMED: 'appointment.claimed', // {appointment, uid}
  APPOINTMENT_REMINDER: 'appointment.reminder', // {appointment, kind: 'r24'|'r1'}
  HOURS_CHANGED: 'hours.changed', // {outsideHours: appointment[]}
  PATIENT_REGISTERED: 'patient.registered', // {patient}
  USER_ROLE_CHANGED: 'user.role_changed', // {uid, from, to}
  USER_DELETED: 'user.deleted', // {uid, role} — personal data is already removed; extensions clean up theirs
  NOTIFICATION_CREATED: 'notification.created', // {notification} — delivery channels listen here
});

export class HookBus {
  constructor({ logger = console } = {}) {
    this.listeners = new Map();
    this.filters = new Map();
    this.actions = new Map();
    this.logger = logger;
  }

  on(event, fn) {
    if (!this.listeners.has(event)) this.listeners.set(event, []);
    this.listeners.get(event).push(fn);
    return () => this.listeners.set(event, this.listeners.get(event).filter((f) => f !== fn));
  }

  /**
   * Runs every listener and resolves when all have finished (Cloud Functions may
   * stop the instance once a request returns, so callers await this).
   */
  emit(event, payload) {
    const runs = (this.listeners.get(event) ?? []).map((fn) =>
      Promise.resolve()
        .then(() => fn(payload))
        .catch((e) => this.logger.error(`[hook ${event}]`, e)),
    );
    return Promise.all(runs);
  }

  addFilter(name, fn) {
    if (!this.filters.has(name)) this.filters.set(name, []);
    this.filters.get(name).push(fn);
  }

  applyFilters(name, value, ctx) {
    let v = value;
    for (const fn of this.filters.get(name) ?? []) {
      try {
        v = fn(v, ctx);
      } catch (e) {
        this.logger.error(`[filter ${name}]`, e);
      }
    }
    return v;
  }

  /** auth: 'public' | 'patient' | 'admin'. handler({data, auth}) -> JSON-safe value (may be async). */
  addAction({ name, auth = 'admin', handler }) {
    if (!['public', 'patient', 'admin'].includes(auth)) throw new Error(`Bad action auth: ${auth}`);
    if (!/^[a-z][a-zA-Z0-9.]{1,60}$/.test(name)) throw new Error(`Bad action name: ${name}`);
    if (this.actions.has(name)) throw new Error(`Action already registered: ${name}`);
    this.actions.set(name, { name, auth, handler });
  }

  action(name) {
    return this.actions.get(name) ?? null;
  }
}
