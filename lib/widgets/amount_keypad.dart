import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../theme/app_colors.dart';
import '../utils/keypad.dart';

/// 3x4 number pad for entering amounts. Calls [onKey] with a digit, '.',
/// or [KeypadInput.backspace]; long-press backspace calls [onClear].
class AmountKeypad extends StatelessWidget {
  const AmountKeypad({
    super.key,
    required this.onKey,
    required this.onClear,
  });

  final ValueChanged<String> onKey;
  final VoidCallback onClear;

  static const _rows = [
    ['1', '2', '3'],
    ['4', '5', '6'],
    ['7', '8', '9'],
    ['.', '0', KeypadInput.backspace],
  ];

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: _rows.map((row) {
        return Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: Row(
            children: [
              for (var i = 0; i < row.length; i++) ...[
                if (i > 0) const SizedBox(width: 10),
                Expanded(
                  child: _Key(
                    value: row[i],
                    onTap: () {
                      HapticFeedback.selectionClick();
                      onKey(row[i]);
                    },
                    onLongPress: row[i] == KeypadInput.backspace
                        ? () {
                            HapticFeedback.mediumImpact();
                            onClear();
                          }
                        : null,
                  ),
                ),
              ],
            ],
          ),
        );
      }).toList(),
    );
  }
}

class _Key extends StatelessWidget {
  const _Key({
    required this.value,
    required this.onTap,
    this.onLongPress,
  });

  final String value;
  final VoidCallback onTap;
  final VoidCallback? onLongPress;

  @override
  Widget build(BuildContext context) {
    final isBackspace = value == KeypadInput.backspace;

    return Material(
      color: AppColors.surface,
      borderRadius: BorderRadius.circular(18),
      child: InkWell(
        onTap: onTap,
        onLongPress: onLongPress,
        borderRadius: BorderRadius.circular(18),
        child: SizedBox(
          height: 58,
          child: Center(
            child: isBackspace
                ? Semantics(
                    label: 'Delete',
                    child: const Icon(
                      Icons.backspace_outlined,
                      size: 22,
                      color: AppColors.textSecondary,
                    ),
                  )
                : Text(
                    value,
                    style: const TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
          ),
        ),
      ),
    );
  }
}
