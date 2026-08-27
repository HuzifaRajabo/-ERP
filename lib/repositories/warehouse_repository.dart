import 'package:sqflite/sqflite.dart';

import '../core/database/database_helper.dart';
import '../models/warehouse_model.dart';

class WarehouseRepository {
  Future<Database> get _db async => DatabaseHelper.instance.database;

  Future<int> insertWarehouse(WarehouseModel warehouse) async {
    try {
      final db = await _db;
      final data = warehouse.toMap()..remove('id');
      if (data['created_at'] == null) data.remove('created_at');
      return await db.insert(
        'warehouses',
        data,
        conflictAlgorithm: ConflictAlgorithm.abort,
      );
    } on DatabaseException catch (e) {
      if (e.isUniqueConstraintError()) {
        throw Exception('يوجد مستودع بهذا الاسم بالفعل');
      }
      throw Exception('خطأ في قاعدة البيانات أثناء إضافة المستودع: $e');
    }
  }

  Future<List<WarehouseModel>> getAllWarehouses({
    bool activeOnly = true,
  }) async {
    final db = await _db;
    final result = await db.query(
      'warehouses',
      where: activeOnly ? 'is_active = 1' : null,
      orderBy: 'is_default DESC, name ASC',
    );
    return result.map((e) => WarehouseModel.fromMap(e)).toList();
  }

  Future<WarehouseModel?> getWarehouseById(int id) async {
    final db = await _db;
    final result = await db.query(
      'warehouses',
      where: 'id = ?',
      whereArgs: [id],
      limit: 1,
    );
    return result.isEmpty ? null : WarehouseModel.fromMap(result.first);
  }

  Future<WarehouseModel?> getDefaultWarehouse() async {
    final db = await _db;
    final result = await db.query(
      'warehouses',
      where: 'is_default = 1',
      limit: 1,
    );
    return result.isEmpty ? null : WarehouseModel.fromMap(result.first);
  }

  Future<int> updateWarehouse(WarehouseModel warehouse) async {
    final db = await _db;
    return await db.update(
      'warehouses',
      warehouse.toMap(),
      where: 'id = ?',
      whereArgs: [warehouse.id],
    );
  }

  /// تعطيل المستودع بدلاً من حذفه (soft delete) لأن حركات مخزون
  /// وفواتير قديمة قد تكون مرتبطة به.
  Future<int> deactivateWarehouse(int id) async {
    final db = await _db;
    return await db.update(
      'warehouses',
      {'is_active': 0},
      where: 'id = ?',
      whereArgs: [id],
    );
  }
}
