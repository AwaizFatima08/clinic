// PRESCRIPTIONS — extension point, not active yet.
//
// Where it plugs in:
//   * Collection `prescriptions/{id}` is reserved: {appointmentRef, patientUid, doctorName,
//     items: [{medicine, dose, frequency, duration, notes}], advice, createdAt, updatedAt,
//     pdfPath}. The patient can read their own; only functions write (see firestore.rules).
//   * hooks.addAction({name: 'prescriptions.save', auth: 'admin', handler}) to create or
//     update one after an appointment is completed.
//   * hooks.on(EVENTS.APPOINTMENT_STATUS, ...) with to === 'completed' to prompt the doctor.
//   * Use the notifier ({ notify } returned by registerNotifications) to tell the patient
//     "Your prescription is ready" in-app and by email.
//   * PDF generation can run in the same function (e.g. pdf-lib) and be stored in Cloud
//     Storage; serve it to the patient through a signed URL from an action.
//
// Prescriptions are medical records: keep them out of logs and review access rules
// carefully before enabling.

export default function registerPrescriptions(/* { hooks, db, service, notify } */) {
  // Intentionally empty.
}
