# Drink Water Reminder (Flutter)

Water intake tracker with scheduled daily reminder notifications. UI and flow follow the Figma prototype: Home, Switch cup, History (month and year), Reminder schedule, Settings.

Everything runs on the phone. No backend, no account, no network calls.

## What it does

| Screen | Behaviour |
|---|---|
| Home | Progress ring with animated water level, one-tap "Drink" for the current cup, "Other amount", timeline of today's drinks with Edit/Delete (Undo on delete), next reminder at the top of the timeline. |
| Switch cup | 100, 200, 300, 400, 500, 1000 ml presets plus a custom size. |
| History | Year view (completion % per month) and Month view (per day), Sunday to Saturday week strip with goal-met badges, report: weekly average, monthly average, average completion, drink frequency. |
| Reminder schedule | Add, edit time, toggle, pick weekdays, delete. |
| Settings | Reminder sound, Auto/Manual mode, missed-intake alert, further reminder after goal, unit (ml/fl oz), intake goal with a suggested value, gender and weight. |

### Reminder rules

All decisions live in `lib/domain/services/reminder_planner.dart` and are covered by `test/reminder_planner_test.dart`.

1. Each active reminder gets one weekly OS notification per selected weekday.
2. Once today's goal is reached, the rest of today's reminders are skipped, unless "Further reminder" is on.
3. A reminder is skipped if a drink was logged in the 30 minutes before it.
4. With "Reminder alert" on, a follow-up fires 30 minutes after a reminder if nothing was logged around it.
5. iOS keeps only 64 pending notifications. The planner keeps the soonest 60, regular reminders first. The queue is rebuilt on every app open, every logged drink and at midnight.

Auto mode spreads 4 to 8 reminders across the hours the user actually drinks (learned from the last 14 days). With little history it uses 08:00 to 21:00. Editing any reminder switches to Manual.

Android delivery uses inexact alarms, so a reminder can land a few minutes late. This avoids the "Alarms & reminders" special permission and Play Store review friction.

## Project structure

```
lib/
  main.dart                     startup: storage, notifications, providers
  app.dart                      MaterialApp + startup error screen
  core/                         design tokens, theme, LocalDay, units, time formatting
  domain/models/                IntakeEntry, Reminder/Weekdays, UserSettings, CupPreset
  domain/services/              ReminderPlanner, AutoSchedule, StatsCalculator, HydrationGoal (pure Dart, tested)
  data/                         SQLite schema + repositories, SharedPreferences settings
  infrastructure/notifications/ flutter_local_notifications adapter
  application/                  NotificationSync, AutoScheduleRunner (orchestration)
  state/                        Riverpod controllers
  ui/                           screens and widgets
tool/setup_platforms.dart       one-time Android/iOS native setup
test/                           unit tests
```

## Run it (Windows, Android phone or emulator)

Requires Flutter 3.38.1 or newer and Android Studio.

```powershell
# 1. From the project folder, generate the android/ and ios/ folders
flutter create --platforms=android,ios --org com.yourcompany .

# 2. Apply notification setup (manifest, Gradle, icon, iOS delegate)
dart run tool/setup_platforms.dart

# 3. Install packages and run the tests
flutter pub get
flutter test

# 4. Start an emulator or plug in a phone, then
flutter run
```

Replace `com.yourcompany` with the real reverse domain before the first store upload. It becomes the app's permanent store ID.

iOS builds need a Mac with Xcode. Steps 1 to 3 are the same; then open `ios/Runner.xcworkspace` in Xcode, set the signing team, and run.

## Testing reminders quickly

1. Allow notifications from the banner on Home.
2. Settings > Reminder mode > Manual.
3. Settings > Reminder schedule > Add a time 2 minutes from now.
4. Lock the phone and wait. On Android emulators, inexact delivery can add a few minutes.

## Status

| Part | State |
|---|---|
| All six screens and flows | Implemented |
| Local storage (SQLite + SharedPreferences) | Implemented |
| Scheduled reminders, skip rules, follow-ups, Auto mode | Implemented |
| Unit tests for planner, stats, Auto schedule, goal | Implemented |
| Android/iOS native config | Applied by `tool/setup_platforms.dart` after `flutter create` |
| Language picker | Placeholder (English only, strings ready to extract) |
| Logging a drink straight from the notification | Not built (next phase) |
| App icon and store listing assets | Not built |
| Character illustrations from the prototype | Replaced with original drawn-in-code artwork (glass, droplet mascot) to avoid licensing issues |
