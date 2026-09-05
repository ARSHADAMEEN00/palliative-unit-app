# Google Play release guide

This guide is for the first Google Play release of Palliative App. The values
below match the Android production configuration in this repository.

## 1. Create the app in Play Console

On the **Create app** screen use:

- App name: **Palliative App**
- Package name: **com.osperb.palliative**
- Default language: **English (United States) – en-US**
- App or game: **App**
- Free or paid: **Free**

Accept the declarations only after reading them, then choose **Create app**.
The package name is permanent after the first uploaded artifact. If Play Console
says it is unavailable, stop before creating the app, choose another ID, update
both `applicationId` and `namespace` in `android/app/build.gradle.kts`, move the
Kotlin activity to the matching package, and rebuild.

## 2. Items already prepared in the project

- Android application ID and namespace are `com.osperb.palliative`.
- The app explicitly targets Android 16 / API 36 and has minimum API 24.
- Version is `1.0.0+1` (`versionName` 1.0.0, `versionCode` 1).
- Release builds use an upload keystore, R8 code shrinking, resource shrinking,
  Dart obfuscation, and native debug symbols.
- Clear-text HTTP and Android backups/device transfers are disabled.
- The login token is stored in encrypted platform storage, with automatic
  migration from the old SharedPreferences value.
- A Privacy & Data Use notice is reachable before and after login.
- External plan/upgrade calls to action are hidden in Android release builds so
  the Play build does not direct users to a non-Play purchase flow.
- The launcher icon source is a 1024 x 1024 opaque PNG at
  `assets/logo/app_icon.png`.

## 3. Owner-supplied items required before review

These cannot be safely invented in source code:

1. Publish a legally reviewed privacy policy at a public HTTPS URL. It must be
   reachable without login, not geofenced, and be an HTML page rather than a
   PDF. Use the in-app Privacy & Data Use text as a technical starting point,
   then add the legal entity name, address, privacy contact, server/service
   providers, retention periods, deletion process, and applicable law.
2. Create a permanent review/demo account with realistic fake data. Never give
   Google a real staff or patient account. Keep the credentials working during
   review and do not require OTP or location restrictions.
3. Prepare a 1024 x 500 feature graphic and at least two phone screenshots.
   Screenshots must contain only synthetic patient and staff data.
4. Confirm the developer profile, public support email, phone, website, and
   organisation verification details in Play Console.
5. Confirm that the production API and database backup/retention controls are
   ready for real health data.
6. Decide and document the account/data deletion process. If the app is treated
   as allowing account creation, Play requires an in-app request path and a
   public web request page; healthcare retention duties can be explained in the
   process but do not remove the requirement to accept requests.

## 4. Store listing copy

Suggested short description:

> Secure care records, visits, medicines and equipment for palliative teams.

Suggested full description:

> Palliative App is a secure care-management workspace for authorised
> palliative-care teams. It helps participating organisations maintain patient
> records, coordinate home visits, document care assessments, manage medicines
> and equipment, record social support, and organise volunteers.
>
> Key features include role-based access, patient registration and history,
> home-visit records, NHC assessment workflows, medicine stock and supply
> records, equipment distribution, printable reports, and unit administration.
>
> Access requires an account issued by a participating organisation. This app
> is intended for authorised care-team workflows and is not a public emergency
> or self-diagnosis service.
>
> This app is not a medical device and does not diagnose, treat, cure or prevent
> any medical condition. Consult a qualified healthcare professional for
> medical advice, diagnosis or treatment.

Choose the **Medical** store category unless the organisation's policy adviser
directs otherwise.

## 5. App content and policy forms

Complete every card under **Policy and programs > App content**:

- Privacy policy: enter the public HTTPS policy URL.
- Ads: select **No** unless advertising is added later.
- App access: select that all or some functionality is restricted and provide
  the demo email, password, and simple English navigation instructions.
- Target audience: this staff tool should normally target adults only; verify
  the answer with the organisation.
