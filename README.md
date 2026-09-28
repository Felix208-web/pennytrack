<div align="center">
  <img src="web/icons/Icon-192.png" width="96" alt="PennyTrack logo" />

  <h1>PennyTrack</h1>

  <p><strong>A mobile-first personal finance and expense tracker.</strong><br />
  Track what you earn and spend, stay within a monthly budget and never miss a bill.</p>

  <p>
    <img alt="Flutter" src="https://img.shields.io/badge/Flutter-02569B?logo=flutter&logoColor=white" />
    <img alt="Dart" src="https://img.shields.io/badge/Dart-0175C2?logo=dart&logoColor=white" />
    <img alt="Platform" src="https://img.shields.io/badge/platform-Android%20%7C%20iOS-FF8A00" />
    <img alt="Storage" src="https://img.shields.io/badge/storage-on--device%20SQLite-0B0B0B" />
  </p>
</div>

---

## About

PennyTrack is built for everyday budgeting in Naira (₦). Everything is stored on
the phone in a local SQLite database — there are no accounts, no sign-up and no
data leaves the device.

The app uses a dark theme with an orange gradient accent and a floating bottom
navigation bar.

## Features

| Area | What it does |
|---|---|
| **Welcome** | Three intro slides and an optional name, shown only on first launch |
| **Home** | Total balance, this month's income and spending, budget progress, quick actions and recent transactions |
| **Add (+)** | Log an expense or income with an on-screen keypad, category and date |
| **Stats** | Animated donut chart and category breakdown for any month, plus income / spent / saved |
| **Transactions** | Full history grouped by day, with search and filters. Tap to edit, swipe left to delete |
| **Recurring bills** | Weekly, monthly or yearly bills. Recorded as expenses automatically when due, with reminders 3 days and 1 day before |
| **Budget alerts** | Notifications when spending reaches 80% and 100% of the monthly budget |
| **Settings** | Name, monthly budget, notifications on/off, clear all data |

## Tech stack

- **[Flutter](https://flutter.dev)** (Material 3), written in Dart
- **[sqflite](https://pub.dev/packages/sqflite)** for on-device storage
- **[flutter_local_notifications](https://pub.dev/packages/flutter_local_notifications)** + **[timezone](https://pub.dev/packages/timezone)** for bill reminders and budget alerts
- **Plus Jakarta Sans** font, bundled in `assets/fonts/`

Charts and illustrations are drawn with plain Flutter widgets, so no extra
packages are needed for them.

## Getting started

### Prerequisites

- [Flutter SDK](https://docs.flutter.dev/get-started/install) (stable channel)
- Android: Android Studio with the Android SDK, and either a phone with
  **USB debugging** enabled or an emulator from **Device Manager**
- iOS (macOS only): Xcode

Run `flutter doctor` and fix anything it reports before continuing.

### Run the app

```sh
git clone https://github.com/Felix208-web/pennytrack.git
cd pennytrack
git checkout dev
flutter pub get
flutter run
```

While the app is running, press **`r`** in the terminal to hot reload after a
code change, or **`R`** to restart it.

> The app relies on SQLite and local notifications, so run it on Android or
> iOS. The web build does not work.

### Tests and linting

```sh
flutter test      # unit tests
flutter analyze   # static analysis
```

## Project structure

```
lib/
├── main.dart          # Entry point: shows the welcome flow or the main app
├── database/          # SQLite schema, migrations and queries
├── models/            # Expense, Income, RecurringBill
├── screens/           # One file per page; app_shell.dart holds the bottom nav
├── services/          # Notifications, and AppSync (keeps screens in sync)
├── theme/             # Colours and the app theme
├── utils/             # Currency/date formatting, keypad input, recurrence maths
└── widgets/           # Reusable UI: cards, buttons, keypad, donut chart, …
assets/fonts/          # Plus Jakarta Sans (SIL Open Font License)
test/                  # Unit tests
```

## How it works

- **Balance** is all-time income minus all-time expenses. The monthly figures
  on Home and Stats cover a single calendar month.
- **Recurring bills** are checked every time the app opens. Any bill that has
  fallen due is recorded as an expense on its due date, including missed
  periods if the app wasn't opened for a while. Monthly bills on the 29th–31st
  fall on the last day of shorter months and then return to their original day.
- **Reminders** are scheduled for 9:00 AM, three days and one day before each
  bill is due.
- **Budget alerts** fire once per month at 80% and 100%, and are re-armed if
  spending drops back below a threshold.
- **Keeping screens in sync:** anything that changes data calls `AppSync`, and
  every open screen reloads.

## Branches and contributing

| Branch | Purpose |
|---|---|
| `main` | Stable, released code |
| `develop` | Integration branch |
| `dev` | Current redesign work in progress |

1. Branch off `dev` for new work (e.g. `feature/export-csv`).
2. Keep commits focused, using [Conventional Commits](https://www.conventionalcommits.org)
   (`feat:`, `fix:`, `chore:`, …).
3. Run `flutter analyze` and `flutter test` before opening a pull request.
4. Open the pull request into `dev`.

## Known limitations

- Notification times use the **Africa/Lagos** timezone, whatever the phone's own timezone.
- Categories are fixed (Food, Transport, Bills, Shopping, Other).
- No backup, export or sync yet. Uninstalling the app deletes its data.
- Designed and tested for Android first. iOS is supported but less tested.

## Roadmap ideas

- Custom categories
- Export to CSV / PDF
- Backup and restore
- Savings goals
- Home-screen widget

## License

The Plus Jakarta Sans font is licensed under the
[SIL Open Font License 1.1](assets/fonts/OFL.txt). A license for the app's own
code has not been chosen yet.
