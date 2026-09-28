import 'package:flutter/material.dart';
import 'database/database_helper.dart';
import 'models/expense.dart';
import 'models/income.dart';
import 'models/recurring_bill.dart';
import 'services/notification_service.dart';

const List<String> expenseCategories = [
  'Food',
  'Transport',
  'Bills',
  'Shopping',
  'Other',
];

List<DropdownMenuItem<String>> categoryDropdownItems() {
  return expenseCategories
      .map(
        (category) => DropdownMenuItem(
          value: category,
          child: Text(category),
        ),
      )
      .toList();
}

String formatNaira(double amount) {
  final digits = amount.abs().toStringAsFixed(0).replaceAllMapped(
        RegExp(r'\B(?=(\d{3})+(?!\d))'),
        (match) => ',',
      );

  return '${amount.round() < 0 ? '-' : ''}₦$digits';
}

/// Parses a user-entered amount, allowing thousands separators.
/// Returns null unless the amount is a positive number.
double? parseAmount(String text) {
  final value = double.tryParse(text.replaceAll(',', '').trim());

  if (value == null || value <= 0) return null;

  return value;
}

String formatExpenseDate(String dateString) {
  final date = DateTime.parse(dateString);
  final now = DateTime.now();

  if (date.year == now.year &&
      date.month == now.month &&
      date.day == now.day) {
    return 'Today';
  }

  final yesterday = now.subtract(const Duration(days: 1));

  if (date.year == yesterday.year &&
      date.month == yesterday.month &&
      date.day == yesterday.day) {
    return 'Yesterday';
  }

  return '${date.day}/${date.month}/${date.year}';
}

IconData getCategoryIcon(String category) {
  switch (category) {
    case 'Food':
      return Icons.restaurant;
    case 'Transport':
      return Icons.directions_bus;
    case 'Bills':
      return Icons.receipt_long;
    case 'Shopping':
      return Icons.shopping_bag;
    default:
      return Icons.more_horiz;
  }
}

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await NotificationService.initialize();

  runApp(const PennyTrackApp());
}

class PennyTrackLogo extends StatelessWidget {
  const PennyTrackLogo({
    super.key,
    this.size = 48,
  });

