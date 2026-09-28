import 'package:flutter/material.dart';

import '../database/database_helper.dart';
import '../models/expense.dart';
import '../services/app_sync.dart';
import '../utils/formatters.dart';
import '../widgets/category_picker.dart';
import '../widgets/dialogs.dart';
import '../widgets/gradient_button.dart';

class AddExpenseScreen extends StatefulWidget {
  final Map<String, dynamic>? expense;

  const AddExpenseScreen({
    super.key,
    this.expense,
  });

  @override
  State<AddExpenseScreen> createState() => _AddExpenseScreenState();
}

class _AddExpenseScreenState extends State<AddExpenseScreen> {
  final amountController = TextEditingController();
  final descriptionController = TextEditingController();

  String selectedCategory = expenseCategories.first;

  bool get isEditing => widget.expense != null;

  @override
  void initState() {
    super.initState();

    final expense = widget.expense;

    if (expense != null) {
      amountController.text = expense['amount'].toString();
      descriptionController.text = expense['description'];
      selectedCategory = expense['category'];
    }
  }

  @override
  void dispose() {
    amountController.dispose();
    descriptionController.dispose();
    super.dispose();
  }

  Future<void> saveExpense() async {
    final amount = parseAmount(amountController.text);
    final description = descriptionController.text.trim();

    if (amount == null || description.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please enter a valid amount and description'),
        ),
      );
      return;
    }

    if (widget.expense == null) {
      final expense = Expense(
        amount: amount,
        description: description,
        category: selectedCategory,
        date: DateTime.now(),
      );

      await DatabaseHelper.insertExpense(
        expense.toMap(),
      );
    } else {
      await DatabaseHelper.updateExpense({
        'id': widget.expense!['id'],
        'amount': amount,
        'description': description,
        'category': selectedCategory,
        'date': widget.expense!['date'],
      });
    }

    await AppSync.transactionsChanged();

    if (!mounted) return;

    Navigator.pop(context);
  }

  Future<void> deleteExpense() async {
    if (!await confirmDelete(context)) return;

    await DatabaseHelper.deleteExpense(widget.expense!['id']);
    await AppSync.transactionsChanged();

    if (!mounted) return;

    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(isEditing ? 'Edit Expense' : 'Add Expense'),
        actions: [
          if (isEditing)
            IconButton(
              tooltip: 'Delete',
              icon: const Icon(Icons.delete_outline_rounded),
              onPressed: deleteExpense,
            ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
        children: [
          const FieldLabel('Amount'),
          TextField(
            controller: amountController,
            autofocus: !isEditing,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            style: const TextStyle(
              fontSize: 28,
              fontWeight: FontWeight.w700,
            ),
            decoration: const InputDecoration(
              hintText: '0',
              prefixText: '₦ ',
            ),
          ),
          const SizedBox(height: 20),
          const FieldLabel('Description'),
          TextField(
            controller: descriptionController,
            textCapitalization: TextCapitalization.sentences,
            decoration: const InputDecoration(
              hintText: 'What did you spend on?',
            ),
          ),
          const SizedBox(height: 20),
          const FieldLabel('Category'),
          CategoryPicker(
            selected: selectedCategory,
            onChanged: (category) {
              setState(() {
                selectedCategory = category;
              });
            },
          ),
          const SizedBox(height: 36),
          GradientButton(
            label: isEditing ? 'Update Expense' : 'Save Expense',
            onPressed: saveExpense,
          ),
        ],
      ),
    );
  }
}
