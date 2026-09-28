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

/// Whole calendar days from [from] to [to], ignoring the time of day.
/// Uses UTC so a daylight-saving change can't make a day 23 hours long.
int calendarDaysBetween(DateTime from, DateTime to) {
  final start = DateTime.utc(from.year, from.month, from.day);
  final end = DateTime.utc(to.year, to.month, to.day);

  return end.difference(start).inDays;
}

/// "Due today", "Due tomorrow", "Due in 5 days" for a bill's next due date.
String formatDueIn(DateTime dueDate) {
  final days = calendarDaysBetween(DateTime.now(), dueDate);

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

const List<String> _monthNames = [
  'January',
  'February',
  'March',
  'April',
  'May',
  'June',
  'July',
  'August',
  'September',
  'October',
  'November',
  'December',
];

const List<String> _weekdayShort = [
  'Mon',
  'Tue',
  'Wed',
  'Thu',
  'Fri',
  'Sat',
  'Sun',
];

/// "September 2026".
String formatMonthYear(DateTime date) {
  return '${_monthNames[date.month - 1]} ${date.year}';
}

/// "28 Sep 2026".
String formatShortDate(DateTime date) {
  return '${date.day} ${_monthNames[date.month - 1].substring(0, 3)} ${date.year}';
}

/// Heading for a day in a transaction list: "Today", "Yesterday",
/// "Mon, 21 Sep", or "Mon, 21 Sep 2025" for other years.
String formatDayHeader(DateTime date, {DateTime? now}) {
  final today = now ?? DateTime.now();
  final day = date;
  final difference = calendarDaysBetween(day, today);

  if (difference == 0) return 'Today';
  if (difference == 1) return 'Yesterday';

  final label =
      '${_weekdayShort[day.weekday - 1]}, ${day.day} ${_monthNames[day.month - 1].substring(0, 3)}';

  return day.year == today.year ? label : '$label ${day.year}';
}
