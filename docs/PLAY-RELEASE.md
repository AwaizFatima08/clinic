# Google Play release checklist — Clinic Schedule

App: **Clinic Schedule**, package `org.homilabs.clinicschedule`, Flutter app in `app/`.
Backend: Firebase project `clinic-schedule-homilabs` (region asia-south1). Website and
policy pages: https://clinic-schedule.homilabs.org.

Work top to bottom. Items marked **(Homi)** need the Play Console or a decision; the rest
is done in this repo.

---

## 0. Before the first upload

- [ ] **Deploy the backend** with the account-deletion ops (`deleteMyAccount`, `deleteUser`) —
      the app's "Delete my account" button calls them:
      `firebase deploy --only functions,firestore` (from the repo root). Test once on a test
      account: book, delete, check the slot is free and the admin got "Patient cancelled".
- [ ] **(Homi) Publish the two policy pages** — drafts are in `web/src/privacy.html` and
      `web/src/delete-account.html`. They are *not* deployed and not linked yet. To publish:
      add both to the copy list in `web/build.mjs`, add footer links in `web/src/index.html`
      (e.g. `Privacy · Delete account`), then `npm run deploy:web`. Play needs both URLs to be
      live before the app is reviewed:
      - Privacy policy: `https://clinic-schedule.homilabs.org/privacy.html`
      - Account deletion: `https://clinic-schedule.homilabs.org/delete-account.html`
- [ ] **(Homi) Make sure `support@clinic.homilabs.org` exists and is read.** Both pages and
      the store listing use it; deletion requests by email must be handled within 7 days
      (Users tab → user → *Delete this account*).
- [ ] **(Homi) Confirm the wording** "built and run by HomiLabs for that clinic" in
      privacy.html, and add the clinic's / doctor's name if you want it shown.
- [ ] Add a **Privacy policy** link inside the app (optional but recommended; Play only
      requires it in the listing). Not done yet.

## 1. Build the bundle

Heavy-job rules apply (`~/.claude/heavy-jobs.md`): `free -h` ≥ 4 GiB available, no
emulator or other build running.

1. Bump the version in `app/pubspec.yaml` **before every upload**: `version: X.Y.Z+N`.
   `N` (versionCode) must be higher than any bundle already uploaded to *any* track —
   Play rejects a reused code. Current: `0.1.0+1`.
2. Build:
   ```bash
   cd app && flutter build appbundle --release
   ```
   Output: `app/build/app/outputs/bundle/release/app-release.aab`. Copy it to
   `release/clinic-schedule-<version>.aab` (gitignored, excluded from backups).
3. Then `cd android && ./gradlew --stop`.
4. **Signing:** release builds use `app/android/key.properties` → `upload-keystore.jks`
   (alias `upload`). Both are gitignored. If `key.properties` is missing, Gradle silently
   signs with the *debug* key and Play rejects the upload.
   - **(Homi) Back up `upload-keystore.jks` and `key.properties` somewhere safe outside this
     machine** (password manager / encrypted drive). The project backup copies them, but a
     second copy elsewhere is worth it. With Play App Signing (default) a lost upload key can
     be reset through Play support, but it takes days.

## 2. Play Console setup (Homi)

### Create the app
- App name: **Clinic Schedule**, default language English (en-US), **App**, **Free**.
- Accept the Developer Program Policies and US export laws declarations.
- Play App Signing: keep the default (Google manages the app signing key; you upload with the
  upload key above).

### App content (Policy → App content)

**Privacy policy** — `https://clinic-schedule.homilabs.org/privacy.html`

**Ads** — No, the app contains no ads.

**App access** — *All or some functionality is restricted* (login required). Give the
reviewer a working **test patient account** (email + password) created for review, plus a
note: "Log in, open Book to see open times, My appointments to see bookings and Delete my
account." Make sure the clinic has open slots on the review days, or the reviewer sees
an empty calendar. Do not give an admin account.

**Content rating** — fill the IARC questionnaire with category *Utility, Productivity,
Communication or Other*. Answer **No** to violence, sexuality, bad language, controlled
substances and gambling, and **No** to "users can interact or exchange content" (patients
cannot message each other; the clinic only sends booking notices). Expected rating:
Everyone / PEGI 3.

**Target audience and content** — age groups **18 and over** only. Answer that the app is
not designed for children. (Choosing under-13 groups pulls in the Families policy.)

**News app** — No.

**COVID-19 contact tracing / status** — No.

**Data safety** — see section 3.

**Government app** — No.

**Financial features** — None.

**Health apps** declaration (Policy → App content → Health apps) — tick
**"Medical — appointment booking / clinic management"** (wording varies; pick the
appointment/scheduling or "healthcare services and management" option). Do **not** tick
anything about diagnosis, treatment, medical devices, or health research. The app does not
give medical advice; it only books times with a doctor. Keep the store description factual
(no health claims) so it does not trigger the medical-device questions.

