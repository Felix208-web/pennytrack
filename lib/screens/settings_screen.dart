import 'package:flutter/material.dart';

import '../database/database_helper.dart';
import '../services/app_sync.dart';
import '../services/notification_service.dart';
import '../theme/app_colors.dart';
import '../utils/formatters.dart';
import '../widgets/dialogs.dart';
import '../widgets/pennytrack_logo.dart';
import 'home_screen.dart' show defaultMonthlyBudget;

/// The Settings tab: profile, budget, notifications and data.
class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  String name = '';
  double budget = defaultMonthlyBudget;
  bool notificationsEnabled = NotificationService.isEnabledByUser;

  @override
  void initState() {
    super.initState();
    _load();
    AppSync.changes.addListener(_load);
  }

  @override
  void dispose() {
    AppSync.changes.removeListener(_load);
    super.dispose();
  }

  Future<void> _load() async {
    final savedName = await DatabaseHelper.getSetting('user_name');
    final savedBudget = await DatabaseHelper.getSavedBudget();

    if (!mounted) return;

    setState(() {
      name = savedName ?? '';
      budget = savedBudget ?? defaultMonthlyBudget;
      notificationsEnabled = NotificationService.isEnabledByUser;
    });
  }

  Future<void> _toggleNotifications(bool enabled) async {
    setState(() {
      notificationsEnabled = enabled;
    });

    await NotificationService.setEnabledByUser(enabled);

    if (enabled) {
      // Puts the bill reminders back that were cancelled when turned off.
      await AppSync.syncRecurringBills();
    }
  }

  Future<void> _clearAllData() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Clear all data?'),
          content: const Text(
            'This permanently deletes every expense, income, recurring bill '
            'and your budget from this phone. It cannot be undone.',
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
              child: const Text('Delete everything'),
            ),
          ],
        );
      },
    );

    if (confirmed != true) return;

    await DatabaseHelper.clearAllData();
    await NotificationService.cancelAll();
    AppSync.notifyChanged();

    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('All data cleared')),
    );
  }

  @override
  Widget build(BuildContext context) {
    final initial = name.isNotEmpty ? name[0].toUpperCase() : '?';

    return Scaffold(
      appBar: AppBar(
        title: const Text('Settings'),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 4, 20, 120),
        children: [
          Card(
            clipBehavior: Clip.antiAlias,
            child: InkWell(
              onTap: () => showEditNameDialog(context, name),
              child: Padding(
                padding: const EdgeInsets.all(18),
                child: Row(
                  children: [
                    Container(
                      width: 56,
                      height: 56,
                      decoration: const BoxDecoration(
                        gradient: AppColors.orangeGradient,
                        shape: BoxShape.circle,
                      ),
                      alignment: Alignment.center,
                      child: Text(
                        initial,
                        style: const TextStyle(
                          color: Colors.black,
                          fontSize: 22,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            name.isNotEmpty ? name : 'Add your name',
                            style: const TextStyle(
                              fontSize: 17,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(height: 2),
                          const Text(
                            'Tap to edit',
                            style: TextStyle(
                              color: AppColors.textSecondary,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const Icon(
                      Icons.edit_outlined,
                      size: 18,
                      color: AppColors.textSecondary,
                    ),
                  ],
                ),
              ),
            ),
          ),
          const _SectionLabel('Preferences'),
          Card(
            clipBehavior: Clip.antiAlias,
            child: Column(
              children: [
                _SettingsTile(
                  icon: Icons.savings_outlined,
                  title: 'Monthly budget',
                  subtitle: formatNaira(budget),
                  onTap: () => showEditBudgetDialog(context, budget),
                ),
                const Divider(height: 1, indent: 60),
                SwitchListTile(
                  secondary: const _TileIcon(
                    Icons.notifications_none_rounded,
                  ),
                  title: const Text(
                    'Notifications',
                    style: TextStyle(fontWeight: FontWeight.w600),
                  ),
                  subtitle: const Text(
                    'Bill reminders and budget alerts',
                    style: TextStyle(
                      color: AppColors.textSecondary,
                      fontSize: 12,
                    ),
                  ),
                  value: notificationsEnabled,
                  onChanged: _toggleNotifications,
                  activeThumbColor: Colors.black,
                  activeTrackColor: AppColors.orange,
                ),
              ],
            ),
          ),
          const _SectionLabel('Data'),
          Card(
            clipBehavior: Clip.antiAlias,
            child: _SettingsTile(
              icon: Icons.delete_forever_outlined,
              iconColor: AppColors.danger,
              title: 'Clear all data',
              subtitle: 'Delete all transactions, bills and your budget',
              onTap: _clearAllData,
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

class _SectionLabel extends StatelessWidget {
  const _SectionLabel(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 24, 4, 10),
      child: Text(
        text.toUpperCase(),
        style: const TextStyle(
          color: AppColors.textMuted,
          fontSize: 12,
          fontWeight: FontWeight.w700,
          letterSpacing: 1,
        ),
      ),
    );
  }
}

class _TileIcon extends StatelessWidget {
  const _TileIcon(this.icon, {this.color = AppColors.orange});

  final IconData icon;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 36,
      height: 36,
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Icon(icon, color: color, size: 20),
    );
  }
}

class _SettingsTile extends StatelessWidget {
  const _SettingsTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
    this.iconColor = AppColors.orange,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;
  final Color iconColor;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      onTap: onTap,
      leading: _TileIcon(icon, color: iconColor),
      title: Text(
        title,
        style: const TextStyle(fontWeight: FontWeight.w600),
      ),
      subtitle: Text(
        subtitle,
        style: const TextStyle(
          color: AppColors.textSecondary,
          fontSize: 12,
        ),
      ),
      trailing: const Icon(
        Icons.chevron_right_rounded,
        color: AppColors.textMuted,
      ),
    );
  }
}
