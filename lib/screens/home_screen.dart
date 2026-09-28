import 'package:flutter/material.dart';

import '../database/database_helper.dart';
import '../services/app_sync.dart';
import '../theme/app_colors.dart';
import '../utils/formatters.dart';
import '../widgets/dialogs.dart';
import '../widgets/empty_state.dart';
import '../widgets/gradient_card.dart';
import '../widgets/pennytrack_logo.dart';
import '../widgets/section_header.dart';
import '../widgets/transaction_tile.dart';
import 'add_transaction_screen.dart';
import 'transactions_screen.dart';

const double defaultMonthlyBudget = 100000;

class _HomeData {
  const _HomeData({
    required this.balance,
    required this.monthIncome,
    required this.monthSpent,
    required this.budget,
    required this.recent,
    required this.name,
  });

  final double balance;
  final double monthIncome;
  final double monthSpent;
  final double budget;
  final List<Map<String, dynamic>> recent;
  final String name;
}

class HomeScreen extends StatefulWidget {
  const HomeScreen({
    super.key,
    required this.onOpenBills,
    required this.onOpenSettings,
  });

  /// Switches the app to the Bills tab.
  final VoidCallback onOpenBills;

  /// Switches the app to the Settings tab.
  final VoidCallback onOpenSettings;

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  late Future<_HomeData> dataFuture;

  @override
  void initState() {
    super.initState();
    dataFuture = _load();
    AppSync.changes.addListener(_reload);
  }

  @override
  void dispose() {
    AppSync.changes.removeListener(_reload);
    super.dispose();
  }

  void _reload() {
    if (!mounted) return;

    setState(() {
      dataFuture = _load();
    });
  }

  Future<_HomeData> _load() async {
    final results = await Future.wait([
      DatabaseHelper.getBalance(),
      DatabaseHelper.getTotalIncome(),
      DatabaseHelper.getTotalExpenses(),
      DatabaseHelper.getSavedBudget(),
      DatabaseHelper.getTransactions(limit: 5),
      DatabaseHelper.getSetting('user_name'),
    ]);

    return _HomeData(
      balance: results[0] as double,
      monthIncome: results[1] as double,
      monthSpent: results[2] as double,
      budget: (results[3] as double?) ?? defaultMonthlyBudget,
      recent: results[4] as List<Map<String, dynamic>>,
      name: (results[5] as String?) ?? '',
    );
  }

  void _push(Widget screen) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => screen),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: FutureBuilder<_HomeData>(
          future: dataFuture,
          builder: (context, snapshot) {
            if (snapshot.hasError) {
              return Center(
                child: Text('Something went wrong: ${snapshot.error}'),
              );
            }

            // Keeps showing the previous data while a refresh loads.
            if (!snapshot.hasData) {
              return const Center(
                child: CircularProgressIndicator(),
              );
            }

            final data = snapshot.data!;

            return ListView(
              // Bottom padding keeps content clear of the floating nav bar.
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 120),
              children: [
                _Header(
                  name: data.name,
                  onAvatarTap: widget.onOpenSettings,
                ),
                const SizedBox(height: 24),
                _BalanceCard(data: data),
                const SizedBox(height: 24),
                _QuickActions(
                  onExpense: () => _push(const AddTransactionScreen()),
                  onIncome: () => _push(
                    const AddTransactionScreen(type: TransactionType.income),
                  ),
                  onBills: widget.onOpenBills,
                  onBudget: () => showEditBudgetDialog(context, data.budget),
                ),
                const SizedBox(height: 24),
                _BudgetCard(
                  spent: data.monthSpent,
                  budget: data.budget,
                  onEdit: () => showEditBudgetDialog(context, data.budget),
                ),
                const SizedBox(height: 28),
                SectionHeader(
                  title: 'Recent transactions',
                  actionLabel: data.recent.isEmpty ? null : 'View all',
                  onAction: () => _push(const TransactionsScreen()),
                ),
                const SizedBox(height: 8),
                if (data.recent.isEmpty)
                  const EmptyState(
                    icon: Icons.receipt_long_rounded,
                    title: 'No transactions yet',
                    message: 'Tap the + button to add your first expense or income.',
                  )
                else
                  ...data.recent.map(
                    (transaction) => TransactionTile(transaction: transaction),
                  ),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({
    required this.name,
    required this.onAvatarTap,
  });

  final String name;
  final VoidCallback onAvatarTap;

  @override
  Widget build(BuildContext context) {
    final greeting = name.isEmpty
        ? '${greetingForNow()} 👋'
        : '${greetingForNow()}, $name 👋';

    return Row(
      children: [
        const PennyTrackLogo(size: 44),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                greeting,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 2),
              const Text(
                'Here’s your money at a glance',
                style: TextStyle(
                  color: AppColors.textSecondary,
                  fontSize: 13,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: 12),
        Semantics(
          button: true,
          label: 'Settings',
          child: GestureDetector(
            onTap: onAvatarTap,
            child: Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: AppColors.surface,
                shape: BoxShape.circle,
                border: Border.all(color: AppColors.border),
              ),
              alignment: Alignment.center,
              child: name.isEmpty
                  ? const Icon(
                      Icons.person_outline_rounded,
                      color: AppColors.textSecondary,
                    )
                  : Text(
                      name[0].toUpperCase(),
                      style: const TextStyle(
                        fontWeight: FontWeight.w800,
                        color: AppColors.orange,
                      ),
                    ),
            ),
          ),
        ),
      ],
    );
  }
}

class _BalanceCard extends StatelessWidget {
  const _BalanceCard({required this.data});

  final _HomeData data;

