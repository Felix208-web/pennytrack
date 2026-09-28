import 'package:flutter/material.dart';

import '../database/database_helper.dart';
import '../models/income.dart';
import '../services/app_sync.dart';
import '../utils/formatters.dart';
import '../widgets/category_picker.dart';
import '../widgets/dialogs.dart';
import '../widgets/gradient_button.dart';

class AddIncomeScreen extends StatefulWidget {
  final Map<String, dynamic>? income;

  const AddIncomeScreen({
    super.key,
    this.income,
  });

  @override
  State<AddIncomeScreen> createState() => _AddIncomeScreenState();
}

class _AddIncomeScreenState extends State<AddIncomeScreen> {
  final amountController = TextEditingController();
  final descriptionController = TextEditingController();

  bool get isEditing => widget.income != null;

  @override
  void initState() {
    super.initState();

    if (widget.income != null) {
      amountController.text = widget.income!['amount'].toString();
      descriptionController.text = widget.income!['description'];
    }
  }

  @override
  void dispose() {
    amountController.dispose();
    descriptionController.dispose();
    super.dispose();
  }

  Future<void> saveIncome() async {
    final amount = parseAmount(amountController.text);
    final description = descriptionController.text.trim();

    if (amount == null || description.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Please enter a valid amount and description',
          ),
        ),
      );
      return;
    }

    if (widget.income != null) {
      await DatabaseHelper.updateIncome({
        'id': widget.income!['id'],
        'amount': amount,
        'description': description,
        'date': widget.income!['date'],
      });
    } else {
      final income = Income(
        amount: amount,
        description: description,
        date: DateTime.now(),
      );

      await DatabaseHelper.insertIncome(
        income.toMap(),
      );
    }

    await AppSync.transactionsChanged();

    if (!mounted) return;

    Navigator.pop(context);
  }

  Future<void> deleteIncome() async {
    if (!await confirmDelete(context)) return;

    await DatabaseHelper.deleteIncome(widget.income!['id']);
    await AppSync.transactionsChanged();

    if (!mounted) return;

    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(isEditing ? 'Edit Income' : 'Add Income'),
        actions: [
          if (isEditing)
            IconButton(
              tooltip: 'Delete',
              icon: const Icon(Icons.delete_outline_rounded),
              onPressed: deleteIncome,
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
              hintText: 'e.g. Salary, Allowance',
            ),
          ),
          const SizedBox(height: 36),
          GradientButton(
            label: isEditing ? 'Update Income' : 'Save Income',
            onPressed: saveIncome,
          ),
        ],
      ),
    );
  }
}
