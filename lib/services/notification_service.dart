import 'dart:io' show Platform;

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest.dart' as tz;
import 'package:timezone/timezone.dart' as tz;
import '../database/database_helper.dart';

class NotificationService {
  static final FlutterLocalNotificationsPlugin _notifications =
      FlutterLocalNotificationsPlugin();

  // Notification ids are split into ranges so budget alerts and the two
  // reminders for each bill never overwrite one another.
  static const int _budgetAlert80Id = 1;
  static const int _budgetAlert100Id = 2;
  static const int _billReminder3DaysBase = 100000;
  static const int _billReminder1DayBase = 200000;

  static bool _enabled = false;

  static bool get _isSupportedPlatform =>
      !kIsWeb && (Platform.isAndroid || Platform.isIOS || Platform.isMacOS);

  static Future<void> initialize() async {
    if (!_isSupportedPlatform) return;

    tz.initializeTimeZones();

    tz.setLocalLocation(
      tz.getLocation('Africa/Lagos'),
    );

    const androidSettings = AndroidInitializationSettings(
      '@mipmap/ic_launcher',
    );

    const darwinSettings = DarwinInitializationSettings();

    const settings = InitializationSettings(
      android: androidSettings,
      iOS: darwinSettings,
      macOS: darwinSettings,
    );

    await _notifications.initialize(settings);

    await _notifications
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>()
        ?.requestNotificationsPermission();

    _enabled = true;
  }

  static Future<void> showNotification({
    required int id,
    required String title,
    required String body,
  }) async {
    if (!_enabled) return;

    const details = NotificationDetails(
      android: AndroidNotificationDetails(
        'pennytrack_notifications',
        'PennyTrack Notifications',
        channelDescription: 'Notifications from PennyTrack',
        importance: Importance.high,
        priority: Priority.high,
      ),
      iOS: DarwinNotificationDetails(),
      macOS: DarwinNotificationDetails(),
    );

    await _notifications.show(
      id,
      title,
      body,
      details,
    );
  }

  /// Compares this month's spending with the saved budget and sends the 80%
  /// or 100% alert if it has not been sent yet. When spending drops back
  /// below a threshold (an expense deleted or the budget raised), that alert
  /// is re-armed so it can fire again.
  static Future<void> checkBudget() async {
    final budget = await DatabaseHelper.getSavedBudget();

    if (budget == null || budget <= 0) return;

    final spent = await DatabaseHelper.getTotalExpenses();

    await showBudgetAlert(
      spent: spent,
      budget: budget,
    );
  }

  static Future<void> showBudgetAlert({
    required double spent,
    required double budget,
  }) async {
    if (budget <= 0) return;

    final percentage = (spent / budget) * 100;

    if (percentage < 100) {
      await DatabaseHelper.setBudgetAlertSent('100', false);
    }

    if (percentage < 80) {
      await DatabaseHelper.setBudgetAlertSent('80', false);
      return;
    }

    if (percentage >= 100) {
      final alreadySent = await DatabaseHelper.getBudgetAlertSent('100');

      if (alreadySent) return;

      await showNotification(
        id: _budgetAlert100Id,
        title: 'Budget Exceeded',
        body:
            'You have spent ₦${spent.toStringAsFixed(0)} of your ₦${budget.toStringAsFixed(0)} budget.',
      );

      await DatabaseHelper.setBudgetAlertSent('100', true);
      // Reaching 100% implies 80%, so don't send a stale 80% alert later.
      await DatabaseHelper.setBudgetAlertSent('80', true);
    } else {
      final alreadySent = await DatabaseHelper.getBudgetAlertSent('80');

      if (alreadySent) return;

      await showNotification(
        id: _budgetAlert80Id,
        title: 'Budget Alert',
        body:
            'You have used ${percentage.toStringAsFixed(0)}% of your monthly budget.',
      );

      await DatabaseHelper.setBudgetAlertSent('80', true);
    }
  }

  /// Schedules reminders at 9am three days and one day before [dueDate].
  /// Reminders whose time has already passed are skipped. Scheduling again
  /// for the same bill replaces the previous reminders.
  static Future<void> scheduleBillReminder({
    required int id,
    required String description,
    required double amount,
    required DateTime dueDate,
  }) async {
    if (!_enabled) return;

    await _scheduleReminder(
      id: _billReminder3DaysBase + id,
      body: '$description of ₦${amount.toStringAsFixed(0)} is due in 3 days.',
      reminderDate: dueDate.subtract(const Duration(days: 3)),
    );

    await _scheduleReminder(
      id: _billReminder1DayBase + id,
      body: '$description of ₦${amount.toStringAsFixed(0)} is due tomorrow.',
      reminderDate: dueDate.subtract(const Duration(days: 1)),
    );
  }

  static Future<void> _scheduleReminder({
    required int id,
    required String body,
    required DateTime reminderDate,
  }) async {
    final scheduledDate = tz.TZDateTime(
      tz.local,
      reminderDate.year,
      reminderDate.month,
      reminderDate.day,
      9,
    );

    if (scheduledDate.isBefore(tz.TZDateTime.now(tz.local))) {
      await _notifications.cancel(id);
      return;
    }

    const details = NotificationDetails(
      android: AndroidNotificationDetails(
        'pennytrack_bill_reminders',
        'Bill Reminders',
        channelDescription: 'Reminders for upcoming recurring bills',
        importance: Importance.high,
        priority: Priority.high,
      ),
      iOS: DarwinNotificationDetails(),
      macOS: DarwinNotificationDetails(),
    );

    await _notifications.zonedSchedule(
      id,
      'Upcoming Bill',
      body,
      scheduledDate,
      details,
      androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
    );
  }

  static Future<void> cancelBillReminders(int billId) async {
    if (!_enabled) return;

    await _notifications.cancel(_billReminder3DaysBase + billId);
    await _notifications.cancel(_billReminder1DayBase + billId);
  }
}
