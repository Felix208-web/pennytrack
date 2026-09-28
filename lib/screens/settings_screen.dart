import 'package:flutter/material.dart';

import '../database/database_helper.dart';
import '../services/app_sync.dart';
import '../theme/app_colors.dart';
import '../utils/formatters.dart';
import '../widgets/dialogs.dart';
import '../widgets/pennytrack_logo.dart';
import 'home_screen.dart' show defaultMonthlyBudget;

/// The Settings tab. More options (name, notifications, clearing data)
/// come in a later phase.
class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  double budget = defaultMonthlyBudget;

  @override
  void initState() {
    super.initState();
    _loadBudget();
    AppSync.changes.addListener(_loadBudget);
  }

  @override
  void dispose() {
    AppSync.changes.removeListener(_loadBudget);
    super.dispose();
  }

  Future<void> _loadBudget() async {
    final saved = await DatabaseHelper.getSavedBudget();

    if (!mounted) return;

    setState(() {
      budget = saved ?? defaultMonthlyBudget;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Settings'),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 4, 20, 120),
        children: [
          Card(
            clipBehavior: Clip.antiAlias,
            child: ListTile(
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 16,
                vertical: 6,
              ),
              leading: const Icon(
                Icons.savings_outlined,
                color: AppColors.orange,
              ),
              title: const Text(
                'Monthly budget',
                style: TextStyle(fontWeight: FontWeight.w600),
              ),
              subtitle: Text(
                formatNaira(budget),
                style: const TextStyle(color: AppColors.textSecondary),
              ),
              trailing: const Icon(Icons.chevron_right_rounded),
              onTap: () => showEditBudgetDialog(context, budget),
            ),
          ),
          const SizedBox(height: 40),
          const Center(child: PennyTrackLogo(size: 56)),
          const SizedBox(height: 12),
          const Center(
            child: Text(
              'PennyTrack',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          const SizedBox(height: 4),
          const Center(
            child: Text(
              'Your money, on your phone. Nothing leaves this device.',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: AppColors.textSecondary,
                fontSize: 12,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
