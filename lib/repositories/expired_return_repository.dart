import 'package:sqflite/sqflite.dart';

import '../core/database/database_helper.dart';
import '../core/database/inventory_stock_sql.dart';
import '../models/expired_return_model.dart';
import '../models/inventory_transaction_model.dart';
import '../models/waste_model.dart';

class ExpiredReturnRepository {
  ExpiredReturnRepository({Future<Database> Function()? dbProvider})
      : _dbProvider =
            dbProvider ?? (() async => DatabaseHelper.instance.database);

  final Future<Database> Function() _dbProvider;

  Future<Database> get _db async => _dbProvider();

  Future<int> createExpiredReturn({
    required int partyId,
    required String partyName,
    required int warehouseId,
    required int compensationAmount,
    String? reason,
    String? notes,
    required List<WasteItemDraft> items,
  }) async {
    if (items.isEmpty) {
      throw Exception('يجب إضافة منتج واحد على الأقل');
    }
    if (compensationAmount < 0) {
      throw Exception('قيمة التعويض لا يمكن أن تكون سالبة');
    }
    for (final item in items) {
      if (item.baseQuantity <= 0) {
        throw Exception('الكمية يجب أن تكون أكبر من صفر');
      }
    }

    final db = await _db;
    return db.transaction<int>((txn) async {
      final party = await txn.query(
        'parties',
        where: 'id = ?',
        whereArgs: [partyId],
        limit: 1,
      );
      if (party.isEmpty) {
        throw Exception('المورد غير موجود');
      }

      for (final item in items) {
        final available = await _batchStock(
          txn,
          batchId: item.batchId,
          warehouseId: warehouseId,
        );
        if (item.baseQuantity > available + 0.0001) {
          throw Exception(
            'الكمية المطلوبة لإرجاع "${item.productName}" '
            'تتجاوز المتاح في الدفعة ($available)',
          );
        }
      }

      final inventoryCost =
          items.fold<int>(0, (sum, item) => sum + item.lineCost);
      final returnNumber = await _nextNumber(txn);
      final expiredReturnId = await txn.insert('expired_returns', {
        'return_number': returnNumber,
        'party_id': partyId,
        'party_name_snapshot': partyName,
        'warehouse_id': warehouseId,
        'inventory_cost': inventoryCost,
        'compensation_amount': compensationAmount,
        'paid_amount': 0,
        'reason': reason?.trim().isEmpty == true ? null : reason?.trim(),
        'notes': notes?.trim().isEmpty == true ? null : notes?.trim(),
      });

      for (final item in items) {
        await txn.insert('expired_return_items', {
          'expired_return_id': expiredReturnId,
          'product_id': item.productId,
          'batch_id': item.batchId,
          'unit_id': item.unitId,
          'product_name_snapshot': item.productName,
          'unit_name_snapshot': item.unitName,
          'batch_number_snapshot': item.batchNumber,
          'expiry_date_snapshot': item.expiryDate,
          'quantity': item.quantity,
          'conversion_factor_snapshot': item.conversionFactor,
          'base_quantity': item.baseQuantity,
          'unit_cost': item.unitCost,
          'line_cost': item.lineCost,
        });
        await txn.insert('inventory_transactions', {
          'product_id': item.productId,
          'type': InventoryTransactionType.expiredReturn.dbValue,
          'quantity': item.baseQuantity,
          'warehouse_id': warehouseId,
          'batch_id': item.batchId,
          'unit_id': item.unitId,
          'expired_return_id': expiredReturnId,
          'notes': reason?.trim(),
        });
      }

      return expiredReturnId;
    });
  }

  Future<List<ExpiredReturnRecord>> getAll() async {
    final db = await _db;
    final rows = await db.rawQuery('''
      SELECT e.*, wh.name AS warehouse_name
      FROM expired_returns e
      LEFT JOIN warehouses wh ON wh.id = e.warehouse_id
      ORDER BY e.id DESC
    ''');
    return rows.map(ExpiredReturnRecord.fromMap).toList();
  }

  Future<ExpiredReturnWithItems?> getById(int id) async {
    final db = await _db;
    final headers = await db.rawQuery(
      '''
      SELECT e.*, wh.name AS warehouse_name
      FROM expired_returns e
      LEFT JOIN warehouses wh ON wh.id = e.warehouse_id
      WHERE e.id = ?
      LIMIT 1
      ''',
      [id],
    );
    if (headers.isEmpty) return null;
    final items = await db.query(
      'expired_return_items',
      where: 'expired_return_id = ?',
      whereArgs: [id],
      orderBy: 'id ASC',
    );
    return ExpiredReturnWithItems(
      record: ExpiredReturnRecord.fromMap(headers.first),
      items: items.map(ExpiredReturnItem.fromMap).toList(),
    );
  }

  Future<double> _batchStock(
    DatabaseExecutor txn, {
    required int batchId,
    required int warehouseId,
  }) async {
    final rows = await txn.rawQuery(
      '''
      SELECT COALESCE(SUM(${InventoryStockSql.signedQuantityCase()}), 0) AS available
      FROM inventory_transactions
      WHERE batch_id = ? AND warehouse_id = ?
      ''',
      [batchId, warehouseId],
    );
    return (rows.first['available'] as num).toDouble();
  }

  Future<String> _nextNumber(DatabaseExecutor txn) async {
    final result =
        await txn.rawQuery('SELECT COUNT(*) as count FROM expired_returns');
    final count = (result.first['count'] as int) + 1;
    return 'EXP-${count.toString().padLeft(4, '0')}';
  }
}
