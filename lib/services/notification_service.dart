import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest.dart' as tz;
import 'package:timezone/timezone.dart' as tz;
import '../database/database_helper.dart';

class NotificationService {
  static final FlutterLocalNotificationsPlugin _notifications =
      FlutterLocalNotificationsPlugin();

  static Future<void> initialize() async {
    tz.initializeTimeZones();

    tz.setLocalLocation(
      tz.getLocation('Africa/Lagos'),
    );

    const androidSettings = AndroidInitializationSettings(
      '@mipmap/ic_launcher',
    );

    const settings = InitializationSettings(
      android: androidSettings,
    );

    await _notifications.initialize(settings);

    await _notifications
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>()
        ?.requestNotificationsPermission();
  }

  static Future<void> showNotification({
    required int id,
    required String title,
    required String body,
  }) async {
    const details = NotificationDetails(
      android: AndroidNotificationDetails(
        'pennytrack_notifications',
        'PennyTrack Notifications',
        channelDescription: 'Notifications from PennyTrack',
        importance: Importance.high,
        priority: Priority.high,
      ),
    );

    await _notifications.show(
      id,
      title,
      body,
      details,
    );
  }

  static Future<void> showBudgetAlert({
  required double spent,
  required double budget,
}) async {
  if (budget <= 0) return;

  final percentage = (spent / budget) * 100;

  if (percentage >= 100) {
    final alreadySent =
        await DatabaseHelper.getBudgetAlertSent('100');

    if (alreadySent) return;

    await showNotification(
      id: 1000,
      title: 'Budget Exceeded',
      body:
          'You have spent ₦${spent.toStringAsFixed(0)} of your ₦${budget.toStringAsFixed(0)} budget.',
    );

    await DatabaseHelper.setBudgetAlertSent('100', true);
  } else if (percentage >= 80) {
    final alreadySent =
        await DatabaseHelper.getBudgetAlertSent('80');

    if (alreadySent) return;

    await showNotification(
      id: 1001,
      title: 'Budget Alert',
      body:
          'You have used ${percentage.toStringAsFixed(0)}% of your monthly budget.',
    );

    await DatabaseHelper.setBudgetAlertSent('80', true);
  }
}

  static Future<void> scheduleBillReminder({
  required int id,
  required String description,
  required double amount,
  required DateTime dueDate,
}) async {
  final reminderDate = dueDate.subtract(
    const Duration(days: 3),
  );

  final scheduledDate = tz.TZDateTime(
    tz.local,
    reminderDate.year,
    reminderDate.month,
    reminderDate.day,
    9,
  );

  if (scheduledDate.isBefore(tz.TZDateTime.now(tz.local))) {
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
  );

  await _notifications.zonedSchedule(
    id,
    'Upcoming Bill',
    '$description of ₦${amount.toStringAsFixed(0)} is due in 3 days.',
    scheduledDate,
    details,
    androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
  );
}

  static Future<void> cancelNotification(int id) async {
    await _notifications.cancel(id);
  }
}