import 'package:flutter/material.dart';

import '../database/database_helper.dart';
import '../services/app_sync.dart';
import '../theme/app_colors.dart';
import '../utils/formatters.dart';
import '../widgets/category_icon.dart';
import '../widgets/empty_state.dart';

/// The Stats tab: this month's spending by category.
/// (The donut chart comes in a later phase.)
class StatsScreen extends StatefulWidget {
  const StatsScreen({super.key});

  @override
  State<StatsScreen> createState() => _StatsScreenState();
}

class _StatsScreenState extends State<StatsScreen> {
  late Future<List<Map<String, dynamic>>> categoriesFuture;

  @override
  void initState() {
    super.initState();
    categoriesFuture = DatabaseHelper.getCategoryTotals();
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
      categoriesFuture = DatabaseHelper.getCategoryTotals();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Spending'),
      ),
      body: FutureBuilder<List<Map<String, dynamic>>>(
        future: categoriesFuture,
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return const Center(
              child: CircularProgressIndicator(),
            );
          }

          final categories = snapshot.data!;

          if (categories.isEmpty) {
            return const Center(
              child: EmptyState(
                icon: Icons.pie_chart_outline_rounded,
                title: 'No spending this month',
                message: 'Your spending by category will show up here.',
              ),
            );
          }

          final total = categories.fold<double>(
            0,
            (sum, category) => sum + (category['total'] as num).toDouble(),
          );

          return ListView(
            padding: const EdgeInsets.fromLTRB(20, 4, 20, 120),
            children: [
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Spent this month',
                        style: TextStyle(color: AppColors.textSecondary),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        formatNaira(total),
                        style: const TextStyle(
                          fontSize: 32,
                          fontWeight: FontWeight.w800,
                          letterSpacing: -1,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 24),
              const Text(
                'By category',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 16),
              ...categories.map((category) {
                final name = category['category'].toString();
                final amount = (category['total'] as num).toDouble();
                final share = total > 0 ? amount / total : 0.0;

                return Padding(
                  padding: const EdgeInsets.only(bottom: 18),
                  child: _CategoryRow(
                    name: name,
                    amount: amount,
                    share: share,
                  ),
                );
              }),
            ],
          );
        },
      ),
    );
  }
}

class _CategoryRow extends StatelessWidget {
  const _CategoryRow({
    required this.name,
    required this.amount,
    required this.share,
  });

  final String name;
  final double amount;
  final double share;

  @override
  Widget build(BuildContext context) {
    final color = AppColors.category(name);

    return Row(
      children: [
        CategoryIcon(category: name, size: 42),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      name,
                      style: const TextStyle(fontWeight: FontWeight.w600),
                    ),
                  ),
                  Text(
                    formatNaira(amount),
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(6),
                      child: LinearProgressIndicator(
                        value: share,
                        minHeight: 6,
                        color: color,
                        backgroundColor: AppColors.surfaceHigh,
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  SizedBox(
                    width: 38,
                    child: Text(
                      '${(share * 100).round()}%',
                      textAlign: TextAlign.right,
                      style: const TextStyle(
                        color: AppColors.textSecondary,
                        fontSize: 12,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }
}
