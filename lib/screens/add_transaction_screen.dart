import 'package:flutter/material.dart';

import '../database/database_helper.dart';
import '../models/expense.dart';
import '../models/income.dart';
import '../services/app_sync.dart';
import '../theme/app_colors.dart';
import '../utils/formatters.dart';
import '../utils/keypad.dart';
import '../widgets/amount_keypad.dart';
import '../widgets/category_picker.dart';
import '../widgets/dialogs.dart';
import '../widgets/gradient_button.dart';

enum TransactionType { expense, income }

/// Adds or edits an expense or income, with a big amount display and an
/// on-screen keypad.
class AddTransactionScreen extends StatefulWidget {
  const AddTransactionScreen({
    super.key,
    this.type = TransactionType.expense,
    this.transaction,
  });

  final TransactionType type;

  /// The expense or income row being edited, or null to add a new one.
  final Map<String, dynamic>? transaction;

  @override
  State<AddTransactionScreen> createState() => _AddTransactionScreenState();
}

class _AddTransactionScreenState extends State<AddTransactionScreen> {
  final descriptionController = TextEditingController();

  late TransactionType type = widget.type;
  String amountText = '';
  String selectedCategory = expenseCategories.first;
  DateTime date = DateTime.now();
  bool dateChanged = false;

  bool get isEditing => widget.transaction != null;
  bool get isExpense => type == TransactionType.expense;

  @override
  void initState() {
    super.initState();

    final transaction = widget.transaction;

    if (transaction != null) {
      amountText = KeypadInput.fromAmount(
        (transaction['amount'] as num).toDouble(),
      );
      descriptionController.text = transaction['description'].toString();
      date = DateTime.parse(transaction['date'].toString());

      if (isExpense) {
        selectedCategory = transaction['category'].toString();
      }
    }
  }

  @override
  void dispose() {
    descriptionController.dispose();
    super.dispose();
  }

  void _onKey(String key) {
    // Typing on the keypad closes the system keyboard if it was open.
    FocusScope.of(context).unfocus();

    setState(() {
      amountText = KeypadInput.apply(amountText, key);
    });
  }

  Future<void> _pickDate() async {
    FocusScope.of(context).unfocus();

    final today = DateUtils.dateOnly(DateTime.now());

    final picked = await showDatePicker(
      context: context,
      initialDate: date.isAfter(today) ? today : date,
      firstDate: DateTime(2000),
      lastDate: today,
    );

    if (picked != null) {
      setState(() {
        date = picked;
        dateChanged = true;
      });
    }
  }

  /// The ISO date to store: now for today, midday for a past day, or the
  /// original timestamp if the date was not changed while editing.
  String _dateToSave() {
    if (isEditing && !dateChanged) {
      return widget.transaction!['date'].toString();
    }

    final now = DateTime.now();

    if (calendarDaysBetween(date, now) == 0) {
      return now.toIso8601String();
    }

    return DateTime(date.year, date.month, date.day, 12).toIso8601String();
  }

  Future<void> _save() async {
    final amount = double.tryParse(amountText) ?? 0;

    if (amount <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Enter an amount first')),
      );
      return;
    }

    final typed = descriptionController.text.trim();
    final description =
        typed.isNotEmpty ? typed : (isExpense ? selectedCategory : 'Income');
    final dateString = _dateToSave();

    if (isExpense) {
      if (isEditing) {
        await DatabaseHelper.updateExpense({
          'id': widget.transaction!['id'],
          'amount': amount,
          'description': description,
          'category': selectedCategory,
          'date': dateString,
        });
      } else {
        await DatabaseHelper.insertExpense(
          Expense(
            amount: amount,
            description: description,
            category: selectedCategory,
            date: DateTime.parse(dateString),
          ).toMap(),
        );
      }
    } else {
      if (isEditing) {
        await DatabaseHelper.updateIncome({
          'id': widget.transaction!['id'],
          'amount': amount,
          'description': description,
          'date': dateString,
        });
      } else {
        await DatabaseHelper.insertIncome(
          Income(
            amount: amount,
            description: description,
            date: DateTime.parse(dateString),
          ).toMap(),
        );
      }
    }

    await AppSync.transactionsChanged();

    if (!mounted) return;

