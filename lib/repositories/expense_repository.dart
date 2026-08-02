import 'package:sqflite/sqflite.dart';
import '../core/database/database_helper.dart';
import '../models/expense_model.dart';

class ExpenseRepository {
  Future<Database> get _db async => DatabaseHelper.instance.database;

  static const int _defaultPageSize = 20;

  Future<ExpensePage> getAllExpenses({
    int? lastId,
    int pageSize = _defaultPageSize,
  }) async {
    final db = await _db;

    final whereClauses = <String>[];
    final whereArgs = <dynamic>[];

    if (lastId != null) {
      whereClauses.add('id < ?');
      whereArgs.add(lastId);
    }

    final result = await db.query(
      'expenses',
      orderBy: 'id DESC',
      where: whereClauses.isEmpty ? null : whereClauses.join(' AND '),
      whereArgs: whereArgs.isEmpty ? null : whereArgs,
      limit: pageSize + 1,
    );

    final hasNextPage = result.length > pageSize;
    final items = hasNextPage ? result.sublist(0, pageSize) : result;

    return ExpensePage(
      expenses: items.map((e) => ExpenseModel.fromMap(e)).toList(),
      hasNextPage: hasNextPage,
      nextCursor: hasNextPage && items.isNotEmpty
          ? items.last['id'] as int
          : null,
    );
  }

  Future<ExpenseModel?> getExpenseById(int id) async {
    final db = await _db;
    final result = await db.query(
      'expenses',
      where: 'id = ?',
      whereArgs: [id],
      limit: 1,
    );
    return result.isEmpty ? null : ExpenseModel.fromMap(result.first);
  }

  String _formatDateTimeForSqlite(DateTime dateTime) {
    final value = dateTime.toUtc().toIso8601String().split('.').first;
    return value.replaceFirst('T', ' ');
  }

  Future<int> insertExpense(ExpenseModel expense) async {
    final db = await _db;
    final payload = expense.toMap();

    if (!payload.containsKey('created_at') || payload['created_at'] == null) {
      payload['created_at'] = _formatDateTimeForSqlite(DateTime.now());
    }

    return await db.insert(
      'expenses',
      payload,
      conflictAlgorithm: ConflictAlgorithm.abort,
    );
  }

  Future<int> updateExpense(ExpenseModel expense) async {
    if (expense.id == null) {
      throw Exception('Missing expense id for update');
    }
    final db = await _db;
    return await db.update(
      'expenses',
      expense.toMap(),
      where: 'id = ?',
      whereArgs: [expense.id],
    );
  }

  Future<int> deleteExpense(int id) async {
    final db = await _db;
    return await db.delete('expenses', where: 'id = ?', whereArgs: [id]);
  }
}

class ExpensePage {
  final List<ExpenseModel> expenses;
  final bool hasNextPage;
  final int? nextCursor;

  const ExpensePage({
    required this.expenses,
    required this.hasNextPage,
    this.nextCursor,
  });
}
