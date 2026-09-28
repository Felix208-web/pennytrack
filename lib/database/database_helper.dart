import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';

import '../utils/recurrence.dart';

class DatabaseHelper {
  static Database? _database;

  static Future<Database> get database async {
    if (_database != null) {
      return _database!;
    }

    _database = await _initDatabase();
    return _database!;
  }

  static Future<Database> _initDatabase() async {
    final databasePath = await getDatabasesPath();

    final path = join(
      databasePath,
      'pennytrack.db',
    );

    return await openDatabase(
      path,
      version: 5,
      onCreate: (database, version) async {
        await database.execute('''
          CREATE TABLE expenses (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            amount REAL NOT NULL,
            description TEXT NOT NULL,
            category TEXT NOT NULL,
            date TEXT NOT NULL
          )
        ''');

        await database.execute('''
          CREATE TABLE settings (
            key TEXT PRIMARY KEY,
            value TEXT NOT NULL
          )
        ''');

        await database.execute('''
          CREATE TABLE income (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            amount REAL NOT NULL,
            description TEXT NOT NULL,
            date TEXT NOT NULL
          )
        ''');

        await database.execute('''
          CREATE TABLE recurring_bills (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            amount REAL NOT NULL,
            description TEXT NOT NULL,
            category TEXT NOT NULL,
            frequency TEXT NOT NULL,
            nextDueDate TEXT NOT NULL,
            anchorDay INTEGER
          )
        ''');
      },
      onUpgrade: (database, oldVersion, newVersion) async {
        if (oldVersion < 2) {
          await database.execute('''
            CREATE TABLE settings (
              key TEXT PRIMARY KEY,
              value TEXT NOT NULL
            )
          ''');
        }

        if (oldVersion < 3) {
          await database.execute('''
            CREATE TABLE income (
              id INTEGER PRIMARY KEY AUTOINCREMENT,
              amount REAL NOT NULL,
              description TEXT NOT NULL,
              date TEXT NOT NULL
            )
          ''');
        }

        if (oldVersion < 4) {
          await database.execute('''
    CREATE TABLE recurring_bills (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      amount REAL NOT NULL,
      description TEXT NOT NULL,
      category TEXT NOT NULL,
      frequency TEXT NOT NULL,
      nextDueDate TEXT NOT NULL
    )
  ''');
}

        if (oldVersion < 5) {
          await database.execute(
            'ALTER TABLE recurring_bills ADD COLUMN anchorDay INTEGER',
          );
        }
      },
    );
  }

  static Future<int> insertExpense(
    Map<String, dynamic> expense,
  ) async {
    final database = await DatabaseHelper.database;

    return await database.insert(
      'expenses',
      expense,
    );
  }

  static Future<List<Map<String, dynamic>>> getExpenses() async {
    final database = await DatabaseHelper.database;

    return await database.query(
      'expenses',
      orderBy: 'date DESC',
    );
  }

  /// Start (inclusive) and end (exclusive) of [month]'s calendar month
  /// (the current month if null), as ISO strings comparable with the stored
  /// `date` columns.
  static List<String> _monthRange([DateTime? month]) {
    final date = month ?? DateTime.now();

    return [
      DateTime(date.year, date.month, 1).toIso8601String(),
      DateTime(date.year, date.month + 1, 1).toIso8601String(),
    ];
  }

  static Future<double> _sum(
    String table, {
    DateTime? month,
    bool allTime = false,
  }) async {
    final database = await DatabaseHelper.database;

    final result = allTime
        ? await database.rawQuery(
            'SELECT SUM(amount) as total FROM $table',
          )
        : await database.rawQuery(
            'SELECT SUM(amount) as total FROM $table WHERE date >= ? AND date < ?',
            _monthRange(month),
          );

    return (result.first['total'] as num?)?.toDouble() ?? 0.0;
  }

  /// Total spent in [month] (the current month if null).
  static Future<double> getTotalExpenses({DateTime? month}) =>
      _sum('expenses', month: month);

  /// Total income in [month] (the current month if null).
  static Future<double> getTotalIncome({DateTime? month}) =>
      _sum('income', month: month);