    Navigator.pop(context);
  }

  Future<void> _delete() async {
    if (!await confirmDelete(context)) return;

    final id = widget.transaction!['id'] as int;

    if (isExpense) {
      await DatabaseHelper.deleteExpense(id);
    } else {
      await DatabaseHelper.deleteIncome(id);
    }

    await AppSync.transactionsChanged();

    if (!mounted) return;

    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final noun = isExpense ? 'Expense' : 'Income';
    // The keypad is hidden while the system keyboard is up (typing the
    // description), otherwise the two don't fit on screen together.
    final keyboardOpen = MediaQuery.viewInsetsOf(context).bottom > 0;

    return Scaffold(
      appBar: AppBar(
        title: Text(isEditing ? 'Edit $noun' : 'Add $noun'),
        actions: [
          if (isEditing)
            IconButton(
              tooltip: 'Delete',
              icon: const Icon(Icons.delete_outline_rounded),
              onPressed: _delete,
            ),
        ],
      ),
      body: SafeArea(
        top: false,
        child: Column(
          children: [
            if (!isEditing)
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
                child: _TypeToggle(
                  type: type,
                  onChanged: (value) {
                    setState(() {
                      type = value;
                    });
                  },
                ),
              ),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                children: [
                  const SizedBox(height: 12),
                  _AmountDisplay(
                    text: amountText,
                    color: isExpense ? AppColors.textPrimary : AppColors.income,
                  ),
                  const SizedBox(height: 24),
                  TextField(
                    controller: descriptionController,
                    textCapitalization: TextCapitalization.sentences,
                    textInputAction: TextInputAction.done,
                    decoration: InputDecoration(
                      hintText: isExpense
                          ? 'What was it for? (optional)'
                          : 'Where from? e.g. Salary (optional)',
                      prefixIcon: const Icon(Icons.notes_rounded),
                    ),
                  ),
                  const SizedBox(height: 16),
                  if (isExpense) ...[
                    CategoryPicker(
                      selected: selectedCategory,
                      onChanged: (category) {
                        setState(() {
                          selectedCategory = category;
                        });
                      },
                    ),
                    const SizedBox(height: 16),
                  ],
                  _DateButton(
                    label: formatDayHeader(date),
                    onTap: _pickDate,
                  ),
                  const SizedBox(height: 16),
                ],
              ),
            ),
            if (!keyboardOpen)
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 12),
                child: Column(
                  children: [
                    AmountKeypad(
                      onKey: _onKey,
                      onClear: () {
                        setState(() {
                          amountText = '';
                        });
                      },
                    ),
                    const SizedBox(height: 4),
                    GradientButton(
                      label: isEditing ? 'Update $noun' : 'Save $noun',
                      onPressed: _save,
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _TypeToggle extends StatelessWidget {
  const _TypeToggle({
    required this.type,
    required this.onChanged,
  });

  final TransactionType type;
  final ValueChanged<TransactionType> onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 48,
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: [
          _segment('Expense', TransactionType.expense),
          _segment('Income', TransactionType.income),
        ],
      ),
    );
  }

  Widget _segment(String label, TransactionType value) {
    final selected = type == value;

    return Expanded(
      child: GestureDetector(
        onTap: () => onChanged(value),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          alignment: Alignment.center,
          decoration: BoxDecoration(
            gradient: selected ? AppColors.orangeGradient : null,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Text(
            label,
            style: TextStyle(
              fontWeight: FontWeight.w700,
              color: selected ? Colors.black : AppColors.textSecondary,
            ),
          ),
        ),
      ),
    );
  }
}

class _AmountDisplay extends StatelessWidget {
  const _AmountDisplay({
    required this.text,
    required this.color,
  });

  final String text;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final isEmpty = text.isEmpty;

    return Column(
      children: [
        const Text(
          'Amount',
          style: TextStyle(
            color: AppColors.textSecondary,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 6),
        FittedBox(
          fit: BoxFit.scaleDown,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              const Text(
                '₦',
                style: TextStyle(
                  fontSize: 30,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textSecondary,
                ),
              ),
              const SizedBox(width: 4),
              Text(
                KeypadInput.format(text),
                style: TextStyle(
                  fontSize: 52,
                  fontWeight: FontWeight.w800,
                  letterSpacing: -1.5,
                  color: isEmpty ? AppColors.textMuted : color,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _DateButton extends StatelessWidget {
  const _DateButton({
    required this.label,
    required this.onTap,
  });

  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: const BorderSide(color: AppColors.border),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          child: Row(
            children: [
              const Icon(
                Icons.calendar_today_rounded,
                size: 20,
                color: AppColors.orange,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  label,
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
              ),
              const Icon(
                Icons.chevron_right_rounded,
                color: AppColors.textMuted,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
