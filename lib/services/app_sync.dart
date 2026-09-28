import 'package:flutter/foundation.dart';

import '../database/database_helper.dart';
import 'notification_service.dart';

/// Keeps the tabs in sync with the database.
///
/// The tabs stay alive while you switch between them, so instead of each
/// screen refreshing the others, anything that changes data calls one of
/// these methods and every screen listening to [changes] reloads.
class AppSync {
  AppSync._();

  static final ValueNotifier<int> changes = ValueNotifier(0);

  static void notifyChanged() => changes.value++;

  /// Runs once when the app opens.
  static Future<void> startup() async {
    await DatabaseHelper.checkAndResetBudgetAlerts();
    await syncRecurringBills();
  }

  /// Records due recurring bills as expenses, reschedules their reminders,
  /// re-checks the budget and refreshes every screen.
  static Future<void> syncRecurringBills() async {
    await DatabaseHelper.processRecurringBills();

    final bills = await DatabaseHelper.getRecurringBills();

    for (final bill in bills) {
      await NotificationService.scheduleBillReminder(
        id: bill['id'] as int,
        description: bill['description'].toString(),
        amount: (bill['amount'] as num).toDouble(),
        dueDate: DateTime.parse(
          bill['nextDueDate'].toString(),
        ),
      );
    }

    await transactionsChanged();
  }

  /// Call after an expense, income or the budget is added, edited or deleted.
  static Future<void> transactionsChanged() async {
    await NotificationService.checkBudget();
    notifyChanged();
  }
}