**Account deletion** (inside Data safety) — app lets users create accounts: **Yes**.
Deletion URL: `https://clinic-schedule.homilabs.org/delete-account.html`.
In-app path: *My appointments → Delete my account*.

## 3. Data safety answers

What the app really does (checked against the code on 28 Oct 2026): no analytics, no
crash reporting, no ads SDK, only the `INTERNET` permission; Firebase Auth, Firestore and
Cloud Functions; email via the clinic mailbox (Hostinger SMTP) from the server.

**Overview**
- Does your app collect or share any of the required user data types? **Yes**
- Is all user data encrypted in transit? **Yes** (HTTPS / Firebase TLS)
- Do you provide a way for users to request that their data be deleted? **Yes**
  (in-app + the deletion URL)

**Data types — all "Collected", none "Shared"** (Google/Firebase and Hostinger act as
service providers, which Play does not count as sharing). For each: *not* processed
ephemerally, collection **required** unless noted, purposes as listed.

| Play category → type | What it is in this app | Required? | Purposes |
|---|---|---|---|
| Personal info → **Name** | profile name, name on bookings | Required | App functionality, Account management |
| Personal info → **Email address** | login + confirmations/reminders | Required | App functionality, Account management |
| Personal info → **Phone number** | profile phone, on bookings | Required | App functionality, Account management |
| Personal info → **User IDs** | Firebase Auth uid | Required | App functionality, Account management |
| Health and fitness → **Health info** | the optional "reason for visit" text | **Optional** | App functionality |
| App activity → **Other user-generated content**? | — | — | Not needed: the reason text is already declared as health info |
| App info and performance | none collected | — | — |
| Device or other IDs | none (Firebase Installations/Analytics not used) | — | — |
| Location, Contacts, Photos, Files, Messages, Financial info, Web browsing | none | — | — |

Appointment date/time/status has no own Play category; it is covered by the account and
health-info answers above. Do not tick "Fraud prevention, security" for the IP address —
it is only held in memory for rate limiting and never stored.

**If you later add** Firebase Analytics / Crashlytics, push notifications (FCM token =
Device ID), payments or prescriptions, update this form *before* releasing that version.

## 4. Store listing (Main store listing)

- **App name:** Clinic Schedule (max 30 chars)
- **Short description** (max 80): e.g. "Book, view and cancel your clinic appointments
  online."
- **Full description:** what patients can do (see open times, book, cancel, reminders by
  email and in the app, add a booking made by phone, delete account). No medical claims.
- **App icon:** `app/assets/icon/play_store_512.png` (512×512 PNG, ready).
- **Feature graphic:** 1024×500 PNG/JPG — **still needed**. Can be made on homidev
  (`image-zimage-basic`, commercial OK) or as a simple brand-colour graphic in code; ask
  before generating.
- **Phone screenshots:** at least 2 (recommend 4–6), 16:9 or 9:16, min 320 px, max
  3840 px — **still needed**. Suggested: Book (calendar with open slots), slot picked →
  confirm, booked confirmation, My appointments, notifications. Take them on a real phone or
  the emulator with seeded data (`scripts/seed-emulator.sh`), never with real patient data.
- **Tablet screenshots** (7" and 10"): optional, but the app has a tablet layout
  (navigation rail) — the Tab S9 is attached for this.
- **App category:** Medical (or Health & Fitness). **Tags:** appointments, clinic.
- **Contact details:** email `support@clinic.homilabs.org`; website
  `https://clinic-schedule.homilabs.org`.

## 5. Release — internal testing first

1. **Testing → Internal testing → Create new release.** Upload the `.aab`, release name =
   pubspec version, short release notes.
2. Add testers (an email list: Homi, the doctor, 1–2 patients). Share the opt-in link.
3. Install from Play on a real phone; check: sign up, book, cancel, notification bell,
   reminder emails, delete account, admin login and tabs on the Tab S9.
4. Read the **pre-launch report** (Play runs the app on test devices; login screens may limit
   it).
5. **New personal developer accounts** (created after Nov 2023) must run a **closed test
   with at least 12 testers for 14 continuous days** before *Production* is unlocked. If
   the HomiLabs Play account is a personal account, plan that time; an organisation account
   is exempt.
6. Then **Production → Create release** (start with a staged rollout, e.g. 20 %), countries:
   Pakistan (add others only if the clinic serves them).

## 6. Every later release

- [ ] Bump `version:` in `app/pubspec.yaml` (`+N` always up).
- [ ] `flutter analyze` clean, `flutter test`, functions `npm test` and
      `npm run test:emulator` (needs Java 21: `JAVA_HOME=~/tools/jdk-21`).
- [ ] Deploy functions first if the app needs new ops.
- [ ] If the app now collects anything new → update Data safety and `privacy.html` first.
- [ ] If any homidev sound/music was added → "Powered by Stability AI" on the About screen or
      store description; run `~/ai-inbox/_tools/release-check.sh <repo>` (FAIL = do not build).
- [ ] Build the bundle (section 1), upload to internal testing, then promote.