  final double size;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: Colors.green.shade700,
        borderRadius: BorderRadius.circular(size * 0.25),
      ),
      child: Center(
        child: Text(
          'P',
          style: TextStyle(
            color: Colors.white,
            fontSize: size * 0.6,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }
}

class PennyTrackApp extends StatelessWidget {
  const PennyTrackApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,

      title: 'PennyTrack',

      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: Colors.green,
        ),
        useMaterial3: true,
      ),

      darkTheme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: Colors.green,
          brightness: Brightness.dark,
        ),
        useMaterial3: true,
      ),

      themeMode: ThemeMode.system,

      home: const DashboardScreen(),
    );
  }
}

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  late Future<List<Map<String, dynamic>>> expensesFuture;
  late Future<double> totalExpensesFuture;
  late Future<List<Map<String, dynamic>>> categoryTotalsFuture;
  late Future<double> totalIncomeFuture;
  late Future<List<Map<String, dynamic>>> incomeFuture;
  late Future<double> balanceFuture;

  double monthlyBudget = 100000;
  String searchQuery = '';
  String selectedCategory = 'All';
  Future<void> editBudget() async {
  final controller = TextEditingController(
    text: monthlyBudget.toStringAsFixed(0),
  );

  final newBudget = await showDialog<double>(
    context: context,
    builder: (context) {
      return AlertDialog(
        title: const Text('Set Monthly Budget'),
        content: TextField(
          controller: controller,
          keyboardType: TextInputType.number,
          decoration: const InputDecoration(
            prefixText: '₦',
            hintText: 'Enter budget',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context);
            },
            child: const Text('Cancel'),
          ),
          ElevatedButton(
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

  if (!mounted) return;

  setState(() {
    monthlyBudget = newBudget;
  });

  await NotificationService.checkBudget();
}
}

Future<void> loadSavedBudget() async {
  final savedBudget = await DatabaseHelper.getSavedBudget();

  if (savedBudget != null && mounted) {
    setState(() {
      monthlyBudget = savedBudget;
    });
  }
}

  @override
void initState() {
  super.initState();

  _loadData();
  loadSavedBudget();
  _startup();
}

/// Points every dashboard future at fresh database queries.
void _loadData() {
  expensesFuture = DatabaseHelper.getExpenses();
  totalExpensesFuture = DatabaseHelper.getTotalExpenses();
  totalIncomeFuture = DatabaseHelper.getTotalIncome();
  incomeFuture = DatabaseHelper.getIncome();
  categoryTotalsFuture = DatabaseHelper.getCategoryTotals();
  balanceFuture = DatabaseHelper.getBalance();
}

void refreshDashboard() {
  if (!mounted) return;

  setState(_loadData);
}

Future<void> _startup() async {
  await DatabaseHelper.checkAndResetBudgetAlerts();
  await processRecurringBills();
}

/// Records due recurring bills as expenses, reschedules their reminders,
/// then refreshes the dashboard and re-checks the budget.
Future<void> processRecurringBills() async {
  await DatabaseHelper.processRecurringBills();

  final bills = await DatabaseHelper.getRecurringBills();

  for (final bill in bills) {
    await NotificationService.scheduleBillReminder(
      id: bill['id'] as int,
      description: bill['description'].toString(),
      amount: (bill['amount'] as num).toDouble(),
      dueDate: DateTime.parse(
        bill['nextDueDate'].toString(),
      ),
    );
  }

  await NotificationService.checkBudget();

  refreshDashboard();
}

@override
Widget build(BuildContext context) {
  return Scaffold(
    appBar: AppBar(
      title: Row(
        children: [
          const PennyTrackLogo(size: 36),
          const SizedBox(width: 1),
          const Text(
            'ennyTrack',
            style: TextStyle(
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    ),

    body: FutureBuilder<List<Map<String, dynamic>>>(
      future: expensesFuture,
      builder: (context, snapshot) {
        // Only show the spinner on first load; refreshes keep the old data
        // on screen instead of replacing the whole dashboard.
        if (!snapshot.hasData && !snapshot.hasError) {
          return const Center(
            child: CircularProgressIndicator(),
          );
        }

        if (snapshot.hasError) {
          return Center(
            child: Text(
              'Error loading expenses: ${snapshot.error}',
            ),
          );
        }

        final expenses = snapshot.data ?? [];

        final filteredExpenses = expenses.where((expense) {
          final description =
              expense['description'].toString().toLowerCase();

          final category =
              expense['category'].toString().toLowerCase();

          final matchesSearch =
              description.contains(searchQuery) ||
              category.contains(searchQuery);

          final matchesCategory =
              selectedCategory == 'All' ||
              category == selectedCategory.toLowerCase();

          return matchesSearch && matchesCategory;
        }).toList();

        return SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '${DateTime.now().hour < 12 ? 'Good Morning' : DateTime.now().hour < 17 ? 'Good Afternoon' : 'Good Evening'} 👋',
                style: const TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                ),
              ),

              const SizedBox(height: 6),

              Text(
                'Here’s your financial overview',
                style: TextStyle(
                  color: Colors.grey[600],
                  fontSize: 15,
                ),
              ),

              const SizedBox(height: 24),

              Card(
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Current Balance',
                              style: TextStyle(
                                color: Colors.grey[600],
                              ),
                            ),

                            const SizedBox(height: 8),

                            FutureBuilder<double>(
                              future: balanceFuture,
                              builder: (context, snapshot) {
                                if (!snapshot.hasData) {
                                  return const Text(
                                    '₦...',
                                    style: TextStyle(
                                      fontSize: 32,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  );
                                }

                                return Text(
                                  formatNaira(snapshot.data ?? 0),
                                  style: const TextStyle(
                                    fontSize: 32,
                                    fontWeight: FontWeight.bold,
                                  ),
                                );
                              },
                            ),
                          ],
                        ),
                      ),

                      Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Container(
                            decoration: BoxDecoration(
                              color: Colors.green.shade50,
                              borderRadius:
                                  BorderRadius.circular(20),
                            ),
                            child: TextButton.icon(
                              onPressed: () async {
                                await Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (context) =>
                                        const AddIncomeScreen(),
                                  ),
                                );

                                refreshDashboard();
                              },
                              icon: const Icon(
                                Icons.add,
                                size: 18,
                              ),
                              label: const Text('Add Income'),
                              style: TextButton.styleFrom(
                                padding:
                                    const EdgeInsets.symmetric(
                                  horizontal: 12,
                                  vertical: 6,
                                ),
                                minimumSize: Size.zero,
                                tapTargetSize:
                                    MaterialTapTargetSize.shrinkWrap,
                              ),
                            ),
                          ),

                          const SizedBox(height: 12),

                          Text(
                            'Income this month',
                            style: TextStyle(
                              color: Colors.grey[600],
                              fontSize: 13,
                            ),
                          ),

                          const SizedBox(height: 2),

                          FutureBuilder<double>(
                            future: totalIncomeFuture,
                            builder: (context, snapshot) {
                              if (!snapshot.hasData) {
                                return const Text(
                                  '₦...',
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w600,
                                  ),
                                );
                              }

                              return Text(
                                formatNaira(snapshot.data ?? 0),
                                style: const TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w600,
                                ),
                              );
                            },
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 20),

              const Text(
                'This Month',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),

              const SizedBox(height: 12),

Row(
  crossAxisAlignment: CrossAxisAlignment.start,
  children: [
    Expanded(
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Spent',
                style: TextStyle(
                  color: Colors.grey[600],
                ),
              ),
              const SizedBox(height: 8),
              FutureBuilder<double>(
                future: totalExpensesFuture,
                builder: (context, snapshot) {
                  final total = snapshot.data ?? 0.0;

                  return Text(
                    formatNaira(total),
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  );
                },
              ),
            ],
          ),
        ),
      ),
    ),

    const SizedBox(width: 12),

    Expanded(
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Text(
                    'Budget Left',
                    style: TextStyle(
                      color: Colors.grey[600],
                    ),
                  ),
                  const SizedBox(width: 4),
                  GestureDetector(
                    onTap: editBudget,
                    child: const Icon(
                      Icons.edit_outlined,
                      size: 16,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              FutureBuilder<double>(
                future: totalExpensesFuture,
                builder: (context, snapshot) {
                  final totalSpent = snapshot.data ?? 0.0;
                  final budgetLeft = monthlyBudget - totalSpent;

                  return Text(
                    formatNaira(budgetLeft),
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  );
                },
              ),

            
            ],
          ),
        ),
      ),
    ),
  ],
),

