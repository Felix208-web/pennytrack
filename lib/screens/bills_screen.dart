import 'package:flutter/material.dart';

import '../database/database_helper.dart';
import '../services/app_sync.dart';
import '../theme/app_colors.dart';
import '../utils/formatters.dart';
import '../widgets/category_icon.dart';
import '../widgets/empty_state.dart';
import 'add_recurring_bill_screen.dart';

/// The Bills tab: recurring bills, soonest first.
class BillsScreen extends StatefulWidget {
  const BillsScreen({super.key});

  @override
  State<BillsScreen> createState() => _BillsScreenState();
}

class _BillsScreenState extends State<BillsScreen> {
  late Future<List<Map<String, dynamic>>> billsFuture;

  @override
  void initState() {
    super.initState();
    billsFuture = DatabaseHelper.getRecurringBills();
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
      billsFuture = DatabaseHelper.getRecurringBills();
    });
  }

  void _openBill([Map<String, dynamic>? bill]) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => AddRecurringBillScreen(bill: bill),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Recurring Bills'),
        actions: [
          IconButton(
            tooltip: 'Add bill',
            icon: const Icon(Icons.add_rounded),
            onPressed: _openBill,
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: FutureBuilder<List<Map<String, dynamic>>>(
        future: billsFuture,
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return const Center(
              child: CircularProgressIndicator(),
            );
          }

          final bills = snapshot.data!;

          if (bills.isEmpty) {
            return const Center(
              child: EmptyState(
                icon: Icons.repeat_rounded,
                title: 'No recurring bills yet',
                message:
                    'Add rent, data or subscriptions and PennyTrack will record them and remind you before they are due.',
              ),
            );
          }

          final monthlyTotal = bills
              .where((bill) => bill['frequency'] == 'Monthly')
              .fold<double>(
                0,
                (sum, bill) => sum + (bill['amount'] as num).toDouble(),
              );

          return ListView(
            // Bottom padding keeps the last card clear of the nav bar.
            padding: const EdgeInsets.fromLTRB(20, 4, 20, 120),
            children: [
              Text(
                '${bills.length} bill${bills.length == 1 ? '' : 's'} · ${formatNaira(monthlyTotal)} monthly',
                style: const TextStyle(color: AppColors.textSecondary),
              ),
              const SizedBox(height: 16),
              ...bills.map(
                (bill) => Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: _BillCard(
                    bill: bill,
                    onTap: () => _openBill(bill),
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _BillCard extends StatelessWidget {
  const _BillCard({
    required this.bill,
    required this.onTap,
  });

  final Map<String, dynamic> bill;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final dueDate = DateTime.parse(bill['nextDueDate'].toString());
    final daysLeft = DateUtils.dateOnly(dueDate)
        .difference(DateUtils.dateOnly(DateTime.now()))
        .inDays;
    final isSoon = daysLeft <= 3;

    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              CategoryIcon(category: bill['category'].toString()),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      bill['description'].toString(),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      bill['frequency'].toString(),
                      style: const TextStyle(
                        color: AppColors.textSecondary,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    formatNaira((bill['amount'] as num).toDouble()),
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 3,
                    ),
                    decoration: BoxDecoration(
                      color: (isSoon ? AppColors.orange : AppColors.surfaceHigh)
                          .withValues(alpha: isSoon ? 0.15 : 1),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      formatDueIn(dueDate),
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: isSoon
                            ? AppColors.orange
                            : AppColors.textSecondary,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
