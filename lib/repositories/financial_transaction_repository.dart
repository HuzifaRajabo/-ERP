import 'package:sqflite/sqflite.dart';
import '../core/database/database_helper.dart';
import '../models/financial_transaction_model.dart';

class FinancialTransactionRepository {
  Future<Database> get _db async => DatabaseHelper.instance.database;

  Future<int> createTransaction({
    int? invoiceId,
    int? paymentId,
    int? returnId,
    required int partyId,
    required FinancialTransactionType type,
    required FinancialTransactionDirection direction,
    required int amount,
    String? notes,
  }) async {
    final db = await _db;
    return await db.insert('financial_transactions', {
      'invoice_id': invoiceId,
      'payment_id': paymentId,
      'return_id': returnId,
      'party_id': partyId,
      'type': type.dbValue,
      'direction': direction.dbValue,
      'amount': amount,
      'notes': notes,
    });
  }

  Future<void> deleteTransactionsByInvoice(int invoiceId) async {
    final db = await _db;
    await db.delete(
      'financial_transactions',
      where: 'invoice_id = ?',
      whereArgs: [invoiceId],
    );
  }

  Future<void> deleteTransactionsByPayment(int paymentId) async {
    final db = await _db;
    await db.delete(
      'financial_transactions',
      where: 'payment_id = ?',
      whereArgs: [paymentId],
    );
  }

  Future<void> deleteTransactionsByReturn(int returnId) async {
    final db = await _db;
    await db.delete(
      'financial_transactions',
      where: 'return_id = ?',
      whereArgs: [returnId],
    );
  }
}