const SizedBox(height: 16),

Text(
  'Monthly Budget',
  style: TextStyle(
    color: Colors.grey[600],
  ),
),

const SizedBox(height: 8),

FutureBuilder<double>(
  future: totalExpensesFuture,
  builder: (context, snapshot) {
    final totalSpent = snapshot.data ?? 0.0;

    final progress = monthlyBudget > 0
        ? (totalSpent / monthlyBudget).clamp(0.0, 1.0)
        : 0.0;

    final percentage = monthlyBudget > 0
        ? (totalSpent / monthlyBudget) * 100
        : 0.0;

    String budgetMessage;

    if (percentage >= 100) {
      budgetMessage = 'Budget exceeded';
    } else if (percentage >= 80) {
      budgetMessage = 'You are close to your budget limit';
    } else {
      budgetMessage = 'You are within your budget';
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        LinearProgressIndicator(
          value: progress,
          minHeight: 8,
        ),

        const SizedBox(height: 6),

        Text(
          '${formatNaira(totalSpent)} of ${formatNaira(monthlyBudget)}',
          style: TextStyle(
            color: Colors.grey[600],
            fontSize: 12,
          ),
        ),

        const SizedBox(height: 6),

        Text(
          budgetMessage,
          style: const TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  },
),

const SizedBox(height: 24),

const Text(
  'Spending by Category',
  style: TextStyle(
    fontSize: 20,
    fontWeight: FontWeight.bold,
  ),
),

const SizedBox(height: 12),

FutureBuilder<List<Map<String, dynamic>>>(
  future: categoryTotalsFuture,
  builder: (context, snapshot) {
    if (!snapshot.hasData || snapshot.data!.isEmpty) {
      return const Text(
        'No spending data yet.',
        style: TextStyle(
          color: Colors.grey,
        ),
      );
    }

    final categories = snapshot.data!;

    final totalCategorySpending = categories.fold<double>(
      0.0,
      (sum, category) =>
          sum + (category['total'] as num).toDouble(),
    );

    return Column(
      children: categories.map((category) {
        final categoryTotal =
            (category['total'] as num).toDouble();

        final percentage = totalCategorySpending > 0
            ? categoryTotal / totalCategorySpending
            : 0.0;

        return Padding(
          padding: const EdgeInsets.only(bottom: 18),
          child: Column(
            children: [
              Row(
                children: [
                  CircleAvatar(
                    radius: 20,
                    child: Icon(
                      getCategoryIcon(category['category']),
                      size: 20,
                    ),
                  ),

                  const SizedBox(width: 12),

                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          category['category'],
                          style: const TextStyle(
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          '${(percentage * 100).round()}%',
                          style: TextStyle(
                            color: Colors.grey[600],
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),

                  Text(
                    formatNaira(categoryTotal),
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 8),

              SizedBox(
  width: double.infinity,
  child: LinearProgressIndicator(
    value: percentage,
    minHeight: 6,
  ),
),
            ],
          ),
        );
      }).toList(),
    );
  },
),

const SizedBox(height: 16),

SizedBox(
  width: double.infinity,
  child: OutlinedButton.icon(
    onPressed: () async {
      await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => const IncomeScreen(),
        ),
      );

      refreshDashboard();
    },
    icon: const Icon(Icons.list_alt),
    label: const Text('View Income'),
  ),
),

const SizedBox(height: 8),

SizedBox(
  width: double.infinity,
  child: OutlinedButton.icon(
    onPressed: () async {
      await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => const RecurringBillsScreen(),
        ),
      );

      // A bill added or edited with a due date of today is recorded now.
      await processRecurringBills();
    },
    icon: const Icon(Icons.repeat),
    label: const Text('Recurring Bills'),
  ),
),

const SizedBox(height: 24),

const Text(
  'Recent Transactions',
  style: TextStyle(
    fontSize: 20,
    fontWeight: FontWeight.bold,
  ),
),

const SizedBox(height: 12),

TextField(
  decoration: InputDecoration(
    hintText: 'Search transactions',
    prefixIcon: const Icon(Icons.search),
    border: OutlineInputBorder(
      borderRadius: BorderRadius.circular(12),
    ),
  ),
  onChanged: (value) {
    setState(() {
      searchQuery = value.toLowerCase();
    });
  },
),

const SizedBox(height: 12),

DropdownButtonFormField<String>(
  initialValue: selectedCategory,
  decoration: InputDecoration(
    labelText: 'Category',
    border: OutlineInputBorder(
      borderRadius: BorderRadius.circular(12),
    ),
  ),
  items: [
    const DropdownMenuItem(
      value: 'All',
      child: Text('All Categories'),
    ),
    ...categoryDropdownItems(),
  ],
  onChanged: (value) {
    setState(() {
      selectedCategory = value!;
    });
  },
),

                const SizedBox(height: 12),

                if (filteredExpenses.isEmpty)
  SizedBox(
    width: double.infinity,
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
      SizedBox(height: 20),
      Icon(
        Icons.receipt_long_outlined,
        size: 48,
      ),
      SizedBox(height: 12),
      Text(
  expenses.isEmpty
      ? 'No expenses yet'
      : 'No matching transactions',
        style: TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.bold,
        ),
      ),
      SizedBox(height: 4),
      Text(
  expenses.isEmpty
      ? 'Start tracking your spending by adding an expense.'
      : 'Try changing your search or category filter.',
  textAlign: TextAlign.center,
  style: TextStyle(
    color: Colors.grey,
  ),
),

const SizedBox(height: 12),

if (expenses.isEmpty)
  ElevatedButton.icon(
  onPressed: () async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => const AddExpenseScreen(),
      ),
    );

    refreshDashboard();
  },
  icon: const Icon(Icons.add),
  label: const Text('Add Expense'),
),
    ],
  )
  )
