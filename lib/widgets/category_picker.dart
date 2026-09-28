import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../utils/formatters.dart';

/// Row of chips for choosing an expense category.
class CategoryPicker extends StatelessWidget {
  const CategoryPicker({
    super.key,
    required this.selected,
    required this.onChanged,
  });

  final String selected;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: expenseCategories.map((category) {
        final isSelected = category == selected;

        return ChoiceChip(
          selected: isSelected,
          showCheckmark: false,
          onSelected: (_) => onChanged(category),
          avatar: Icon(
            getCategoryIcon(category),
            size: 18,
            color: isSelected ? Colors.black : AppColors.category(category),
          ),
          label: Text(category),
          labelStyle: TextStyle(
            color: isSelected ? Colors.black : AppColors.textPrimary,
            fontWeight: FontWeight.w600,
          ),
        );
      }).toList(),
    );
  }
}

/// Small grey label shown above a form field.
class FieldLabel extends StatelessWidget {
  const FieldLabel(this.text, {super.key});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(
        text,
        style: const TextStyle(
          color: AppColors.textSecondary,
          fontSize: 13,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}
