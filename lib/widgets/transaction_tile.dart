import 'package:flutter/material.dart';

import '../database/database_helper.dart';
import '../screens/add_expense_screen.dart';
import '../screens/add_income_screen.dart';
import '../services/app_sync.dart';
import '../theme/app_colors.dart';
import '../utils/formatters.dart';
import 'category_icon.dart';
import 'dialogs.dart';

/// One expense or income row from [DatabaseHelper.getTransactions].
/// Tap to edit; swipe left to delete.
class TransactionTile extends StatelessWidget {
  const TransactionTile({
    super.key,
    required this.transaction,
  });

  final Map<String, dynamic> transaction;

  bool get _isIncome => transaction['type'] == 'income';

  Future<void> _edit(BuildContext context) async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => _isIncome
            ? AddIncomeScreen(income: transaction)
            : AddExpenseScreen(expense: transaction),
      ),
    );
  }

  /// Always returns false so the Dismissible never removes the row itself;
  /// the row disappears when the list reloads after [AppSync] fires.
  /// (A dismissed Dismissible that is still in the tree throws.)
  Future<bool> _delete(BuildContext context) async {
    if (!await confirmDelete(context)) return false;

    final id = transaction['id'] as int;

    if (_isIncome) {
      await DatabaseHelper.deleteIncome(id);
    } else {
      await DatabaseHelper.deleteExpense(id);
    }

    await AppSync.transactionsChanged();

    return false;
  }

  @override
  Widget build(BuildContext context) {
    final amount = (transaction['amount'] as num).toDouble();
    final category = transaction['category'].toString();

    return Dismissible(
      key: ValueKey('${transaction['type']}-${transaction['id']}'),
      direction: DismissDirection.endToStart,
      confirmDismiss: (_) => _delete(context),
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 24),
        decoration: BoxDecoration(
          color: AppColors.danger.withValues(alpha: 0.2),
          borderRadius: BorderRadius.circular(18),
        ),
        child: const Icon(
          Icons.delete_outline_rounded,
          color: AppColors.danger,
        ),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () => _edit(context),
          borderRadius: BorderRadius.circular(18),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 4),
            child: Row(
              children: [
                CategoryIcon(category: category),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        transaction['description'].toString(),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        '$category · ${formatExpenseDate(transaction['date'].toString())}',
                        style: const TextStyle(
                          color: AppColors.textSecondary,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                Text(
                  '${_isIncome ? '+' : '-'}${formatNaira(amount)}',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: _isIncome
                        ? AppColors.income
                        : AppColors.textPrimary,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
