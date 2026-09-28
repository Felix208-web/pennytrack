import 'package:flutter_test/flutter_test.dart';

import 'package:pennytrack/utils/formatters.dart';
import 'package:pennytrack/utils/recurrence.dart';

void main() {
  group('formatNaira', () {
    test('adds thousands separators', () {
      expect(formatNaira(0), '₦0');
      expect(formatNaira(950), '₦950');
      expect(formatNaira(1500), '₦1,500');
      expect(formatNaira(1234567), '₦1,234,567');
    });

    test('puts the minus sign before the currency symbol', () {
      expect(formatNaira(-5000), '-₦5,000');
    });
  });

  group('parseAmount', () {
    test('accepts positive numbers, with or without commas', () {
      expect(parseAmount('2500'), 2500);
      expect(parseAmount(' 10,000.50 '), 10000.5);
    });

    test('rejects empty, zero, negative and non-numeric input', () {
      expect(parseAmount(''), isNull);
      expect(parseAmount('0'), isNull);
      expect(parseAmount('-200'), isNull);
      expect(parseAmount('abc'), isNull);
    });
  });

  group('calculateNextDueDate', () {
    test('weekly adds seven days, across month ends', () {
      expect(
        calculateNextDueDate(DateTime(2026, 9, 28), 'Weekly', 28),
        DateTime(2026, 10, 5),
      );
    });

    test('monthly clamps to the last day of short months', () {
      expect(
        calculateNextDueDate(DateTime(2026, 1, 31), 'Monthly', 31),
        DateTime(2026, 2, 28),
      );
      expect(
        calculateNextDueDate(DateTime(2028, 1, 31), 'Monthly', 31),
        DateTime(2028, 2, 29),
      );
    });

    test('monthly returns to the anchor day after a short month', () {
      expect(
        calculateNextDueDate(DateTime(2026, 2, 28), 'Monthly', 31),
        DateTime(2026, 3, 31),
      );
    });

    test('monthly rolls over into the next year', () {
      expect(
        calculateNextDueDate(DateTime(2026, 12, 15), 'Monthly', 15),
        DateTime(2027, 1, 15),
      );
    });

    test('yearly handles 29 February', () {
      expect(
        calculateNextDueDate(DateTime(2028, 2, 29), 'Yearly', 29),
        DateTime(2029, 2, 28),
      );
    });
  });
}
