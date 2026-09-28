import 'package:flutter/material.dart';

const List<String> expenseCategories = [
  'Food',
  'Transport',
  'Bills',
  'Shopping',
  'Other',
];

String formatNaira(double amount) {
  final digits = amount.abs().toStringAsFixed(0).replaceAllMapped(
        RegExp(r'\B(?=(\d{3})+(?!\d))'),
        (match) => ',',
      );

  return '${amount.round() < 0 ? '-' : ''}₦$digits';
}

/// Parses a user-entered amount, allowing thousands separators.
/// Returns null unless the amount is a positive number.
double? parseAmount(String text) {
  final value = double.tryParse(text.replaceAll(',', '').trim());

  if (value == null || value <= 0) return null;

  return value;
}

String formatExpenseDate(String dateString) {
  final date = DateTime.parse(dateString);
  final now = DateTime.now();

  if (date.year == now.year &&
      date.month == now.month &&
      date.day == now.day) {
    return 'Today';
  }

  final yesterday = now.subtract(const Duration(days: 1));

  if (date.year == yesterday.year &&
      date.month == yesterday.month &&
      date.day == yesterday.day) {
    return 'Yesterday';
  }

  return '${date.day}/${date.month}/${date.year}';
}

/// "Due today", "Due tomorrow", "Due in 5 days" for a bill's next due date.
String formatDueIn(DateTime dueDate) {
  final today = DateUtils.dateOnly(DateTime.now());
  final days = DateUtils.dateOnly(dueDate).difference(today).inDays;

  if (days <= 0) return 'Due today';
  if (days == 1) return 'Due tomorrow';

  return 'Due in $days days';
}

String greetingForNow() {
  final hour = DateTime.now().hour;

  if (hour < 12) return 'Good morning';
  if (hour < 17) return 'Good afternoon';

  return 'Good evening';
}

IconData getCategoryIcon(String category) {
  switch (category) {
    case 'Food':
      return Icons.restaurant_rounded;
    case 'Transport':
      return Icons.directions_bus_rounded;
    case 'Bills':
      return Icons.receipt_long_rounded;
    case 'Shopping':
      return Icons.shopping_bag_rounded;
    case 'Income':
      return Icons.south_west_rounded;
    default:
      return Icons.more_horiz_rounded;
  }
}
