import 'package:flutter_test/flutter_test.dart';

import 'package:pennytrack/utils/formatters.dart';
import 'package:pennytrack/utils/keypad.dart';
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

  group('KeypadInput', () {
    String type(String keys) {
      var text = '';
      for (final key in keys.split('')) {
        text = KeypadInput.apply(text, key == '<' ? KeypadInput.backspace : key);
      }
      return text;
    }

    test('builds a number from digits', () {
      expect(type('2500'), '2500');
    });

    test('replaces a lone leading zero', () {
      expect(type('05'), '5');
      expect(type('00'), '0');
    });

    test('allows one decimal point and at most two decimals', () {
      expect(type('.5'), '0.5');
      expect(type('1.2.3'), '1.23');
      expect(type('1.234'), '1.23');
    });

    test('backspace removes the last character', () {
      expect(type('123<'), '12');
      expect(type('<'), '');
    });

    test('caps whole digits', () {
      expect(type('12345678901'), '1234567890');
    });

    test('formats with separators, keeping partial decimals', () {
      expect(KeypadInput.format(''), '0');
      expect(KeypadInput.format('2500'), '2,500');
      expect(KeypadInput.format('1234567.5'), '1,234,567.5');
      expect(KeypadInput.format('12.'), '12.');
    });

    test('turns stored amounts back into keypad text', () {
      expect(KeypadInput.fromAmount(2500), '2500');
      expect(KeypadInput.fromAmount(2500.5), '2500.5');
      expect(KeypadInput.fromAmount(99.99), '99.99');
    });
  });

  group('dates', () {
    final now = DateTime(2026, 9, 28, 20, 30);

    test('calendarDaysBetween ignores the time of day', () {
      expect(calendarDaysBetween(DateTime(2026, 9, 28, 23), DateTime(2026, 9, 29, 1)), 1);
      expect(calendarDaysBetween(DateTime(2026, 9, 28, 1), DateTime(2026, 9, 28, 23)), 0);
    });

    test('formatDayHeader', () {
      expect(formatDayHeader(DateTime(2026, 9, 28, 8), now: now), 'Today');
      expect(formatDayHeader(DateTime(2026, 9, 27, 23), now: now), 'Yesterday');
      expect(formatDayHeader(DateTime(2026, 9, 21), now: now), 'Mon, 21 Sep');
      expect(formatDayHeader(DateTime(2025, 12, 25), now: now), 'Thu, 25 Dec 2025');
    });

    test('formatMonthYear', () {
      expect(formatMonthYear(DateTime(2026, 9, 1)), 'September 2026');
    });
  });

  group('monthlyEquivalent', () {
    test('converts weekly and yearly bills to a monthly figure', () {
      expect(monthlyEquivalent(12000, 'Monthly'), 12000);
      expect(monthlyEquivalent(1200, 'Weekly'), 5200);
      expect(monthlyEquivalent(120000, 'Yearly'), 10000);
    });
  });
}
