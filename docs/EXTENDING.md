# Extending the clinic app

The app is built so new features (payments, prescriptions, SMS/WhatsApp, video links …)
plug in without changing the booking core. Everything server-side lives in `functions/src`.

## The hook bus (`functions/src/hooks.js`)

| API | Use |
|---|---|
| `hooks.on(event, fn)` | React after something happened. `fn` may be async; it is awaited. A failing listener is logged and never undoes the action. |
| `hooks.addFilter(name, fn)` | Change a value the core is about to use: `fn(value, ctx) → value`. |
| `hooks.addAction({ name, auth, handler })` | New server operation, called from the web app with `call('ext:<name>', data)`. `auth` is `public`, `patient` or `admin`. |

### Events

| Event | Payload |
|---|---|
| `appointment.booked` | `{ appointment, by: 'patient' \| 'admin' }` |
| `appointment.cancelled` | `{ appointment, by: 'patient' \| 'admin' }` |
| `appointment.status_changed` | `{ appointment, from, to }` (`completed`, `no_show`, back to `booked`) |
| `appointment.claimed` | `{ appointment, uid }` — guest booking added to an account |
| `appointment.reminder` | `{ appointment, kind: 'r24' \| 'r1' }` |
| `hours.changed` | `{ outsideHours: appointment[] }` |
| `patient.registered` | `{ patient: { uid, name, phone, email } }` |
| `notification.created` | `{ notification, email }` — hook point for SMS / WhatsApp / push |

### Filters

| Filter | Value | Context |
|---|---|---|
| `booking.beforeCreate` | `{ paymentStatus: 'not_required', extras: {} }` | `{ input, uid, byAdmin, settings }` |

## Adding a module

1. Create `functions/src/extensions/<name>.js` exporting `default function register({ db, hooks, service, notify })`.
2. Add it to the list in `functions/src/extensions/index.js`.
3. Add rules for any new collection to `firestore.rules` (clients read only; functions write).
4. Add tests next to the existing ones in `functions/test/`.
5. `npm run test && npm run test:emulator`, then `firebase deploy --only functions,firestore`.

`notify({ audience, uid, appointmentId, kind, msg: { title, body }, email, settings })` sends an
in-app notification (and an email when enabled) — use it rather than writing to
`notifications` yourself.

## Payments (`extensions/payments.js`)

Reserved: collection `payments/{id}` and field `appointments/{ref}.paymentStatus`
(`not_required`, `pending`, `paid`, `failed`, `refunded`).

Typical flow:
1. Filter `booking.beforeCreate` sets `paymentStatus: 'pending'` when the clinic charges a fee.
2. Action `payments.checkout` (auth `patient`) creates a checkout with the provider
   (Stripe, JazzCash, Easypaisa, PayFast …) and returns its URL.
3. An HTTPS function (export it from `index.js`) receives the provider's webhook, verifies the
   signature, updates `payments/{id}` and the appointment, and calls `notify`.
4. Decide what happens to unpaid bookings (e.g. a scheduled function cancels `pending`
   bookings after 30 minutes — use `service.changeStatus(ref, 'cancelled', 'admin')`).

Keep provider keys in Firebase secrets (`defineSecret`), never in the repository.

## Prescriptions (`extensions/prescriptions.js`)

Reserved: collection `prescriptions/{id}` with `{ appointmentRef, patientUid, doctorName,
items: [{ medicine, dose, frequency, duration, notes }], advice, createdAt, updatedAt, pdfPath }`.
Patients can read their own; the admin can read all; only functions write.

Typical flow:
1. Action `prescriptions.save` (auth `admin`) validates and stores a prescription for a
   completed appointment.
2. Optionally render a PDF (e.g. `pdf-lib`) into Cloud Storage and return a signed URL
   through an action.
3. `notify` the patient: "Your prescription is ready".
4. Add a "Prescription" button to the admin appointment row and a section to
   "My appointments" in the web app.

Prescriptions are medical records: keep them out of logs, and review the rules before enabling.

## More notification channels

Listen to `notification.created` (or the appointment events directly) and send through the
provider of your choice (e.g. WhatsApp Business API, SMS gateway). Store the provider key as
a Firebase secret and respect the patient's preferences.
