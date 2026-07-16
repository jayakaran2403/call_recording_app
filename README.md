# Employee Call Recording & Location Tracking System

A production-oriented Flutter + native Android (Kotlin) application for
recording business calls, tagging them with GPS location, and preparing
them for backend upload. Built for company-managed devices under HAB
Business Solutions.

---

## 1. Getting the project running

```bash
flutter pub get
flutter run   # Android 12+ (API 31+) device or emulator with telephony
```

Requires the Flutter SDK (stable channel), Android Studio / SDK 35, and a
JDK 17. `android/local.properties` must point `flutter.sdk` at your local
Flutter install — Android Studio creates this automatically on first
open.

The Android `minSdk` is set to **31** (Android 12) to match the target
platform in the spec. Adjust `android/app/build.gradle.kts` if you need
to support older devices, understanding that the call-recording
limitation below gets worse, not better, on older Android versions with
OEM audio restrictions.

---

## 2. Architecture

```
lib/
  core/        constants, Material 3 theme (blue/white corporate palette)
  models/      Employee, RecordingMetadata (mirrors the JSON schema)
  database/    SQLite (sqflite) — employee + recordings tables
  services/    permission, location, storage, upload, native bridge
  repository/  AuthRepository, RecordingRepository (orchestration layer)
  providers/   Riverpod StateNotifiers / Providers (MVVM view-models)
  screens/     Splash, Login, Dashboard, Permissions, Folder selection,
               Recording history, Settings
  widgets/     RecordingTile, StatusCard

android/app/src/main/kotlin/com/hab/callrecorder/
  MainActivity.kt              Registers Flutter <-> native channels
  CallRecordingService.kt      Foreground service, notification, file/folder mgmt
  PhoneStateReceiver.kt        Detects call start/end + phone number
  AudioRecorderManager.kt      MediaRecorder wrapper (see limitation below)
  LocationHelper.kt            Native GPS + Geocoder fallback
  BootReceiver.kt              Restarts service after device reboot
  CallRecordingServiceContext  App Context holder for API 31+ MediaRecorder
```

**Flutter ↔ Native communication** uses three channels (names defined in
`lib/core/constants.dart` and mirrored in `MainActivity.kt`):

| Channel | Type | Purpose |
|---|---|---|
| `com.hab.callrecorder/service` | MethodChannel | start/stop foreground service, folder path push, running-state query |
| `com.hab.callrecorder/recording` | MethodChannel | query native recording-in-progress state |
| `com.hab.callrecorder/call_events` | EventChannel | stream of `call_started` / `call_ended` events from `PhoneStateReceiver` |

Native code owns the actual audio capture lifecycle so recording
continues even when the Flutter engine/UI is not active. `PhoneStateReceiver`
drives `CallRecordingService` directly; Flutter's `RecordingRepository`
listens to the same events (via the event channel) purely to keep the
local SQLite database and UI in sync (GPS capture + DB insert/update,
history list refresh, etc).

---

## 3. IMPORTANT: Call-audio recording platform limitation

**This must be communicated to employees and stakeholders before rollout.**

Since Android 10 (API 29), `MediaRecorder.AudioSource.VOICE_CALL` — the
audio source needed to capture *both* sides of a cellular call — is
restricted to system/privileged apps. Almost all consumer OEM devices
(Samsung, Xiaomi, Pixel, OnePlus, etc.) block or silently mute this
source for third-party apps, regardless of granted permissions. This is
a platform/OEM policy, not a bug in this codebase, and there is **no
universal workaround** for a standard (non-system, non-rooted) app.

`AudioRecorderManager.kt` documents and handles this by:
- Attempting `VOICE_CALL` only on Android 9 and below, where some
  AOSP-based devices still allow it.
- Falling back to `VOICE_COMMUNICATION`, then plain `MIC`, on Android 10+.
- These fallbacks reliably capture the employee's own voice, and the
  other party's voice only when it's audible through the device
  microphone (e.g. speakerphone is on).

**Recommended paths if full dual-channel recording is a hard
requirement:**
1. Enroll the app as a device-owner / system app via MDM (Android
   Enterprise) on company-managed devices — this can unlock privileged
   audio sources on some OEMs, but is not guaranteed across all vendors.
2. Move call recording to the telephony layer instead of on-device
   capture — i.e. record on HAB Dialer's SIP/VoIP backend when calls are
   routed through it, which sidesteps the Android OS restriction
   entirely.
3. Instruct employees to use speakerphone for calls that must be fully
   captured, and set expectations accordingly.

This limitation should be surfaced in onboarding/training material, not
just this README.

---

## 4. Legal note — call recording consent

Recording phone calls may require one-party or two-party consent
depending on jurisdiction. This codebase does not include a consent
announcement; add one (e.g. a short recorded/TTS notice played at call
start) if operating in a two-party-consent region. This is a product/
legal decision, not a technical one, and is intentionally left
configurable rather than hardcoded.

---

## 5. Error handling covered

- Permission denied → explanatory UI + deep link to Android Settings
  (`PermissionsScreen`).
- GPS unavailable / timeout → recording still proceeds without location
  (`LocationService` / `LocationHelper` return null gracefully).
- Geocoder unavailable → falls back to raw lat/lng only.
- Storage unavailable / low → `StorageService` exposes a `formatBytes`/
  usage view in Settings; hook `isStorageLow` into a real StatFs channel
  before production use (currently a documented stub).
- Interrupted recording (call ends abnormally) → `stopRecording()`
  catches `RuntimeException` from `MediaRecorder.stop()` and the service
  checks the resulting file length before trusting it.
- Service killed by Android → `START_STICKY` return value in
  `onStartCommand`; any recording in progress at the moment of kill is
  lost (documented, not silently hidden).
- App restarted → `SettingsNotifier._load()` re-queries native
  (`isServiceRunning`) and permission state on launch.
- Phone reboot → `BootReceiver` restarts the foreground service if
  recording was enabled before shutdown.

---

## 6. Future cloud upload

`UploadService` (`lib/services/upload_service.dart`) already implements
multipart upload (audio + metadata JSON) with retry-count tracking and a
`retryPendingUploads()` sweep you can call from a connectivity listener.
Point `_baseUrl` / `_uploadEndpoint` at the real HAB backend and wire up
authentication headers before enabling automatic uploads.

---

## 7. Known follow-ups before production

- Replace the local-only `AuthRepository.login()` with a real backend
  auth call; local SQLite is currently the offline fallback path.
- Wire a proper release signing config in
  `android/app/build.gradle.kts` (currently uses debug signing so the
  project builds out of the box).
- Add a native StatFs-backed low-storage check
  (`StorageService.isStorageLow` is currently a stub returning `false`).
- Add unit tests for `RecordingRepository` and the SQLite layer
  (`DatabaseHelper`) — architecture is DI-friendly (constructor
  injection throughout) specifically to support this.
