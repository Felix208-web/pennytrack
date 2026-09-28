import 'package:flutter/material.dart';

import '../database/database_helper.dart';
import '../services/app_sync.dart';
import '../theme/app_colors.dart';
import '../utils/formatters.dart';
import '../widgets/category_icon.dart';
import '../widgets/donut_chart.dart';
import '../widgets/empty_state.dart';
import 'transactions_screen.dart';

class _StatsData {
  const _StatsData({
    required this.income,
    required this.spent,
    required this.categories,
  });

  final double income;
  final double spent;
  final List<Map<String, dynamic>> categories;
}

/// The Stats tab: a month's income, spending and spending by category.
class StatsScreen extends StatefulWidget {
  const StatsScreen({super.key});

  @override
  State<StatsScreen> createState() => _StatsScreenState();
}

class _StatsScreenState extends State<StatsScreen> {
  DateTime month = _firstOfMonth(DateTime.now());
  late Future<_StatsData> dataFuture;

  static DateTime _firstOfMonth(DateTime date) =>
      DateTime(date.year, date.month);

  bool get _isCurrentMonth => month == _firstOfMonth(DateTime.now());

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

  Future<_StatsData> _load() async {
    final results = await Future.wait([
      DatabaseHelper.getTotalIncome(month: month),
      DatabaseHelper.getTotalExpenses(month: month),
      DatabaseHelper.getCategoryTotals(month: month),
    ]);

    return _StatsData(
      income: results[0] as double,
      spent: results[1] as double,
      categories: results[2] as List<Map<String, dynamic>>,
    );
  }

  void _changeMonth(int delta) {
    setState(() {
      month = DateTime(month.year, month.month + delta);
      dataFuture = _load();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Stats'),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 4, 20, 120),
        children: [
          _MonthSelector(
            label: formatMonthYear(month),
            onPrevious: () => _changeMonth(-1),
            onNext: _isCurrentMonth ? null : () => _changeMonth(1),
          ),
          const SizedBox(height: 16),
          FutureBuilder<_StatsData>(
            future: dataFuture,
            builder: (context, snapshot) {
              if (!snapshot.hasData) {
                return const Padding(
                  padding: EdgeInsets.only(top: 80),
                  child: Center(child: CircularProgressIndicator()),
                );
              }

              return _StatsBody(data: snapshot.data!);
            },
          ),
        ],
      ),
    );
  }
}

class _MonthSelector extends StatelessWidget {
  const _MonthSelector({
    required this.label,
    required this.onPrevious,
    required this.onNext,
  });

  final String label;
  final VoidCallback onPrevious;
  final VoidCallback? onNext;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: [
          IconButton(
            tooltip: 'Previous month',
            icon: const Icon(Icons.chevron_left_rounded),
            onPressed: onPrevious,
          ),
          Expanded(
            child: Text(
              label,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          IconButton(
            tooltip: 'Next month',
            icon: const Icon(Icons.chevron_right_rounded),
            onPressed: onNext,
          ),
        ],
      ),
    );
  }
}

class _StatsBody extends StatelessWidget {
  const _StatsBody({required this.data});

  final _StatsData data;

  @override
  Widget build(BuildContext context) {
    final saved = data.income - data.spent;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: _SummaryTile(
                label: 'Income',
                value: formatNaira(data.income),
                color: AppColors.income,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _SummaryTile(
                label: 'Spent',
                value: formatNaira(data.spent),
                color: AppColors.orange,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _SummaryTile(
                label: saved >= 0 ? 'Saved' : 'Overspent',
                value: formatNaira(saved.abs()),
                color: saved >= 0 ? AppColors.textPrimary : AppColors.danger,
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        if (data.categories.isEmpty)
          const Card(
            child: SizedBox(
              width: double.infinity,
              child: EmptyState(
                icon: Icons.pie_chart_outline_rounded,
                title: 'No spending this month',
                message: 'Your spending by category will show up here.',
              ),
            ),
          )
        else ...[
          _ChartCard(data: data),
          const SizedBox(height: 24),
          const Text(
            'By category',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 12),
          ...data.categories.map((category) {
            final name = category['category'].toString();
            final amount = (category['total'] as num).toDouble();

            return _CategoryRow(
              name: name,
              amount: amount,
              share: data.spent > 0 ? amount / data.spent : 0,
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) =>
                      TransactionsScreen(initialFilter: name),
                ),
              ),
            );
          }),
        ],
      ],
    );
  }
}

class _SummaryTile extends StatelessWidget {
  const _SummaryTile({
    required this.label,
    required this.value,
    required this.color,
  });

  final String label;
  final String value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: const TextStyle(
                color: AppColors.textSecondary,
                fontSize: 12,
              ),
            ),
            const SizedBox(height: 4),
            FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerLeft,
              child: Text(
                value,
                style: TextStyle(
                  color: color,
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ChartCard extends StatelessWidget {
  const _ChartCard({required this.data});

  final _StatsData data;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 24, 20, 20),
        child: Column(
          children: [
            DonutChart(
              segments: data.categories
                  .map(
                    (category) => DonutSegment(
                      value: (category['total'] as num).toDouble(),
                      color: AppColors.category(category['category'].toString()),
                    ),
                  )
                  .toList(),
              center: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text(
                    'Total spent',
                    style: TextStyle(
                      color: AppColors.textSecondary,
                      fontSize: 12,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 44),
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Text(
                        formatNaira(data.spent),
                        style: const TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
            Wrap(
              alignment: WrapAlignment.center,
              spacing: 14,
              runSpacing: 8,
              children: data.categories.map((category) {
                final name = category['category'].toString();

                return Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 10,
                      height: 10,
                      decoration: BoxDecoration(
                        color: AppColors.category(name),
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      name,
                      style: const TextStyle(
                        fontSize: 12,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                );
              }).toList(),
            ),
          ],
        ),
      ),
    );
  }
}

class _CategoryRow extends StatelessWidget {
  const _CategoryRow({
    required this.name,
    required this.amount,
    required this.share,
    required this.onTap,
  });

  final String name;
  final double amount;
  final double share;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final color = AppColors.category(name);

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 9, horizontal: 4),
        child: Row(
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
                          child: TweenAnimationBuilder<double>(
                            tween: Tween(begin: 0, end: share),
                            duration: const Duration(milliseconds: 700),
                            curve: Curves.easeOutCubic,
                            builder: (context, value, _) {
                              return LinearProgressIndicator(
                                value: value,
                                minHeight: 6,
                                color: color,
                                backgroundColor: AppColors.surfaceHigh,
                              );
                            },
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
            const SizedBox(width: 4),
            const Icon(
              Icons.chevron_right_rounded,
              color: AppColors.textMuted,
              size: 20,
            ),
          ],
        ),
      ),
    );
  }
}
