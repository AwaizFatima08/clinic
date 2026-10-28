// PAYMENTS — extension point, not active yet.
//
// Where it plugs in:
//   * filter 'booking.beforeCreate' ({paymentStatus, extras}, ctx) -> set paymentStatus
//     to 'pending' and store a checkout reference in extras when the clinic charges a fee.
//   * hooks.addAction({name: 'payments.checkout', auth: 'patient', handler}) -> return a
//     checkout URL from the provider (e.g. Stripe, JazzCash, Easypaisa, PayFast).
//   * A provider webhook needs its own HTTPS function (onRequest) exported from index.js;
//     it should verify the provider's signature and then update `payments/{id}` and
//     `appointments/{ref}.paymentStatus` ('paid' | 'failed' | 'refunded').
//   * Collection `payments/{id}` is reserved: {appointmentRef, patientUid, provider,
//     amountMinor, currency, status, externalRef, createdAt, updatedAt}. Clients can read
//     their own payments (see firestore.rules); only functions write.
//
// Keep provider secrets in Firebase secrets (defineSecret), never in this repository.

export const PAYMENT_STATUSES = ['not_required', 'pending', 'paid', 'failed', 'refunded'];

export default function registerPayments(/* { hooks, db, service } */) {
  // Intentionally empty: every appointment is 'not_required' until a provider is added here.
}
