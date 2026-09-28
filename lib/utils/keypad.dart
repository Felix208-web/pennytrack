/// Input rules for the on-screen amount keypad.
///
/// The amount is kept as the raw string the user typed (e.g. "2500.5") and
/// only formatted for display, so partial input like "12." is preserved.
class KeypadInput {
  KeypadInput._();

  static const backspace = 'back';
  static const maxWholeDigits = 10;
  static const maxDecimals = 2;

  /// Returns [current] with [key] (a digit, '.', or [backspace]) applied.
  static String apply(String current, String key) {
    if (key == backspace) {
      return current.isEmpty ? '' : current.substring(0, current.length - 1);
    }

    if (key == '.') {
      if (current.contains('.')) return current;

      return current.isEmpty ? '0.' : '$current.';
    }

    final parts = current.split('.');

    if (parts.length == 2) {
      return parts[1].length >= maxDecimals ? current : current + key;
    }

    if (current == '0') return key;

    if (current.length >= maxWholeDigits) return current;

    return current + key;
  }

  /// "2500.5" -> "2,500.5"; empty -> "0".
  static String format(String raw) {
    if (raw.isEmpty) return '0';

    final parts = raw.split('.');
    final whole = parts[0].replaceAllMapped(
      RegExp(r'\B(?=(\d{3})+(?!\d))'),
      (match) => ',',
    );

    return parts.length == 2 ? '$whole.${parts[1]}' : whole;
  }

  /// Turns a stored amount back into keypad text: 2500.0 -> "2500",
  /// 2500.5 -> "2500.5".
  static String fromAmount(double amount) {
    var text = amount.toStringAsFixed(maxDecimals);

    text = text.replaceFirst(RegExp(r'0+$'), '');

    return text.endsWith('.') ? text.substring(0, text.length - 1) : text;
  }
}
