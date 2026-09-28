import 'package:flutter/material.dart';

import '../database/database_helper.dart';
import '../services/app_sync.dart';
import '../theme/app_colors.dart';
import '../utils/formatters.dart';

/// Asks the user to confirm a delete. Returns true if they confirmed.
Future<bool> confirmDelete(BuildContext context) async {
  final confirmed = await showDialog<bool>(
    context: context,
    builder: (context) {
      return AlertDialog(
        title: const Text('Delete this item?'),
        content: const Text(
          'This action cannot be undone.',
          style: TextStyle(color: AppColors.textSecondary),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            style: TextButton.styleFrom(
              foregroundColor: AppColors.textSecondary,
            ),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(
              foregroundColor: AppColors.danger,
            ),
            child: const Text('Delete'),
          ),
        ],
      );
    },
  );

  return confirmed == true;
}

/// Lets the user change the monthly budget. Returns the new budget, or
/// null if they cancelled.
Future<double?> showEditBudgetDialog(
  BuildContext context,
  double currentBudget,
) async {
  final controller = TextEditingController(
    text: currentBudget.toStringAsFixed(0),
  );

  final newBudget = await showDialog<double>(
    context: context,
    builder: (context) {
      return AlertDialog(
        title: const Text('Monthly budget'),
        content: TextField(
          controller: controller,
          autofocus: true,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          decoration: const InputDecoration(
            prefixText: '₦ ',
            hintText: 'Enter budget',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            style: TextButton.styleFrom(
              foregroundColor: AppColors.textSecondary,
            ),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              final value = parseAmount(controller.text);

              if (value != null) {
                Navigator.pop(context, value);
              }
            },
            child: const Text('Save'),
          ),
        ],
      );
    },
  );

  if (newBudget != null) {
    await DatabaseHelper.saveBudget(newBudget);
    await AppSync.transactionsChanged();
  }

  return newBudget;
}

/// Asks for the user's name and saves it. Returns the new name, or null if
/// they cancelled.
Future<String?> showEditNameDialog(
  BuildContext context,
  String currentName,
) async {
  final controller = TextEditingController(text: currentName);

  final newName = await showDialog<String>(
    context: context,
    builder: (context) {
      return AlertDialog(
        title: const Text('Your name'),
        content: TextField(
          controller: controller,
          autofocus: true,
          textCapitalization: TextCapitalization.words,
          decoration: const InputDecoration(
            hintText: 'What should we call you?',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            style: TextButton.styleFrom(
              foregroundColor: AppColors.textSecondary,
            ),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, controller.text.trim()),
            child: const Text('Save'),
          ),
        ],
      );
    },
  );

  if (newName != null) {
    await DatabaseHelper.setSetting('user_name', newName);
    AppSync.notifyChanged();
  }

  return newName;
}
