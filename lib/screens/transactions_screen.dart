import 'package:flutter/material.dart';

import '../database/database_helper.dart';
import '../services/app_sync.dart';
import '../theme/app_colors.dart';
import '../utils/formatters.dart';
import '../widgets/empty_state.dart';
import '../widgets/transaction_tile.dart';

/// Every expense and income, with search and a category filter.
class TransactionsScreen extends StatefulWidget {
  const TransactionsScreen({super.key});

  @override
  State<TransactionsScreen> createState() => _TransactionsScreenState();
}

class _TransactionsScreenState extends State<TransactionsScreen> {
  static const _filters = ['All', 'Income', ...expenseCategories];

  late Future<List<Map<String, dynamic>>> transactionsFuture;

  String searchQuery = '';
  String selectedFilter = 'All';

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

                return ListView.builder(
                  padding: const EdgeInsets.fromLTRB(20, 4, 20, 32),
                  itemCount: filtered.length,
                  itemBuilder: (context, index) {
                    return TransactionTile(transaction: filtered[index]);
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
