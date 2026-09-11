import 'package:sqflite/sqflite.dart';

import '../core/database/database_helper.dart';
import '../core/database/inventory_stock_sql.dart';
import '../models/inventory_transaction_model.dart';
import '../models/waste_model.dart';

class WasteRepository {
  WasteRepository({Future<Database> Function()? dbProvider})
      : _dbProvider =
            dbProvider ?? (() async => DatabaseHelper.instance.database);

  final Future<Database> Function() _dbProvider;

  Future<Database> get _db async => _dbProvider();

  Future<int> createWaste({
    required int warehouseId,
    required String reason,
    String? notes,
    required List<WasteItemDraft> items,
  }) async {
    if (items.isEmpty) {
      throw Exception('يجب إضافة منتج واحد على الأقل');
    }
    if (reason.trim().isEmpty) {
      throw Exception('يجب إدخال سبب الإتلاف');
    }
    for (final item in items) {
      if (item.baseQuantity <= 0) {
        throw Exception('كمية الإتلاف يجب أن تكون أكبر من صفر');
      }
    }

    final db = await _db;
    return db.transaction<int>((txn) async {
      for (final item in items) {
        final available = await _batchStock(
          txn,
          batchId: item.batchId,
          warehouseId: warehouseId,
        );
        if (item.baseQuantity > available + 0.0001) {
          throw Exception(
            'الكمية المطلوبة لإتلاف "${item.productName}" '
            'تتجاوز المتاح في الدفعة ($available)',
          );
        }
      }

      final totalCost =
          items.fold<int>(0, (sum, item) => sum + item.lineCost);
      final wasteNumber = await _nextNumber(txn);
      final wasteId = await txn.insert('waste_records', {
        'waste_number': wasteNumber,
        'warehouse_id': warehouseId,
        'total_cost': totalCost,
        'reason': reason.trim(),
        'notes': notes?.trim().isEmpty == true ? null : notes?.trim(),
      });

      for (final item in items) {
        await txn.insert('waste_items', {
          'waste_id': wasteId,
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
          'type': InventoryTransactionType.waste.dbValue,
          'quantity': item.baseQuantity,
          'warehouse_id': warehouseId,
          'batch_id': item.batchId,
          'unit_id': item.unitId,
          'waste_id': wasteId,
          'notes': reason.trim(),
        });
      }
      return wasteId;
    });
  }

  Future<List<WasteRecord>> getAll() async {
    final db = await _db;
    final rows = await db.rawQuery('''
      SELECT w.*, wh.name AS warehouse_name
      FROM waste_records w
      LEFT JOIN warehouses wh ON wh.id = w.warehouse_id
      ORDER BY w.id DESC
    ''');
    return rows.map(WasteRecord.fromMap).toList();
  }

  Future<WasteWithItems?> getById(int id) async {
    final db = await _db;
    final headers = await db.rawQuery(
      '''
      SELECT w.*, wh.name AS warehouse_name
      FROM waste_records w
      LEFT JOIN warehouses wh ON wh.id = w.warehouse_id
      WHERE w.id = ?
      LIMIT 1
      ''',
      [id],
    );
    if (headers.isEmpty) return null;
    final items = await db.query(
      'waste_items',
      where: 'waste_id = ?',
      whereArgs: [id],
      orderBy: 'id ASC',
    );
    return WasteWithItems(
      record: WasteRecord.fromMap(headers.first),
      items: items.map(WasteItem.fromMap).toList(),
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
        await txn.rawQuery('SELECT COUNT(*) as count FROM waste_records');
    final count = (result.first['count'] as int) + 1;
    return 'WST-${count.toString().padLeft(4, '0')}';
  }
}
