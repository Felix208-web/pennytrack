import 'package:flutter/material.dart';

import '../database/database_helper.dart';
import '../services/app_sync.dart';
import '../theme/app_colors.dart';
import '../utils/formatters.dart';
import '../widgets/empty_state.dart';
import '../widgets/transaction_tile.dart';

/// Every expense and income grouped by day, with search and a filter.
class TransactionsScreen extends StatefulWidget {
  const TransactionsScreen({
    super.key,
    this.initialFilter = 'All',
  });

  /// 'All', 'Income' or an expense category.
  final String initialFilter;

  @override
  State<TransactionsScreen> createState() => _TransactionsScreenState();
}

class _TransactionsScreenState extends State<TransactionsScreen> {
  static const _filters = ['All', 'Income', ...expenseCategories];

  late Future<List<Map<String, dynamic>>> transactionsFuture;

  String searchQuery = '';
  late String selectedFilter = widget.initialFilter;

  @override
  void initState() {
    super.initState();
    transactionsFuture = DatabaseHelper.getTransactions();
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
      transactionsFuture = DatabaseHelper.getTransactions();
    });
  }

  bool _matches(Map<String, dynamic> transaction) {
    final description = transaction['description'].toString().toLowerCase();
    final category = transaction['category'].toString();

    final matchesSearch = searchQuery.isEmpty ||
        description.contains(searchQuery) ||
        category.toLowerCase().contains(searchQuery);

    final matchesFilter =
        selectedFilter == 'All' || category == selectedFilter;

    return matchesSearch && matchesFilter;
  }

  /// Flattens transactions (already newest first) into a list of
  /// [_DayHeader]s, each followed by that day's transactions.
  List<Object> _groupByDay(List<Map<String, dynamic>> transactions) {
    final rows = <Object>[];
    _DayHeader? current;

    for (final transaction in transactions) {
      final date = DateTime.parse(transaction['date'].toString());
      final day = DateTime(date.year, date.month, date.day);

      if (current == null || current.day != day) {
        current = _DayHeader(day);
        rows.add(current);
      }

      final amount = (transaction['amount'] as num).toDouble();

      if (transaction['type'] == 'income') {
        current.income += amount;
      } else {
        current.spent += amount;
      }

      rows.add(transaction);
    }

    return rows;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Transactions'),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 4, 20, 12),
            child: TextField(
              decoration: const InputDecoration(
                hintText: 'Search transactions',
                prefixIcon: Icon(Icons.search_rounded),
              ),
              onChanged: (value) {
                setState(() {
                  searchQuery = value.trim().toLowerCase();
                });
              },
            ),
          ),
          SizedBox(
            height: 40,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 20),
              itemCount: _filters.length,
              separatorBuilder: (context, index) => const SizedBox(width: 8),
              itemBuilder: (context, index) {
                final filter = _filters[index];
                final isSelected = filter == selectedFilter;

                return ChoiceChip(
                  label: Text(filter),
                  selected: isSelected,
                  showCheckmark: false,
                  labelStyle: TextStyle(
                    color: isSelected ? Colors.black : AppColors.textPrimary,
                    fontWeight: FontWeight.w600,
                  ),
                  onSelected: (_) {
                    setState(() {
                      selectedFilter = filter;
                    });
                  },
                );
              },
            ),
          ),
          const SizedBox(height: 8),
          Expanded(
            child: FutureBuilder<List<Map<String, dynamic>>>(
              future: transactionsFuture,
              builder: (context, snapshot) {
                if (!snapshot.hasData) {
                  return const Center(
                    child: CircularProgressIndicator(),
                  );
                }

                final all = snapshot.data!;
                final filtered = all.where(_matches).toList();

                if (filtered.isEmpty) {
                  return Center(
                    child: all.isEmpty
                        ? const EmptyState(
                            icon: Icons.receipt_long_rounded,
                            title: 'No transactions yet',
                            message:
                                'Expenses and income you add will show up here.',
                          )
                        : const EmptyState(
                            icon: Icons.search_off_rounded,
                            title: 'No matching transactions',
                            message:
                                'Try changing your search or filter.',
                          ),
                  );
                }

                final rows = _groupByDay(filtered);

                return ListView.builder(
                  padding: const EdgeInsets.fromLTRB(20, 4, 20, 32),
                  itemCount: rows.length,
                  itemBuilder: (context, index) {
                    final row = rows[index];

                    if (row is _DayHeader) {
                      return _DayHeaderRow(header: row);
                    }

                    return TransactionTile(
                      transaction: row as Map<String, dynamic>,
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _DayHeader {
  _DayHeader(this.day);

  final DateTime day;
  double spent = 0;
  double income = 0;
}

class _DayHeaderRow extends StatelessWidget {
  const _DayHeaderRow({required this.header});

  final _DayHeader header;

  @override
  Widget build(BuildContext context) {
    final totals = [
      if (header.income > 0) '+${formatNaira(header.income)}',
      if (header.spent > 0) '-${formatNaira(header.spent)}',
    ].join('  ');

    return Padding(
      padding: const EdgeInsets.only(top: 16, bottom: 4),
      child: Row(
        children: [
          Expanded(
            child: Text(
              formatDayHeader(header.day),
              style: const TextStyle(
                fontWeight: FontWeight.w700,
                color: AppColors.textSecondary,
              ),
            ),
          ),
          Text(
            totals,
            style: const TextStyle(
              fontSize: 12,
              color: AppColors.textMuted,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}
