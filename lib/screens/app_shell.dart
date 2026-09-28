import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../services/app_sync.dart';
import '../services/notification_service.dart';
import '../theme/app_colors.dart';
import 'add_transaction_screen.dart';
import 'add_recurring_bill_screen.dart';
import 'bills_screen.dart';
import 'home_screen.dart';
import 'settings_screen.dart';
import 'stats_screen.dart';

/// The main screen: four tabs behind a floating bottom bar with an add
/// button in the middle.
class AppShell extends StatefulWidget {
  const AppShell({super.key});

  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> {
  static const _billsTab = 2;
  static const _settingsTab = 3;

  int currentTab = 0;

  @override
  void initState() {
    super.initState();
    AppSync.startup();
    // No-op if the user already answered the prompt (e.g. in onboarding).
    NotificationService.requestPermission();
  }

  void _selectTab(int index) {
    if (index != currentTab) HapticFeedback.selectionClick();

    setState(() {
      currentTab = index;
    });
  }

  Future<void> _showAddSheet() async {
    HapticFeedback.lightImpact();

    final screen = await showModalBottomSheet<Widget>(
      context: context,
      builder: (context) => const _AddSheet(),
    );

    if (screen == null || !mounted) return;

    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => screen),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // Lets the tabs scroll underneath the floating nav bar.
      extendBody: true,
      body: IndexedStack(
        index: currentTab,
        children: [
          HomeScreen(
            onOpenBills: () => _selectTab(_billsTab),
            onOpenSettings: () => _selectTab(_settingsTab),
          ),
          const StatsScreen(),
          const BillsScreen(),
          const SettingsScreen(),
        ],
      ),
      bottomNavigationBar: _FloatingNavBar(
        currentTab: currentTab,
        onTabSelected: _selectTab,
        onAdd: _showAddSheet,
      ),
    );
  }
}

class _FloatingNavBar extends StatelessWidget {
  const _FloatingNavBar({
    required this.currentTab,
    required this.onTabSelected,
    required this.onAdd,
  });

  final int currentTab;
  final ValueChanged<int> onTabSelected;
  final VoidCallback onAdd;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      minimum: const EdgeInsets.only(bottom: 12),
      child: Container(
        height: 72,
        margin: const EdgeInsets.symmetric(horizontal: 20),
        padding: const EdgeInsets.symmetric(horizontal: 8),
        decoration: BoxDecoration(
          color: AppColors.surfaceHigh,
          borderRadius: BorderRadius.circular(28),
          border: Border.all(color: AppColors.border),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.5),
              blurRadius: 24,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: [
            _NavItem(
              icon: Icons.home_rounded,
              label: 'Home',
              selected: currentTab == 0,
              onTap: () => onTabSelected(0),
            ),
            _NavItem(
              icon: Icons.pie_chart_rounded,
              label: 'Stats',
              selected: currentTab == 1,
              onTap: () => onTabSelected(1),
            ),
            _AddButton(onTap: onAdd),
            _NavItem(
              icon: Icons.repeat_rounded,
              label: 'Bills',
              selected: currentTab == 2,
              onTap: () => onTabSelected(2),
            ),
            _NavItem(
              icon: Icons.settings_rounded,
              label: 'Settings',
              selected: currentTab == 3,
              onTap: () => onTabSelected(3),
            ),
          ],
        ),
      ),
    );
  }
}

class _NavItem extends StatelessWidget {
  const _NavItem({
    required this.icon,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final color = selected ? AppColors.orange : AppColors.textMuted;

    return Semantics(
      button: true,
      selected: selected,
      label: label,
      child: InkResponse(
        onTap: onTap,
        radius: 28,
        child: SizedBox(
          width: 52,
          height: 52,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, color: color, size: 26),
              const SizedBox(height: 4),
              AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                width: selected ? 5 : 0,
                height: 5,
                decoration: const BoxDecoration(
                  color: AppColors.orange,
                  shape: BoxShape.circle,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _AddButton extends StatelessWidget {
  const _AddButton({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: 'Add',
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          width: 56,
          height: 56,
          decoration: BoxDecoration(
            gradient: AppColors.orangeGradient,
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                color: AppColors.orange.withValues(alpha: 0.45),
                blurRadius: 18,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: const Icon(
            Icons.add_rounded,
            color: Colors.black,
            size: 30,
          ),
        ),
      ),
    );
  }
}

/// Bottom sheet asking what to add. Pops with the screen to open.
class _AddSheet extends StatelessWidget {
  const _AddSheet();

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Add new',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 16),
            _AddOption(
              icon: Icons.north_east_rounded,
              color: AppColors.orange,
              title: 'Expense',
              subtitle: 'Something you spent money on',
              onTap: () => Navigator.pop(context, const AddTransactionScreen()),
            ),
            _AddOption(
              icon: Icons.south_west_rounded,
              color: AppColors.income,
              title: 'Income',
              subtitle: 'Salary, allowance, gifts',
              onTap: () => Navigator.pop(
                context,
                const AddTransactionScreen(type: TransactionType.income),
              ),
            ),
            _AddOption(
              icon: Icons.repeat_rounded,
              color: AppColors.category('Bills'),
              title: 'Recurring bill',
              subtitle: 'Rent, data, subscriptions',
              onTap: () =>
                  Navigator.pop(context, const AddRecurringBillScreen()),
            ),
          ],
        ),
      ),
    );
  }
}

class _AddOption extends StatelessWidget {
  const _AddOption({
    required this.icon,
    required this.color,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final IconData icon;
  final Color color;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Material(
        color: AppColors.surfaceHigh,
        borderRadius: BorderRadius.circular(18),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(18),
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Row(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Icon(icon, color: color),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        subtitle,
                        style: const TextStyle(
                          color: AppColors.textSecondary,
                          fontSize: 12,
                        ),
                      ),
                    ],
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
      ),
    );
  }
}
