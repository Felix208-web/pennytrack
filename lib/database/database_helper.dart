import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';

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
      version: 4,
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
            nextDueDate TEXT NOT NULL
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

  static Future<double> getTotalExpenses() async {
    final database = await DatabaseHelper.database;

    final now = DateTime.now();

    final startOfMonth = DateTime(
      now.year,
      now.month,
      1,
    );

    final result = await database.rawQuery(
      '''
      SELECT SUM(amount) as total
      FROM expenses
      WHERE date >= ?
      ''',
      [startOfMonth.toIso8601String()],
    );

    return (result.first['total'] as num?)?.toDouble() ?? 0.0;
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

  static Future<List<Map<String, dynamic>>> getCategoryTotals() async {
    final database = await DatabaseHelper.database;

    final now = DateTime.now();

    final startOfMonth = DateTime(
      now.year,
      now.month,
      1,
    );

    return await database.rawQuery(
      '''
      SELECT category, SUM(amount) as total
      FROM expenses
      WHERE date >= ?
      GROUP BY category
      ORDER BY total DESC
      ''',
      [startOfMonth.toIso8601String()],
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

  static Future<double> getTotalIncome() async {
    final database = await DatabaseHelper.database;

    final now = DateTime.now();

    final startOfMonth = DateTime(
      now.year,
      now.month,
      1,
    );

    final result = await database.rawQuery(
      '''
      SELECT SUM(amount) as total
      FROM income
      WHERE date >= ?
      ''',
      [startOfMonth.toIso8601String()],
    );

    return (result.first['total'] as num?)?.toDouble() ?? 0.0;
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
  
  static Future<void> processRecurringBills() async {
  final database = await DatabaseHelper.database;

  final now = DateTime.now();

  final bills = await database.query(
    'recurring_bills',
    where: 'nextDueDate <= ?',
    whereArgs: [now.toIso8601String()],
  );

  for (final bill in bills) {
    await database.insert(
      'expenses',
      {
        'amount': bill['amount'],
        'description': bill['description'],
        'category': bill['category'],
        'date': now.toIso8601String(),
      },
    );

    final currentDueDate = DateTime.parse(
      bill['nextDueDate'].toString(),
    );

    DateTime nextDueDate;

    switch (bill['frequency']) {
      case 'Weekly':
        nextDueDate = currentDueDate.add(
          const Duration(days: 7),
        );
        break;

      case 'Yearly':
        nextDueDate = DateTime(
          currentDueDate.year + 1,
          currentDueDate.month,
          currentDueDate.day,
        );
        break;

      case 'Monthly':
      default:
        nextDueDate = DateTime(
          currentDueDate.year,
          currentDueDate.month + 1,
          currentDueDate.day,
        );
        break;
    }

    await database.update(
      'recurring_bills',
      {
        'nextDueDate': nextDueDate.toIso8601String(),
      },
      where: 'id = ?',
      whereArgs: [bill['id']],
    );
  }
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