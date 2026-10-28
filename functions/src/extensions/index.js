// Every extension module exports a default register(context) function.
// Add new modules to this list; they run once when the functions start.
import registerPayments from './payments.js';
import registerPrescriptions from './prescriptions.js';

const EXTENSIONS = [registerPayments, registerPrescriptions];

export function loadExtensions(context) {
  for (const register of EXTENSIONS) register(context);
}