  /// All-time income minus all-time expenses.
  static Future<double> getBalance() async {
    final income = await _sum('income', allTime: true);
    final expenses = await _sum('expenses', allTime: true);

    return income - expenses;
  }

  /// Expenses and income together, newest first. Each row has a `type` of
  /// 'expense' or 'income'; income rows use 'Income' as their category.
  static Future<List<Map<String, dynamic>>> getTransactions({
    int? limit,
  }) async {
    final database = await DatabaseHelper.database;

    return await database.rawQuery(
      '''
      SELECT id, amount, description, category, date, 'expense' AS type
      FROM expenses
      UNION ALL
      SELECT id, amount, description, 'Income' AS category, date, 'income' AS type
      FROM income
      ORDER BY date DESC
      ${limit != null ? 'LIMIT $limit' : ''}
      ''',
    );
  }

  static Future<String?> getSetting(String key) async {
    final database = await DatabaseHelper.database;

    final result = await database.query(
      'settings',
      where: 'key = ?',
      whereArgs: [key],
      limit: 1,
    );

    return result.isEmpty ? null : result.first['value'].toString();
  }

  static Future<void> setSetting(String key, String value) async {
    final database = await DatabaseHelper.database;

    await database.insert(
      'settings',
      {
        'key': key,
        'value': value,
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  /// Settings that survive "Clear all data": who the user is and their
  /// preferences, as opposed to their financial data.
  static const _keptSettings = [
    'user_name',
    'onboarding_done',
    'notifications_enabled',
  ];

  /// Deletes every expense, income, recurring bill, the budget and the
  /// budget-alert state.
  static Future<void> clearAllData() async {
    final database = await DatabaseHelper.database;

    await database.transaction((txn) async {
      await txn.delete('expenses');
      await txn.delete('income');
      await txn.delete('recurring_bills');
      await txn.delete(
        'settings',
        where: 'key NOT IN (${List.filled(_keptSettings.length, '?').join(', ')})',
        whereArgs: _keptSettings,
      );
    });
  }

  static Future<void> saveBudget(double budget) async {
    final database = await DatabaseHelper.database;

    await database.insert(
      'settings',
      {
        'key': 'monthly_budget',
        'value': budget.toString(),
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  static Future<bool> getBudgetAlertSent(String alertType) async {
  final database = await DatabaseHelper.database;

  final result = await database.query(
    'settings',
    where: 'key = ?',
    whereArgs: ['budget_alert_$alertType'],
    limit: 1,
  );

  return result.isNotEmpty && result.first['value'] == 'true';
  }

  static Future<void> setBudgetAlertSent(
  String alertType,
  bool sent,
) async {
  final database = await DatabaseHelper.database;

  await database.insert(
    'settings',
    {
      'key': 'budget_alert_$alertType',
      'value': sent.toString(),
    },
    conflictAlgorithm: ConflictAlgorithm.replace,
  );
}

  static Future<void> resetBudgetAlerts() async {
  final database = await DatabaseHelper.database;

  await database.delete(
    'settings',
    where: 'key IN (?, ?)',
    whereArgs: [
      'budget_alert_80',
      'budget_alert_100',
    ],
  );
  }

  static Future<double?> getSavedBudget() async {
    final database = await DatabaseHelper.database;

    final result = await database.query(
      'settings',
      where: 'key = ?',
      whereArgs: ['monthly_budget'],
      limit: 1,
    );

    if (result.isEmpty) {
      return null;
    }

    return double.tryParse(
      result.first['value'].toString(),
    );
  }

  /// Spending per category in [month] (the current month if null),
  /// largest first.
  static Future<List<Map<String, dynamic>>> getCategoryTotals({
    DateTime? month,
  }) async {
    final database = await DatabaseHelper.database;

    return await database.rawQuery(
      '''
      SELECT category, SUM(amount) as total
      FROM expenses
      WHERE date >= ? AND date < ?
      GROUP BY category
      ORDER BY total DESC
      ''',
      _monthRange(month),
    );
  }

  static Future<int> deleteExpense(int id) async {
    final database = await DatabaseHelper.database;

    return await database.delete(
      'expenses',
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  static Future<int> updateExpense(
    Map<String, dynamic> expense,
  ) async {
    final database = await DatabaseHelper.database;

    return await database.update(
      'expenses',
      expense,
      where: 'id = ?',
      whereArgs: [expense['id']],
    );
  }

  static Future<int> insertIncome(
    Map<String, dynamic> income,
  ) async {
    final database = await DatabaseHelper.database;

    return await database.insert(
      'income',
      income,
    );
  }

  static Future<List<Map<String, dynamic>>> getIncome() async {
    final database = await DatabaseHelper.database;

    return await database.query(
      'income',
      orderBy: 'date DESC',
    );
  }

  static Future<int> deleteIncome(int id) async {
    final database = await DatabaseHelper.database;

    return await database.delete(
      'income',
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  static Future<int> updateIncome(
    Map<String, dynamic> income,
  ) async {
    final database = await DatabaseHelper.database;

    return await database.update(
      'income',
      income,
      where: 'id = ?',
      whereArgs: [income['id']],
    );
  }

    static Future<int> insertRecurringBill(
    Map<String, dynamic> bill,
  ) async {
    final database = await DatabaseHelper.database;

    return await database.insert(
      'recurring_bills',
      bill,
    );
  }

  static Future<List<Map<String, dynamic>>> getRecurringBills() async {
    final database = await DatabaseHelper.database;

    return await database.query(
      'recurring_bills',
      orderBy: 'nextDueDate ASC',
    );
  }

  static Future<int> deleteRecurringBill(int id) async {
    final database = await DatabaseHelper.database;

    return await database.delete(
      'recurring_bills',
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  static Future<int> updateRecurringBill(
    Map<String, dynamic> bill,
  ) async {
    final database = await DatabaseHelper.database;

    return await database.update(
      'recurring_bills',
      bill,
      where: 'id = ?',
      whereArgs: [bill['id']],
    );
  }
  
  /// Records an expense for every recurring bill payment that has fallen due,
  /// including several missed periods if the app was not opened for a while,
  /// and moves each bill's next due date forward.
  static Future<void> processRecurringBills() async {
    final database = await DatabaseHelper.database;

    final now = DateTime.now();

    await database.transaction((txn) async {
      final bills = await txn.query(
        'recurring_bills',
        where: 'nextDueDate <= ?',
        whereArgs: [now.toIso8601String()],
      );

      for (final bill in bills) {
        final frequency = bill['frequency'].toString();

        var dueDate = DateTime.parse(
          bill['nextDueDate'].toString(),
        );

        final anchorDay = (bill['anchorDay'] as int?) ?? dueDate.day;

        while (!dueDate.isAfter(now)) {
          await txn.insert(
            'expenses',
            {
              'amount': bill['amount'],
              'description': bill['description'],
              'category': bill['category'],
              'date': dueDate.toIso8601String(),
            },
          );

          dueDate = calculateNextDueDate(dueDate, frequency, anchorDay);
        }

        await txn.update(
          'recurring_bills',
          {
            'nextDueDate': dueDate.toIso8601String(),
            'anchorDay': anchorDay,
          },
          where: 'id = ?',
          whereArgs: [bill['id']],
        );
      }
    });
  }

  static Future<void> checkAndResetBudgetAlerts() async {
  final database = await DatabaseHelper.database;

  final currentMonth =
      '${DateTime.now().year}-${DateTime.now().month}';

  final result = await database.query(
    'settings',
    where: 'key = ?',
    whereArgs: ['budget_alert_month'],
    limit: 1,
  );

  if (result.isEmpty) {
    await database.insert(
      'settings',
      {
        'key': 'budget_alert_month',
        'value': currentMonth,
      },
    );
    return;
  }

  final savedMonth = result.first['value'].toString();

  if (savedMonth != currentMonth) {
    await resetBudgetAlerts();

    await database.update(
      'settings',
      {
        'value': currentMonth,
      },
      where: 'key = ?',
      whereArgs: ['budget_alert_month'],
    );
  }
  }
}