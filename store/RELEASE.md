# Releasing Interval Alarm to the App Store

Everything builds on GitHub Actions macOS runners, so no Mac is needed.

- **iOS check** (`.github/workflows/ios-ci.yml`) runs on every PR and push: analyze, unsigned release build, then the app runs in the iPhone simulator with sample alarms to confirm notifications get scheduled and tunes get converted, and captures App Store screenshots to the `ci-screenshots` branch.
- **iOS release** (`.github/workflows/ios-release.yml`) signs the app and uploads it to TestFlight.

## One-time setup

### 1. GitHub secrets

These are the same four values the Task Tracker repo uses, so copy them over. The same API key and certificate key work for every app on the team.

GitHub → praveendhra/interval_alarm_app → Settings → Secrets and variables → Actions → **New repository secret**:

| Secret | Value |
|---|---|
| `APP_STORE_CONNECT_ISSUER_ID` | Issuer ID (App Store Connect → Users and Access → Integrations → App Store Connect API, above the keys list) |
| `APP_STORE_CONNECT_KEY_IDENTIFIER` | the API key's Key ID |
| `APP_STORE_CONNECT_PRIVATE_KEY` | full contents of the `AuthKey_XXXX.p8` file, including the BEGIN/END lines |
| `IOS_CERTIFICATE_PRIVATE_KEY` | full contents of the `ios_cert_key` private key used for Task Tracker |

If you no longer have the `.p8` file, generate a new key on the same page (role **App Manager**); Apple only lets you download it once. Then update the Task Tracker secrets too.

### 2. Create the app in App Store Connect

The release workflow registers the bundle ID `com.pravii.intervalAlarm` on its first run. Apple's API can't create the app record itself, so:

App Store Connect → Apps → **+** → New App:
- Platforms: iOS
- Name: **Interval Alarm: Repeat Timer** (alternatives in [listing.md](listing.md))
- Primary language: English (U.S.)
- Bundle ID: **com.pravii.intervalAlarm** (if it isn't in the list yet, run the release workflow once first; the upload step fails but the bundle ID gets registered)
- SKU: `interval-alarm`
- User access: Full Access

## Shipping a build

1. GitHub → Actions → **iOS release** → Run workflow (or push a tag: `git tag ios-v1.0.0 && git push origin ios-v1.0.0`).
2. After 5–30 minutes the build shows up in App Store Connect → TestFlight. Install it with the TestFlight app on your iPhone and try an alarm.
3. Fill in the version page from [listing.md](listing.md): description, keywords, support and privacy URLs, screenshots from the `ci-screenshots` branch, App Privacy (**Data Not Collected**), age rating, price (Free).
4. Pick the build, then **Add for Review** → **Submit to App Review**.

Each run gets a higher build number automatically (100 + run number). Bump `version:` in `pubspec.yaml` (or pass a version when running the workflow) for each new App Store version.

## How alarms work on iOS

iOS doesn't let apps run code at an exact time in the background, so on iPhone every ring and reminder is a scheduled local notification:

- The tune plays as the notification sound, looped to about 28 seconds for rings and 10 seconds for reminders (iOS caps notification sounds at 30 seconds). Imported tunes are converted automatically; formats iOS can't decode (like OGG) fall back to the default sound.
- iOS allows 64 pending notifications per app. When all alarms fit, they're scheduled as repeating daily/weekly notifications and keep working without opening the app. Denser schedules get the next 64 alerts, topped up every time the app is opened, and the home screen says so.
- Notifications follow the ringer switch and Focus modes, unlike the Android version, which uses the alarm audio stream.
