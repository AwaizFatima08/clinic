// Firebase setup shared by the patient page and the admin panel.
import { initializeApp } from 'firebase/app';
import { connectAuthEmulator, getAuth } from 'firebase/auth';
import { connectFirestoreEmulator, getFirestore } from 'firebase/firestore';
import { connectFunctionsEmulator, getFunctions, httpsCallable } from 'firebase/functions';
import { FUNCTIONS_REGION, firebaseConfig } from './firebase-config.js';

export const app = initializeApp(firebaseConfig);
export const auth = getAuth(app);
export const db = getFirestore(app);
const functions = getFunctions(app, FUNCTIONS_REGION);

// Local development: pages served from localhost talk to the Firebase emulators
// (ports from firebase.json). Never true on clinic-schedule.homilabs.org.
if (['localhost', '127.0.0.1'].includes(location.hostname)) {
  connectAuthEmulator(auth, 'http://127.0.0.1:9197', { disableWarnings: true });
  connectFirestoreEmulator(db, '127.0.0.1', 8187);
  connectFunctionsEmulator(functions, '127.0.0.1', 5107);
}

const apiFn = httpsCallable(functions, 'api');

/** Calls one operation of the `api` Cloud Function. Errors carry a readable message. */
export async function call(op, data = {}) {
  try {
    return (await apiFn({ op, data })).data;
  } catch (e) {
    const err = new Error(friendlyError(e));
    err.code = e.code;
    throw err;
  }
}

const AUTH_MESSAGES = {
  'auth/invalid-credential': 'Wrong email or password.',
  'auth/wrong-password': 'Wrong email or password.',
  'auth/user-not-found': 'Wrong email or password.',
  'auth/email-already-in-use': 'An account with this email already exists. Please log in.',
  'auth/weak-password': 'Please choose a password of at least 8 characters.',
  'auth/invalid-email': 'Please enter a valid email address.',
  'auth/too-many-requests': 'Too many attempts. Please wait a few minutes and try again.',
  'auth/network-request-failed': 'No connection. Please check your internet and try again.',
  'permission-denied': 'You do not have access to this.',
  unavailable: 'No connection. Please check your internet and try again.',
};

export function friendlyError(e) {
  if (AUTH_MESSAGES[e?.code]) return AUTH_MESSAGES[e.code];
  if (e?.code?.startsWith?.('functions/') && e.message) return e.message;
  return e?.message || 'Something went wrong. Please try again.';
}