else
  ...filteredExpenses.map(
    (expense) => ListTile(
    leading: CircleAvatar(
  child: Icon(
    getCategoryIcon(expense['category']),
  ),
),
    title: Text(expense['description']),
    subtitle: Text(
  '${expense['category']} · ${formatExpenseDate(expense['date'])}',
),
    trailing: Row(
  mainAxisSize: MainAxisSize.min,
  children: [
    Text(
      '- ${formatNaira((expense['amount'] as num).toDouble())}',
      style: const TextStyle(
        fontWeight: FontWeight.bold,
      ),
    ),
    IconButton(
      icon: const Icon(Icons.edit_outlined),
      onPressed: () async {
        await Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => AddExpenseScreen(
              expense: expense,
            ),
          ),
        );

        refreshDashboard();
      },
    ),
    IconButton(
      icon: const Icon(Icons.delete_outline),
      onPressed: () async {
  final confirm = await showDialog<bool>(
    context: context,
    builder: (context) {
      return AlertDialog(
        title: const Text('Are you sure you want to delete?'),
        content: const Text(
          'This action cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context, false);
            },
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context, true);
            },
            child: const Text('Delete'),
          ),
        ],
      );
    },
  );

  if (confirm != true) return;

  await DatabaseHelper.deleteExpense(expense['id']);
  await NotificationService.checkBudget();

  refreshDashboard();
},
    ),
  ],
),
  ),
),
              ],
            ),
          );
        },
      ),

      floatingActionButton: FloatingActionButton(
        onPressed: () async {
          await Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => const AddExpenseScreen(),
            ),
          );

          refreshDashboard();
        },
        child: const Icon(Icons.add),
      ),
    );
  }
}

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

  String selectedCategory = 'Food';

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
    final updatedExpense = {
      'id': widget.expense!['id'],
      'amount': amount,
      'description': description,
      'category': selectedCategory,
      'date': widget.expense!['date'],
    };

    await DatabaseHelper.updateExpense(
      updatedExpense,
    );
  }

  await NotificationService.checkBudget();

  if (!mounted) return;

  Navigator.pop(context);
}
  @override
  Widget build(BuildContext context) {
    final isEditing = widget.expense != null;

    return Scaffold(
      appBar: AppBar(
        title: Text(isEditing ? 'Edit Expense' : 'Add Expense'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Amount',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),

            const SizedBox(height: 8),

            TextField(
              controller: amountController,
              keyboardType: TextInputType.number,
              decoration: InputDecoration(
                hintText: 'Enter amount',
                prefixText: '₦ ',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),

            const SizedBox(height: 20),

            const Text(
              'Description',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),

            const SizedBox(height: 8),

            TextField(
              controller: descriptionController,
              decoration: InputDecoration(
                hintText: 'What did you spend on?',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),

            const SizedBox(height: 20),

            const Text(
              'Category',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),

            const SizedBox(height: 8),

            DropdownButtonFormField<String>(
              initialValue: selectedCategory,
              decoration: InputDecoration(
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              items: categoryDropdownItems(),
              onChanged: (value) {
                setState(() {
                  selectedCategory = value!;
                });
              },
            ),

            const Spacer(),

            SizedBox(
              width: double.infinity,
              height: 52,
              child: ElevatedButton(
                onPressed: saveExpense,
                child: Text(
                  isEditing ? 'Update Expense' : 'Save Expense',
                  style: const TextStyle(fontSize: 16),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

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

  @override
  void initState() {
    super.initState();

    if (widget.income != null) {
      amountController.text = widget.income!['amount'].toString();
      descriptionController.text = widget.income!['description'];
    }
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

    if (!mounted) return;

    Navigator.pop(context);
  }

  @override
  void dispose() {
    amountController.dispose();
    descriptionController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isEditing = widget.income != null;

    return Scaffold(
      appBar: AppBar(
        title: Text(
          isEditing ? 'Edit Income' : 'Add Income',
        ),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            TextField(
              controller: amountController,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: 'Amount',
                prefixText: '₦',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: descriptionController,
              decoration: const InputDecoration(
                labelText: 'Description',
                hintText: 'e.g. Allowance',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: saveIncome,
                child: Text(
                  isEditing ? 'Update Income' : 'Save Income',
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class IncomeScreen extends StatefulWidget {
  const IncomeScreen({super.key});

  @override
  State<IncomeScreen> createState() => _IncomeScreenState();
}

class _IncomeScreenState extends State<IncomeScreen> {
  late Future<List<Map<String, dynamic>>> incomeFuture;
  late Future<double> totalIncomeFuture;

  @override
  void initState() {
    super.initState();
    incomeFuture = DatabaseHelper.getIncome();
    totalIncomeFuture = DatabaseHelper.getTotalIncome();
  }

  void refreshIncome() {
    setState(() {
      incomeFuture = DatabaseHelper.getIncome();
      totalIncomeFuture = DatabaseHelper.getTotalIncome();
    });
  }

  Future<void> deleteIncome(int id) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Are you sure you want to delete?'),
          content: const Text(
            'This action cannot be undone.',
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(context, false);
              },
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () {
                Navigator.pop(context, true);
              },
              child: const Text('Delete'),
            ),
          ],
        );
      },
    );

    if (confirm != true) return;

    await DatabaseHelper.deleteIncome(id);

    if (!mounted) return;

    setState(() {
      totalIncomeFuture = DatabaseHelper.getTotalIncome();
      incomeFuture = DatabaseHelper.getIncome();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Income'),
      ),
      body: FutureBuilder<List<Map<String, dynamic>>>(
        future: incomeFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(
              child: CircularProgressIndicator(),
            );
          }

          final income = snapshot.data ?? [];

          if (income.isEmpty) {
            return const Center(
              child: Text('No income recorded yet.'),
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: income.length,
            itemBuilder: (context, index) {
              final item = income[index];

              return ListTile(
                leading: const CircleAvatar(
                  child: Icon(Icons.account_balance_wallet),
                ),
                title: Text(item['description']),
                subtitle: Text(
                  formatExpenseDate(item['date']),
                ),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      '+ ${formatNaira((item['amount'] as num).toDouble())}',
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.edit_outlined),
                      onPressed: () async {
                        await Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => AddIncomeScreen(
                              income: item,
                            ),
                          ),
                        );

                        refreshIncome();
                      },
                    ),
                    IconButton(
                      icon: const Icon(Icons.delete_outline),
                      onPressed: () {
                        deleteIncome(item['id']);
                      },
                    ),
                  ],
                ),
              );
            },
          );
        },
      ),
    );
  }
}
class RecurringBillsScreen extends StatefulWidget {
  const RecurringBillsScreen({super.key});

  @override
  State<RecurringBillsScreen> createState() => _RecurringBillsScreenState();
}

class _RecurringBillsScreenState extends State<RecurringBillsScreen> {
  late Future<List<Map<String, dynamic>>> billsFuture;

  @override
  void initState() {
    super.initState();
    billsFuture = DatabaseHelper.getRecurringBills();
  }

  void refreshBills() {
    setState(() {
      billsFuture = DatabaseHelper.getRecurringBills();
    });
  }

  Future<void> deleteBill(int id) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Are you sure you want to delete?'),
          content: const Text(
            'This action cannot be undone.',
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(context, false);
              },
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () {
                Navigator.pop(context, true);
              },
              child: const Text('Delete'),
            ),
          ],
        );
      },
    );

    if (confirm != true) return;

    await NotificationService.cancelBillReminders(id);

    await DatabaseHelper.deleteRecurringBill(id);

    refreshBills();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Recurring Bills'),
      ),
      body: FutureBuilder<List<Map<String, dynamic>>>(
        future: billsFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(
              child: CircularProgressIndicator(),
            );
          }

          final bills = snapshot.data ?? [];

          if (bills.isEmpty) {
            return const Center(
              child: Text('No recurring bills added yet.'),
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: bills.length,
            itemBuilder: (context, index) {
              final bill = bills[index];

              return ListTile(
                leading: const CircleAvatar(
                  child: Icon(Icons.repeat),
                ),
                title: Text(bill['description']),
                subtitle: Text(
                  '${bill['category']} · ${bill['frequency']}',
                ),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      formatNaira(
                        (bill['amount'] as num).toDouble(),
                      ),
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.edit_outlined),
                      onPressed: () async {
                        await Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => AddRecurringBillScreen(
                              bill: bill,
                            ),
                          ),
                        );

                        refreshBills();
                      },
                    ),
                    IconButton(
                      icon: const Icon(Icons.delete_outline),
                      onPressed: () {
                        deleteBill(bill['id']);
                      },
                    ),
                  ],
                ),
              );
            },
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () async {
          await Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => const AddRecurringBillScreen(),
            ),
          );

          refreshBills();
        },
        child: const Icon(Icons.add),
      ),
    );
  }
}
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

  final bill = {
    'amount': amount,
    'description': description,
    'category': selectedCategory,
    'frequency': selectedFrequency,
    'nextDueDate': selectedDate.toIso8601String(),
    'anchorDay': anchorDay,
  };

  int billId;

  if (widget.bill != null) {
  billId = widget.bill!['id'];

  bill['id'] = billId;

  await DatabaseHelper.updateRecurringBill(bill);
}
  else {
    final recurringBill = RecurringBill(
      amount: amount,
      description: description,
      category: selectedCategory,
      frequency: selectedFrequency,
      nextDueDate: selectedDate,
    );

    billId = await DatabaseHelper.insertRecurringBill(
      recurringBill.toMap(),
    );
  }

  await NotificationService.scheduleBillReminder(
    id: billId,
    description: description,
    amount: amount,
    dueDate: selectedDate,
  );

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
  void dispose() {
    amountController.dispose();
    descriptionController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isEditing = widget.bill != null;

    return Scaffold(
      appBar: AppBar(
        title: Text(
          isEditing ? 'Edit Recurring Bill' : 'Add Recurring Bill',
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            TextField(
              controller: amountController,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: 'Amount',
                prefixText: '₦',
                border: OutlineInputBorder(),
              ),
            ),

            const SizedBox(height: 16),

            TextField(
              controller: descriptionController,
              decoration: const InputDecoration(
                labelText: 'Description',
                hintText: 'e.g. Internet subscription',
                border: OutlineInputBorder(),
              ),
            ),

            const SizedBox(height: 16),

            DropdownButtonFormField<String>(
              initialValue: selectedCategory,
              decoration: const InputDecoration(
                labelText: 'Category',
                border: OutlineInputBorder(),
              ),
              items: categoryDropdownItems(),
              onChanged: (value) {
                if (value != null) {
                  setState(() {
                    selectedCategory = value;
                  });
                }
              },
            ),

            const SizedBox(height: 16),

            DropdownButtonFormField<String>(
              initialValue: selectedFrequency,
              decoration: const InputDecoration(
                labelText: 'Frequency',
                border: OutlineInputBorder(),
              ),
              items: const [
                DropdownMenuItem(
                  value: 'Weekly',
                  child: Text('Weekly'),
                ),
                DropdownMenuItem(
                  value: 'Monthly',
                  child: Text('Monthly'),
                ),
                DropdownMenuItem(
                  value: 'Yearly',
                  child: Text('Yearly'),
                ),
              ],
              onChanged: (value) {
                if (value != null) {
                  setState(() {
                    selectedFrequency = value;
                  });
                }
              },
            ),

            const SizedBox(height: 16),

            ListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Next Due Date'),
              subtitle: Text(
                formatExpenseDate(
                  selectedDate.toIso8601String(),
                ),
              ),
              trailing: OutlinedButton(
                onPressed: pickDate,
                child: const Text('Choose Date'),
              ),
            ),

            const SizedBox(height: 24),

            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: saveBill,
                child: Text(
                  isEditing ? 'Update Bill' : 'Save Bill',
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}