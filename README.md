# PennyTrack

A mobile-first personal finance and expense tracker, built with Flutter. Amounts
are in Naira (₦). Everything is stored on the phone in a local SQLite database —
there are no accounts and nothing is sent to a server.

## Features

- **Welcome flow** — three intro slides and an optional name, shown on first launch
- **Home** — total balance, this month's income and spending, monthly budget
  progress and recent transactions
- **Add (+)** — expenses and income with an on-screen keypad, category and date
- **Stats** — donut chart and breakdown of spending by category, for any month
- **Transactions** — full history grouped by day, with search and filters;
  tap to edit, swipe left to delete
- **Recurring bills** — weekly, monthly or yearly bills recorded automatically
  when due, with reminders 3 days and 1 day before
- **Budget alerts** — notifications at 80% and 100% of the monthly budget
- **Settings** — name, budget, notifications on/off, clear all data

## Project structure

```
lib/
  main.dart        App entry: shows onboarding or the main app
  database/        SQLite schema, migrations and queries
  models/          Expense, Income, RecurringBill
  screens/         One file per page (app_shell.dart holds the bottom nav)
  services/        Notifications and AppSync (keeps screens in sync)
  theme/           Colours and theme
  utils/           Formatting, keypad input and recurrence date maths
  widgets/         Reusable UI pieces
assets/fonts/      Plus Jakarta Sans (SIL Open Font License)
```

## Running the app

1. Install the [Flutter SDK](https://docs.flutter.dev/get-started/install) and
   run `flutter doctor` until it reports no problems for Android.
2. Connect an Android phone with USB debugging enabled, or start an emulator
   from Android Studio's Device Manager.
3. From the project folder:

   ```sh
   flutter pub get
   flutter run
   ```

   While it's running, press `r` to hot reload after a code change.

The app uses SQLite and local notifications, so run it on Android or iOS — the
web build won't work.

## Tests

```sh
flutter test
flutter analyze
```