  @override
  Widget build(BuildContext context) {
    return GradientCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Total balance',
            style: TextStyle(
              color: Colors.black87,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 6),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            // Counts up from zero on first load, then from the old
            // balance to the new one after each change.
            child: TweenAnimationBuilder<double>(
              tween: Tween(begin: 0, end: data.balance),
              duration: const Duration(milliseconds: 800),
              curve: Curves.easeOutCubic,
              builder: (context, value, _) {
                return Text(
                  formatNaira(value),
                  style: const TextStyle(
                    color: Colors.black,
                    fontSize: 38,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -1,
                  ),
                );
              },
            ),
          ),
          const SizedBox(height: 22),
          Row(
            children: [
              Expanded(
                child: _BalanceStat(
                  icon: Icons.south_west_rounded,
                  label: 'Income',
                  value: formatNaira(data.monthIncome),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _BalanceStat(
                  icon: Icons.north_east_rounded,
                  label: 'Spent',
                  value: formatNaira(data.monthSpent),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _BalanceStat extends StatelessWidget {
  const _BalanceStat({
    required this.icon,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          Container(
            width: 30,
            height: 30,
            decoration: const BoxDecoration(
              color: Colors.black,
              shape: BoxShape.circle,
            ),
            child: Icon(icon, size: 16, color: AppColors.orange),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '$label this month',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Colors.black87,
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerLeft,
                  child: Text(
                    value,
                    style: const TextStyle(
                      color: Colors.black,
                      fontSize: 14,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _QuickActions extends StatelessWidget {
  const _QuickActions({
    required this.onExpense,
    required this.onIncome,
    required this.onBills,
    required this.onBudget,
  });

  final VoidCallback onExpense;
  final VoidCallback onIncome;
  final VoidCallback onBills;
  final VoidCallback onBudget;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        _QuickAction(
          icon: Icons.add_rounded,
          label: 'Expense',
          highlighted: true,
          onTap: onExpense,
        ),
        _QuickAction(
          icon: Icons.south_west_rounded,
          label: 'Income',
          onTap: onIncome,
        ),
        _QuickAction(
          icon: Icons.repeat_rounded,
          label: 'Bills',
          onTap: onBills,
        ),
        _QuickAction(
          icon: Icons.savings_outlined,
          label: 'Budget',
          onTap: onBudget,
        ),
      ],
    );
  }
}

class _QuickAction extends StatelessWidget {
  const _QuickAction({
    required this.icon,
    required this.label,
    required this.onTap,
    this.highlighted = false,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final bool highlighted;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Material(
          color: highlighted ? Colors.white : AppColors.surface,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(22),
            side: highlighted
                ? BorderSide.none
                : const BorderSide(color: AppColors.border),
          ),
          child: InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(22),
            child: SizedBox(
              width: 68,
              height: 68,
              child: Icon(
                icon,
                size: 26,
                color: highlighted ? Colors.black : AppColors.textPrimary,
              ),
            ),
          ),
        ),
        const SizedBox(height: 8),
        Text(
          label,
          style: const TextStyle(
            fontSize: 12,
            color: AppColors.textSecondary,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }
}

class _BudgetCard extends StatelessWidget {
  const _BudgetCard({
    required this.spent,
    required this.budget,
    required this.onEdit,
  });

  final double spent;
  final double budget;
  final VoidCallback onEdit;

  @override
  Widget build(BuildContext context) {
    final ratio = budget > 0 ? spent / budget : 0.0;
    final left = budget - spent;

    final String status;
    final Color statusColor;

    if (ratio >= 1) {
      status = 'Budget exceeded';
      statusColor = AppColors.danger;
    } else if (ratio >= 0.8) {
      status = 'Close to your limit';
      statusColor = AppColors.warning;
    } else {
      status = 'On track';
      statusColor = AppColors.income;
    }

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Expanded(
                  child: Text(
                    'Monthly budget',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: statusColor.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    status,
                    style: TextStyle(
                      color: statusColor,
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                const SizedBox(width: 4),
                IconButton(
                  tooltip: 'Edit budget',
                  visualDensity: VisualDensity.compact,
                  icon: const Icon(Icons.edit_outlined, size: 18),
                  onPressed: onEdit,
                ),
              ],
            ),
            const SizedBox(height: 12),
            _GradientProgressBar(value: ratio.clamp(0.0, 1.0)),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: Text(
                    '${formatNaira(spent)} of ${formatNaira(budget)}',
                    style: const TextStyle(
                      color: AppColors.textSecondary,
                      fontSize: 13,
                    ),
                  ),
                ),
                Text(
                  left >= 0
                      ? '${formatNaira(left)} left'
                      : '${formatNaira(-left)} over',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: left >= 0
                        ? AppColors.textPrimary
                        : AppColors.danger,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _GradientProgressBar extends StatelessWidget {
  const _GradientProgressBar({required this.value});

  /// Between 0 and 1.
  final double value;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 10,
      decoration: BoxDecoration(
        color: AppColors.surfaceHigh,
        borderRadius: BorderRadius.circular(10),
      ),
      alignment: Alignment.centerLeft,
      child: TweenAnimationBuilder<double>(
        tween: Tween(begin: 0, end: value),
        duration: const Duration(milliseconds: 800),
        curve: Curves.easeOutCubic,
        builder: (context, animatedValue, _) {
          return FractionallySizedBox(
            widthFactor: animatedValue,
            child: Container(
              decoration: BoxDecoration(
                gradient: AppColors.orangeGradient,
                borderRadius: BorderRadius.circular(10),
              ),
            ),
          );
        },
      ),
    );
  }
}