- Content rating: complete the questionnaire accurately.
- Data safety: complete from the deployed system, not from assumptions.
- Health apps: declare the features actually present. For the current app,
  **Healthcare Services and Management** and **Medication and Treatment
  Management** apply. Also select **Diseases and Conditions Management** if the
  organisation uses the app to manage condition-specific care. Do not select
  **Medical Device Apps** unless the organisation has determined that the
  software is regulated and can provide the required certification.

### Data safety working inventory

Validate this inventory against the backend, hosting, logs, backups, support
tools, and all contracts before submitting the form:

- Personal info: names, email addresses, user IDs, postal addresses and phone
  numbers for staff, patients, contacts and volunteers.
- Health data: diagnoses/conditions, symptoms, vital signs, medicines,
  assessments, treatment/care notes and related clinical records.
- Photos/files: user-selected medicine or assessment images, signatures and
  generated reports where applicable.
- Financial/admin data: organisation plan, invoice and payment-history records.
- Purposes: app functionality, account management, care/operations management,
  security and compliance.
- Security: data is encrypted in transit; the Android login credential is
  encrypted at rest on the device; Android backup is disabled.
- Audio: Palliative App does not retain microphone recordings, but the device's
  installed speech-recognition provider may process audio. Verify whether that
  provider changes the disclosure required for the intended devices.
- Sharing: the app has no ads or analytics SDK. Determine whether any hosting,
  support, backup or other recipients count as service providers or sharing
  under Google's definitions.
- Deletion: answer only after the organisation has a working request path and
  documented health-record retention rules.

The microphone permission supports user-initiated clinical dictation. Camera or
photo access supports user-selected attachments. Bluetooth supports compatible
audio accessories during dictation. Do not add permissions that are not used.

## 6. Build the upload artifact

The ignored files `android/upload-keystore.jks` and `android/key.properties`
hold the upload key and password. Back up both in a secure password manager or
encrypted organisation vault before uploading the first release. Losing the
upload key requires a Play Console key-reset process.

For future machines, restore both files or create them once with:

```bash
./tool/create_upload_keystore.sh
```

Build from the `oruma-app` directory:

```bash
flutter clean
flutter pub get
flutter analyze
flutter test
flutter build appbundle --release --obfuscate \
  --split-debug-info=build/symbols/android/1.0.0+1
```

Upload:

`build/app/outputs/bundle/release/app-release.aab`

The verified `1.0.0+1` bundle created on 4 September 2026 has SHA-256:

`0087de37c5d5cc2cc1b4eb6d043455613f6d4b103aea0f07a973b0ff6e9af156`

Archive the matching `build/symbols/android/1.0.0+1` directory and
`build/app/outputs/mapping/release/mapping.txt` with the release. Native debug
symbols and the R8 mapping are also embedded as bundle metadata for Play. Keep
the local copies because they are needed to decode production crashes outside
Play Console.

For every update, increment the build number in `pubspec.yaml`, for example
`1.0.1+2`, and use a matching symbol-directory name. Play rejects a reused
version code.

## 7. Upload, test and release

1. Open **Test and release > Testing > Internal testing** and create a release.
2. Accept **Play App Signing** and upload the signed `.aab`.
3. Fix every blocking Play Console message. Warnings should be reviewed rather
   than automatically ignored.
4. Add internal testers and install from the Play opt-in link. Test login,
   logout, API access, role permissions, microphone consent/dictation, camera
   and gallery attachments, PDF generation/printing, the privacy notice, and
   failure behaviour with no network.
5. Promote to closed testing after internal acceptance.
6. Personal developer accounts created after 13 November 2023 must keep at
   least 12 opted-in closed testers continuously enrolled for 14 days, then
   apply for production access. Organisation accounts and older personal
   accounts may not have this gate; follow the Dashboard shown for the account.
7. Create the production release, use a staged rollout, monitor Android vitals
   and crashes, then increase the rollout only after the first cohort is stable.

Do not upload an APK for the store release; upload the Android App Bundle. Do
not re-enable the external upgrade/plan link in the Play release unless Google
Play Billing or an applicable enrolled external-billing program is implemented.
