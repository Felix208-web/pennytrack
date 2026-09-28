import 'package:flutter/material.dart';

import '../database/database_helper.dart';
import '../models/recurring_bill.dart';
import '../services/app_sync.dart';
import '../services/notification_service.dart';
import '../theme/app_colors.dart';
import '../utils/formatters.dart';
import '../widgets/category_picker.dart';
import '../widgets/dialogs.dart';
import '../widgets/gradient_button.dart';

const List<String> billFrequencies = ['Weekly', 'Monthly', 'Yearly'];

class AddRecurringBillScreen extends StatefulWidget {
  final Map<String, dynamic>? bill;

  const AddRecurringBillScreen({
    super.key,
    this.bill,
  });

  @override
  State<AddRecurringBillScreen> createState() =>
      _AddRecurringBillScreenState();
}

class _AddRecurringBillScreenState extends State<AddRecurringBillScreen> {
  final amountController = TextEditingController();
  final descriptionController = TextEditingController();

  String selectedCategory = 'Bills';
  String selectedFrequency = 'Monthly';
  DateTime selectedDate = DateUtils.dateOnly(DateTime.now());
  late int anchorDay = selectedDate.day;

  bool get isEditing => widget.bill != null;

  @override
  void initState() {
    super.initState();

    if (widget.bill != null) {
      amountController.text = widget.bill!['amount'].toString();
      descriptionController.text = widget.bill!['description'];
      selectedCategory = widget.bill!['category'];
      selectedFrequency = widget.bill!['frequency'];
      selectedDate = DateTime.parse(widget.bill!['nextDueDate']);
      anchorDay = (widget.bill!['anchorDay'] as int?) ?? selectedDate.day;
    }
  }

  @override
  void dispose() {
    amountController.dispose();
    descriptionController.dispose();
    super.dispose();
  }

  Future<void> saveBill() async {
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

    if (widget.bill != null) {
      await DatabaseHelper.updateRecurringBill({
        'id': widget.bill!['id'],
        'amount': amount,
        'description': description,
        'category': selectedCategory,
        'frequency': selectedFrequency,
        'nextDueDate': selectedDate.toIso8601String(),
        'anchorDay': anchorDay,
      });
    } else {
      final recurringBill = RecurringBill(
        amount: amount,
        description: description,
        category: selectedCategory,
        frequency: selectedFrequency,
        nextDueDate: selectedDate,
      );

      await DatabaseHelper.insertRecurringBill(
        recurringBill.toMap(),
      );
    }

    // Records the bill now if it is due today, and (re)schedules reminders.
    await AppSync.syncRecurringBills();

    if (!mounted) return;

    Navigator.pop(context);
  }

  Future<void> deleteBill() async {
    if (!await confirmDelete(context)) return;

    final id = widget.bill!['id'] as int;

    await NotificationService.cancelBillReminders(id);
    await DatabaseHelper.deleteRecurringBill(id);
    AppSync.notifyChanged();

    if (!mounted) return;

    Navigator.pop(context);
  }

  Future<void> pickDate() async {
    final today = DateUtils.dateOnly(DateTime.now());

    final pickedDate = await showDatePicker(
      context: context,
      initialDate: selectedDate.isBefore(today) ? today : selectedDate,
      firstDate: today,
      lastDate: DateTime(2100),
    );

    if (pickedDate != null) {
      setState(() {
        selectedDate = pickedDate;
        anchorDay = pickedDate.day;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(isEditing ? 'Edit Bill' : 'Add Recurring Bill'),
        actions: [
          if (isEditing)
            IconButton(
              tooltip: 'Delete',
              icon: const Icon(Icons.delete_outline_rounded),
              onPressed: deleteBill,
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
              hintText: 'e.g. Internet subscription',
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
          const SizedBox(height: 20),
          const FieldLabel('Repeats'),
          SegmentedButton<String>(
            showSelectedIcon: false,
            segments: billFrequencies
                .map(
                  (frequency) => ButtonSegment(
                    value: frequency,
                    label: Text(frequency),
                  ),
                )
                .toList(),
            selected: {selectedFrequency},
            onSelectionChanged: (selection) {
              setState(() {
                selectedFrequency = selection.first;
              });
            },
            style: SegmentedButton.styleFrom(
              selectedBackgroundColor: AppColors.orange,
              selectedForegroundColor: Colors.black,
              side: const BorderSide(color: AppColors.border),
            ),
          ),
          const SizedBox(height: 20),
          const FieldLabel('Next due date'),
          Material(
            color: AppColors.surface,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
              side: const BorderSide(color: AppColors.border),
            ),
            child: ListTile(
              onTap: pickDate,
              leading: const Icon(
                Icons.calendar_today_rounded,
                color: AppColors.orange,
              ),
              title: Text(
                '${selectedDate.day}/${selectedDate.month}/${selectedDate.year}',
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
              subtitle: Text(
                formatDueIn(selectedDate),
                style: const TextStyle(color: AppColors.textSecondary),
              ),
              trailing: const Icon(Icons.chevron_right_rounded),
            ),
          ),
          const SizedBox(height: 36),
          GradientButton(
            label: isEditing ? 'Update Bill' : 'Save Bill',
            onPressed: saveBill,
          ),
        ],
      ),
    );
  }
}
