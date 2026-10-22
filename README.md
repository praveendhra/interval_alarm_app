# Interval Alarm App

A Flutter alarm app that rings at configurable intervals between a start and end time, with pre-ring reminders and customizable tunes.

---

## Features

- **Interval Alarms** — Set a start time, end time, and interval. The alarm rings at every interval point (start and end inclusive).
- **Pre-Ring Reminders** — Configurable reminder (in minutes) before each interval ring. Set per alarm.
- **Separate Tunes** — Choose different tunes for alarm rings vs. reminders. 8 alarm tunes + 4 reminder tunes preloaded.
- **Tune Preview** — Tap play to preview any tune before selecting it.
- **Active Days** — Choose which days of the week the alarm is active.
- **Schedule Preview** — See all ring times calculated live as you configure.
- **Detail View** — Full timeline of all rings with past/next indicators and reminder times.
- **Persistence** — Alarms saved locally via SharedPreferences.
- **Notifications** — Native scheduled notifications via `flutter_local_notifications` for both rings and reminders.
- **Cross Platform** — Works on both Android and iOS.
- **Privacy** — No accounts, analytics or network access. See [PRIVACY.md](PRIVACY.md).

---

## Architecture

```
lib/
├── main.dart                         # App entry point
├── models/
│   └── alarm_model.dart              # IntervalAlarm, AlarmTune, PreloadedTunes
├── providers/
│   └── alarm_provider.dart           # State management (ChangeNotifier + Provider)
├── screens/
│   ├── home_screen.dart              # Main alarm list with quick stats
│   ├── create_alarm_screen.dart      # Create/edit alarm form
│   └── alarm_detail_screen.dart      # Alarm detail with ring timeline
├── services/
│   ├── notification_service.dart     # Schedule/cancel local notifications
│   ├── storage_service.dart          # SharedPreferences persistence
│   └── audio_service.dart            # Tune preview playback
├── utils/
│   ├── theme.dart                    # App theme, colors, typography
│   └── helpers.dart                  # Time formatting utilities
└── widgets/
    ├── alarm_card.dart               # Alarm list card widget
    ├── empty_state.dart              # No-alarms empty state
    └── tune_picker.dart              # Tune selection widget
```

---

## How It Works

### Interval Logic
Given `startTime`, `endTime`, and `intervalMinutes`:
1. First ring at `startTime`
2. Next ring at `startTime + interval`
3. Continue until `endTime`
4. `endTime` is always included as the final ring

**Example:** Start 8:00 AM, End 10:00 AM, Interval 30 min
→ Rings at: 8:00, 8:30, 9:00, 9:30, 10:00 (5 rings)

### Reminders
If `reminderMinutesBefore = 5`, a separate reminder notification fires 5 minutes before each ring:
→ Reminders at: 7:55, 8:25, 8:55, 9:25, 9:55

---

## Setup

### Prerequisites
- Flutter SDK >= 3.1.0
- Android Studio / Xcode

### Install
```bash
flutter pub get
```

### Add Tune Assets
Place `.mp3` files in `assets/tunes/` matching the IDs in `PreloadedTunes`:
- `gentle_chime.mp3`, `morning_bird.mp3`, `digital_pulse.mp3`
- `ocean_wave.mp3`, `zen_bell.mp3`, `classic_alarm.mp3`
- `soft_marimba.mp3`, `electric_buzz.mp3`
- `soft_ping.mp3`, `whisper_bell.mp3`, `subtle_knock.mp3`, `light_tap.mp3`

> You can source royalty-free alarm sounds from sites like freesound.org or pixabay.com/sound-effects.

### Android Setup
Add the permissions from `android/AndroidManifest_permissions.xml` into your actual `AndroidManifest.xml`.

### iOS
iOS builds run on GitHub Actions (no Mac needed). See [`store/RELEASE.md`](store/RELEASE.md) for App Store setup and releases, and [`store/listing.md`](store/listing.md) for the store listing. On iPhone, rings and reminders are scheduled local notifications that play the chosen tune (details in RELEASE.md).

### Run
```bash
flutter run
```

---

## Customization

### Adding More Tunes
Edit `PreloadedTunes` in `lib/models/alarm_model.dart` — add entries to `alarmTunes` or `reminderTunes` and drop the corresponding `.mp3` in `assets/tunes/`.

### Changing Theme
Edit `lib/utils/theme.dart` — all colors, gradients, and typography are centralized there.

---

## Tech Stack

| Layer            | Tool                          |
|------------------|-------------------------------|
| Framework        | Flutter 3.x                   |
| State Management | Provider                      |
| Notifications    | flutter_local_notifications   |
| Audio            | audioplayers                  |
| Persistence      | SharedPreferences             |
| Typography       | Google Fonts (Space Grotesk, Outfit, Space Mono) |
