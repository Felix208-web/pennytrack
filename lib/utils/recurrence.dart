/// Returns the due date that follows [current] for a bill of [frequency].
///
/// [anchorDay] is the day of the month the bill was originally due on. It
/// keeps monthly and yearly bills from drifting: a bill due on the 31st is
/// due on Feb 28/29 in February, then back on the 31st in March.
DateTime calculateNextDueDate(
  DateTime current,
  String frequency,
  int anchorDay,
) {
  switch (frequency) {
    case 'Weekly':
      return DateTime(current.year, current.month, current.day + 7);

    case 'Yearly':
      return _clampedDate(current.year + 1, current.month, anchorDay);

    case 'Monthly':
    default:
      return _clampedDate(current.year, current.month + 1, anchorDay);
  }
}

DateTime _clampedDate(int year, int month, int day) {
  // Normalises month overflow (e.g. month 13 -> January of next year).
  final firstOfMonth = DateTime(year, month, 1);
  final lastDay = DateTime(firstOfMonth.year, firstOfMonth.month + 1, 0).day;

  return DateTime(
    firstOfMonth.year,
    firstOfMonth.month,
    day > lastDay ? lastDay : day,
  );
}
